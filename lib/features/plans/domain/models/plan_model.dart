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

  String get displayImageUrl {
    final searchSpace = "${title.toLowerCase()} ${description?.toLowerCase() ?? ''} ${locationName.toLowerCase()}";
    final daysSinceEpoch = DateTime.now().difference(DateTime(1970, 1, 1)).inDays;
    
    String categoryKey = '';

    if (searchSpace.contains('cine') || searchSpace.contains('película') || searchSpace.contains('cinema')) {
      categoryKey = 'cine';
    } else if (searchSpace.contains('restaurante') || searchSpace.contains('comida') || searchSpace.contains('menú')) {
      categoryKey = 'restaurante';
    } else if (searchSpace.contains('deporte') || searchSpace.contains('running') || searchSpace.contains('futbol') || searchSpace.contains('beisbol')) {
      categoryKey = 'deporte';
    } else if (searchSpace.contains('desayuno') || searchSpace.contains('almuerzo') || searchSpace.contains('brunch') || searchSpace.contains('cena')) {
      categoryKey = 'comida';
    } else if (searchSpace.contains('cultura') || searchSpace.contains('museo') || searchSpace.contains('arte') || searchSpace.contains('historia')) {
      categoryKey = 'cultura';
    } else if (searchSpace.contains('amigos') || searchSpace.contains('parche') || searchSpace.contains('reunión')) {
      categoryKey = 'amigos';
    } else if (searchSpace.contains('bar') || searchSpace.contains('cerveza') || searchSpace.contains('pola') || searchSpace.contains('cocktail')) {
      categoryKey = 'bares_cervezas';
    } else if (searchSpace.contains('concierto') || searchSpace.contains('rock') || searchSpace.contains('música en vivo')) {
      categoryKey = 'conciertos';
    } else if (searchSpace.contains('viaje') || searchSpace.contains('paseo') || searchSpace.contains('escapada')) {
      categoryKey = 'viajes';
    } else if (searchSpace.contains('acuatico') || searchSpace.contains('tobogán') || searchSpace.contains('parque de agua')) {
      categoryKey = 'parques_acuaticos';
    } else if (searchSpace.contains('playa') || searchSpace.contains('mar') || searchSpace.contains('arena')) {
      categoryKey = 'playas';
    } else if (searchSpace.contains('piscina') || searchSpace.contains('pool') || searchSpace.contains('balneario')) {
      categoryKey = 'piscina';
    } else if (searchSpace.contains('iconico') || searchSpace.contains('monumento') || searchSpace.contains('turismo')) {
      categoryKey = 'lugares_iconicos';
    } else if (searchSpace.contains('festival') || searchSpace.contains('carnaval') || searchSpace.contains('feria')) {
      categoryKey = 'festivales';
    } else if (searchSpace.contains('natural') || searchSpace.contains('senderismo') || searchSpace.contains('naturaleza') || searchSpace.contains('campamento')) {
      categoryKey = 'parques_naturales';
    } else if (searchSpace.contains('casa') || searchSpace.contains('lecura') || searchSpace.contains('gamer') || searchSpace.contains('netflix')) {
      categoryKey = 'planes_casa';
    } else if (searchSpace.contains('teatro') || searchSpace.contains('escena') || searchSpace.contains('obra')) {
      categoryKey = 'teatro';
    } else if (searchSpace.contains('romantico') || searchSpace.contains('pareja') || searchSpace.contains('amor') || searchSpace.contains('cita')) {
      categoryKey = 'romantico';
    }

    final pool = ImagePools.pools[categoryKey] ?? ImagePools.pools['cultura']!;
    final seed = (id.hashCode + daysSinceEpoch).abs();
    final finalId = pool[seed % pool.length];

    final rawUrl = 'images.unsplash.com/photo-$finalId?auto=format&fit=crop&q=80&w=800';
    return 'https://wsrv.nl/?url=${Uri.encodeComponent(rawUrl)}';
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
        imageUrl: json['image_url']?.toString(),
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
