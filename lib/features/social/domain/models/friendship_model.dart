
enum FriendshipStatus { pending, accepted, blocked }

class Friendship {
  final String id;
  final String requesterId;
  final String receiverId;
  final FriendshipStatus status;
  final DateTime createdAt;

  // Additional fields for UI convenience (joined from profiles)
  final String? friendName;
  final String? friendAvatarUrl;
  final String? friendId; // The ID of the "other" person relative to Me
  final List<String> friendInterests;

  const Friendship({
    required this.id,
    required this.requesterId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    this.friendName,
    this.friendAvatarUrl,
    this.friendId,
    this.friendInterests = const [],
  });

  factory Friendship.fromJson(Map<String, dynamic> json, {String? myUserId}) {
    final statusStr = json['status'] as String;
    final status = FriendshipStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => FriendshipStatus.pending,
    );
    
    // Determine who the friend is
    String? fName;
    String? fAvatar;
    String? fId;
    List<String> fInterests = [];

    if (myUserId != null) {
      final isRequester = json['requester_id'] == myUserId;
      final receiverProfile = json['receiver'] as Map<String, dynamic>?;
      final requesterProfile = json['requester'] as Map<String, dynamic>?;

      if (isRequester) {
         fId = json['receiver_id'];
         fName = receiverProfile?['nickname'] ?? receiverProfile?['display_name'];
         fAvatar = receiverProfile?['avatar_url'];
         if (receiverProfile?['interests'] != null) {
             fInterests = List<String>.from((receiverProfile!['interests'] as List).map((e) => e.toString()));
         }
      } else {
         fId = json['requester_id'];
         fName = requesterProfile?['nickname'] ?? requesterProfile?['display_name'];
         fAvatar = requesterProfile?['avatar_url'];
         if (requesterProfile?['interests'] != null) {
             fInterests = List<String>.from((requesterProfile!['interests'] as List).map((e) => e.toString()));
         }
      }
    }

    return Friendship(
      id: json['id'],
      requesterId: json['requester_id'],
      receiverId: json['receiver_id'],
      status: status,
      createdAt: DateTime.parse(json['created_at']),
      friendName: fName,
      friendAvatarUrl: fAvatar,
      friendId: fId,
      friendInterests: fInterests,
    );
  }
}
