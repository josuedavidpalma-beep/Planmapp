import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/explore/data/models/event_model.dart';

class EventsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Event>> getDailyEvents() async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .order('date', ascending: true) // Sort by date? or created_at? Let's use created_at for "freshness" or date for event timing. 
          // Let's assume we want upcoming events, so date. But text date is tricky.
          // Let's use created_at desc to show latest added for now, or just limit to 20.
          // In a real app we'd parse date.
          .limit(20);

      // ignore: unnecessary_type_check
      if (response is List) {
        return response.map((e) => Event.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      // Handle error gracefully or rethrow
      // debugPrint('Error fetching events: $e'); // using debugPrint if available or just silence for now
      return [];
    }
  }
}
