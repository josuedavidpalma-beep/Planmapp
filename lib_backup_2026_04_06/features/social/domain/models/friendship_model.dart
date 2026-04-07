
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

  const Friendship({
    required this.id,
    required this.requesterId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    this.friendName,
    this.friendAvatarUrl,
    this.friendId,
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

    if (myUserId != null) {
      final isRequester = json['requester_id'] == myUserId;
      // If I am requester, friend is receiver. If I am receiver, friend is requester to me.
      // However, usually we join 'receiver:profiles(...)' or 'requester:profiles(...)'
      // For now, let's assume the passed json might have joined profile data if we query efficiently.
      // Or we handle it later.
      
      // Let's assume the JSON structure comes from a join like:
      // ..., receiver:profiles!receiver_id(display_name), requester:profiles!requester_id(display_name)
      
      final receiverProfile = json['receiver'] as Map<String, dynamic>?;
      final requesterProfile = json['requester'] as Map<String, dynamic>?;

      if (isRequester) {
         fId = json['receiver_id'];
         fName = receiverProfile?['display_name'];
         fAvatar = receiverProfile?['avatar_url'];
      } else {
         fId = json['requester_id'];
         fName = requesterProfile?['display_name'];
         fAvatar = requesterProfile?['avatar_url'];
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
    );
  }
}
