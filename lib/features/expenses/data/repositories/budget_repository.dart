
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/expenses/data/models/budget_model.dart';

class BudgetRepository {
  final SupabaseClient _supabase;

  BudgetRepository(this._supabase);

  // BUDGETS
  Future<List<BudgetItem>> getBudgetItems(String planId) async {
    final response = await _supabase.from('budget_items').select().eq('plan_id', planId);
    return (response as List).map((e) => BudgetItem.fromJson(e)).toList();
  }

  Future<void> addBudgetItem(Map<String, dynamic> data) async {
    await _supabase.from('budget_items').insert(data);
  }
  
  Future<void> deleteBudgetItem(String id) async {
      await _supabase.from('budget_items').delete().eq('id', id);
  }

  // PAYMENTS
  
  // This function ensures that we have a Tracker entry for every real Plan Member
  // If not, it creates it.
  Future<void> syncMembersToTrackers(String planId) async {
      // 1. Get all real members
      final membersResp = await _supabase.from('plan_members').select('user_id').eq('plan_id', planId);
      final memberIds = (membersResp as List).map((e) => e['user_id'] as String).toSet();
      
      // 2. Get existing trackers
      final trackerResp = await _supabase.from('payment_trackers').select('user_id').eq('plan_id', planId);
      final trackedIds = (trackerResp as List).map((e) => e['user_id'] as String?).where((e) => e != null).toSet();
      
      // 3. Insert missing
      final missing = memberIds.difference(trackedIds);
      if (missing.isNotEmpty) {
          final newTrackers = missing.map((uid) => {
              'plan_id': planId,
              'user_id': uid,
              'status': 'pending', 
              'description': 'Cuota Vaca',
              'amount_owe': 0 // Will recalculate later
          }).toList();
          
          await _supabase.from('payment_trackers').insert(newTrackers);
      }
  }

  Future<List<PaymentTracker>> getPaymentTrackers(String planId) async {
    // Ensure sync first (optional, but good for consistency)
    // await syncMembersToTrackers(planId); 
    
    final response = await _supabase.from('payment_trackers').select().eq('plan_id', planId);
    return (response as List).map((e) => PaymentTracker.fromJson(e)).toList();
  }
  
  Future<void> addGuestTracker(String planId, String guestName) async {
      final currentUserId = _supabase.auth.currentUser?.id;
      
      await _supabase.from('payment_trackers').insert({
          'plan_id': planId,
          'guest_name': guestName,
          'status': 'pending',
          'description': 'Cuota Vaca',
          'amount_owe': 0,
          'responsible_user_id': currentUserId // Link guest to the creator
      });
  }

  Future<void> updatePaymentStatus(String trackerId, PaymentStatus status, {String? receiptUrl}) async {
      final updates = {'status': status.name};
      if (receiptUrl != null) updates['receipt_url'] = receiptUrl;
      await _supabase.from('payment_trackers').update(updates).eq('id', trackerId);
  }
  
  // LOGIC: Recalculate Quota per Person
  // Formula: (Sum of Budget Items) / (Count of Trackers)
  Future<void> recalculateQuotas(String planId) async {
      // 1. Get total budget
      final items = await getBudgetItems(planId);
      final totalBudget = items.fold(0.0, (sum, item) => sum + item.estimatedAmount);
      
      // 2. Get count of participants (Real + Guests)
      final trackers = (await getPaymentTrackers(planId)).where((t) => t.billId == null).toList();
      if (trackers.isEmpty) return; // Divide by zero safety
      
      final quota = totalBudget / trackers.length;
      
      // 3. Update all legacy trackers
      for (var t in trackers) {
           await _supabase.from('payment_trackers').update({'amount_owe': quota}).eq('id', t.id);
      }

      // 4. INJECT INTO EXPENSES SCHEMA (For Global Dashboard)
      // Look for an existing "Vaca" expense for this plan
      final currentUid = _supabase.auth.currentUser?.id;
      if (currentUid == null || totalBudget <= 0) return;

      try {
          final existing = await _supabase.from('expenses')
              .select('id')
              .eq('plan_id', planId)
              .eq('title', 'Presupuesto Inicial (Vaca)')
              .maybeSingle();

          if (existing != null) {
              // Delete old to recreate fresh assignments
              await _supabase.from('expenses').delete().eq('id', existing['id']);
          }

          // Create Expense header
          final expRes = await _supabase.from('expenses').insert({
              'plan_id': planId,
              'created_by': currentUid,
              'title': 'Presupuesto Inicial (Vaca)',
              'subtotal': totalBudget,
              'total_amount': totalBudget,
              'tax_amount': 0,
              'tip_amount': 0,
          }).select('id').single();

          final expId = expRes['id'];

          // Create Single Item: Fondo Común
          final itemRes = await _supabase.from('expense_items').insert({
              'expense_id': expId,
              'name': 'Fondo Común',
              'price': totalBudget,
              'quantity': 1
          }).select('id').single();

          final itemId = itemRes['id'];

          // Insert Assignments and Participant Statuses based on Trackers
          final assigns = [];
          final statuses = [];

          for (var t in trackers) {
              // Assignment
              assigns.add({
                  'expense_item_id': itemId,
                  'user_id': t.userId,
                  'guest_name': t.guestName,
                  'quantity': 1.0 / trackers.length
              });

              // Status for Dashboard
              statuses.add({
                  'expense_id': expId,
                  'user_id': t.userId,
                  'guest_name': t.guestName,
                  'amount_owed': quota,
                  'is_paid': t.status == PaymentStatus.paid,
              });
          }

          if (assigns.isNotEmpty) await _supabase.from('expense_assignments').insert(assigns);
          if (statuses.isNotEmpty) await _supabase.from('expense_participant_status').insert(statuses);
      } catch (e) {
          print("ERROR INJECTING BUDGET INTO EXPENSES: $e");
      }
  }
}
