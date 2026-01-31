import 'package:latlong2/latlong.dart';

enum ActivityCategory { transport, food, lodging, activity, other }

class Activity {
  final String id;
  final String planId;
  final String title;
  final String? description;
  final String? locationName;
  final LatLng? location;
  final DateTime startTime;
  final DateTime? endTime;
  final ActivityCategory category;
  final String? createdBy;

  Activity({
    required this.id,
    required this.planId,
    required this.title,
    this.description,
    this.locationName,
    this.location,
    required this.startTime,
    this.endTime,
    this.category = ActivityCategory.other,
    this.createdBy,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id']?.toString() ?? 'unknown_activity',
      planId: json['plan_id']?.toString() ?? 'unknown_plan',
      title: json['title']?.toString() ?? 'Actividad sin título',
      description: json['description']?.toString(),
      locationName: json['location_name']?.toString(),
      location: (json['location_lat'] != null && json['location_lng'] != null)
          ? LatLng((json['location_lat'] as num).toDouble(), (json['location_lng'] as num).toDouble())
          : null,
      startTime: json['start_time'] != null 
          ? (DateTime.tryParse(json['start_time'].toString())?.toLocal() ?? DateTime.now()) 
          : DateTime.now(),
      endTime: json['end_time'] != null 
          ? DateTime.tryParse(json['end_time'].toString())?.toLocal() 
          : null,
      category: _parseCategory(json['category']?.toString()),
      createdBy: json['created_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plan_id': planId,
      'title': title,
      'description': description,
      'location_name': locationName,
      'location_lat': location?.latitude,
      'location_lng': location?.longitude,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime?.toUtc().toIso8601String(),
      'category': category.name,
    };
  }

  static ActivityCategory _parseCategory(String? value) {
    return ActivityCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ActivityCategory.other,
    );
  }
}
