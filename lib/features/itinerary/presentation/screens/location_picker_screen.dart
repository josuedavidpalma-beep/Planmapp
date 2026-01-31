import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:planmapp/core/theme/app_theme.dart';
// import 'package:google_maps_webservice/places.dart';
// import 'package:flutter_google_places/flutter_google_places.dart';

// PLACEHOLDER: User must replace this KEY!
const kGoogleApiKey = "YOUR_GOOGLE_MAPS_API_KEY";

class LocationPickerScreen extends StatefulWidget {
  final LatLng initialCenter;

  const LocationPickerScreen({super.key, this.initialCenter = const LatLng(4.6097, -74.0817)}); // Default Bogota

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng _pickedLocation;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialCenter;
  }

  Future<void> _handleSearch() async {
      // TEMPORARY FIX: Disabled due to Windows Build bugs with google_headers
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Búsqueda temporalmente desactivada por mantenimiento en Windows."))
      );
      /*
      try {
        Prediction? p = await PlacesAutocomplete.show(
            context: context, 
            apiKey: kGoogleApiKey,
            mode: Mode.overlay, // or Mode.fullscreen
            language: "es",
            components: [Component(Component.country, "co")]
        );

        if (p != null && p.placeId != null) {
            // Get details for lat/lng
            GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: kGoogleApiKey);
            PlacesDetailsResponse detail = await _places.getDetailsByPlaceId(p.placeId!);
            
            if (detail.result.geometry != null) {
                final lat = detail.result.geometry!.location.lat;
                final lng = detail.result.geometry!.location.lng;
                
                setState(() {
                    _pickedLocation = LatLng(lat, lng);
                    _mapController.move(_pickedLocation, 15.0);
                });
            }
        }
      } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error en búsqueda: $e")));
      }
      */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Seleccionar Ubicación"),
        actions: [
            IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: _handleSearch,
            ),
            TextButton(
                onPressed: () {
                    Navigator.pop(context, _pickedLocation);
                },
                child: const Text("Confirmar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: Stack(
          children: [
              FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                      initialCenter: widget.initialCenter,
                      initialZoom: 13.0,
                      onTap: (tapPosition, point) {
                          setState(() {
                              _pickedLocation = point;
                          });
                      },
                  ),
                  children: [
                      TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.planmapp.app',
                      ),
                      MarkerLayer(
                          markers: [
                              Marker(
                                  point: _pickedLocation,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                              )
                          ],
                      ),
                  ],
              ),
              Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                  const Text("Toca la lupa 🔍 para buscar o el mapa para mover.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 8),
                                  Text(
                                      "Lat: ${_pickedLocation.latitude.toStringAsFixed(4)}\nLng: ${_pickedLocation.longitude.toStringAsFixed(4)}",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                              ],
                          ),
                      ),
                  ),
              )
          ],
      ),
    );
  }
}
