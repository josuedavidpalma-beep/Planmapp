import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/explore/data/models/event_model.dart';
import 'package:planmapp/features/explore/services/places_service.dart';

class EventsService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final PlacesService _placesService = PlacesService();

  /// NEW: Fetches static local businesses from Google Places with personalization
  Future<List<Event>> getPlaces({
    String city = 'Barranquilla', 
    String? category,
    List<String>? userInterests,
    String? budgetLevel,
  }) async {
    try {
      // coordinates for Barranquilla (Default) - In a real scenario, this would be dynamic
      final coords = {
        "Bogotá": [4.711, -74.072],
        "Medellín": [6.244, -75.581],
        "Cali": [3.451, -76.532],
        "Barranquilla": [10.963, -74.796],
        "Cartagena": [10.391, -75.479],
      };
      
      double lat = coords[city]?[0] ?? 10.9685;
      double lng = coords[city]?[1] ?? -74.7813;

      final places = await _placesService.getNearbyPlaces(lat: lat, lng: lng, category: category);
      
      List<Event> events = places.map((p) => Event(
        id: p['place_id'],
        title: p['name'],
        address: p['address'],
        location: p['name'],
        imageUrl: _placesService.getPhotoUrl(p['photo_reference']),
        ratingGoogle: p['rating'],
        latitude: p['latitude'],
        longitude: p['longitude'],
        category: p['category'],
        city: city,
        googlePlaceId: p['place_id'],
        priceLevel: p['price_level'],
      )).toList();

      // 1. BUDGET FILTERING
      if (budgetLevel == 'economico') {
        events = events.where((e) => (e.priceLevel?.length ?? 0) <= 1).toList();
      } else if (budgetLevel == 'bacano') {
        events = events.where((e) => (e.priceLevel?.length ?? 0) <= 3).toList();
      }

      // 2. INTEREST RANKING
      if (userInterests != null && userInterests.isNotEmpty) {
        events.sort((a, b) {
          bool aMatches = userInterests.any((interest) => 
             (a.category?.toLowerCase().contains(interest.toLowerCase()) ?? false) ||
             (a.title.toLowerCase().contains(interest.toLowerCase()))
          );
          bool bMatches = userInterests.any((interest) => 
             (b.category?.toLowerCase().contains(interest.toLowerCase()) ?? false) ||
             (b.title.toLowerCase().contains(interest.toLowerCase()))
          );
          if (aMatches && !bMatches) return -1;
          if (!aMatches && bMatches) return 1;
          return 0;
        });
      }

      return events;
    } catch (e) {
      print('❌ getPlaces Error: $e');
      return [];
    }
  }

  /// NEW: Fetches real-time events/promos with personalized ranking
  Future<List<Event>> getDailyEvents({
    String city = 'Barranquilla',
    List<String>? userInterests,
    String? budgetLevel,
    int? userAge,
  }) async {
    try {
      var query = _supabase
          .from('local_events')
          .select()
          .eq('city', city)
          .eq('status', 'active');

      final localResponse = await query.order('date', ascending: true);

      if (localResponse is List) {
        List<Event> events = localResponse.map((e) => Event(
          id: e['id'].toString(),
          title: e['event_name'],
          description: e['description'],
          date: e['date'],
          endDate: e['end_date'],
          location: e['venue_name'],
          address: e['address'],
          imageUrl: e['image_url'],
          category: e['vibe_tag']?.split('/')[0] ?? 'General',
          sourceUrl: e['reservation_link'] ?? e['primary_source'],
          contactInfo: e['contact_phone'],
          latitude: e['latitude'],
          longitude: e['longitude'],
          city: e['city'],
          promoHighlights: e['promo_highlights'],
          priceLevel: e['price_level'],
        )).toList();

        // 1. AGE FILTERING (My criterion: Exclude heavy nightlife/bars if under 18)
        if (userAge != null && userAge < 18) {
           events = events.where((e) {
             final cat = e.category?.toLowerCase() ?? '';
             return !cat.contains('nightlife') && !cat.contains('bar') && !cat.contains('rumba');
           }).toList();
        }

        // 2. BUDGET FILTERING
        // Mapping: Ahorrador -> $, Equilibrado -> $, $$, $$$ , Ilimitado -> All
        if (budgetLevel == 'economico') {
          events = events.where((e) => (e.priceLevel?.length ?? 0) <= 1).toList();
        } else if (budgetLevel == 'bacano') {
          events = events.where((e) => (e.priceLevel?.length ?? 0) <= 3).toList();
        }

        // 3. PERSONALIZED RANKING (Interests match)
        if (userInterests != null && userInterests.isNotEmpty) {
          events.sort((a, b) {
            bool aMatches = userInterests.any((interest) => 
               (a.category?.toLowerCase().contains(interest.toLowerCase()) ?? false) ||
               (a.title.toLowerCase().contains(interest.toLowerCase()))
            );
            bool bMatches = userInterests.any((interest) => 
               (b.category?.toLowerCase().contains(interest.toLowerCase()) ?? false) ||
               (b.title.toLowerCase().contains(interest.toLowerCase()))
            );
            if (aMatches && !bMatches) return -1;
            if (!aMatches && bMatches) return 1;
            return 0;
          });
        }

        return events;
      }
      return [];
    } catch (e) {
      print('❌ getDailyEvents Error: $e');
      return [];
    }
  }
}
