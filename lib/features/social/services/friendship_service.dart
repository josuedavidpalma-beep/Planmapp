
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/social/domain/models/friendship_model.dart';
import 'package:planmapp/features/auth/domain/models/user_model.dart';

class FriendshipService {
  final _supabase = Supabase.instance.client;

  /// Search for users by email or display_name
  /// Returns a list of UserProfile (mocked or real from profiles table)
  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.length < 3) return []; // Minimum 3 chars

    try {
      // Search in profiles table
      final currentUserId = _supabase.auth.currentUser?.id;
      
      final res = await _supabase
          .from('profiles')
          .select()
          .ilike('display_name', '%$query%') // or email if exposed
          .neq('id', currentUserId!) // Don't show myself
          .limit(10);

      return (res as List).map((e) => UserProfile.fromJson(e)).toList();
    } catch (e) {
      // If profiles table doesn't exist or error, return empty
      print("Search error: $e");
      return [];
    }
  }

  /// Send a friend request
  Future<void> sendRequest(String receiverId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) throw Exception("Not logged in");

    await _supabase.from('friendships').insert({
      'requester_id': myId,
      'receiver_id': receiverId,
      'status': 'pending',
    });
  }

  /// Accept a friend request
  Future<void> acceptRequest(String friendshipId) async {
    await _supabase
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('id', friendshipId);
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
          receiver:profiles!receiver_id(display_name, avatar_url),
          requester:profiles!requester_id(display_name, avatar_url)
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
