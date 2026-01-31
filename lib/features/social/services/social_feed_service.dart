
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/plans/domain/models/plan_model.dart';
import 'package:planmapp/features/social/services/friendship_service.dart';
import 'package:planmapp/features/social/domain/models/friendship_model.dart';

class SocialFeedService {
  final _supabase = Supabase.instance.client;
  final _friendshipService = FriendshipService();

  /// Fetches the feed: Plans created by friends that are strictly PUBLIC.
  /// (In the future we can add 'Friends Only' visibility, but strictly public is safer for MVP)
  Future<List<Plan>> getFriendsPlans() async {
    try {
       // 1. Get Friend IDs
       final friendships = await _friendshipService.getFriendships();
       // Only accepted friends
       final friendIds = friendships
           .where((f) => f.status == FriendshipStatus.accepted) // Use the enum we restored
           .map((f) => f.friendId)
           .where((id) => id != null)
           .map((id) => id!)
           .toList();

       if (friendIds.isEmpty) return [];

       // 2. Query Plans
       // TODO: Ensure we have a 'visibility' column in plans or similar. 
       // For now, let's assume valid plans are those in the list.
       // Ideally we should filter by .eq('visibility', 'public') if that column exists. 
       // If not, we might be leaking private plans.
       // CHECK database schema needed. Assuming we fetch all for now and filter in memory or assume trust.
       
       final res = await _supabase
           .from('plans')
           .select()
           .inFilter('creator_id', friendIds) // Created by friends
           .eq('visibility', 'public') // PRIVACY FILTER: Only public plans
           .order('created_at', ascending: false)
           .limit(20);

       return (res as List).map((e) => Plan.fromJson(e)).toList();
    } catch (e) {
      print("Error fetching feed: $e");
      return [];
    }
  }
}
