enum PlanStatus { draft, active, completed, cancelled }

class Plan {
  final String id;
  final String creatorId;
  final String title;
  final String? description;
  final DateTime? eventDate;
  final String locationName;
  final PlanStatus status;
  final int participantCount;
  final String paymentMode; // 'individual', 'pool', 'guest', 'split'
  final String visibility; // 'public' or 'private'
  final DateTime? budgetDeadline;
  final int reminderFrequencyDays;
  final String reminderChannel;
  final DateTime? lastReminderSent;

  const Plan({
    required this.id,
    required this.creatorId,
    required this.title,
    this.description,
    this.eventDate,
    required this.locationName,
    this.status = PlanStatus.draft,
    this.participantCount = 1,
    this.visibility = 'private',
    this.budgetDeadline,
    this.reminderFrequencyDays = 0,
    this.reminderChannel = 'whatsapp',
    this.lastReminderSent,
    this.paymentMode = 'individual',
  });

  // ... existing code ...

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creator_id': creatorId,
      'title': title,
      'description': description,
      'event_date': eventDate?.toIso8601String(),
      'location_name': locationName,
      'status': status.name,
      'reminder_channel': reminderChannel,
      'visibility': visibility,
      'payment_mode': paymentMode,
    };
  }

  // Create from Supabase JSON
  factory Plan.fromJson(Map<String, dynamic> json) {
    try {
      return Plan(
        id: json['id']?.toString() ?? 'unknown_id',
        creatorId: json['creator_id']?.toString() ?? 'unknown_user',
        title: json['title']?.toString() ?? 'Sin Título',
        description: json['description']?.toString(),
        eventDate: json['event_date'] != null 
            ? DateTime.tryParse(json['event_date'].toString()) 
            : null,
        locationName: json['location_name']?.toString() ?? 'Sin ubicación',
        status: PlanStatus.values.firstWhere(
          (e) => e.name.toLowerCase() == (json['status']?.toString().toLowerCase() ?? ''), 
          orElse: () => PlanStatus.draft
        ),
        participantCount: json['participant_count'] is int ? json['participant_count'] : 1, 
        visibility: json['visibility']?.toString() ?? 'private',
        budgetDeadline: json['budget_deadline'] != null ? DateTime.tryParse(json['budget_deadline'].toString()) : null,
        reminderFrequencyDays: json['reminder_frequency_days'] as int? ?? 0,
        reminderChannel: json['reminder_channel']?.toString() ?? 'whatsapp',
        lastReminderSent: json['last_reminder_sent'] != null ? DateTime.tryParse(json['last_reminder_sent'].toString()) : null,
        paymentMode: json['payment_mode']?.toString() ?? 'individual',
      );
    } catch (e) {
      print("Error parsing Plan ${json['id']}: $e");
      // Return a fallback plan instead of crashing app
      return Plan(
         id: json['id']?.toString() ?? 'error_plan', 
         creatorId: 'sys',
         title: 'Error de Datos', 
         eventDate: DateTime.now(), 
         locationName: 'Error'
      );
    }
  }
}
