import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:http/http.dart' as http;

class LocationPickerScreen extends StatefulWidget {
  final LatLng initialCenter;

  const LocationPickerScreen({super.key, this.initialCenter = const LatLng(4.6097, -74.0817)}); // Default Bogota

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng _pickedLocation;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  
  String _currentAddress = "Cargando dirección...";
  bool _isSearching = false;
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialCenter;
    _fetchAddress(_pickedLocation);
  }

  Future<void> _fetchAddress(LatLng loc) async {
    try {
      final url = Uri.parse("https://nominatim.openstreetmap.org/reverse?format=json&lat=${loc.latitude}&lon=${loc.longitude}");
      final response = await http.get(url, headers: {'User-Agent': 'PlanmappApp/1.0'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['address'] != null) {
          final addressObj = data['address'];
          final street = addressObj['road'] ?? addressObj['pedestrian'] ?? '';
          final city = addressObj['city'] ?? addressObj['town'] ?? addressObj['village'] ?? '';
          
          String finalAddress = "$street".trim();
          if (finalAddress.isEmpty) {
              finalAddress = data['display_name'] ?? "Ubicación seleccionada";
          } else if (city.isNotEmpty) {
              finalAddress += ", $city";
          }
          if (mounted) setState(() => _currentAddress = finalAddress);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _currentAddress = "Ubicación guardada");
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse("https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&countrycodes=co");
      final response = await http.get(url, headers: {'User-Agent': 'PlanmappApp/1.0'});
      if (response.statusCode == 200) {
        setState(() {
          _searchResults = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print("Search error: $e");
    } finally {
      setState(() => _isSearching = false);
    }
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
                child: const Text("Confirmar", style: TextStyle(color: AppTheme.primaryBrand, fontWeight: FontWeight.bold, fontSize: 16)),
            )
        ],
      ),
      body: Stack(
          children: [
              FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                      initialCenter: widget.initialCenter,
                      initialZoom: 14.0,
                      onTap: (tapPosition, point) {
                          setState(() {
                              _pickedLocation = point;
                              _currentAddress = "Cargando...";
                              _searchResults = []; // Close results on tap
                          });
                          _fetchAddress(point);
                      },
                  ),
                  children: [
                      TileLayer(
                          urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', 
                          userAgentPackageName: 'com.planmapp.app',
                          subdomains: const ['a', 'b', 'c', 'd'],
                      ),
                      MarkerLayer(
                          markers: [
                              Marker(
                                  point: _pickedLocation,
                                  width: 60,
                                  height: 60,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: AppTheme.primaryBrand.withOpacity(0.3), blurRadius: 10, spreadRadius: 5)],
                                    ),
                                    child: const Icon(Icons.location_on, color: AppTheme.primaryBrand, size: 45)
                                  ),
                              )
                          ],
                      ),
                  ],
              ),
              
              // Top Search Bar
              Positioned(
                top: 16, left: 16, right: 16,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                      ),
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _performSearch,
                        decoration: InputDecoration(
                          hintText: "¿A qué lugar o ciudad vamos?",
                          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryBrand),
                          suffixIcon: _isSearching 
                              ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                              : IconButton(
                                  icon: const Icon(Icons.clear), 
                                  onPressed: () { 
                                     _searchController.clear(); 
                                     setState(() => _searchResults = []); 
                                  }
                                ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    if (_searchResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                        ),
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final place = _searchResults[index];
                            return ListTile(
                              leading: const Icon(Icons.place_outlined, color: Colors.grey),
                              title: Text(place['display_name'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                              onTap: () {
                                final lat = double.parse(place['lat']);
                                final lon = double.parse(place['lon']);
                                final loc = LatLng(lat, lon);
                                setState(() {
                                  _pickedLocation = loc;
                                  _searchResults = [];
                                  _currentAddress = place['display_name'];
                                  _searchController.text = place['name'] ?? '';
                                });
                                _mapController.move(loc, 16.0);
                              },
                            );
                          },
                        ),
                      )
                  ],
                ),
              ),

              // Bottom Info Card
              Positioned(
                  bottom: 24, left: 16, right: 16,
                  child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                              children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: AppTheme.primaryBrand.withOpacity(0.1), shape: BoxShape.circle),
                                    child: const Icon(Icons.my_location, color: AppTheme.primaryBrand)
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                            const Text("Ubicación Exacta", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 4),
                                            Text(
                                                _currentAddress,
                                                maxLines: 2, overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                            ),
                                        ],
                                    ),
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
