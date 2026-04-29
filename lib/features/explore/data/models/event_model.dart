import 'package:planmapp/core/constants/image_pools.dart';

class Event {
  final String id;
  final String title;
  final String? description;
  final String? date;
  final String? location;
  final String? category;
  final String? _imageUrl;
  String? get imageUrl => (_imageUrl != null && _imageUrl!.isNotEmpty) ? _imageUrl : null;
  final String? sourceUrl;
  final String? endDate;
  final String? address;
  final String? contactPhone;
  final String? reservationLink;
  final String city;
  final String? visualKeyword;
  final double? latitude;
  final double? longitude;
  final String? promoHighlights;
  final String? status;
  final String? priceLevel;
  final bool? isOpen;
  final String? googlePlaceId;
  final double? ratingGoogle;
  final bool isVerified;
  final String? b2bTier;

  Event({
    required this.id,
    required this.title,
    this.description,
    this.date,
    this.location,
    this.category,
    String? imageUrl,
    this.sourceUrl,
    this.endDate,
    this.address,
    this.contactPhone,
    this.reservationLink,
    this.city = 'Bogotá',
    this.visualKeyword,
    this.latitude,
    this.longitude,
    this.googlePlaceId,
    this.ratingGoogle,
    this.promoHighlights,
    this.status = 'active',
    this.priceLevel,
    this.isOpen,
    this.isVerified = false,
    this.b2bTier,
  }) : _imageUrl = imageUrl;

  Event copyWith({
    String? id,
    String? title,
    String? description,
    String? date,
    String? location,
    String? category,
    String? imageUrl,
    String? sourceUrl,
    String? endDate,
    String? address,
    String? contactPhone,
    String? reservationLink,
    String? city,
    String? visualKeyword,
    double? latitude,
    double? longitude,
    String? googlePlaceId,
    double? ratingGoogle,
    String? promoHighlights,
    String? status,
    String? priceLevel,
    bool? isOpen,
    bool? isVerified,
    String? b2bTier,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      location: location ?? this.location,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      endDate: endDate ?? this.endDate,
      address: address ?? this.address,
      contactPhone: contactPhone ?? this.contactPhone,
      reservationLink: reservationLink ?? this.reservationLink,
      city: city ?? this.city,
      visualKeyword: visualKeyword ?? this.visualKeyword,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      ratingGoogle: ratingGoogle ?? this.ratingGoogle,
      promoHighlights: promoHighlights ?? this.promoHighlights,
      status: status ?? this.status,
      priceLevel: priceLevel ?? this.priceLevel,
      isOpen: isOpen ?? this.isOpen,
      isVerified: isVerified ?? this.isVerified,
      b2bTier: b2bTier ?? this.b2bTier,
    );
  }


  String get displayImageUrl {
    final searchSpace = "${visualKeyword ?? ''} ${title.toLowerCase()} ${description?.toLowerCase() ?? ''} ${category?.toLowerCase() ?? ''}";
    
    // Daily Rotation Seed
    final daysSinceEpoch = DateTime.now().difference(DateTime(1970, 1, 1)).inDays;
    
    String categoryKey = '';

    // 1. MATCH POR TIPOLOGÍAS ESPECÍFICAS
    if (searchSpace.contains('malecon') || searchSpace.contains('malecón') || searchSpace.contains('caiman del rio') || searchSpace.contains('caimán')) {
      categoryKey = 'malecon';
    } else if (searchSpace.contains('rio ') || searchSpace.contains('río ') || searchSpace.contains('magdalena')) {
      categoryKey = 'rio';
    } else if (searchSpace.contains('cine') || searchSpace.contains('película') || searchSpace.contains('cinema')) {
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
    } else if (searchSpace.contains('bar') || searchSpace.contains('cerveza') || searchSpace.contains('pola') || searchSpace.contains('cocktail') || searchSpace.contains('cóctel') || searchSpace.contains('rumba') || searchSpace.contains('discoteca')) {
      categoryKey = 'bares_cervezas';
    } else if (searchSpace.contains('concierto') || searchSpace.contains('rock') || searchSpace.contains('música en vivo')) {
      categoryKey = 'conciertos';
    } else if (searchSpace.contains('viaje') || searchSpace.contains('paseo') || searchSpace.contains('escapada')) {
      categoryKey = 'viajes';
    } else if (searchSpace.contains('acuatico') || searchSpace.contains('tobogán') || searchSpace.contains('parque de agua')) {
      categoryKey = 'parques_acuaticos';
    } else if (searchSpace.contains('playa') || searchSpace.contains('mar') || searchSpace.contains('arena') || searchSpace.contains('puerto colombia') || searchSpace.contains('salgar') || searchSpace.contains('pradomar')) {
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
      categoryKey = 'romantic';
    } else {
      categoryKey = 'city';
    }

    // Logic: Rotation by ID + Day
    final seed = (id.hashCode + daysSinceEpoch).abs() % 1000;
    return 'https://loremflickr.com/800/600/$categoryKey?lock=$seed';
  }

  String _getRandomFromPool(List<String> pool) {
    final seed = (id.hashCode + title.hashCode).abs() % 1000;
    return 'https://loremflickr.com/800/600/city?lock=$seed';
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      date: json['date'] as String?,
      location: json['location'] as String?,
      category: json['category'] as String?,
      imageUrl: (json['image_url'] != null && json['image_url'].toString().trim().isNotEmpty) ? json['image_url'] as String : null,
      sourceUrl: json['source_url'] as String?,
      endDate: json['end_date'] as String?,
      address: json['address'] as String?,
      contactPhone: json['contact_phone'] as String?,
      reservationLink: json['reservation_link'] as String?,
      city: json['city'] as String? ?? 'Bogotá',
      visualKeyword: json['visual_keyword'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      ratingGoogle: json['rating_google'] != null ? (json['rating_google'] as num).toDouble() : null,
      promoHighlights: json['promo_highlights'] as String?,
      status: json['status'] as String? ?? 'active',
      priceLevel: json['price_level'] as String?,
      isOpen: json['open_now'] as bool?,
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
      'contact_phone': contactPhone,
      'reservation_link': reservationLink,
      'city': city,
      'visual_keyword': visualKeyword,
      'latitude': latitude,
      'longitude': longitude,
      'google_place_id': googlePlaceId,
      'rating_google': ratingGoogle,
      'promo_highlights': promoHighlights,
      'status': status,
      'price_level': priceLevel,
      'open_now': isOpen,
    };
  }
}
