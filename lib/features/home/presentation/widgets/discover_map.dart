import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/explore/data/models/event_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DiscoverMap extends StatelessWidget {
  final List<Event> events;
  final String city;
  final Function(Event) onEventTap;

  const DiscoverMap({
    super.key,
    required this.events,
    required this.city,
    required this.onEventTap,
  });

  // Default coordinate if no events have valid coordinates
  LatLng _getCityCenter(String cityName) {
    switch (cityName) {
      case "Medellín": return const LatLng(6.244, -75.581);
      case "Cali": return const LatLng(3.451, -76.532);
      case "Barranquilla": return const LatLng(10.963, -74.796);
      case "Cartagena": return const LatLng(10.391, -75.479);
      case "Bogotá": 
      default:
        return const LatLng(4.711, -74.072);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter events that actually have coordinates
    final validEvents = events.where((e) => e.latitude != null && e.longitude != null).toList();

    // Determine initial center
    LatLng center = _getCityCenter(city);
    if (validEvents.isNotEmpty) {
      // Approximate center based on the first event or average
      double avgLat = validEvents.map((e) => e.latitude!).reduce((a, b) => a + b) / validEvents.length;
      double avgLng = validEvents.map((e) => e.longitude!).reduce((a, b) => a + b) / validEvents.length;
      center = LatLng(avgLat, avgLng);
    }

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13.0,
        maxZoom: 18.0,
      ),
      children: [
        TileLayer(
           // Usa un layer dark style o uno de cartoDB para sentirse muy pro/tech
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
          subdomains: const ['a', 'b', 'c', 'd'],
        ),
        MarkerLayer(
          markers: validEvents.map((event) {
            // Un evento dorados si tiene super rating > 4.5
            final isSuperMatch = (event.ratingGoogle ?? 0.0) >= 4.5;

            return Marker(
              point: LatLng(event.latitude!, event.longitude!),
              width: 50,
              height: 50,
              child: GestureDetector(
                onTap: () => onEventTap(event),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: Stack(
                      alignment: Alignment.center,
                      children: [
                          Icon(
                              Icons.location_on,
                              color: isSuperMatch ? AppTheme.secondaryBrand : AppTheme.primaryBrand,
                              size: 45,
                              shadows: [
                                  Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5)
                                  )
                              ],
                          ),
                          if (event.imageUrl != null)
                             Positioned(
                                 top: 5,
                                 child: CircleAvatar(
                                     radius: 12,
                                     backgroundImage: CachedNetworkImageProvider(event.imageUrl!),
                                 )
                             )
                      ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
