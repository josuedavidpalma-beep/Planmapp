import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/expenses/domain/models/bill_model.dart';
import 'package:planmapp/features/expenses/domain/models/bill_item_model.dart';
import 'dart:developer';

class BillService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- BILLS ---

  Future<List<Bill>> getBillsForPlan(String planId) async {
    try {
      final response = await _supabase
          .from('bills')
          .select()
          .eq('plan_id', planId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => Bill.fromJson(json)).toList();
    } catch (e) {
      log("Error fetching bills: $e");
      rethrow;
    }
  }

  Future<Bill?> getBillRefreshed(String billId) async {
      try {
           final response = await _supabase
              .from('bills')
              .select('id, plan_id, payer_id, title, location, subtotal, tax_amount, tip_amount, other_fees, total_amount, tip_rate, tax_rate, status, created_at')
              .eq('id', billId)
              .single();
           return Bill.fromJson(response);
      } catch (e) {
           log("Error fetching bill: $e");
           return null;
      }
  }

  Future<Bill> createBill(String planId, String payerId, String title) async {
    try {
      final response = await _supabase
          .from('bills')
          .insert({
            'plan_id': planId,
            'payer_id': payerId,
            'title': title,
            'status': 'draft',
          })
          .select()
          .single();
      return Bill.fromJson(response);
    } catch (e) {
      log("Error creating bill: $e");
      rethrow;
    }
  }

  Future<void> updateBillTotals(String billId, {double? tipRate, double? taxRate}) async {
      // Logic: Trigger a stored procedure or handle calculation client-side and update.
      // For now, simple update of rates. Recalculation handles elsewhere or trigger.
      final updates = <String, dynamic>{};
      if (tipRate != null) updates['tip_rate'] = tipRate;
      if (taxRate != null) updates['tax_rate'] = taxRate;
      
      if (updates.isNotEmpty) {
          await _supabase.from('bills').update(updates).eq('id', billId);
      }
  }

  // --- ITEMS ---

  Future<List<BillItem>> getBillItems(String billId) async {
    try {
      // Fetch items with their assignments
      final response = await _supabase
          .from('bill_items')
          .select('*, bill_item_assignments(user_id)')
          .eq('bill_id', billId)
          .order('created_at', ascending: true);

      return (response as List).map((json) => BillItem.fromJson(json)).toList();
    } catch (e) {
      log("Error fetching bill items: $e");
      rethrow;
    }
  }

  Future<void> addBillItem(String billId, String name, double price, int quantity) async {
    try {
      await _supabase.from('bill_items').insert({
        'bill_id': billId,
        'name': name,
        'unit_price': price,
        'quantity': quantity,
        'total_price': price * quantity,
      });
      // Optionally trigger bill total update here or via database trigger
    } catch (e) {
      log("Error adding bill item: $e");
      rethrow;
    }
  }
  
  Future<void> deleteBillItem(String itemId) async {
      try {
          await _supabase.from('bill_items').delete().eq('id', itemId);
      } catch (e) {
          log("Error deleting item: $e");
          rethrow;
      }
  }

  // --- ASSIGNMENTS ---

  Future<void> toggleAssignment(String itemId, String userId) async {
    try {
      // Check if exists
      final exists = await _supabase
          .from('bill_item_assignments')
          .select()
          .eq('bill_item_id', itemId)
          .eq('user_id', userId)
          .maybeSingle();

      if (exists != null) {
        // Remove
        await _supabase
            .from('bill_item_assignments')
            .delete()
            .eq('id', exists['id']);
      } else {
        // Add
        await _supabase
            .from('bill_item_assignments')
            .insert({
              'bill_item_id': itemId,
              'user_id': userId,
            });
      }
    } catch (e) {
      log("Error toggling assignment: $e");
      rethrow;
    }
  }
  
  // --- CALCULATIONS (Proxy to Server or Local) ---
  // Ideally, we might use BillCalculator locally for UI responsiveness and save final Snapshot to DB.
}
