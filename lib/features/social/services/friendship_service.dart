
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
          .limit(15);

      return (res as List).map((e) => UserProfile.fromJson(e)).toList();
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
        await _supabase.from('friendships').insert({
          'requester_id': myId,
          'receiver_id': receiverId,
          'status': 'pending',
        });
        
        final profile = await _supabase.from('profiles').select('full_name, nickname').eq('id', myId).maybeSingle();
        final name = profile?['nickname'] ?? profile?['full_name'] ?? 'Alguien';
        
        await _supabase.from('notifications').insert({
            'user_id': receiverId,
            'title': 'Solicitud de Amistad',
            'body': '$name te ha enviado una solicitud de amistad.',
            'type': 'friend_request',
            'data': {'route': '/social'}
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
  /// This requires a complex query or multiple queries because "Friend" can be requester or receiver.
  Future<List<Friendship>> getFriendships() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];

    // Query where I am requester OR receiver
    // We also want to fetch the profile of the counterparty.
    // Supabase standard join syntax:
    // select(*, receiver:profiles!receiver_id(*), requester:profiles!requester_id(*))
    
    try {
       final res = await _supabase.from('friendships').select('''
          *,
          receiver:profiles!receiver_id(display_name, nickname, avatar_url, interests),
          requester:profiles!requester_id(display_name, nickname, avatar_url, interests)
       ''').or('requester_id.eq.$myId,receiver_id.eq.$myId');

       return (res as List).map((item) => Friendship.fromJson(item, myUserId: myId)).toList();
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
}
