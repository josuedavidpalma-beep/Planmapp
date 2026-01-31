
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/plans/domain/models/plan_model.dart';
import 'package:flutter/foundation.dart';

class PlanService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // A simple notifier to signal UI to refresh lists
  static final ValueNotifier<int> listUpdateNotifier = ValueNotifier(0);

  Future<void> createPlan(Plan plan) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("Usuario no autenticado");

      // FIX 1: Send the ID explicitly so client and server share the same UUID.
      // FIX 2: Clean payload (reminder_channel issues)
      final data = plan.toJson();
      data['id'] = plan.id; // EXPICITLY ADD ID
      data['creator_id'] = plan.creatorId; // Ensure creator_id is sent too
      data.remove('reminder_channel'); 
      data.remove('reminder_frequency_days');
      
      
      // 1. Insert Plan
      await _supabase.from('plans').insert(data);

      // 2. FORCE INSERT CREATOR as ADMIN member immediately
      // This is critical for RLS to work, otherwise the creator won't see their own plan.
      await _supabase.from('plan_members').insert({
          'plan_id': plan.id,
          'user_id': user.id,
          'role': 'admin'
      });
      
      // Notify listeners to refresh lists
      listUpdateNotifier.value++;
      
    } catch (e) {
      throw Exception('Error al crear plan: $e');
    }
  }


  Future<List<Plan>> getPlans() async {
    try {
      final response = await _supabase
          .from('plans')
          .select()
          // Filter: Show Drafts (null) OR Future Plans (>= yesterday)
          // We use yesterday to give a grace period before disappearing
          .or('event_date.is.null,event_date.gte.${DateTime.now().subtract(const Duration(days: 1)).toIso8601String()}')
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((item) => Plan.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Error al cargar planes: $e');
    }
  }

  Future<Plan?> getPlanById(String id) async {
    try {
      final response = await _supabase
          .from('plans')
          .select()
          .eq('id', id)
          .single();
      
      return Plan.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<void> updatePlanSettings(String planId, int reminderDays, {String channel = 'whatsapp'}) async {
      try {
          await _supabase.from('plans').update({
              'reminder_frequency_days': reminderDays,
              'reminder_channel': channel
          }).eq('id', planId);
      } catch (e) {
          throw Exception("Error updating settings: $e");
      }
  }

  Future<void> deletePlan(String planId) async {
       try {
          // MANUAL CASCADE (Order matters due to FKs)
          
          // 1. Polls: We need to manually fetch IDs to delete votes/options first
          // because we can't do "delete where poll.plan_id = x" directly on sub-tables easily.
          final pollsRes = await _supabase.from('polls').select('id').eq('plan_id', planId);
          final pollIds = (pollsRes as List).map((e) => e['id'] as String).toList();
          
           if (pollIds.isNotEmpty) {
             // Delete votes for these polls
             try { await _supabase.from('poll_votes').delete().filter('poll_id', 'in', pollIds); } catch(_) {}
             // Delete options for these polls
             try { await _supabase.from('poll_options').delete().filter('poll_id', 'in', pollIds); } catch(_) {}
             // Delete the polls themselves
             try { await _supabase.from('polls').delete().filter('id', 'in', pollIds); } catch(_) {}
          }

          // 2. Other simple dependencies (Cascading manually just in case)
          try { await _supabase.from('expenses').delete().eq('plan_id', planId); } catch (_) {}
          try { await _supabase.from('budget_items').delete().eq('plan_id', planId); } catch (_) {}
          try { await _supabase.from('activities').delete().eq('plan_id', planId); } catch (_) {}
          try { await _supabase.from('messages').delete().eq('plan_id', planId); } catch (_) {}
          try { await _supabase.from('plan_members').delete().eq('plan_id', planId); } catch (_) {} // Members last before plan

          // 3. Finally delete Plan
          await _supabase.from('plans').delete().eq('id', planId);
          listUpdateNotifier.value++;
       } catch (e) {
          print("Delete Plan Error: $e");
          // If we fail to delete, try to just LEAVE if we are not the owner really?
          // No, this method is explicit delete.
          throw Exception("Error deleting plan: $e");
       }
  }

  Future<void> deleteAllPlans() async {
      try {
          final plans = await getPlans();
          for (final plan in plans) {
              // AGGRESSIVE DELETE: Use the robust deletePlan method which handles Cascades (Polls, Expenses, etc.)
              try { 
                  await deletePlan(plan.id);
              } catch (e) {
                  print("Full delete failed (maybe not owner): $e");
                  // If we can't delete (not owner), at least LEAVE.
                  try { await leavePlan(plan.id); } catch (_) {}
              }
          }
      } catch (e) {
          throw Exception("Error deleting all plans: $e");
      }
  }
  Future<void> leavePlan(String planId) async {
       try {
           final user = _supabase.auth.currentUser;
           if (user == null) throw Exception("No autenticado");
           
           await _supabase.from('plan_members').delete().match({
               'plan_id': planId,
               'user_id': user.id
           });
       } catch (e) {
           throw Exception("Error al salir del plan: $e");
       }
  }

  Future<void> cancelPlan(String planId) async {
       try {
           final user = _supabase.auth.currentUser;
           if (user == null) throw Exception("No autenticado");
           
           // Verify is admin (double check)
           final roleRes = await _supabase.from('plan_members').select('role').match({'plan_id': planId, 'user_id': user.id}).maybeSingle();
           if (roleRes?['role'] != 'admin') throw Exception("Solo el administrador puede cancelar el plan");

           await _supabase.from('plans').update({
               'status': 'cancelled'
           }).eq('id', planId);

           // Send system message
           await _supabase.from('messages').insert({
               'plan_id': planId,
               'user_id': user.id,
               'content': "⚠️ EL PLAN HA SIDO CANCELADO POR EL ADMINISTRADOR.",
               'is_system_message': true,
               'type': 'system'
           });

       } catch (e) {
           throw Exception("Error al cancelar plan: $e");
       }
  }
  Future<void> updateMemberStatus(String planId, String status) async {
       try {
           final user = _supabase.auth.currentUser;
           if (user == null) throw Exception("No autenticado");
           
           await _supabase.from('plan_members').update({
               'status': status
           }).match({
               'plan_id': planId,
               'user_id': user.id
           });
       } catch (e) {
           throw Exception("Error al actualizar estado: $e");
       }
  }
}
