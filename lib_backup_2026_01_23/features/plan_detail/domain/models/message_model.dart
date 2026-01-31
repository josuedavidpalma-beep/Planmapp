
class Message {
  final String id;
  final String planId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final bool isSystemMessage;

  // Optional: User Display Name (Joined later or fetched)
  final String? userDisplayName;

  Message({
    required this.id,
    required this.planId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.isSystemMessage = false,
    this.userDisplayName,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      planId: json['plan_id'],
      userId: json['user_id'] ?? 'unknown',
      content: json['content'] ?? "", // Safe Default
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(), // Safe Default
      isSystemMessage: json['is_system_message'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plan_id': planId,
      'content': content,
      'is_system_message': isSystemMessage,
      // user_id is auto-filled by Supabase
    };
  }
}
