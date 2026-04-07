
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
          'amount_owe': 0,
          'responsible_user_id': currentUserId // Link guest to the creator
      });
  }

  Future<void> updatePaymentStatus(String trackerId, PaymentStatus status) async {
      await _supabase.from('payment_trackers').update({'status': status.name}).eq('id', trackerId);
  }
  
  // LOGIC: Recalculate Quota per Person
  // Formula: (Sum of Budget Items) / (Count of Trackers)
  Future<void> recalculateQuotas(String planId) async {
      // 1. Get total budget
      final items = await getBudgetItems(planId);
      final totalBudget = items.fold(0.0, (sum, item) => sum + item.estimatedAmount);
      
      // 2. Get count of participants (Real + Guests)
      final trackers = await getPaymentTrackers(planId);
      if (trackers.isEmpty) return; // Divide by zero safety
      
      final quota = totalBudget / trackers.length;
      
      // 3. Update all (ideally batch)
      // For MVP loop updates
      for (var t in trackers) {
           await _supabase.from('payment_trackers').update({'amount_owe': quota}).eq('id', t.id);
      }
  }
}
