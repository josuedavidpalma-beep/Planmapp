import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class PlacesService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // WARNING: Ensure you pass this from a secure source (e.g. Supabase secrets or dart-define)
  final String? _apiKey = const String.fromEnvironment('MAPS_API_KEY');

  /// Fetches nearby places with caching logic (7-day TTL).
  Future<List<Map<String, dynamic>>> getNearbyPlaces({
    required String city,
    required double lat,
    required double lng,
    double radius = 17000.0,
    String? category, // e.g. 'restaurant'
  }) async {
    try {
      // 1. Try to fetch from Supabase cache first
      var query = _supabase
          .from('cached_places')
          .select()
          .eq('city', city);
          
      if (category != null) {
          query = query.eq('category', category);
      }
      
      final cacheResponse = await query
          .order('last_updated', ascending: false)
          .limit(100);

      // Check TTL (7 days)
      if (cacheResponse.isNotEmpty) {
        final lastUpdate = DateTime.parse(cacheResponse[0]['last_updated']);
        if (DateTime.now().difference(lastUpdate).inDays < 7) {
          print('✅ Serving from Supabase Cache');
          return List<Map<String, dynamic>>.from(cacheResponse);
        }
      }

      if (_apiKey == null || _apiKey!.isEmpty) {
        print('⚠️ MAPS_API_KEY not found. Returning empty list.');
        return [];
      }

      print('🌐 Fetching from Google Places API (New)...');

      // 2. Fetch from Google Places API (New)
      // Convert our internal categories to valid Google Places types
      List<String> validTypes = [];
      if (category != null) {
          if (category == 'restaurant') {
              validTypes = ["restaurant", "cafe", "bakery"];
          } else if (category == 'bar') {
              validTypes = ["bar", "night_club"];
          } else if (category == 'movie_theater') {
              validTypes = ["movie_theater", "museum", "art_gallery"];
          } else if (category == 'gym') {
              validTypes = ["gym", "spa", "park", "stadium", "fitness_center", "sports_club"];
          } else if (category == 'park') {
              validTypes = ["park", "campground", "amusement_park", "tourist_attraction"];
          } else {
              validTypes = [category];
          }
      } else {
          validTypes = ["restaurant", "bar", "cafe", "tourist_attraction", "park", "museum", "shopping_mall", "beauty_salon", "spa", "movie_theater"];
      }

      final url = Uri.parse('https://places.googleapis.com/v1/places:searchNearby');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey!,
          // Optimized Field Masking: Added priceLevel and regularOpeningHours
          'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.rating,places.photos,places.location,places.types,places.priceLevel,places.regularOpeningHours',
        },
        body: jsonEncode({
          "includedTypes": validTypes,
          "excludedPrimaryTypes": [
              "dentist", "doctor", "school", "bank", "hospital", "pharmacy", 
              "police", "laundry", "car_repair", "hair_care", "hardware_store", 
              "veterinary_care", "real_estate_agency", "lawyer", "atm"
          ],
          "maxResultCount": 20,
          "locationRestriction": {
            "circle": {
              "center": {"latitude": lat, "longitude": lng},
              "radius": radius
            }
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List places = data['places'] ?? [];

        final results = <Map<String, dynamic>>[];

        for (var p in places) {
          final types = List<String>.from(p['types'] ?? []);
          final nameStr = p['displayName']?['text']?.toString().toLowerCase() ?? '';
          
          // Strict block against parsing neighborhoods/zones as if they were commercial places
          if (nameStr.contains('barrio') || types.contains('neighborhood') || types.contains('sublocality') || types.contains('locality') || types.contains('political') || types.contains('administrative_area_level_1') || types.contains('administrative_area_level_2')) {
              continue;
          }
          final mapped = {
            'place_id': p['id'],
            'name': p['displayName']?['text'] ?? 'Lugar desconocido',
            'address': p['formattedAddress'],
            'rating': p['rating']?.toDouble(),
            'photo_reference': (p['photos'] != null && p['photos'].isNotEmpty) 
                ? p['photos'][0]['name'] 
                : null,
            'latitude': p['location']?['latitude'],
            'longitude': p['location']?['longitude'],
            'city': city,
            'category': category ?? 'restaurant',
            'price_level': _mapPriceLevel(p['priceLevel']),
            'open_now': p['regularOpeningHours']?['openNow'] ?? false,
            'last_updated': DateTime.now().toIso8601String(),
          };

          // Filter out low quality places: We accept >= 4.0.
          final double? rating = mapped['rating'] as double?;
          if (rating != null && rating >= 4.0) {
              await _supabase.from('cached_places').upsert(mapped);
              results.add(mapped);
          }
        }

        return results;
      } else {
        throw Exception('Google Places API Error: ${response.body}');
      }
    } catch (e) {
      print('❌ PlacesService Error: $e');
      return [];
    }
  }

  /// NEW: Searches for specific places by name in a city.
  Future<List<Map<String, dynamic>>> searchPlacesByName(String query, String city) async {
    if (_apiKey == null || _apiKey!.isEmpty) return [];
    
    try {
      // 1. First check cache for similar names in the same city
      final cacheRes = await _supabase
          .from('cached_places')
          .select()
          .eq('city', city)
          .ilike('name', '%$query%')
          .limit(10);
      
      if (cacheRes.isNotEmpty) {
          return List<Map<String, dynamic>>.from(cacheRes);
      }

      // 2. Search via Google Places Text Search
      final url = Uri.parse('https://places.googleapis.com/v1/places:searchText');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey!,
          'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.rating,places.photos,places.location,places.types,places.priceLevel',
        },
        body: jsonEncode({
          "textQuery": "$query in $city",
          "maxResultCount": 10,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List places = data['places'] ?? [];
        final results = <Map<String, dynamic>>[];

        for (var p in places) {
          final types = List<String>.from(p['types'] ?? []);
          final nameStr = p['displayName']?['text']?.toString().toLowerCase() ?? '';
          
          if (nameStr.contains('barrio') || types.contains('neighborhood') || types.contains('sublocality') || types.contains('locality') || types.contains('political') || types.contains('administrative_area_level_1') || types.contains('administrative_area_level_2')) {
              continue;
          }
          final mapped = {
            'place_id': p['id'],
            'name': p['displayName']?['text'] ?? 'Lugar desconocido',
            'address': p['formattedAddress'],
            'rating': p['rating']?.toDouble(),
            'photo_reference': (p['photos'] != null && p['photos'].isNotEmpty) 
                ? p['photos'][0]['name'] 
                : null,
            'latitude': p['location']?['latitude'],
            'longitude': p['location']?['longitude'],
            'city': city,
            'category': 'search_result', // Marking to avoid categorization bugs
            'price_level': _mapPriceLevel(p['priceLevel']),
            'last_updated': DateTime.now().toIso8601String(),
          };
          await _supabase.from('cached_places').upsert(mapped);
          results.add(mapped);
        }
        return results;
      }
      return [];
    } catch (e) {
      print('❌ searchPlacesByName Error: $e');
      return [];
    }
  }

  String? _mapPriceLevel(dynamic level) {
    if (level == null) return null;
    // Google returns enum strings like 'PRICE_LEVEL_MODERATE' or potentially ints depending on lib versions
    final levelStr = level.toString();
    if (levelStr.contains('INEXPENSIVE') || levelStr == '1') return '\$';
    if (levelStr.contains('MODERATE') || levelStr == '2') return '\$\$';
    if (levelStr.contains('EXPENSIVE') || levelStr == '3') return '\$\$\$';
    if (levelStr.contains('VERY_EXPENSIVE') || levelStr == '4') return '\$\$\$\$';
    return null;
  }

  /// Generates a Photo URL with 400px max width as requested.
  String? getPhotoUrl(String? photoName) {
    if (photoName == null || photoName.isEmpty || _apiKey == null || _apiKey!.isEmpty) return null;
    // photoName is in format: "places/PLACE_ID/photos/PHOTO_ID"
    return 'https://places.googleapis.com/v1/$photoName/media?maxHeightPx=400&maxWidthPx=400&key=$_apiKey';
  }
}
