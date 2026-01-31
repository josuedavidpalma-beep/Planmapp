
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/expenses/data/models/expense_model.dart';

class ExpenseRepository {
  final SupabaseClient _supabase;

  ExpenseRepository(this._supabase);

  // Fetch expenses for a plan
  Future<List<Expense>> getExpensesForPlan(String planId) async {
    try {
      final response = await _supabase
          .from('expenses')
          .select('*, expense_items(*, expense_assignments(*)), expense_participant_status(*)')
          .eq('plan_id', planId)
          .order('created_at', ascending: false);

      final List<Expense> parsedList = [];
      
      for (var json in (response as List)) {
          try {
             parsedList.add(Expense.fromJson(json));
          } catch (e) {
             print("ERROR PARSING EXPENSE ${json['id']}: $e");
          }
      }
      return parsedList;
    } catch (e) {
      print("ERROR FETCHING EXPENSES: $e");
      return []; // Return empty list on global failure
    }
  }

  // Create a new expense header
  Future<Expense> createExpense(Map<String, dynamic> expenseData) async {
    try {
      final response = await _supabase
          .from('expenses')
          .insert(expenseData)
          .select()
          .single();

      return Expense.fromJson(response);
    } catch (e) {
      print("ERROR CREATING EXPENSE: $e"); // Debug print
      throw Exception('Failed to create expense: $e');
    }
  }

  // Add items to an expense
  Future<void> addExpenseItems(List<Map<String, dynamic>> itemsData) async {
    try {
      // itemsData should NOT contain 'assignments' key when inserting to expense_items table
      // We need to strip it if present, but usually the UI handles this.
      if (itemsData.isEmpty) return;
      await _supabase.from('expense_items').insert(itemsData);
    } catch (e) {
      throw Exception('Failed to add expense items: $e');
    }
  }

  // Create full expense with items and assignments
  Future<void> createFullExpense({
    required Map<String, dynamic> expenseData,
    required List<Map<String, dynamic>> itemsData, // items contain 'assignments' key with List<AssignmentModel>
  }) async {
    try {
      // 1. Create Expense
      final expenseResponse = await _supabase
          .from('expenses')
          .insert(expenseData)
          .select()
          .single();
      
      final expenseId = expenseResponse['id'] as String;

      // 2. Insert Items One by One
      Map<String, double> userDebts = {}; // UserId -> Amount
      Map<String, double> guestDebts = {}; // GuestName -> Amount

      for (var item in itemsData) {
          final assignments = item['assignments'] as List<AssignmentModel>? ?? [];
          final itemPrice = (item['price'] as num).toDouble(); // Total price of this item line
          
          final itemInsert = Map<String, dynamic>.from(item)..remove('assignments');
          itemInsert['expense_id'] = expenseId;

          final itemRes = await _supabase.from('expense_items').insert(itemInsert).select().single();
          final itemId = itemRes['id'] as String;

          if (assignments.isNotEmpty) {
             // SANITIZE: guest_1 etc. are not valid UUIDs.
             final assignData = assignments.map((a) {
                 final json = a.toJson(itemId);
                 // FIX: Ensure no 'guest_' strings go into user_id column
                 if (json['user_id'] != null && (json['user_id'] as String).startsWith('guest_')) {
                     // Check if guest_name is missing, fallback to the ID itself
                     if (json['guest_name'] == null) {
                         json['guest_name'] = json['user_id']; 
                     }
                     json['user_id'] = null; // Important: Clear the invalid UUID
                 }
                 return json;
             }).toList();

             await _supabase.from('expense_assignments').insert(assignData);
             
             // Calculate Debt
             // Sum of portions assigned
             final totalPortions = assignments.fold(0.0, (sum, a) => sum + a.quantity);
             if (totalPortions > 0) {
                 final costPerPortion = itemPrice / totalPortions;
                 for (var a in assignments) {
                     final debt = costPerPortion * a.quantity;
                     
                     String? finalUserId = a.userId;
                     String? finalGuestName = a.guestName;
                     
                     // Handle mocked guests from UI (guest_1)
                     if (finalUserId != null && finalUserId.startsWith('guest_')) {
                         finalGuestName = a.guestName ?? finalUserId;
                         finalUserId = null;
                     }

                     if (finalUserId != null) {
                         userDebts[finalUserId] = (userDebts[finalUserId] ?? 0) + debt;
                     } else if (finalGuestName != null) {
                         guestDebts[finalGuestName] = (guestDebts[finalGuestName] ?? 0) + debt;
                     }
                 }
             }
          }
      }
      
      // 3. Insert Participant Statuses (Debt)
      final statusInserts = <Map<String, dynamic>>[];
      
      userDebts.forEach((uid, amount) {
          statusInserts.add({
              'expense_id': expenseId,
              'user_id': uid,
              'amount_owed': amount,
              'is_paid': false
          });
      });
      
      guestDebts.forEach((name, amount) {
           statusInserts.add({
              'expense_id': expenseId,
              'guest_name': name,
              'amount_owed': amount,
              'is_paid': false
          });
      });
      
      if (statusInserts.isNotEmpty) {
          await _supabase.from('expense_participant_status').insert(statusInserts);
      }

    } catch (e) {
      throw Exception('Failed to create full expense: $e');
    }
  }
  
  // Update item assignment (Granular)
  Future<void> updateItemAssignments(String itemId, List<AssignmentModel> assignments) async {
     try {
       // 1. Delete existing assignments
       await _supabase.from('expense_assignments').delete().eq('expense_item_id', itemId);

       // 2. Insert new ones
       if (assignments.isNotEmpty) {
           final data = assignments.map((a) => a.toJson(itemId)).toList();
           await _supabase.from('expense_assignments').insert(data);
       }
    } catch (e) {
      throw Exception('Failed to update item assignment: $e');
    }
  }

  // Fetch debts owed TO the current user (where created_by = me)
  Future<List<Map<String, dynamic>>> getReceivables(String planId) async {
      try {
          final currentUid = _supabase.auth.currentUser?.id;
          if (currentUid == null) return [];
          
          // 1. Get my expenses for this plan
          final response = await _supabase
              .from('expense_participant_status')
              .select('*, expenses!inner(title, total_amount, created_by, currency), profiles:user_id(full_name, avatar_url)')
              .eq('expenses.plan_id', planId)
              .eq('expenses.created_by', currentUid)
              .neq('status', 'paid'); // Only show unpaid/pending/reminded
              
          return List<Map<String, dynamic>>.from(response);
      } catch (e) {
          print("ERROR FETCHING RECEIVABLES: $e");
          return [];
      }
  }

  // Mark a specific debt as paid
  Future<void> markDebtAsPaid(String expenseId, String? userId, String? guestName) async {
       try {
           final query = _supabase.from('expense_participant_status')
               .update({'status': 'paid', 'is_paid': true}) // Keep both synced for now
               .eq('expense_id', expenseId);
               
           if (userId != null) {
               await query.eq('user_id', userId);
           } else if (guestName != null) {
               await query.eq('guest_name', guestName);
           }
       } catch (e) {
           throw Exception("Error updating debt: $e");
       }
  }


  Future<void> deleteExpense(String expenseId) async {
      try {
          await _supabase.from('expenses').delete().eq('id', expenseId);
      } catch (e) {
          throw Exception("Error deleting expense: $e");
      }
  }
}
