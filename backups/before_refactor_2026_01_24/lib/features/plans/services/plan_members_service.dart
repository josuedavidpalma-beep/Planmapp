
import 'package:planmapp/features/auth/domain/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlanMembersService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fetch plan members
  // Ideally this joins with the profiles/users table. 
  // Since we might not have a public profiles table fully set up with names yet, 
  // we will try to fetch from 'profiles' or 'users' if available, otherwise return mock/auth data.
  
  Future<List<PlanMember>> getMembers(String planId) async {
    try {
      // 1. Get member IDs + Profile data
      // We assume a foreign key usually exists, but if not we fail gracefully.
      // Since we can't easily guarantee FK name, we will try fetching members first
      final membersRes = await _supabase
          .from('plan_members')
          .select('user_id, role')
          .eq('plan_id', planId);

      final List<PlanMember> members = [];
      final myId = _supabase.auth.currentUser?.id;

      for (var row in membersRes) {
        final uid = row['user_id']?.toString() ?? '';
        if (uid.isEmpty) continue; // Skip invalid rows

        final role = row['role']?.toString() ?? 'member';
        
        // Fetch name from Profile (Best effort)
        String displayName = "Miembro";
        String? avatarUrl;
        try {
           final profile = await _supabase.from('profiles').select('display_name, email, avatar_url').eq('id', uid).maybeSingle();
           if (profile != null) {
              displayName = profile['display_name'] ?? profile['email']?.split('@')[0] ?? "Miembro";
              avatarUrl = profile['avatar_url'];
           }
        } catch (_) {}

        // Override name for "Me"
        if (uid == myId) displayName = "Yo";

        members.add(PlanMember(id: uid, name: displayName, isGuest: false, role: role, avatarUrl: avatarUrl));
      }

      return members;

    } catch (e) {
      print("Error fetching members: $e");
      return [];
    }
  }

  // Check my role helper
  Future<String> getMyRole(String planId) async {
       final uid = _supabase.auth.currentUser?.id;
       if (uid == null) return 'member';
       
       try {
           // Check if creator
           final planRes = await _supabase.from('plans').select('creator_id').eq('id', planId).maybeSingle();
           if (planRes != null && planRes['creator_id'] == uid) return 'admin';
           
           final res = await _supabase.from('plan_members').select('role').eq('plan_id', planId).eq('user_id', uid).maybeSingle();
           return res?['role']?.toString() ?? 'member';
       } catch (e) {
           return 'member';
       }
  }
  Future<void> leavePlan(String planId) async {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return;
      await _supabase.from('plan_members').delete().eq('plan_id', planId).eq('user_id', uid);
  }
}

class PlanMember {
  final String id;
  final String name;
  final bool isGuest;
  final String role; // admin, treasure, member
  final String? avatarUrl;

  PlanMember({
      required this.id, 
      required this.name, 
      required this.isGuest,
      this.role = 'member',
      this.avatarUrl,
  });
}
