
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/social/domain/models/friendship_model.dart';
import 'package:planmapp/features/auth/domain/models/user_model.dart';

class FriendshipService {
  final _supabase = Supabase.instance.client;

  /// Search for users by email, display_name or phone
  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.length < 3) return []; 

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      
      // Attempt search by name or phone
      final res = await _supabase
          .from('profiles')
          .select()
          .or('display_name.ilike.%$query%,phone.ilike.%$query%')
          .neq('id', currentUserId!) 
          .limit(20);

      final list = (res as List).map((e) => UserProfile.fromJson(e)).toList();
      // Sort to prioritize users with avatars so the 'real' test account shows up first
      list.sort((a, b) {
          if (a.avatarUrl != null && b.avatarUrl == null) return -1;
          if (a.avatarUrl == null && b.avatarUrl != null) return 1;
          return 0;
      });
      return list;
    } catch (e) {
      print("Search error: $e");
      return [];
    }
  }

  /// Send a friend request
  Future<void> sendRequest(String receiverId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) throw Exception("Not logged in");
    final myId = currentUser.id;

    try {
        final friendshipDoc = await _supabase.from('friendships').insert({
          'requester_id': myId,
          'receiver_id': receiverId,
          'status': 'pending',
        }).select('id').single();
        
        final profile = await _supabase.from('profiles').select('full_name, nickname, avatar_url').eq('id', myId).maybeSingle();
        final name = profile?['nickname'] ?? profile?['full_name'] ?? 'Alguien';
        final avatar = profile?['avatar_url'] ?? '';
        
        await _supabase.from('notifications').insert({
            'user_id': receiverId,
            'title': 'Solicitud de Amistad',
            'body': '$name te ha enviado una solicitud de amistad.',
            'type': 'friend_request',
            'data': {'route': '/social', 'requester_id': myId, 'friendship_id': friendshipDoc['id'], 'requester_avatar': avatar, 'requester_name': name}
        });
        
    } on PostgrestException catch (e) {
        if (e.code == '23505') {
            throw Exception("Ya hay una solicitud enviada para este usuario.");
        }
        rethrow;
    }
  }

  /// Accept a friend request
  Future<void> acceptRequest(String friendshipId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;
    
    // Get requester to notify them
    final friendship = await _supabase.from('friendships').select('requester_id').eq('id', friendshipId).single();
    
    await _supabase
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('id', friendshipId);
        
    final profile = await _supabase.from('profiles').select('full_name, nickname').eq('id', currentUser.id).maybeSingle();
    final name = profile?['nickname'] ?? profile?['full_name'] ?? 'Alguien';
    
    await _supabase.from('notifications').insert({
        'user_id': friendship['requester_id'],
        'title': 'Solicitud Aceptada',
        'body': '$name ha aceptado tu solicitud de amistad.',
        'type': 'friend_accept',
        'data': {'route': '/social'}
    });
  }

  /// Get my friends (accepted) and pending requests
  Future<List<Friendship>> getFriendships() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];

    try {
       // 1. Fetch raw friendships directly (avoids PostgREST relation errors if FKs are directed to auth.users instead of profiles)
       final resRaw = await _supabase.from('friendships').select('*').or('requester_id.eq.$myId,receiver_id.eq.$myId');
       final List<Map<String,dynamic>> res = List<Map<String,dynamic>>.from(resRaw);

       if (res.isEmpty) return [];

       // 2. Extract profile IDs we need to fetch
       final Set<String> profileIdsToFetch = {};
       for (final item in res) {
           profileIdsToFetch.add(item['requester_id']);
           profileIdsToFetch.add(item['receiver_id']);
       }

       // 3. Fetch all related profiles in one query
       final profilesRaw = await _supabase.from('profiles').select('id, display_name, nickname, avatar_url, interests').inFilter('id', profileIdsToFetch.toList());
       
       final Map<String, dynamic> profilesMap = {
           for (final p in profilesRaw) p['id'] as String: p
       };

       // 4. Inject profiles into each friendship JSON so fromJson parses normally
       for (final item in res) {
           item['requester'] = profilesMap[item['requester_id']];
           item['receiver'] = profilesMap[item['receiver_id']];
       }

       return res.map((item) => Friendship.fromJson(item, myUserId: myId)).toList();
    } catch (e) {
      print("Get Friendships Error: $e");
      return [];
    }
  }
  
  /// Helper to check if a user is already my friend or pending
  Future<FriendshipStatus?> checkFriendshipStatus(String otherUserId) async {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return null;
      
      final res = await _supabase.from('friendships')
        .select('status')
        .or('and(requester_id.eq.$myId,receiver_id.eq.$otherUserId),and(requester_id.eq.$otherUserId,receiver_id.eq.$myId)')
        .maybeSingle();
        
      if (res == null) return null;
      
      final statusStr = res['status'] as String;
      return FriendshipStatus.values.firstWhere(
        (e) => e.toString().split('.').last == statusStr,
        orElse: () => FriendshipStatus.pending,
      );
  }

  /// Sends an in-app plan invitation to a friend
  Future<void> sendPlanInvite(String friendId, dynamic plan) async {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) throw Exception("Not logged in");
      
      final profile = await _supabase.from('profiles').select('full_name, nickname, avatar_url').eq('id', currentUser.id).maybeSingle();
      final name = profile?['nickname'] ?? profile?['full_name'] ?? 'Alguien';
      final avatar = profile?['avatar_url'] ?? '';

      await _supabase.from('notifications').insert({
          'user_id': friendId,
          'title': 'Invitación a Plan',
          'body': '$name te ha invitado al plan "${plan.title}".',
          'type': 'plan_invite',
          'data': {
              'plan_id': plan.id,
              'plan_title': plan.title,
              'inviter_name': name,
              'inviter_avatar': avatar
          }
      });
  }
}
