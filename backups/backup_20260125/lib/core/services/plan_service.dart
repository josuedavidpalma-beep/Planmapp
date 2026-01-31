
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/plans/domain/models/plan_model.dart';

class PlanService {
  final SupabaseClient _supabase = Supabase.instance.client;

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
             await _supabase.from('poll_votes').delete().filter('poll_id', 'in', pollIds);
             // Delete options for these polls
             await _supabase.from('poll_options').delete().filter('poll_id', 'in', pollIds);
             // Delete the polls themselves (or do it later with plan_id)
             await _supabase.from('polls').delete().filter('id', 'in', pollIds);
          }

          // 2. Other simple dependencies
          try { await _supabase.from('expenses').delete().eq('plan_id', planId); } catch (_) {}
          try { await _supabase.from('budget_items').delete().eq('plan_id', planId); } catch (_) {}
          try { await _supabase.from('activities').delete().eq('plan_id', planId); } catch (_) {}
          try { await _supabase.from('plan_members').delete().eq('plan_id', planId); } catch (_) {}
          try { await _supabase.from('messages').delete().eq('plan_id', planId); } catch (_) {}

          // 3. Finally delete Plan
          await _supabase.from('plans').delete().eq('id', planId);
       } catch (e) {
          throw Exception("Error deleting plan: $e");
       }
  }
}
