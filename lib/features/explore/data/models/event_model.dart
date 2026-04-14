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
  final double? latitude;
  final double? longitude;
  final String? googlePlaceId;
  final double? ratingGoogle;

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
    this.latitude,
    this.longitude,
    this.googlePlaceId,
    this.ratingGoogle,
  });

  String get displayImageUrl {
    final searchSpace = "${title.toLowerCase()} ${description?.toLowerCase() ?? ''} ${category?.toLowerCase() ?? ''}";
    
    String finalId = '';

    // 1. MATCH EXACTO POR PALABRAS CLAVES DEL TÍTULO/DESCRIPCIÓN (Alta prioridad para que tenga sentido)
    if (searchSpace.contains('cine') || searchSpace.contains('película')) {
        finalId = '1489599872518-e3c63964ff58'; // Asientos de cine rojos
    } else if (searchSpace.contains('hamburguesa') || searchSpace.contains('burger')) {
        finalId = '1568901346375-23c9450c58cd'; // Hamburguesa premium
    } else if (searchSpace.contains('pizza')) {
        finalId = '1513104890138-7c749659a591'; // Pizza leña
    } else if (searchSpace.contains('sushi')) {
        finalId = '1579871494447-9811cf80d66c'; // Sushi roll
    } else if (searchSpace.contains('café') || searchSpace.contains('coffee') || searchSpace.contains('brunch')) {
        finalId = '1476224203463-3a1315b41fae'; // Café aesthetic chill
    } else if (searchSpace.contains('teatro') || searchSpace.contains('obra')) {
        finalId = '1460661419205-02194c653ff9'; // Tarima de teatro con luces
    } else if (searchSpace.contains('comedia') || searchSpace.contains('stand up')) {
        finalId = '1585699324571-085731998ba2'; // Micrófono de standup
    } else if (searchSpace.contains('cerveza') || searchSpace.contains('pola') || searchSpace.contains('pub')) {
        finalId = '1514362545857-3bc16c4c7d1b'; // Brindis de cervezas
    } else if (searchSpace.contains('rock') || searchSpace.contains('metal')) {
        finalId = '1498038432885-c6f3f1b912ee'; // Guitarrista rock en vivo
    } else if (searchSpace.contains('tributo')) {
        finalId = '1459749411175-04bf5292ceea'; // Banda en vivo luces
    } else if (searchSpace.contains('reggaeton') || searchSpace.contains('electrónic') || searchSpace.contains('dj')) {
        finalId = '1516450360452-9312f5e86fc7'; // DJ tocando en rumba
    } else if (searchSpace.contains('parque') || searchSpace.contains('caminata') || searchSpace.contains('senderismo')) {
        finalId = '1478131143081-80f7f84ca84d'; // Gente caminando en parque/naturaleza
    } else if (searchSpace.contains('gato') || searchSpace.contains('perro') || searchSpace.contains('mascota')) {
        finalId = '1548199973-03cce0bbc87b'; // Perrito feliz
    } else if (searchSpace.contains('arte') || searchSpace.contains('exposición')) {
        finalId = '1533105079780-92b9be482077'; // Galería de arte moderna
    } else if (searchSpace.contains('vino') || searchSpace.contains('cata')) {
        finalId = '1506377247377-2a5b3b417ebb'; // Copas de vino
    }

    // 2. MATCH GENÉRICO POR CATEGORÍA BÁSICA (Fallback con cálculo pseudo-aleatorio para variedad)
    else {
        List<String> pool = [];
        if (searchSpace.contains('food') || searchSpace.contains('restaurante')) {
            pool = ['1414235077428-9711855ed407', '1550966871-3ed3cdb5ce0c', '1504674900247-0877df9cc836', '1517248135467-4c7edcad34c4'];
        } else if (searchSpace.contains('party') || searchSpace.contains('rumba') || searchSpace.contains('concierto')) {
            pool = ['1514525253161-7a46d19cd819', '1520113101900-51c0d45bf860', '1540039155732-6bc14b781b03', '1470225620780-dba8ba36b745'];
        } else if (searchSpace.contains('outdoors') || searchSpace.contains('aire libre')) {
            pool = ['1501555088652-0dcac8b233a7', '1441973656156-fbf3e0a89d31', '1519331379826-f16638a16709', '1526772662000-2f882ecc3025'];
        } else if (searchSpace.contains('culture') || searchSpace.contains('cultura')) {
            pool = ['1518998053901-5362aa729aae', '1544928147-79a203f71c4c', '1561214115-f2f134cc4912'];
        } else {
            pool = ['1492684223066-81342ee5ff30', '1511632765486-a96cb75aa88a', '1464366400600-7168b8b7edad', '1523580494863-6f3031224c94'];
        }
        
        int index = (id.hashCode + title.hashCode).abs() % pool.length;
        finalId = pool[index];
    }

    return 'https://images.unsplash.com/photo-$finalId?auto=format&fit=crop&q=80&w=800';
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
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      googlePlaceId: json['google_place_id'] as String?,
      ratingGoogle: json['rating_google'] != null ? (json['rating_google'] as num).toDouble() : null,
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
      'latitude': latitude,
      'longitude': longitude,
      'google_place_id': googlePlaceId,
      'rating_google': ratingGoogle,
    };
  }
}
