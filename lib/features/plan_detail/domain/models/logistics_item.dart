class LogisticsItem {
  final String id;
  final String planId;
  final String description; // "Hielo", "Carpa"
  final String? assignedUserId; // Who volunteered
  final String? assignedGuestName; // Or guest name
  final bool isCompleted;
  final DateTime createdAt;
  final String? creatorId;

  const LogisticsItem({
    required this.id,
    required this.planId,
    required this.description,
    this.assignedUserId,
    this.assignedGuestName,
    this.isCompleted = false,
    required this.createdAt,
    this.creatorId,
    this.assignedProfile,
  });

  factory LogisticsItem.fromJson(Map<String, dynamic> json) {
    return LogisticsItem(
      id: json['id'] as String,
      planId: json['plan_id'] as String,
      description: json['description'] as String,
      assignedUserId: json['assigned_user_id'] as String?,
      assignedGuestName: json['assigned_guest_name'] as String?,
      isCompleted: json['is_completed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      creatorId: json['creator_id'] as String?,
      assignedProfile: json['profiles'] != null ? Map<String, dynamic>.from(json['profiles']) : null,
    );
  }

  final Map<String, dynamic>? assignedProfile; // JOIN result

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plan_id': planId,
      'description': description,
      'assigned_user_id': assignedUserId,
      'assigned_guest_name': assignedGuestName,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
      'creator_id': creatorId,
    };
  }
}
