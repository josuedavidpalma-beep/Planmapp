import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planmapp/features/explore/data/models/event_model.dart';
import 'package:planmapp/features/explore/services/places_service.dart';

class ExploreFeedData {
  final List<Event> viralEvents;
  final List<Event> recommendedPlaces;

  ExploreFeedData({required this.viralEvents, required this.recommendedPlaces});
}

// CACHE PROVIDER: Evita recargas molestas al cambiar de tabs
final feedEventsProvider = FutureProvider.family<ExploreFeedData, String>((ref, cacheKey) async {
  final params = jsonDecode(cacheKey);
  
  final city = params['city'] as String? ?? 'Bogotá';
  final category = params['category'] as String?;
  final userInterests = (params['userInterests'] as List<dynamic>?)?.map((e) => e.toString()).toList();
  final budgetLevel = params['budgetLevel'] as String?;

  final service = EventsService();
  
  if (category == 'preventas') {
      final preventas = await service.getPlaces(city: city, category: category);
      return ExploreFeedData(viralEvents: preventas, recommendedPlaces: []);
  }

  final places = await service.getPlaces(
    city: city, category: category, userInterests: userInterests, budgetLevel: budgetLevel
  );

  final dailyPromos = await service.getDailyEvents(
    city: city, userInterests: userInterests, budgetLevel: budgetLevel, userAge: 20 // Dummy age to bypass strict filter if not provided
  );

  // Nest Promos directly onto their respective Places by ID or name
  final List<Event> nestedPlaces = [];
  final List<Event> standalonePromos = List.from(dailyPromos);

  for (var place in places) {
      final matchingPromos = standalonePromos.where((promo) => 
          (promo.googlePlaceId != null && promo.googlePlaceId == place.googlePlaceId) || 
          (promo.location != null && promo.location!.toLowerCase() == place.title.toLowerCase())
      ).toList();

      if (matchingPromos.isNotEmpty) {
          final List<String> promoTexts = matchingPromos.map((p) => p.promoHighlights ?? p.title).toList();
          final combinedPromo = promoTexts.join(' • '); // e.g. "2x1 Cocktails • Cover Free"
          final phoneInfos = matchingPromos.where((p) => p.contactPhone != null).toList();
          final linkInfos = matchingPromos.where((p) => p.reservationLink != null).toList();
          nestedPlaces.add(place.copyWith(
              promoHighlights: combinedPromo,
              contactPhone: phoneInfos.isNotEmpty ? phoneInfos.first.contactPhone : null,
              reservationLink: linkInfos.isNotEmpty ? linkInfos.first.reservationLink : null,
          ));
          // Quitar promos emparejadas para que no queden duplicadas
          for (var mp in matchingPromos) {
              standalonePromos.remove(mp);
          }
      } else {
          nestedPlaces.add(place); // Keep intact
      }
  }

  // Preserve billboard positioning if injected by getPlaces
  final billboardIndex = nestedPlaces.indexWhere((e) => e.id == 'cartelera_nacional');
  if (billboardIndex != -1) {
      final billboard = nestedPlaces.removeAt(billboardIndex);
      standalonePromos.insert(0, billboard);
  }

  return ExploreFeedData(
      viralEvents: standalonePromos,
      recommendedPlaces: nestedPlaces,
  );
});

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
                  contactPhone: e['contact_phone'],
                  reservationLink: e['reservation_link']
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
      
      List<Event> events = places
        .where((p) {
            final rating = p['rating'];
            if (rating == null) return false;
            final numRating = rating is num ? rating : num.tryParse(rating.toString()) ?? 0.0;
            return numRating >= 4.0;
        })
        .map((p) => Event(
        id: p['place_id'],
        title: p['name'],
        address: p['address'],
        location: p['name'],
        imageUrl: _placesService.getPhotoUrl(p['photo_reference']) ?? _getDeterministicImage(p['place_id'], category ?? p['category']),
        ratingGoogle: p['rating'],
        latitude: p['latitude'],
        longitude: p['longitude'],
        category: p['category'],
        city: city,
        googlePlaceId: p['place_id'],
        priceLevel: p['price_level'],
      )).toList();

      // ====== B2B INJECTION (Planmapp Business) ======
      try {
          // Fetch all active B2B clients that have a Google Place ID mapped
          final b2bRes = await _supabase.from('restaurants').select().not('google_place_id', 'is', null);
          final List<dynamic> b2bClients = b2bRes as List<dynamic>;

          if (b2bClients.isNotEmpty) {
              final List<Event> featuredEvents = [];
              
              for (var i = 0; i < events.length; i++) {
                  final e = events[i];
                  // Find if this Google Place is one of our B2B clients
                  final b2bMatch = b2bClients.cast<Map<String,dynamic>>().firstWhere(
                      (r) => r['google_place_id'] == e.googlePlaceId,
                      orElse: () => <String,dynamic>{}
                  );
                  
                  if (b2bMatch.isNotEmpty) {
                      final tier = b2bMatch['tier'] ?? 'basic';
                      final isVerified = b2bMatch['is_verified'] == true;
                      final isFeatured = b2bMatch['is_featured'] == true;
                      
                      // Upgrade the event card with B2B perks
                      final upgradedEvent = e.copyWith(
                          isVerified: isVerified,
                          b2bTier: tier,
                          contactPhone: (tier == 'premium' || tier == 'gold') ? (b2bMatch['whatsapp_link'] ?? e.contactPhone) : e.contactPhone,
                          promoHighlights: (tier == 'premium' || tier == 'gold') ? (b2bMatch['promo_text'] ?? e.promoHighlights) : e.promoHighlights,
                      );
                      
                      events[i] = upgradedEvent;
                      
                      if (isFeatured && tier == 'gold') {
                          featuredEvents.add(upgradedEvent);
                      }
                  }
              }
              
              // Move featured Gold events to the top of the list
              for (var fEvent in featuredEvents) {
                  events.removeWhere((e) => e.id == fEvent.id);
                  events.insert(0, fEvent);
              }
          }
      } catch (e) {
          print("Error injecting B2B data: $e");
      }
      // ===============================================

      // Shuffle if category is "Todo" (null) to interleave different types of places
      if (category == null) {
          // Keep featured events at top, shuffle the rest
          final featured = events.where((e) => e.b2bTier == 'gold').toList();
          final rest = events.where((e) => e.b2bTier != 'gold').toList();
          rest.shuffle();
          events = [...featured, ...rest];
      }

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
              promoHighlights: "🎟 COMPRAR BOLETAS ONLINE",
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
          final List<Event> highlyMatched = [];
          final List<Event> moderatelyMatched = [];
          final List<Event> otherEvents = [];
          
          for (var e in events) {
             if (e.id == 'cartelera_nacional') continue;
             
             final title = e.title.toLowerCase();
             final desc = (e.description ?? '').toLowerCase();
             
             bool isHighMatch = userInterests.any((vibe) {
                 final v = vibe.toLowerCase();
                 return title.contains(v) || desc.contains(v);
             });
             
             if (isHighMatch) {
                 highlyMatched.add(e);
             } else if (userInterests.any((v) => e.category?.toLowerCase().contains(v.toLowerCase()) ?? false)) {
                 moderatelyMatched.add(e);
             } else {
                 otherEvents.add(e);
             }
          }
          
          highlyMatched.shuffle();
          moderatelyMatched.shuffle();
          
          final List<Event> interleaved = [...highlyMatched, ...moderatelyMatched, ...otherEvents];
          
          final billboardIndex = events.indexWhere((e) => e.id == 'cartelera_nacional');
          if (billboardIndex != -1) {
              interleaved.insert(0, events[billboardIndex]);
          }
          
          events = interleaved;
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
      final places = results.map((p) => Event(
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

      final dailyPromos = await getDailyEvents(city: city);

      final List<Event> nestedPlaces = [];
      for (var place in places) {
          final matchingPromos = dailyPromos.where((promo) => 
              (promo.googlePlaceId != null && promo.googlePlaceId == place.googlePlaceId) || 
              (promo.location != null && promo.location!.toLowerCase() == place.title.toLowerCase())
          ).toList();

          if (matchingPromos.isNotEmpty) {
              final List<String> promoTexts = matchingPromos.map((p) => p.promoHighlights ?? p.title).toList();
              final combinedPromo = promoTexts.join(' • '); 
              nestedPlaces.add(place.copyWith(promoHighlights: combinedPromo));
          } else {
              nestedPlaces.add(place);
          }
      }
      return nestedPlaces;
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
      final today = DateTime.now().toIso8601String().split('T')[0];

      var query = _supabase
          .from('local_events')
          .select()
          .eq('city', city)
          .eq('status', 'active')
          .or('date.gte.$today,date.is.null'); // Filtrar eventos pasados

      final localResponse = await query.order('date', ascending: true);

      if (localResponse is List) {
        List<Event> events = localResponse.map<Event>((e) => Event(
          id: e['id'].toString(),
          title: e['event_name'],
          description: e['description'],
          date: e['date'],
          endDate: e['end_date'],
          location: e['venue_name'],
          address: e['address'],
          imageUrl: (e['image_url'] != null && e['image_url'].toString().isNotEmpty) ? e['image_url'] : _getDeterministicImage(e['id'].toString(), e['vibe_tag']),
          category: e['vibe_tag']?.split('/')[0] ?? 'General',
          sourceUrl: e['reservation_link'] ?? e['primary_source'],
          contactPhone: e['contact_phone'],
          reservationLink: e['reservation_link'],
          latitude: e['latitude'],
          longitude: e['longitude'],
          city: e['city'],
          googlePlaceId: e['place_id'],
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
                if (interest.contains('comida') || interest.contains('gastro')) { validTags.addAll(['gastronomía', 'gastronomia', 'restaurant']); }
                if (interest.contains('rumba') || interest.contains('party')) { validTags.addAll(['vida nocturna', 'bar', 'club', 'nightlife']); }
                if (interest.contains('aventura') || interest.contains('outdoor')) { validTags.addAll(['aventura', 'outdoor', 'park']); }
                if (interest.contains('cultura') || interest.contains('cine')) { validTags.addAll(['cultura & ocio', 'cultura', 'cine', 'museum', 'art']); }
                if (interest.contains('chill') || interest.contains('café')) { validTags.addAll(['gastronomía', 'cafe', 'coffee']); }
                if (interest.contains('belleza') || interest.contains('deporte')) { validTags.addAll(['bienestar & deporte', 'spa', 'gym']); }
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

  /// Helper: Deterministically pick a high quality image based on the ID and category
  String _getDeterministicImage(String id, String? category) {
      final int hash = id.hashCode.abs();
      final cat = (category ?? '').toLowerCase();
      
      List<String> images = [
          "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=800&q=80",
          "https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=800&q=80",
          "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=800&q=80",
          "https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3?auto=format&fit=crop&w=800&q=80",
          "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=800&q=80",
          "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80",
          "https://images.unsplash.com/photo-1525268771113-32d9e9021a97?auto=format&fit=crop&w=800&q=80",
          "https://images.unsplash.com/photo-1563298723-dcfebaa392e3?auto=format&fit=crop&w=800&q=80",
      ];

      if (cat.contains('rumba') || cat.contains('nocturna') || cat.contains('bar') || cat.contains('fiesta')) {
          images = [
              "https://images.unsplash.com/photo-1545128485-c400e7702796?auto=format&fit=crop&w=800&q=80",
              "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=800&q=80",
              "https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=800&q=80",
              "https://images.unsplash.com/photo-1470229722913-7c090be5f524?auto=format&fit=crop&w=800&q=80",
              "https://images.unsplash.com/photo-1572116469696-31de0f17cc34?auto=format&fit=crop&w=800&q=80"
          ];
      } else if (cat.contains('comida') || cat.contains('gastronom') || cat.contains('restaurante')) {
          images = [
              "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=800&q=80",
              "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=800&q=80",
              "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80",
              "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=800&q=80",
              "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&q=80"
          ];
      } else if (cat.contains('cine') || cat.contains('película')) {
          images = [
              "https://images.unsplash.com/photo-1536440136628-849c177e76a1?auto=format&fit=crop&w=800&q=80",
              "https://images.unsplash.com/photo-1485846234645-a62644f84728?auto=format&fit=crop&w=800&q=80",
              "https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?auto=format&fit=crop&w=800&q=80"
          ];
      }

      final rawUrl = images[hash % images.length];
      return 'https://wsrv.nl/?url=${Uri.encodeComponent(rawUrl)}';
  }
}
