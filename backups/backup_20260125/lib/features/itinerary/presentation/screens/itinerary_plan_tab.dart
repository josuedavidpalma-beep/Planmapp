import 'dart:async'; // Add Timer import
import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/itinerary/domain/models/activity.dart';
import 'package:planmapp/features/itinerary/services/itinerary_service.dart';
import 'package:planmapp/features/itinerary/presentation/screens/add_activity_screen.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:planmapp/features/itinerary/services/location_service.dart';
import 'package:planmapp/features/itinerary/domain/models/geo_offer_model.dart';
import 'package:planmapp/features/itinerary/services/geo_offer_service.dart';
import 'package:planmapp/core/widgets/auth_guard.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:planmapp/core/presentation/widgets/dancing_empty_state.dart';
import 'package:planmapp/features/itinerary/services/magic_itinerary_service.dart';
import 'package:planmapp/features/itinerary/presentation/widgets/magic_itinerary_dialog.dart';

class ItineraryPlanTab extends StatefulWidget {
  final String planId;
  final String userRole; // 'admin', 'treasurer', 'member'
  final DateTime planDate;

  const ItineraryPlanTab({super.key, required this.planId, required this.userRole, required this.planDate});

  @override
  State<ItineraryPlanTab> createState() => _ItineraryPlanTabState();
}

class _ItineraryPlanTabState extends State<ItineraryPlanTab> {
  final ItineraryService _service = ItineraryService();
  final LocationService _locationService = LocationService();
  final GeoOfferService _offerService = GeoOfferService();
  final MagicItineraryService _magicService = MagicItineraryService(); // Add Magic Service

  bool _isLoading = true;
  bool _isGeneratingMagic = false; // Add generating state
  List<Activity> _activities = [];
  bool _showMap = false;
  
  // Radar State
  bool _isTracking = false;
  Stream<List<UserLocation>>? _radarStream;

  // Offers State
  bool _showOffers = false;
  List<GeoOffer> _offers = [];

  // Safety State
  bool _isSafeMode = false;
  Timer? _safetyTimer;
  bool _showSafetyAlert = false;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }
  
  @override
  void dispose() {
      _locationService.stopTracking();
      _safetyTimer?.cancel(); // Cancel safety timer
      super.dispose();
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getActivities(widget.planId);
      if (mounted) {
        setState(() {
          _activities = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("Error loading itinerary: $e");
    }
  }

  void _toggleRadar() async {
      setState(() => _isTracking = !_isTracking);
      
      if (_isTracking) {
          try {
              await _locationService.startTracking(widget.planId);
              setState(() {
                   _radarStream = _locationService.getPlanLocationsStream(widget.planId);
                   _showMap = true; // Auto switch to map
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("📡 Radar activado: Compartiendo ubicación")));
          } catch (e) {
              setState(() => _isTracking = false);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
          }
      } else {
          _locationService.stopTracking();
          setState(() => _radarStream = null);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Radar desactivado")));
      }
  }

  void _toggleOffers() async {
      setState(() => _showOffers = !_showOffers);
      if (_showOffers && _offers.isEmpty) {
          // Load offers around the first activity or default center
           LatLng center = const LatLng(4.6097, -74.0817);
           final activitiesWithLoc = _activities.where((a) => a.location != null).toList();
           if (activitiesWithLoc.isNotEmpty) {
               center = activitiesWithLoc.first.location!;
           }
           
           try {
               final newOffers = await _offerService.getOffers(center);
               if(mounted) {
                    setState(() => _offers = newOffers);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("🏷️ Se encontraron ${_offers.length} ofertas cercanas")));
               }
           } catch(e) {
               print("Error loading offers: $e");
           }
      }
  }

  void _toggleSafeMode() {
      setState(() {
          _isSafeMode = !_isSafeMode;
          _showSafetyAlert = false;
      });

      _safetyTimer?.cancel();

      if (_isSafeMode) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🛡️ Modo Seguro Activado: Monitoreando tu llegada...")));
          // Simulate a check-in request after 10 seconds (for demo)
          _safetyTimer = Timer(const Duration(seconds: 10), () {
              if (mounted && _isSafeMode) {
                  setState(() => _showSafetyAlert = true);
                  // Play sound or vibrate here in real app
              }
          });
      } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Modo Seguro Desactivado")));
      }
  }

  void _confirmSafeArrival() {
      setState(() {
          _isSafeMode = false;
          _showSafetyAlert = false;
      });
      _safetyTimer?.cancel();
      showDialog(
          context: context,
          builder: (_) => AlertDialog(
              title: const Text("¡Excelente! 🎉"),
              content: const Text("Nos alegra que hayas llegado bien. Se ha notificado a tu grupo."),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
              ],
          )
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
                 if (_showMap) ...[
                    FloatingActionButton.extended(
                        heroTag: "safetyBtn",
                        backgroundColor: _isSafeMode ? Colors.blueAccent : Colors.white,
                        foregroundColor: _isSafeMode ? Colors.white : Colors.blueAccent,
                        icon: Icon(_isSafeMode ? Icons.shield : Icons.shield_outlined),
                        label: Text(_isSafeMode ? "Monitoreando" : "Modo Seguro"),
                        onPressed: _toggleSafeMode,
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton.extended(
                        heroTag: "offersBtn",
                        backgroundColor: _showOffers ? Colors.purple : Colors.white,
                        foregroundColor: _showOffers ? Colors.white : Colors.purple,
                        icon: Icon(_showOffers ? Icons.local_offer : Icons.local_offer_outlined),
                        label: Text(_showOffers ? "Ofertas ON" : "Ofertas"),
                        onPressed: _toggleOffers,
                    ),
                    const SizedBox(height: 12),
                 ],
                if (_showMap) // Show Radar only on Map (optional, but cleaner)
                  FloatingActionButton.extended(
                      heroTag: "radarBtn",
                      backgroundColor: _isTracking ? Colors.green : Colors.grey[800],
                      foregroundColor: Colors.white,
                      icon: Icon(_isTracking ? Icons.radar : Icons.location_disabled),
                      label: Text(_isTracking ? "Radar ON" : "Activar Radar"),
                      onPressed: _toggleRadar,
                  ),
                const SizedBox(height: 16),
                if (_canEdit()) ...[
                    FloatingActionButton.extended(
                        heroTag: "magicBtn",
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        label: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                           decoration: BoxDecoration(
                               gradient: const LinearGradient(colors: [Colors.purpleAccent, Colors.blueAccent]),
                               borderRadius: BorderRadius.circular(24),
                               boxShadow: [BoxShadow(color: Colors.purpleAccent.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))]
                           ),
                           child: Row(
                               children: [
                                   Icon(_isGeneratingMagic ? Icons.hourglass_top : Icons.auto_awesome, color: Colors.white),
                                   const SizedBox(width: 8),
                                   Text(_isGeneratingMagic ? "Generando..." : "Sugerir Plan", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                               ],
                           ),
                        ),
                        onPressed: _isGeneratingMagic ? null : () async {
                             if (await AuthGuard.ensureAuthenticated(context)) {
                                 _openMagicAssistant();
                             }
                        },
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton(
                        heroTag: "addBtn",
                        backgroundColor: AppTheme.primaryBrand,
                        child: const Icon(Icons.add, color: Colors.white),
                        onPressed: () async {
                            if (await AuthGuard.ensureAuthenticated(context)) {
                                _openAddActivity();
                            }
                        },
                    ),
                ], // Close _canEdit list
            ], // Close children list
        ),
        body: Stack( // Change Column to Stack for Overlay
            children: [
                Column(
                    children: [
                        Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SegmentedButton<bool>(
                                segments: const [
                                    ButtonSegment(value: false, icon: Icon(Icons.list), label: Text("Lista")),
                                    ButtonSegment(value: true, icon: Icon(Icons.map), label: Text("Mapa")),
                                ],
                                selected: {_showMap},
                                onSelectionChanged: (Set<bool> newSelection) {
                                    setState(() => _showMap = newSelection.first);
                                },
                            ),
                        ),
                        Expanded(
                            child: _showMap ? _buildMapView() : (_activities.isEmpty ? _buildEmptyList() : _buildListView()),
                        ),
                    ],
                ),
                // Safety Overlay
                if (_isSafeMode)
                    Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                            color: _showSafetyAlert ? Colors.red : Colors.blueAccent,
                            padding: const EdgeInsets.all(16),
                            child: SafeArea(
                                child: Column(
                                    children: [
                                        Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                                Icon(_showSafetyAlert ? Icons.warning : Icons.security, color: Colors.white),
                                                const SizedBox(width: 8),
                                                Text(
                                                    _showSafetyAlert ? "¡CONFIRMA TU LLEGADA!" : "Modo Seguro Activo",
                                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
                                                ),
                                            ],
                                        ),
                                        if (_showSafetyAlert) ...[
                                            const SizedBox(height: 8),
                                            const Text("No hemos detectado movimiento. ¿Estás bien?", style: TextStyle(color: Colors.white)),
                                        ],
                                        const SizedBox(height: 12),
                                        ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                                            onPressed: _confirmSafeArrival,
                                            icon: const Icon(Icons.check_circle, color: Colors.green),
                                            label: const Text("LLEGUÉ BIEN"),
                                        )
                                    ],
                                ),
                            ),
                        ),
                    ),
            ],
        ),
    );
  }

  Widget _buildEmptyList() {
      return Center(
          child: DancingEmptyState(
             icon: Icons.map_outlined,
             title: "No hay actividades aún",
             message: "Agrega eventos o visualiza el mapa para empezar tu aventura.",
             buttonLabel: _canEdit() ? "Agregar Actividad" : null,
             onButtonPressed: _canEdit() ? () async {
                  if (await AuthGuard.ensureAuthenticated(context)) {
                      _openAddActivity();
                  }
             } : null,
          )
      );
  }

  Widget _buildListView() {
      return ListView.builder(
          itemCount: _activities.length,
          padding: const EdgeInsets.only(bottom: 80),
          itemBuilder: (context, index) {
              final activity = _activities[index];
              return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                      leading: _getCategoryIcon(activity.category),
                      title: Text(activity.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(DateFormat('MMM d, h:mm a').format(activity.startTime)),
                             if (activity.locationName != null) 
                                Row(children: [const Icon(Icons.location_on, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(activity.locationName!, style: const TextStyle(fontSize: 12))]),
                          ],
                      ),
                      trailing: _canEdit() ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _openAddActivity(activityToEdit: activity)),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteActivity(activity.id)),
                          ],
                      ) : null,
                  ),
              ).animate(delay: (100 * index).ms).slideX(begin: 0.1, duration: 400.ms).fade(duration: 400.ms);
          },
      );
  }

  Widget _buildMapView() {
      LatLng center = const LatLng(4.6097, -74.0817); 
      final activitiesWithLoc = _activities.where((a) => a.location != null).toList();
      if (activitiesWithLoc.isNotEmpty) {
           center = activitiesWithLoc.first.location!; 
      }

      return StreamBuilder<List<UserLocation>>(
          stream: _radarStream,
          builder: (context, snapshot) {
              final userLocations = snapshot.data ?? [];
              
              return FlutterMap(
                  options: MapOptions(
                      initialCenter: center,
                      initialZoom: 13.0,
                  ),
                  children: [
                      TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.planmapp.app',
                      ),
                      MarkerLayer(
                          markers: activitiesWithLoc.map((activity) {
                              return Marker(
                                  point: activity.location!,
                                  width: 40,
                                  height: 40,
                                  child: GestureDetector(
                                      onTap: () { /* Show modal */ },
                                      child: _getCategoryIcon(activity.category), 
                                  ),
                              );
                          }).toList(),
                      ),
                      if (_showOffers)
                         MarkerLayer(
                             markers: _offers.map((offer) {
                                  return Marker(
                                      point: LatLng(offer.lat, offer.lng),
                                      width: 40,
                                      height: 40,
                                      child: GestureDetector(
                                          onTap: () => _showOfferDetails(offer),
                                          child: Container(
                                              decoration: BoxDecoration(
                                                  color: Colors.purple,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.white, width: 2),
                                              ),
                                              child: const Icon(Icons.local_offer, color: Colors.white, size: 20),
                                          ),
                                      ),
                                  );
                             }).toList(),
                         ),
                      if (_isTracking && userLocations.isNotEmpty)
                          MarkerLayer(
                              markers: userLocations.map((uLoc) {
                                  return Marker(
                                      point: LatLng(uLoc.lat, uLoc.lng),
                                      width: 40,
                                      height: 40,
                                      child: Container(
                                          decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
                                              color: Colors.green, 
                                          ),
                                          child: const Icon(Icons.person, color: Colors.white, size: 24),
                                      ),
                                  );
                              }).toList(),
                          ),
                  ],
              );
          }
      );
  }

  void _showOfferDetails(GeoOffer offer) {
      showModalBottomSheet(
          context: context, 
          builder: (context) {
              return Container(
                  padding: const EdgeInsets.all(24),
                  width: double.infinity,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          const Icon(Icons.stars, color: Colors.purple, size: 48),
                          const SizedBox(height: 16),
                          Text(offer.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Text(offer.description, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                          const SizedBox(height: 24),
                          Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.purple.withOpacity(0.3))
                              ),
                              child: Text(
                                  "CÓDIGO: ${offer.code}",
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple, letterSpacing: 1.5)
                              ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Cerrar"),
                              ),
                          )
                      ],
                  ),
              );
          }
      );
  }

  bool _canEdit() {
      return widget.userRole == 'admin' || widget.userRole == 'treasurer';
  }

  void _openAddActivity({Activity? activityToEdit}) async {
      final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddActivityScreen(planId: widget.planId, activityToEdit: activityToEdit)),
      );
      if (result == true) {
          _loadActivities();
      }
  }

  Future<void> _deleteActivity(String id) async {
       await _service.deleteActivity(id);
       _loadActivities();
  }

  void _openMagicAssistant() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const MagicItineraryDialog(),
    );

    if (result != null) {
       setState(() => _isGeneratingMagic = true);
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✨ La IA está diseñando tu viaje...")));
       
       try {
          final activities = await _magicService.generateItinerary(
            location: result['location'],
            days: result['days'],
            startDate: widget.planDate,
            interests: result['interests'],
          );

          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✨ ¡Listo! Se generaron ${activities.length} actividades")));
             // Batch save
             await _service.addActivities(activities, widget.planId);
             _loadActivities();
          }

       } catch (e) {
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
          }
       } finally {
          if (mounted) setState(() => _isGeneratingMagic = false);
       }
    }
  }

  Widget _getCategoryIcon(ActivityCategory cat) {
      IconData icon;
      Color color;
      switch (cat) {
          case ActivityCategory.food: icon = Icons.restaurant; color = Colors.orange; break;
          case ActivityCategory.transport: icon = Icons.directions_bus; color = Colors.blue; break;
          case ActivityCategory.lodging: icon = Icons.hotel; color = Colors.indigo; break;
          case ActivityCategory.activity: icon = Icons.local_activity; color = Colors.purple; break;
          default: icon = Icons.event; color = Colors.grey;
      }
      return CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color));
  }
}
