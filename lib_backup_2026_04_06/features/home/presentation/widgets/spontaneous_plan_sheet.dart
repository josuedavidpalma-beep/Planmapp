import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:planmapp/features/itinerary/services/location_service.dart';
import 'package:planmapp/features/home/presentation/widgets/spontaneous_results_view.dart';

class SpontaneousPlanSheet extends StatefulWidget {
  const SpontaneousPlanSheet({super.key});

  @override
  State<SpontaneousPlanSheet> createState() => _SpontaneousPlanSheetState();
}

class _SpontaneousPlanSheetState extends State<SpontaneousPlanSheet> {
  bool _loadingLocation = true;
  String? _error;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLocate();
  }

  Future<void> _checkPermissionsAndLocate() async {
      try {
          // Quick location check
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
              permission = await Geolocator.requestPermission();
              if (permission == LocationPermission.denied) {
                  throw Exception("Se requiere ubicación para planes espontáneos.");
              }
          }
          if (permission == LocationPermission.deniedForever) {
               throw Exception("Ubicación denegada permanentemente.");
          }

          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium); // Medium is faster
          if (mounted) {
              setState(() {
                  _currentPosition = pos;
                  _loadingLocation = false;
              });
          }
      } catch (e) {
          if (mounted) setState(() => _error = e.toString());
      }
  }

  void _onMoodSelected(String category) {
      if (_currentPosition == null) return;
      
      // Close this sheet and open results directly (or navigate)
      // For cleaner UX, let's replace content or push modal.
      // Replacing content in same sheet is smoother.
      
      Navigator.pop(context); // Close vibe check
      
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (c) => SpontaneousResultsView(category: category, position: _currentPosition!)
      );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        height: 500,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)]
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 24),
                
                if (_loadingLocation) ...[
                    const Spacer(),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 16),
                    const Text("Sintonizando satélites...", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    const Spacer(),
                ] else if (_error != null) ...[
                    const Spacer(),
                    const Icon(Icons.location_disabled, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text("Necesitamos tu ubicación\npara encontrar planes cerca.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700], fontSize: 16)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _checkPermissionsAndLocate, child: const Text("Intentar de nuevo")),
                    const Spacer(),
                ] else ...[
                    const Text(
                        "¿Cuál es el vibe de hoy?", 
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                        textAlign: TextAlign.center
                    ).animate().fadeIn().moveY(begin: 10),
                    const SizedBox(height: 8),
                    Text(
                        "Te mostraremos opciones top cerca de ti.", 
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center
                    ).animate().fadeIn().moveY(begin: 10, delay: 100.ms),
                    const SizedBox(height: 32),
                    
                    Expanded(
                        child: GridView.count(
                            crossAxisCount: 2, // 2 cols
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.4,
                            children: [
                                _buildMoodCard("Comer", "🍔", Colors.orange),
                                _buildMoodCard("Beber", "🍻", Colors.purple),
                                _buildMoodCard("Café", "☕", Colors.brown),
                                _buildMoodCard("Sorpréndeme", "🎲", Colors.blue),
                            ],
                        ).animate().fadeIn(delay: 200.ms),
                    )
                ]
            ],
        ),
    );
  }

  Widget _buildMoodCard(String label, String emoji, Color color) {
      return InkWell(
          onTap: () => _onMoodSelected(label),
          borderRadius: BorderRadius.circular(20),
          child: Container(
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.3), width: 1.5)
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      Text(emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 8),
                      Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color.withOpacity(0.8)))
                  ],
              ),
          ),
      );
  }
}
