import 'package:planmapp/core/constants/image_pools.dart';

class Event {
  final String id;
  final String title;
  final String? description;
  final String? date;
  final String? location;
  final String? category;
  final String? imageUrl;
  final String? sourceUrl;
  final String? endDate;
  final String? address;
  final String? contactInfo;
  final String city;
  final String? visualKeyword;
  final double? latitude;
  final double? longitude;
  final String? googlePlaceId;
  final double? ratingGoogle;
  final String? promoHighlights;
  final String? status;

  Event({
    required this.id,
    required this.title,
    this.description,
    this.date,
    this.location,
    this.category,
    this.imageUrl,
    this.sourceUrl,
    this.endDate,
    this.address,
    this.contactInfo,
    this.city = 'Bogotá',
    this.visualKeyword,
    this.latitude,
    this.longitude,
    this.googlePlaceId,
    this.ratingGoogle,
    this.promoHighlights,
    this.status = 'active',
  });

  String get displayImageUrl {
    final searchSpace = "${visualKeyword ?? ''} ${title.toLowerCase()} ${description?.toLowerCase() ?? ''} ${category?.toLowerCase() ?? ''}";
    
    // Daily Rotation Seed
    final daysSinceEpoch = DateTime.now().difference(DateTime(1970, 1, 1)).inDays;
    
    String categoryKey = '';

    // 1. MATCH POR TIPOLOGÍAS ESPECÍFICAS
    if (searchSpace.contains('cine') || searchSpace.contains('película') || searchSpace.contains('cinema')) {
      categoryKey = 'cine';
    } else if (searchSpace.contains('restaurante') || searchSpace.contains('comida') || searchSpace.contains('menú')) {
      categoryKey = 'restaurante';
    } else if (searchSpace.contains('deporte') || searchSpace.contains('running') || searchSpace.contains('ciclismo') || searchSpace.contains('futbol') || searchSpace.contains('beisbol')) {
      categoryKey = 'deporte';
    } else if (searchSpace.contains('desayuno') || searchSpace.contains('almuerzo') || searchSpace.contains('brunch') || searchSpace.contains('cena')) {
      categoryKey = 'comida';
    } else if (searchSpace.contains('calle') || searchSpace.contains('pueblo') || searchSpace.contains('colonial')) {
      categoryKey = 'calles_colombia';
    } else if (searchSpace.contains('cultura') || searchSpace.contains('museo') || searchSpace.contains('arte') || searchSpace.contains('historia')) {
      categoryKey = 'cultura';
    } else if (searchSpace.contains('amigos') || searchSpace.contains('parche') || searchSpace.contains('reunión')) {
      categoryKey = 'amigos';
    } else if (searchSpace.contains('bar') || searchSpace.contains('cerveza') || searchSpace.contains('pola') || searchSpace.contains('cocktail') || searchSpace.contains('cóctel')) {
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

    String finalId = '';
    final pool = ImagePools.pools[categoryKey] ?? ImagePools.pools['cultura']!;
    
    // Logic: Rotation by ID + Day
    final seed = (id.hashCode + daysSinceEpoch).abs();
    finalId = pool[seed % pool.length];

    // Handle Backup as emergency fallback (though pool is now large)
    return 'https://images.unsplash.com/photo-$finalId?auto=format&fit=crop&q=80&w=800';
  }

  String _getRandomFromPool(List<String> pool) {
    if (pool.isEmpty) return '1492684223066-81342ee5ff30';
    final hashCode = (id.hashCode + title.hashCode).abs();
    return pool[hashCode % pool.length];
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      date: json['date'] as String?,
      location: json['location'] as String?,
      category: json['category'] as String?,
      imageUrl: json['image_url'] as String?,
      sourceUrl: json['source_url'] as String?,
      endDate: json['end_date'] as String?,
      address: json['address'] as String?,
      contactInfo: json['contact_info'] as String?,
      city: json['city'] as String? ?? 'Bogotá',
      visualKeyword: json['visual_keyword'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      googlePlaceId: json['google_place_id'] as String?,
      ratingGoogle: json['rating_google'] != null ? (json['rating_google'] as num).toDouble() : null,
      promoHighlights: json['promo_highlights'] as String?,
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date,
      'location': location,
      'category': category,
      'image_url': imageUrl,
      'source_url': sourceUrl,
      'end_date': endDate,
      'address': address,
      'contact_info': contactInfo,
      'city': city,
      'visual_keyword': visualKeyword,
      'latitude': latitude,
      'longitude': longitude,
      'google_place_id': googlePlaceId,
      'rating_google': ratingGoogle,
      'promo_highlights': promoHighlights,
      'status': status,
    };
  }
}
