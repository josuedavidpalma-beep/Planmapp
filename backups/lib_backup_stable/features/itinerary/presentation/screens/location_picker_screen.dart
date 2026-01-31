import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:planmapp/core/theme/app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Seleccionar Ubicación"),
        actions: [
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
                          child: Text(
                              "Toca en el mapa para mover el marcador.\nLat: ${_pickedLocation.latitude.toStringAsFixed(4)}, Lng: ${_pickedLocation.longitude.toStringAsFixed(4)}",
                              textAlign: TextAlign.center,
                          ),
                      ),
                  ),
              )
          ],
      ),
    );
  }
}
