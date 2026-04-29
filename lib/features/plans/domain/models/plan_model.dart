import 'package:planmapp/core/constants/image_pools.dart';

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
  final String? imageUrl;
  final String? reservationLink;
  final String? contactInfo;
  final String? promoHighlights;
  final bool isDirectChat;
  final List<Map<String, dynamic>> itinerarySteps;

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
    this.imageUrl,
    this.reservationLink,
    this.contactInfo,
    this.promoHighlights,
    this.isDirectChat = false,
    this.itinerarySteps = const [],
  });

  String? get displayImageUrl {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) return imageUrl;

    final searchSpace = "${title.toLowerCase()} ${description?.toLowerCase() ?? ''} ${locationName.toLowerCase()}";
    final daysSinceEpoch = DateTime.now().difference(DateTime(1970, 1, 1)).inDays;
    
    String tag = 'city';

    if (searchSpace.contains('malecon') || searchSpace.contains('malecón') || searchSpace.contains('caiman del rio') || searchSpace.contains('caimán')) {
      tag = 'riverwalk';
    } else if (searchSpace.contains('rio ') || searchSpace.contains('río ') || searchSpace.contains('magdalena')) {
      tag = 'river';
    } else if (searchSpace.contains('cine') || searchSpace.contains('película') || searchSpace.contains('cinema')) {
      tag = 'cinema';
    } else if (searchSpace.contains('restaurante') || searchSpace.contains('comida') || searchSpace.contains('menú') || searchSpace.contains('hamburguesa') || searchSpace.contains('pizza') || searchSpace.contains('asado')) {
      tag = 'restaurant';
    } else if (searchSpace.contains('deporte') || searchSpace.contains('running') || searchSpace.contains('ciclismo') || searchSpace.contains('futbol') || searchSpace.contains('beisbol')) {
      tag = 'sports';
    } else if (searchSpace.contains('desayuno') || searchSpace.contains('almuerzo') || searchSpace.contains('brunch') || searchSpace.contains('cena')) {
      tag = 'food';
    } else if (searchSpace.contains('calle') || searchSpace.contains('pueblo') || searchSpace.contains('colonial')) {
      tag = 'street';
    } else if (searchSpace.contains('cultura') || searchSpace.contains('museo') || searchSpace.contains('arte') || searchSpace.contains('historia')) {
      tag = 'museum';
    } else if (searchSpace.contains('amigos') || searchSpace.contains('parche') || searchSpace.contains('reunión') || searchSpace.contains('cumpleaños')) {
      tag = 'friends';
    } else if (searchSpace.contains('bar') || searchSpace.contains('cerveza') || searchSpace.contains('pola') || searchSpace.contains('cocktail') || searchSpace.contains('cóctel') || searchSpace.contains('rumba') || searchSpace.contains('discoteca') || searchSpace.contains('fiesta')) {
      tag = 'bar';
    } else if (searchSpace.contains('concierto') || searchSpace.contains('rock') || searchSpace.contains('música en vivo')) {
      tag = 'concert';
    } else if (searchSpace.contains('viaje') || searchSpace.contains('paseo') || searchSpace.contains('escapada')) {
      tag = 'travel';
    } else if (searchSpace.contains('acuatico') || searchSpace.contains('tobogán') || searchSpace.contains('parque de agua')) {
      tag = 'waterpark';
    } else if (searchSpace.contains('playa') || searchSpace.contains('mar') || searchSpace.contains('arena') || searchSpace.contains('puerto colombia') || searchSpace.contains('salgar') || searchSpace.contains('pradomar')) {
      tag = 'beach';
    } else if (searchSpace.contains('piscina') || searchSpace.contains('pool') || searchSpace.contains('balneario')) {
      tag = 'pool';
    } else if (searchSpace.contains('iconico') || searchSpace.contains('monumento') || searchSpace.contains('turismo')) {
      tag = 'landmark';
    } else if (searchSpace.contains('festival') || searchSpace.contains('carnaval') || searchSpace.contains('feria')) {
      tag = 'festival';
    } else if (searchSpace.contains('natural') || searchSpace.contains('senderismo') || searchSpace.contains('naturaleza') || searchSpace.contains('campamento')) {
      tag = 'nature';
    } else if (searchSpace.contains('casa') || searchSpace.contains('lecura') || searchSpace.contains('gamer') || searchSpace.contains('netflix')) {
      tag = 'livingroom';
    } else if (searchSpace.contains('teatro') || searchSpace.contains('escena') || searchSpace.contains('obra')) {
      tag = 'theater';
    } else if (searchSpace.contains('romantico') || searchSpace.contains('pareja') || searchSpace.contains('amor') || searchSpace.contains('cita')) {
      tag = 'romantic';
    }

    final seed = (id.hashCode + daysSinceEpoch).abs() % 1000;
    return 'https://loremflickr.com/800/600/$tag?lock=$seed';
  }

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
      'image_url': imageUrl,
      'reservation_link': reservationLink,
      'contact_info': contactInfo,
      'promo_highlights': promoHighlights,
      'is_direct_chat': isDirectChat,
      'itinerary_steps': itinerarySteps,
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
        imageUrl: (json['image_url'] != null && json['image_url'].toString().trim().isNotEmpty) ? json['image_url'].toString() : null,
        reservationLink: json['reservation_link']?.toString(),
        contactInfo: json['contact_info']?.toString(),
        promoHighlights: json['promo_highlights']?.toString(),
        isDirectChat: json['is_direct_chat'] == true,
        itinerarySteps: _parseItinerarySteps(json['itinerary_steps']),
      );
    } catch (e) {
      print("Error parsing Plan ${json['id']}: $e");
      // Return a fallback plan instead of crashing app
      return Plan(
         id: json['id']?.toString() ?? 'error_plan', 
         creatorId: 'sys',
         title: 'Error de Datos', 
         eventDate: DateTime.now(), 
         locationName: 'Error',
         itinerarySteps: const [],
      );
    }
  }

  static List<Map<String, dynamic>> _parseItinerarySteps(dynamic raw) {
      if (raw == null) return [];
      try {
          if (raw is List) {
              return List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e)));
          }
      } catch (_) {}
      return [];
  }
}
