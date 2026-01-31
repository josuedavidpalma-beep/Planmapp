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
      id: json['id'],
      planId: json['plan_id'],
      title: json['title'],
      description: json['description'],
      locationName: json['location_name'],
      location: (json['location_lat'] != null && json['location_lng'] != null)
          ? LatLng(json['location_lat'], json['location_lng'])
          : null,
      startTime: DateTime.parse(json['start_time']).toLocal(),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']).toLocal() : null,
      category: _parseCategory(json['category']),
      createdBy: json['created_by'],
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
