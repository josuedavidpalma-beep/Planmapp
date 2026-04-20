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
      // 0. INTERCEPT: Preventas (Nationwide Future Events)
      if (category == 'preventas') {
          final today = DateTime.now().toIso8601String().split('T')[0];
          
          final localRes = await _supabase
              .from('local_events')
              .select()
              .eq('status', 'active')
              .gte('date', today) // All upcoming events from today
              .order('date', ascending: true)
              .limit(20);
              
          if (localRes is List) {
              return localRes.map((e) => Event(
                  id: e['id'].toString(),
                  title: e['event_name'],
                  description: e['description'],
                  date: e['date'],
                  endDate: e['end_date'],
                  location: e['venue_name'],
                  address: e['address'],
                  imageUrl: (e['image_url'] != null && e['image_url'].toString().isNotEmpty) ? e['image_url'] : null,
                  category: 'Preventa',
                  sourceUrl: e['reservation_link'] ?? e['primary_source'],
                  city: e['city'],
                  promoHighlights: e['promo_highlights'],
                  contactInfo: e['contact_phone']
              )).toList();
          }
          return [];
      }

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

      final places = await _placesService.getNearbyPlaces(city: city, lat: lat, lng: lng, category: category);
      
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

      // INTERCEPT: Cine & Arte Custom Billboard Injection
      if (category == 'movie_theater') {
          events.insert(0, Event(
              id: 'cartelera_nacional',
              title: "🍿 En Cartelera Hoy (Estrenos)",
              description: "Revisa los horarios y estrenos de películas en las principales cadenas de cine: Cine Colombia, Royal Films, Cinemark.",
              address: "Múltiples opciones de cines y salas VIP.",
              location: "Nacional",
              imageUrl: "https://images.unsplash.com/photo-1536440136628-849c177e76a1?q=80&w=1000&auto=format&fit=crop",
              category: "Cine & Arte",
              city: city,
              sourceUrl: "https://www.cinecolombia.com", 
              promoHighlights: "🍿 COMPRAR BOLETAS ONLINE",
          ));
      }

      // 1. BUDGET FILTERING
      if (budgetLevel == 'economico') {
        events = events.where((e) => (e.priceLevel?.length ?? 0) <= 1).toList();
      } else if (budgetLevel == 'bacano') {
        events = events.where((e) => (e.priceLevel?.length ?? 0) <= 3).toList();
      }

      // 2. STRICT INTEREST FILTERING & RANKING
      if (userInterests != null && userInterests.isNotEmpty) {
          // Translate user vibes (Spanish) to Google Places tags (English)
          final Set<String> validTags = {};
          for (final raw in userInterests) {
              final interest = raw.toLowerCase();
              if (interest.contains('comida') || interest.contains('gastro') || interest.contains('restaurante')) { validTags.addAll(['restaurant', 'food', 'cafe']); }
              if (interest.contains('rumba') || interest.contains('party') || interest.contains('fiesta')) { validTags.addAll(['bar', 'night_club']); }
              if (interest.contains('aventura') || interest.contains('outdoor')) { validTags.addAll(['park', 'amusement_park', 'campground']); }
              if (interest.contains('cultura') || interest.contains('cine') || interest.contains('arte')) { validTags.addAll(['museum', 'tourist_attraction', 'movie_theater', 'art_gallery']); }
              if (interest.contains('chill') || interest.contains('café')) { validTags.addAll(['cafe', 'spa', 'park']); }
              if (interest.contains('belleza')) { validTags.addAll(['beauty_salon', 'spa', 'hair_care']); }
          }
          
          // Sort locations intelligently
          events.sort((a,b) {
             if (a.id == 'cartelera_nacional') return -1;
             if (b.id == 'cartelera_nacional') return 1;
             
             final catA = a.category?.toLowerCase() ?? '';
             final catB = b.category?.toLowerCase() ?? '';
             
             bool aHasVibe = validTags.any((t) => catA.contains(t));
             bool bHasVibe = validTags.any((t) => catB.contains(t));
             
             bool aExactMatch = userInterests.any((interest) => a.title.toLowerCase().contains(interest.toLowerCase()));
             bool bExactMatch = userInterests.any((interest) => b.title.toLowerCase().contains(interest.toLowerCase()));
             
             int scoreA = (aExactMatch ? 2 : 0) + (aHasVibe ? 1 : 0);
             int scoreB = (bExactMatch ? 2 : 0) + (bHasVibe ? 1 : 0);
             
             return scoreB.compareTo(scoreA);
          });
      }

      return events;
    } catch (e) {
      print('❌ getPlaces Error: $e');
      return [];
    }
  }

  /// NEW: Search for places by name
  Future<List<Event>> searchPlaces({required String query, required String city}) async {
    try {
      final results = await _placesService.searchPlacesByName(query, city);
      return results.map((p) => Event(
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
    } catch (e) {
      print('❌ searchPlaces Error: $e');
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
          imageUrl: (e['image_url'] != null && e['image_url'].toString().isNotEmpty) ? e['image_url'] : null,
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

        // 3. STRICT INTEREST FILTERING & RANKING
        if (userInterests != null && userInterests.isNotEmpty) {
            final Set<String> validTags = {};
            for (final raw in userInterests) {
                final interest = raw.toLowerCase();
                if (interest.contains('comida') || interest.contains('gastro')) { validTags.addAll(['comida', 'gastro', 'food', 'restaurant']); }
                if (interest.contains('rumba') || interest.contains('party')) { validTags.addAll(['rumba', 'party', 'bar', 'club', 'nightlife']); }
                if (interest.contains('aventura') || interest.contains('outdoor')) { validTags.addAll(['aventura', 'outdoor', 'park']); }
                if (interest.contains('cultura') || interest.contains('cine')) { validTags.addAll(['cultura', 'cine', 'museum', 'art']); }
                if (interest.contains('chill') || interest.contains('café')) { validTags.addAll(['chill', 'cafe', 'coffee']); }
                if (interest.contains('belleza')) { validTags.addAll(['belleza', 'spa', 'wellness']); }
            }
            
            // Remove strict filtering for daily events so we show all city events,
            // but we'll sort the ones that match their vibe strictly to the top.
            
            events.sort((a, b) {
              if (a.id == 'cartelera_nacional') return -1;
              if (b.id == 'cartelera_nacional') return 1;
              
              final catA = a.category?.toLowerCase() ?? '';
              final catB = b.category?.toLowerCase() ?? '';
              
              bool aHasVibe = validTags.any((t) => catA.contains(t));
              bool bHasVibe = validTags.any((t) => catB.contains(t));
              
              bool aExactMatch = userInterests.any((interest) => a.title.toLowerCase().contains(interest.toLowerCase()));
              bool bExactMatch = userInterests.any((interest) => b.title.toLowerCase().contains(interest.toLowerCase()));
              
              int scoreA = (aExactMatch ? 2 : 0) + (aHasVibe ? 1 : 0);
              int scoreB = (bExactMatch ? 2 : 0) + (bHasVibe ? 1 : 0);
              
              return scoreB.compareTo(scoreA); // Descending score
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
