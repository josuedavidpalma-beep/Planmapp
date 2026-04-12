import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/explore/data/models/event_model.dart';

class EventsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Event>> getDailyEvents({String city = 'Bogotá'}) async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('city', city) // Filter by city
          .order('created_at', ascending: false) // Show fully newest scraped items first
          .limit(20);

      // ignore: unnecessary_type_check
      if (response is List) {
        return response.map((e) => Event.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('=== EventsService Error ===');
      print(e);
      return [];
    }
  }
}
