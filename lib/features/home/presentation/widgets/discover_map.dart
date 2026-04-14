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
           // Dark mode for a premium tech feel
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
        ),
        MarkerLayer(
          markers: validEvents.map((event) {
            final isSuperMatch = (event.ratingGoogle ?? 0.0) >= 4.5;
            final borderColor = isSuperMatch ? AppTheme.secondaryBrand : AppTheme.primaryBrand;

            return Marker(
              point: LatLng(event.latitude!, event.longitude!),
              width: 140, // Wide enough for pill shape
              height: 48,
              child: GestureDetector(
                onTap: () => onEventTap(event),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor.withOpacity(0.8), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: borderColor.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5)
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        CircleAvatar(
                            radius: 16,
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            backgroundImage: CachedNetworkImageProvider(event.displayImageUrl),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(
                                event.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, height: 1.1),
                            ),
                        ),
                        const SizedBox(width: 4),
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
