import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/explore/data/models/event_model.dart';
import 'package:planmapp/features/explore/services/places_service.dart';

class EventsService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final PlacesService _placesService = PlacesService();

  /// NEW: Fetches static local businesses from Google Places (with caching)
  Future<List<Event>> getPlaces({String city = 'Barranquilla', String? category}) async {
    try {
      // coordinates for Barranquilla (Default)
      double lat = 10.9685;
      double lng = -74.7813;

      final places = await _placesService.getNearbyPlaces(lat: lat, lng: lng, category: category);
      
      return places.map((p) => Event(
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
      )).toList();
    } catch (e) {
      print('❌ getPlaces Error: $e');
      return [];
    }
  }

  /// NEW: Fetches real-time events/promos from the scraper
  Future<List<Event>> getDailyEvents({String city = 'Barranquilla'}) async {
    try {
      final localResponse = await _supabase
          .from('local_events')
          .select()
          .eq('city', city)
          .eq('status', 'active') // Filter only active
          .order('date', ascending: true) // Show upcoming first
          .limit(20);

      if (localResponse is List) {
        return localResponse.map((e) => Event(
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
        )).toList();
      }
      return [];
    } catch (e) {
      print('❌ getDailyEvents Error: $e');
      return [];
    }
  }
}
