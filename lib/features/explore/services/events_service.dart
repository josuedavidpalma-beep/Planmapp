import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/explore/data/models/event_model.dart';

class EventsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Event>> getDailyEvents({String city = 'Bogotá'}) async {
    try {
      // 1. Fetch from legacy events
      final eventsResponse = await _supabase
          .from('events')
          .select()
          .eq('city', city)
          .order('created_at', ascending: false)
          .limit(15);

      // 2. Fetch from local_discovery_events
      final localResponse = await _supabase
          .from('local_events')
          .select()
          .eq('city', city)
          .order('created_at', ascending: false)
          .limit(10);

      List<Event> allEvents = [];
      
      if (eventsResponse is List) {
        allEvents.addAll(eventsResponse.map((e) => Event.fromJson(e)).toList());
      }
      
      if (localResponse is List) {
        // Map local_events to Event model if fields match, or adapt
        allEvents.addAll(localResponse.map((e) => Event(
          id: e['id'],
          title: e['event_name'],
          description: e['description'],
          date: e['date'],
          endDate: e['end_date'],
          location: e['venue_name'],
          address: e['address'],
          imageUrl: e['image_url'],
          category: e['vibe_tag']?.split('/')[0] ?? 'General',
          ratingGoogle: null, // Scraped items don't have this yet
          sourceUrl: e['reservation_link'] ?? e['primary_source'],
          contactInfo: e['contact_phone'],
          latitude: e['latitude'],
          longitude: e['longitude'],
          city: e['city']
        )).toList());
      }

      // Sort combined by created_at (if we had it in Event model? Event model might not have created_at).
      // Let's just return merged.
      return allEvents;
    } catch (e) {
      print('=== EventsService Error ===');
      print(e);
      return [];
    }
  }
}
