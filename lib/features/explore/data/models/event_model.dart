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
  });

  String get displayImageUrl {
    final searchSpace = "${visualKeyword ?? ''} ${title.toLowerCase()} ${description?.toLowerCase() ?? ''} ${category?.toLowerCase() ?? ''}";
    
    String finalId = '';

    // 1. MATCH POR PALABRAS CLAVES ESPECÍFICAS (Búsqueda refinada)
    if (searchSpace.contains('cine') || searchSpace.contains('película') || searchSpace.contains('movie') || searchSpace.contains('cinema')) {
        finalId = _getRandomFromPool(['1489599872518-e3c63964ff58', '1460661419205-02194c653ff9', '1585699324571-085731998ba2', '1461344573914-f7ad62660a74', '1517604435381-db28af7cf9d2']);
    } else if (searchSpace.contains('bolera') || searchSpace.contains('bowling')) {
        finalId = '1538108122303-07d745a30abb';
    } else if (searchSpace.contains('billar') || searchSpace.contains('pool table')) {
        finalId = '1542190897-447b869408d6';
    } else if (searchSpace.contains('karaoke')) {
        finalId = '1516280440605-db561c20980d';
    } else if (searchSpace.contains('hamburguesa') || searchSpace.contains('burger')) {
        finalId = '1568901346375-23c9450c58cd';
    } else if (searchSpace.contains('pizza')) {
        finalId = '1513104890138-7c749659a591';
    } else if (searchSpace.contains('sushi')) {
        finalId = '1579871494447-9811cf80d66c';
    } else if (searchSpace.contains('taco') || searchSpace.contains('mexican')) {
        finalId = '1565293288621-4d57c91a3c0c';
    } else if (searchSpace.contains('café') || searchSpace.contains('coffee') || searchSpace.contains('brunch')) {
        finalId = _getRandomFromPool(['1476224203463-3a1315b41fae', '1554118811-1e0d58224f24', '1501339847302-3861fb1796d3', '1511923211756-58bba0979509', '1525648199079-0599525406c7']);
    } else if (searchSpace.contains('cerveza') || searchSpace.contains('pola') || searchSpace.contains('pub') || searchSpace.contains('bar') || searchSpace.contains('cocktail')) {
        finalId = _getRandomFromPool(['1514362545857-3bc16c4c7d1b', '1470333738048-3a1525eef926', '1510626176241-af6dc395cf90', '1551024709-3769c76b4122', '1543007630-976d06086a9f']);
    } else if (searchSpace.contains('rock') || searchSpace.contains('concierto') || searchSpace.contains('festival')) {
        finalId = '1470225620780-dba8ba36b745';
    } else if (searchSpace.contains('dj') || searchSpace.contains('disco') || searchSpace.contains('rumba') || searchSpace.contains('party')) {
        finalId = _getRandomFromPool(['1514525253161-7a46d19cd819', '1516450360452-9312f5e86fc7', '1520113101900-51c0d45bf860', '1533170762720-efec82a4d801', '1540039155732-6bc14b781b03']);
    } else if (searchSpace.contains('parque') || searchSpace.contains('naturaleza') || searchSpace.contains('hiking') || searchSpace.contains('outdoors')) {
        finalId = _getRandomFromPool(['1441974231531-c6227db76b6e', '1501555088652-0dcac8b233a7', '1519331379826-f16638a16709', '1526772662000-2f882ecc3025', '1472214103451-9374bd1c798e']);
    } else if (searchSpace.contains('museo') || searchSpace.contains('arte') || searchSpace.contains('gallery') || searchSpace.contains('culture')) {
        finalId = _getRandomFromPool(['1533105079780-92b9be482077', '1533174072545-7a4b6ad7a6c3', '1561214115-f2f134cc4912', '1501862700950-ef8c2c2a49aa', '1459749411175-04bf5292ceea']);
    }

    // 2. FALLBACK SI NO HAY MATCH ESPECÍFICO (O si el local event no tiene visual_keyword)
    if (finalId.isEmpty) {
        // Only use scraping image as a last resort if it looks like a reliable direct link
        if (imageUrl != null && imageUrl!.contains('unsplash.com')) {
            return imageUrl!;
        }
        
        final categoryPool = [
          '1492684223066-81342ee5ff30', // Party
          '1517048676732-d65bc937f952', // Social (Verified)
          '1441974231531-c6227db76b6e', // Nature (Verified)
          '1523580494863-6f3031224c94', // Aesthetic Gathering
          '1470225620780-dba8ba36b745', // Live Music
          '1533174072545-7a4b6ad7a6c3', // Culture (Verified)
          '1517248135467-4c7edcad34c4', // Dining
        ];
        finalId = _getRandomFromPool(categoryPool);
    }

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
    };
  }
}
