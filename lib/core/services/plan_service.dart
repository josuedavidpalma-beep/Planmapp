
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/plans/domain/models/plan_model.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

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


  Future<List<Plan>> getPlans({bool archived = false, bool deleted = false, bool isDirectChat = false}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("No autenticado");
      
      var query = _supabase.from('plans').select('*, plan_members!inner(user_id)').eq('plan_members.user_id', user.id);

      if (deleted) {
          query = query.not('deleted_at', 'is', null);
      } else if (archived) {
          query = query.filter('deleted_at', 'is', null).not('archived_at', 'is', null);
      } else {
          query = query.filter('deleted_at', 'is', null).filter('archived_at', 'is', null);
      }
      
      query = query.eq('is_direct_chat', isDirectChat);
      
      final response = await query
          .neq('title', '__PLANMAPP_TOOLS_MODE__')
          .order('created_at', ascending: false);
          
      return (response as List).map((item) => Plan.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Error al cargar planes: $e');
    }
  }

  Future<void> softDeletePlan(String planId) async {
       try {
           await _supabase.from('plans').update({
               'deleted_at': DateTime.now().toIso8601String()
           }).eq('id', planId);
           listUpdateNotifier.value++;
       } catch (e) { throw Exception("Error al mover a papelera: $e"); }
  }

  Future<void> archivePlan(String planId) async {
       try {
           await _supabase.from('plans').update({
               'archived_at': DateTime.now().toIso8601String()
           }).eq('id', planId);
           listUpdateNotifier.value++;
       } catch (e) { throw Exception("Error al archivar: $e"); }
  }

  Future<void> restorePlan(String planId) async {
       try {
           await _supabase.from('plans').update({
               'deleted_at': null,
               'archived_at': null
           }).eq('id', planId);
           listUpdateNotifier.value++;
       } catch (e) { throw Exception("Error al restaurar: $e"); }
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

  Future<Plan?> getPlanPreview(String id) async {
    try {
      final response = await _supabase.rpc('get_plan_preview', params: {'p_plan_id': id});
      if (response == null) return null;
      
      // Construir un Plan parcial (preview) a partir del JSON devuelto
      return Plan(
         id: response['id'],
         title: response['title'],
         description: '',
         creatorId: response['creator_id'],
         eventDate: response['event_date'] != null ? DateTime.tryParse(response['event_date']) : null,
         locationName: response['location_name'] ?? '',
         locationAddress: '',
         latitude: null,
         longitude: null,
         createdAt: DateTime.now(),
      );
    } catch (e) {
      print("Error fetching plan preview: $e");
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

  // --- INTERNAL TOOLS PLAN ---
  Future<String> getOrCreateToolsPlan() async {
      try {
          final user = _supabase.auth.currentUser;
          if (user == null) throw Exception("No autenticado");

          // 1. Check if it exists for this user
          // Note: Since each user should have their own isolated tools sandbox, 
          // we look for a plan created by them with the specific title.
          final existing = await _supabase.from('plans')
              .select('id')
              .eq('creator_id', user.id)
              .eq('title', '__PLANMAPP_TOOLS_MODE__')
              .maybeSingle();

          if (existing != null) {
              return existing['id'] as String;
          }

          // 2. Create if not exists
          // Create dummy plan data
          final newId = const Uuid().v4();
          await _supabase.from('plans').insert({
              'id': newId,
              'creator_id': user.id,
              'title': '__PLANMAPP_TOOLS_MODE__',
              'description': 'Internal sandbox for standalone tools',
              'location_name': 'Herramientas',
              'status': 'draft' // or planning
          });

          // Also add them as admin
          await _supabase.from('plan_members').insert({
              'plan_id': newId,
              'user_id': user.id,
              'role': 'admin'
          });

          return newId;
      } catch (e) {
          print("Error in getOrCreateToolsPlan: $e");
          throw Exception("No se pudo inicializar la base de datos de herramientas: $e");
      }
  }

  // --- DIRECT CHATS ---
  Future<String> getOrCreateDirectChat(String targetUserId) async {
       try {
           final user = _supabase.auth.currentUser;
           if (user == null) throw Exception("No autenticado");

           // Usamos una consulta RPC para encontrar un plan que ya tenga EXACTAMENTE a ambos usuarios
           // Pero dado que un chat directo siempre tiene is_direct_chat = true, es más fácil consultar:
           // Buscamos los chats directos míos y vemos si el targetUserId está en ellos.
           final myChatsResponse = await _supabase.from('plans')
             .select('id, plan_members!inner(user_id)')
             .eq('is_direct_chat', true)
             .eq('plan_members.user_id', user.id);
             
           final myChatIds = (myChatsResponse as List).map((p) => p['id'] as String).toList();
           
           if (myChatIds.isNotEmpty) {
               // Verify if targetUserId is in any of these chats
               final targetChat = await _supabase.from('plan_members')
                 .select('plan_id')
                 .inFilter('plan_id', myChatIds)
                 .eq('user_id', targetUserId)
                 .maybeSingle();
                 
               if (targetChat != null) {
                   return targetChat['plan_id'] as String;
               }
           }

           // No existe = Creamos uno nuevo
           final newId = const Uuid().v4();
           await _supabase.from('plans').insert({
               'id': newId,
               'creator_id': user.id,
               'title': 'Chat Directo', // Fallback, the UI will override this visually
               'location_name': 'Chat',
               'status': 'active',
               'is_direct_chat': true
           });

           // Me agrego a mí
           await _supabase.from('plan_members').insert({
               'plan_id': newId,
               'user_id': user.id,
               'role': 'admin'
           });
           
           // Agrego al target
           await _supabase.from('plan_members').insert({
               'plan_id': newId,
               'user_id': targetUserId,
               'role': 'admin'
           });
           
           listUpdateNotifier.value++;
           return newId;
       } catch(e) {
           throw Exception("No se pudo iniciar el chat: $e");
       }
  }
}
