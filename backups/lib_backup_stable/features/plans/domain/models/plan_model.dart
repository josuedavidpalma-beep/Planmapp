enum PlanStatus { draft, active, completed, cancelled }

class Plan {
  final String id;
  final String creatorId;
  final String title;
  final String? description;
  final DateTime eventDate;
  final String locationName;
  final PlanStatus status;
  final int participantCount;

  const Plan({
    required this.id,
    required this.creatorId,
    required this.title,
    this.description,
    required this.eventDate,
    required this.locationName,
    this.status = PlanStatus.draft,
    this.participantCount = 1,
    this.budgetDeadline,
    this.reminderFrequencyDays = 0,
    this.reminderChannel = 'whatsapp',
    this.lastReminderSent,
  });

  final DateTime? budgetDeadline;
  final int reminderFrequencyDays;
  final String reminderChannel;
  final DateTime? lastReminderSent;

  // Factory for mock data
  factory Plan.mock() {
    return Plan(
      id: "mock_1",
      creatorId: "user_1",
      title: "Asado Fin de Semestre",
      description: "Traigan bebida, yo pongo la carne.",
      eventDate: DateTime.now().add(const Duration(days: 3)),
      locationName: "Casa de Josue",
      status: PlanStatus.active,
      participantCount: 5,
    );
  }
  // Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'event_date': eventDate.toIso8601String(),
      'location_name': locationName,
      'status': status.name,
      'reminder_channel': reminderChannel,
      // 'creator_id' is handled by Supabase default usually, but if we send it:
      // 'creator_id': creatorId, 
    };
  }

  // Create from Supabase JSON
  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String? ?? 'unknown',
      title: json['title'] as String,
      description: json['description'] as String?,
      eventDate: DateTime.parse(json['event_date'] as String),
      locationName: json['location_name'] as String? ?? 'Sin ubicación',
      status: PlanStatus.values.firstWhere(
        (e) => e.name == json['status'], 
        orElse: () => PlanStatus.draft
      ),
      participantCount: 1, 
      budgetDeadline: json['budget_deadline'] != null ? DateTime.parse(json['budget_deadline']) : null,
      reminderFrequencyDays: json['reminder_frequency_days'] as int? ?? 0,
      reminderChannel: json['reminder_channel'] as String? ?? 'whatsapp',
      lastReminderSent: json['last_reminder_sent'] != null ? DateTime.parse(json['last_reminder_sent']) : null,
    );
  }
}
