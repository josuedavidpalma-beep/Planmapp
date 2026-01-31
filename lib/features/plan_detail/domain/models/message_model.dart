
class Message {
  final String id;
  final String planId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String type; 
  final Map<String, dynamic>? metadata;
  
  // Restored fields
  final bool isSystemMessage;
  final String? userDisplayName;

  Message({
    required this.id,
    required this.planId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.isSystemMessage = false,
    this.userDisplayName,
    this.type = 'text',
    this.metadata,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id']?.toString() ?? 'unknown_id',
      planId: json['plan_id']?.toString() ?? 'unknown_plan',
      userId: json['user_id']?.toString() ?? 'unknown_user',
      content: json['content']?.toString() ?? "", 
      createdAt: json['created_at'] != null ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()) : DateTime.now(),
      isSystemMessage: json['is_system_message'] ?? false,
      type: json['type'] ?? 'text',
      metadata: json['metadata'] != null ? Map<String, dynamic>.from(json['metadata']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plan_id': planId,
      'content': content,
      'is_system_message': isSystemMessage,
      'type': type,
      'metadata': metadata,
    };
  }
}
