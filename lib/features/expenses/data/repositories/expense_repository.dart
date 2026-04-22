
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

  // Fetch a single expense by ID including items and assignments
  Future<Expense?> getExpenseById(String expenseId) async {
    try {
      final response = await _supabase
          .from('expenses')
          .select('*, expense_items(*, expense_assignments(*)), expense_participant_status(*)')
          .eq('id', expenseId)
          .maybeSingle();

      if (response == null) return null;
      return Expense.fromJson(response);
    } catch (e) {
      print("ERROR FETCHING EXPENSE BY ID ($expenseId): $e");
      return null;
    }
  }

  // Stream expenses for a plan
  Stream<List<Expense>> getExpensesStream(String planId) {
     return _supabase
        .from('expenses')
        .stream(primaryKey: ['id'])
        .eq('plan_id', planId)
        .order('created_at', ascending: false)
        .map((list) => list.map((json) => Expense.fromJson(json)).toList());
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
      if (itemsData.isEmpty) return;
      await _supabase.from('expense_items').insert(itemsData);
    } catch (e) {
      throw Exception('Failed to add expense items: $e');
    }
  }

  // Create Expense and Items returning the saved state (Pre-Vaca Cold Save)
  Future<Expense> createDraftExpense({
    required Map<String, dynamic> expenseData,
    required List<Map<String, dynamic>> itemsData,
  }) async {
      try {
          final expenseResponse = await _supabase.from('expenses').insert(expenseData).select().single();
          
          final expenseId = expenseResponse['id'] as String;
          final itemsInsert = itemsData.map((e) => {...e, 'expense_id': expenseId}).toList();
          
          if (itemsInsert.isNotEmpty) {
              await _supabase.from('expense_items').insert(itemsInsert);
          }
          
          final fullResponse = await _supabase.from('expenses').select('*, expense_items(*)').eq('id', expenseId).single();
          return Expense.fromJson(fullResponse);
      } catch (e) {
          print("ERROR CREATING DRAFT EXPENSE: $e");
          throw Exception('Failed to create draft expense: $e');
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
      
      // Proportional Tax & Tip Calculation
      final double subtotal = (expenseData['subtotal'] as num?)?.toDouble() ?? 0.0;
      final double tax = (expenseData['tax_amount'] as num?)?.toDouble() ?? 0.0;
      final double tip = (expenseData['tip_amount'] as num?)?.toDouble() ?? 0.0;
      
      if (subtotal > 0 && (tax > 0 || tip > 0)) {
          final taxTipTotal = tax + tip;
          
          userDebts.forEach((uid, amount) {
              final proportion = amount / subtotal;
              userDebts[uid] = amount + (taxTipTotal * proportion);
          });
          
          guestDebts.forEach((name, amount) {
              final proportion = amount / subtotal;
              guestDebts[name] = amount + (taxTipTotal * proportion);
          });
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
  
  // Calculate and Update Debts for an Expense based on actual assignments
  Future<void> calculateAndUpdateDebts(String expenseId) async {
      // Fetch expense + items + assignments
      try {
          final expRes = await _supabase.from('expenses').select('plan_id, title, subtotal, tax_amount, tip_amount').eq('id', expenseId).single();
          final itemsRes = await _supabase.from('expense_items').select('id, price').eq('expense_id', expenseId);
          
          Map<String, double> userDebts = {};
          Map<String, double> guestDebts = {};
          
          for (var item in (itemsRes as List)) {
              final itemId = item['id'];
              final itemPrice = (item['price'] as num).toDouble();
              
              final assignRes = await _supabase.from('expense_assignments').select().eq('expense_item_id', itemId);
              final assignments = (assignRes as List).map((a) => AssignmentModel.fromJson(a)).toList();
              
              final totalPortions = assignments.fold(0.0, (sum, a) => sum + a.quantity);
              if (totalPortions > 0) {
                  final costPerPortion = itemPrice / totalPortions;
                  for (var a in assignments) {
                      final debt = costPerPortion * a.quantity;
                      if (a.userId != null) userDebts[a.userId!] = (userDebts[a.userId!] ?? 0) + debt;
                      else if (a.guestName != null) guestDebts[a.guestName!] = (guestDebts[a.guestName!] ?? 0) + debt;
                  }
              }
          }
          
          final double subtotal = (expRes['subtotal'] as num?)?.toDouble() ?? 0.0;
          final double tax = (expRes['tax_amount'] as num?)?.toDouble() ?? 0.0;
          final double tip = (expRes['tip_amount'] as num?)?.toDouble() ?? 0.0;
          
          if (subtotal > 0 && (tax > 0 || tip > 0)) {
              final taxTipTotal = tax + tip;
              userDebts.forEach((uid, amount) {
                  final proportion = amount / subtotal;
                  userDebts[uid] = amount + (taxTipTotal * proportion);
              });
              guestDebts.forEach((name, amount) {
                  final proportion = amount / subtotal;
                  guestDebts[name] = amount + (taxTipTotal * proportion);
              });
          }
          
          // Delete old statuses and insert new into Unified Ledger
          final planId = expRes['plan_id'];
          final String expenseTitle = expRes['title'] ?? 'Scanner Split';
          
          await _supabase.from('payment_trackers').delete()
               .eq('plan_id', planId)
               .eq('description', expenseTitle);
          
          final trackerInserts = <Map<String, dynamic>>[];
          userDebts.forEach((uid, amount) {
              trackerInserts.add({'plan_id': planId, 'user_id': uid, 'amount_owe': amount, 'status': 'pending', 'description': expenseTitle, 'amount_paid': 0});
          });
          guestDebts.forEach((name, amount) {
               trackerInserts.add({'plan_id': planId, 'guest_name': name, 'amount_owe': amount, 'status': 'pending', 'description': expenseTitle, 'amount_paid': 0});
          });
          
          if (trackerInserts.isNotEmpty) {
              await _supabase.from('payment_trackers').insert(trackerInserts);
          }
      } catch (e) {
         print("Error recalculating debts: $e");
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

  /// NEW: Stream assignments for an entire expense
  Stream<List<Map<String, dynamic>>> getAssignmentsStream(String expenseId) {
    // We join with expense_items to filter by expense_id
    // But since Supabase Realtime doesn't support complex joins easily,
    // we can either filter by a list of item IDs or just listen to the whole table and filter locally.
    // However, the best way for a 'live' feel is listening to the table.
    return _supabase
        .from('expense_assignments')
        .stream(primaryKey: ['id'])
        .map((data) => data); // We will filter this in the UI or fetch item IDs first
  }

  /// NEW: Upsert a single assignment (Granular)
  Future<void> upsertAssignment(String itemId, AssignmentModel assignment) async {
      try {
          final data = assignment.toJson(itemId);
          // If it's a user, we match by user_id and item_id
          // If it's a guest, we match by guest_name and item_id
          if (assignment.userId != null) {
              await _supabase.from('expense_assignments').upsert(data, onConflict: 'expense_item_id,user_id');
          } else {
              await _supabase.from('expense_assignments').upsert(data, onConflict: 'expense_item_id,guest_name');
          }
      } catch (e) {
          throw Exception('Failed to upsert assignment: $e');
      }
  }

  /// NEW: Delete a single assignment (Granular)
  Future<void> deleteAssignment(String itemId, {String? userId, String? guestName}) async {
      try {
          var query = _supabase.from('expense_assignments').delete().eq('expense_item_id', itemId);
          if (userId != null) query = query.eq('user_id', userId);
          if (guestName != null) query = query.eq('guest_name', guestName);
          await query;
      } catch (e) {
          throw Exception('Failed to delete assignment: $e');
      }
  }

  // Fetch debts owed TO the current user (Receivables)
  Future<List<Map<String, dynamic>>> getReceivables(String? planId) async {
      try {
          final currentUid = _supabase.auth.currentUser?.id;
          if (currentUid == null) return [];
          
          var query = _supabase
              .from('payment_trackers')
              .select('id, plan_id, bill_id, user_id, guest_name, amount_owe, amount_paid, status, description, created_at, profiles:user_id(full_name, avatar_url, phone), plans!inner(creator_id)')
              .or('user_id.neq.$currentUid,user_id.is.null') // Definitively exclude my own debts
              .neq('status', 'paid')
              .gt('amount_owe', 0);
              
          if (planId != null) {
              query = query.eq('plan_id', planId);
          }
          
          final response = await query;
          
          // Fetch expenses to determine true creditors for bill splits
          final expenses = await _supabase.from('expenses').select('title, created_by');
          final expenseMap = { for (var e in expenses) e['title'] : e['created_by'] };
          
          final List<Map<String, dynamic>> receivables = [];
          
          for (var pt in response) {
              final String desc = pt['description'] ?? '';
              final bool isVaca = desc == 'Gastos Unificados' || desc == 'Gasto Unificado';
              
              bool isOwedToMe = false;
              if (isVaca) {
                  isOwedToMe = pt['plans']['creator_id'] == currentUid;
              } else {
                  final expenseCreator = expenseMap[desc];
                  isOwedToMe = expenseCreator == currentUid;
              }
              
              if (isOwedToMe) {
                  receivables.add({
                      'expense_id': pt['id'], // use tracker id as mock expense_id for UI logic
                      'user_id': pt['user_id'],
                      'guest_name': pt['guest_name'],
                      'amount_owed': (pt['amount_owe'] as num).toDouble() - (pt['amount_paid'] as num).toDouble(),
                      'status': pt['status'],
                      'profiles': pt['profiles'],
                      'expenses': {
                          'title': desc.isNotEmpty ? desc : 'Gasto',
                          'plan_id': pt['plan_id']
                      }
                  });
              }
          }
          return receivables;
      } catch (e) {
          print("ERROR FETCHING RECEIVABLES: $e");
          return [];
      }
  }

  // Fetch debts the current user owes (Payables)
  Future<List<Map<String, dynamic>>> getPayables(String? planId) async {
      try {
          final currentUid = _supabase.auth.currentUser?.id;
          if (currentUid == null) return [];
          
          var query = _supabase
              .from('payment_trackers')
              .select('id, plan_id, bill_id, user_id, guest_name, amount_owe, amount_paid, status, description, created_at, plans!inner(creator_id, profiles:creator_id(full_name, avatar_url, phone, payment_methods))')
              .eq('user_id', currentUid)
              .neq('status', 'paid')
              .gt('amount_owe', 0);
              
          if (planId != null) {
              query = query.eq('plan_id', planId);
          }
          
          final response = await query;
          
          final expenses = await _supabase.from('expenses').select('title, created_by, profiles:created_by(full_name, avatar_url, phone, payment_methods)');
          final expenseMap = { for (var e in expenses) e['title'] : e };
          
          final List<Map<String, dynamic>> payables = [];
          
          for (var pt in response) {
              final String desc = pt['description'] ?? '';
              final bool isVaca = desc == 'Gastos Unificados' || desc == 'Gasto Unificado';
              
              bool isIOwed = true; 
              dynamic creditorProfile = pt['plans']['profiles'];
              
              if (!isVaca && expenseMap.containsKey(desc)) {
                  final exp = expenseMap[desc]!;
                  if (exp['created_by'] == currentUid) isIOwed = false; // I don't owe it to myself if I paid the bill
                  creditorProfile = exp['profiles'];
              } else {
                  if (pt['plans']['creator_id'] == currentUid) isIOwed = false;
              }
              
              if (isIOwed && creditorProfile != null) {
                  payables.add({
                      'expense_id': pt['id'], // mock
                      'user_id': pt['user_id'],
                      'amount_owed': (pt['amount_owe'] as num).toDouble() - (pt['amount_paid'] as num).toDouble(),
                      'status': pt['status'],
                      'profiles': creditorProfile, // dynamic creditor via expense or plan creator
                      'expenses': {
                          'title': desc.isNotEmpty ? desc : 'Gasto',
                          'plan_id': pt['plan_id']
                      }
                  });
              }
          }
          return payables;
      } catch (e) {
          print("ERROR FETCHING PAYABLES: $e");
          return [];
      }
  }

  // Fetch granular items consumed by a user across multiple expenses
  Future<List<Map<String, dynamic>>> getDebtItemsDetailed(List<String> expenseIds, {String? userId, String? guestName}) async {
      try {
          if (expenseIds.isEmpty) return [];
          
          var query = _supabase
              .from('expense_assignments')
              .select('quantity, expense_items!inner(id, name, price, expense_id)')
              .inFilter('expense_items.expense_id', expenseIds);
              
          if (userId != null) {
              query = query.eq('user_id', userId);
          } else if (guestName != null) {
              query = query.eq('guest_name', guestName);
          }
          
          final response = await query;
          return List<Map<String, dynamic>>.from(response);
      } catch (e) {
          print("ERROR FETCHING DEBT ITEMS: $e");
          return [];
      }
  }

  // Report a payment as a debtor
  Future<void> reportPayment(String expenseId, {String? receiptUrl}) async {
       try {
           final currentUser = _supabase.auth.currentUser;
           if (currentUser == null) throw Exception("No estás autenticado");
           
           await _supabase.from('payment_trackers')
               .update({
                   'status': 'reported',
                   // Note: receipt url may not natively exist in payment_trackers yet, but we can temporarily hijack description or add a schema patch later
               })
               .eq('id', expenseId)
               .eq('user_id', currentUser.id);

           // Notify Creditor
           final pt = await _supabase.from('payment_trackers').select('description, plans!inner(creator_id)').eq('id', expenseId).single();
           final profile = await _supabase.from('profiles').select('full_name, nickname').eq('id', currentUser.id).maybeSingle();
           final senderName = profile?['nickname'] ?? profile?['full_name'] ?? 'Un amigo';

           await _supabase.from('notifications').insert({
               'user_id': pt['plans']['creator_id'],
               'title': '💰 Pago Reportado',
               'body': '$senderName ha marcado como pagada su parte de "${pt['description']}". Confirma si ya recibiste el dinero.',
               'type': 'general',
               'data': {'action': 'payment_reported', 'expense_id': expenseId}
           });
       } catch (e) {
           throw Exception("Error reportando pago: $e");
       }
  }

  // Deny a payment as a creditor
  Future<void> denyPayment(String expenseId, String? userId, String? guestName) async {
       try {
           final query = _supabase.from('payment_trackers')
               .update({'status': 'pending'})
               .eq('id', expenseId);
               
           if (userId != null) {
               await query.eq('user_id', userId);
           } else if (guestName != null) {
               await query.eq('guest_name', guestName);
           }

           if (userId != null) {
               final pt = await _supabase.from('payment_trackers').select('description').eq('id', expenseId).single();
               await _supabase.from('notifications').insert({
                   'user_id': userId,
                   'title': '❌ Pago No Recibido',
                   'body': 'El organizador no ha confirmado la recepción de tu pago para "${pt['description']}". Por favor revisa y ponte en contacto.',
                   'type': 'general',
                   'data': {'action': 'payment_denied', 'expense_id': expenseId}
               });
           }
       } catch (e) {
           throw Exception("Error denegando pago: $e");
       }
  }

  // Mark a specific debt as paid
  Future<void> markDebtAsPaid(String expenseId, String? userId, String? guestName) async {
       try {
           final query = _supabase.from('payment_trackers')
               .update({'status': 'paid'})
               .eq('id', expenseId);
               
           if (userId != null) {
               await query.eq('user_id', userId);
           } else if (guestName != null) {
               await query.eq('guest_name', guestName);
           }

           if (userId != null) {
               final pt = await _supabase.from('payment_trackers').select('description').eq('id', expenseId).single();
               await _supabase.from('notifications').insert({
                   'user_id': userId,
                   'title': '✅ Paz y Salvo',
                   'body': 'El organizador ha confirmado el pago de tu parte en "${pt['description']}".',
                   'type': 'general',
                   'data': {'action': 'payment_confirmed', 'expense_id': expenseId}
               });
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
