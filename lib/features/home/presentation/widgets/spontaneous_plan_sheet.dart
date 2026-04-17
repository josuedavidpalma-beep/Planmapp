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
          builder: (c) => SpontaneousResultsView(category: category, position: _currentPosition!, city: "")
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
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black87),
                        textAlign: TextAlign.center
                    ).animate().fadeIn().moveY(begin: 10),
                    const SizedBox(height: 8),
                    Text(
                        "Encuentra los tesoros más frescos de hoy.", 
                        style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center
                    ).animate().fadeIn().moveY(begin: 10, delay: 100.ms),
                    const SizedBox(height: 24),
                    
                    Expanded(
                        child: GridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.1,
                            children: [
                                _buildVisualMoodCard("Rumba", "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=400&q=80"),
                                _buildVisualMoodCard("Chill", "https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=400&q=80"),
                                _buildVisualMoodCard("Comida", "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=400&q=80"),
                                _buildVisualMoodCard("Aventura", "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=400&q=80"),
                                _buildVisualMoodCard("Cultura", "https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3?auto=format&fit=crop&w=400&q=80"),
                                _buildDiceCard(),
                            ],
                        ).animate().fadeIn(delay: 200.ms),
                    )
                ]
            ],
        ),
    );
  }

  Widget _buildVisualMoodCard(String label, String imageUrl) {
      return InkWell(
          onTap: () => _onMoodSelected(label),
          borderRadius: BorderRadius.circular(24),
          child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Stack(
                  fit: StackFit.expand,
                  children: [
                      Image.network(imageUrl, fit: BoxFit.cover),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          label.toUpperCase(), 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)
                        ),
                      )
                  ],
              ),
          ),
      );
  }

  Widget _buildDiceCard() {
      return InkWell(
          onTap: () => _onMoodSelected("Dados"),
          borderRadius: BorderRadius.circular(24),
          child: Container(
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryBrand, AppTheme.secondaryBrand],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: AppTheme.primaryBrand.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]
              ),
              child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      Icon(Icons.casino_rounded, color: Colors.white, size: 40),
                      SizedBox(height: 8),
                      Text(
                        "DADOS", 
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)
                      )
                  ],
              ),
          ),
      );
  }
}
