import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/itinerary/domain/models/activity.dart';

class MagicItineraryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Activity>> generateItinerary({
    required String location,
    required int days,
    String? interests,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'generate-itinerary',
        body: {
          'location': location,
          'days': days,
          'interests': interests,
        },
      );

      final List<dynamic> data = response.data;
      
      // Convert JSON response to Activity objects
      // Note: These activities won't have an ID or planId yet
      return data.map((json) {
        // Map category string to Enum
        ActivityCategory category;
        switch (json['category']?.toString().toLowerCase()) {
          case 'food':
            category = ActivityCategory.food;
            break;
          case 'lodging':
            category = ActivityCategory.lodging;
            break;
          case 'transport':
            category = ActivityCategory.transport;
            break;
          default:
            category = ActivityCategory.activity;
        }

        // Parse Time (HH:MM) to create a DateTime relative to Day 1
        // For a generated itinerary, we'll just store the time string in temporary metadata or 
        // construct a dummy date. The UI will handle actual date assignment.
        // For now, let's use the current date + (day - 1) days + time
        
        final dayOffset = (json['day'] as num? ?? 1).toInt() - 1;
        final timeStr = json['time'] as String? ?? "09:00";
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        final now = DateTime.now();
        final activityDate = DateTime(now.year, now.month, now.day, hour, minute).add(Duration(days: dayOffset));

        return Activity(
          id: '', // Temporary
          planId: '', // Temporary
          title: json['title'] ?? 'Actividad',
          startTime: activityDate,
          category: category,
          locationName: json['title'], // Use title as location name initially
          description: json['description'], // Map description
          createdBy: _supabase.auth.currentUser!.id,
        );
      }).toList();

    } catch (e) {
      throw Exception('Error generating itinerary: $e');
    }
  }
}
