import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<Position>? _positionStream;
  
  // Stream of other users' locations for a specific plan
  Stream<List<UserLocation>> getPlanLocationsStream(String planId) {
    return _supabase
        .from('user_locations')
        .stream(primaryKey: ['user_id', 'plan_id'])
        .eq('plan_id', planId)
        .map((data) => data.map((json) => UserLocation.fromJson(json)).toList());
  }

  // Start tracking my location and sending to Supabase
  Future<void> startTracking(String planId) async {
    // 1. Check Permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permiso de ubicación denegado');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicación denegado permanentemente');
    }

    // 2. Start Stream
    final userId = _supabase.auth.currentUser!.id;
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20, // Update every 20 meters
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) async {
        try {
            await _supabase.from('user_locations').upsert({
                'user_id': userId,
                'plan_id': planId,
                'lat': position.latitude,
                'lng': position.longitude,
                'updated_at': DateTime.now().toIso8601String(),
            });
        } catch (e) {
            print("Error updating location: $e");
        }
      },
      onError: (e) => print("Location Stream Error: $e"),
    );
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }
}

class UserLocation {
    final String userId;
    final double lat;
    final double lng;
    final DateTime updatedAt;

    UserLocation({required this.userId, required this.lat, required this.lng, required this.updatedAt});

    factory UserLocation.fromJson(Map<String, dynamic> json) {
        return UserLocation(
            userId: json['user_id'],
            lat: json['lat'],
            lng: json['lng'],
            updatedAt: DateTime.parse(json['updated_at']),
        );
    }
}
