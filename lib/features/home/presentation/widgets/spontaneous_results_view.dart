import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:planmapp/core/services/plan_service.dart';
import 'package:planmapp/features/plan_detail/presentation/screens/plan_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SpontaneousResultsView extends StatefulWidget {
  final String category;
  final Position position;

  const SpontaneousResultsView({super.key, required this.category, required this.position});

  @override
  State<SpontaneousResultsView> createState() => _SpontaneousResultsViewState();
}

class _SpontaneousResultsViewState extends State<SpontaneousResultsView> {
  final PageController _pageController = PageController(viewportFraction: 0.85); // Peek next card
  List<Map<String, dynamic>> _places = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCuratedPlaces();
  }

  // MOCK ALGORITHM: In real app, this queries DB/API
  Future<void> _fetchCuratedPlaces() async {
      await Future.delayed(const Duration(milliseconds: 1500)); // Fake network delay for effect
      
      final random = Random();
      final cat = widget.category;
      
      // MOCK DATA based on category
      if (cat == "Comer") {
          _places = [
               { 'name': 'La Hamburguesería', 'rating': 4.8, 'dist': '0.5 km', 'tag': 'La Confiable 🛡️', 'desc': 'Las mejores hamburguesas artesanales del barrio.', 'image': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=500' },
               { 'name': 'Tacos El Pastor', 'rating': 4.5, 'dist': '1.2 km', 'tag': 'Oferta 2x1 🏷️', 'desc': 'Martes de tacos, paga 1 lleva 2 en pastor.', 'image': 'https://images.unsplash.com/photo-1599974579688-8dbdd3b43d36?auto=format&fit=crop&w=500' },
               { 'name': 'Ramen Oculto', 'rating': 4.9, 'dist': '2.1 km', 'tag': 'El Descubrimiento 💎', 'desc': 'Un rincón japonés auténtico que pocos conocen.', 'image': 'https://images.unsplash.com/photo-1591814468924-fb92710f6dc5?auto=format&fit=crop&w=500' }
          ];
      } else if (cat == "Beber") {
          _places = [
               { 'name': 'BBC Bodega', 'rating': 4.7, 'dist': '0.3 km', 'tag': 'La Confiable 🛡️', 'desc': 'Cerveza artesanal y buen ambiente siempre.', 'image': 'https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=500' },
               { 'name': 'Cocktail Rooftop', 'rating': 4.6, 'dist': '1.5 km', 'tag': 'Happy Hour 🍹', 'desc': '20% off en cocteles de autor hasta las 9 PM.', 'image': 'https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?auto=format&fit=crop&w=500' },
               { 'name': 'Speakeasy 45', 'rating': 4.9, 'dist': '0.8 km', 'tag': 'Secreto 🤫', 'desc': 'Entra por la nevera de la pizzería. Jazz en vivo.', 'image': 'https://images.unsplash.com/photo-1572116469696-95872153d695?auto=format&fit=crop&w=500' }
          ];
      } else {
           // Generic fallback
           _places = [
               { 'name': 'Café Quindío', 'rating': 4.8, 'dist': '0.2 km', 'tag': 'La Confiable 🛡️', 'desc': 'El mejor café de la zona para charlar.', 'image': 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=500' },
               { 'name': 'Bolera Central', 'rating': 4.4, 'dist': '3.0 km', 'tag': 'Diversión 🎳', 'desc': 'Pistas disponibles y snacks.', 'image': 'https://images.unsplash.com/photo-1538332576228-eb5b4c4de6f5?auto=format&fit=crop&w=500' },
               { 'name': 'Parque Mirador', 'rating': 4.9, 'dist': '1.0 km', 'tag': 'Gratis 🌳', 'desc': 'Vista increíble de la ciudad al atardecer.', 'image': 'https://images.unsplash.com/photo-1519331379826-f947873d63bd?auto=format&fit=crop&w=500' }
           ];
      }
      
      if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _createSpontaneousPlan(Map<String, dynamic> place) async {
       // 1. Show processing
       showDialog(barrierDismissible: false, context: context, builder: (_) => const Center(child: CircularProgressIndicator()));
       
       try {
           // 2. Insert Plan
           final userId = Supabase.instance.client.auth.currentUser!.id;
           // Using direct insert or generic service? Let's use generic PlanService if possible, or direct for control.
           // Since we need 'spontaneous' type (if schema supports it, or just use 'casual').
           // The schema might not have 'type' column, let's assume 'casual' is fine or check schema.
           // Schema has: name, description, location_name, event_date, payment_mode
           
           final title = "Plan Espontáneo en ${place['name']}";
           final desc = "Mood: ${widget.category}\nLugar: ${place['name']} (${place['tag']})\n${place['desc']}";
           
           final planData = {
               'name': title,
               'description': desc,
               'location_name': place['name'],
               'event_date': DateTime.now().toIso8601String(), // NOW!
               'payment_mode': 'individual',
               'created_by': userId,
               'status': 'active' // or confirmed?
           };

           final res = await Supabase.instance.client.from('plans').insert(planData).select().single();
           final planId = res['id'];
           
           // Add creator as member
           await Supabase.instance.client.from('plan_members').insert({
               'plan_id': planId,
               'user_id': userId,
               'role': 'admin',
               'status': 'confirmed' // Auto confirm creator
           });

           if (mounted) {
               Navigator.pop(context); // Pop loading
               Navigator.pop(context); // Pop Sheet
               
               // Navigate to Detail
               Navigator.push(context, MaterialPageRoute(builder: (_) => PlanDetailScreen(planId: planId)));
           }

       } catch (e) {
           Navigator.pop(context); // Pop loading
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error creando plan: $e")));
       }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
         height: 600, // Taller sheet for carousel
         decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
         ),
         child: Column(
             children: [
                 const SizedBox(height: 16),
                 Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                 const SizedBox(height: 24),
                 Text("Top Picks: ${widget.category}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 4),
                 Text("Cerca de ti • Abierto ahora", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                 const SizedBox(height: 24),
                 
                 Expanded(
                     child: _isLoading 
                        ? const Center(child: CircularProgressIndicator())
                        : PageView.builder(
                             controller: _pageController,
                             itemCount: _places.length,
                             itemBuilder: (context, index) {
                                 final place = _places[index];
                                 return _buildPlaceCard(place);
                             },
                        )
                 ),
                 const SizedBox(height: 32),
             ],
         ),
    );
  }

  Widget _buildPlaceCard(Map<String, dynamic> place) {
      return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8))]
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  // Image
                  Expanded(
                      flex: 5,
                      child: Stack(
                          fit: StackFit.expand,
                          children: [
                              Image.network(place['image'], fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[200])),
                              Positioned(
                                  top: 12, right: 12,
                                  child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(20)),
                                      child: Text(place['tag'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                              )
                          ],
                      ),
                  ),
                  
                  // Info
                  Expanded(
                      flex: 4,
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                          Expanded(child: Text(place['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), maxLines: 1)),
                                          Row(children: [const Icon(Icons.star, size: 16, color: Colors.amber), Text(" ${place['rating']}", style: const TextStyle(fontWeight: FontWeight.bold))])
                                      ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(place['desc'], style: TextStyle(color: Colors.grey[600], height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const Spacer(),
                                  Row(
                                      children: [
                                          Icon(Icons.directions_walk, size: 16, color: Colors.grey[400]),
                                          Text(" ${place['dist']}", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                          const Spacer(),
                                          ElevatedButton(
                                              onPressed: () => _createSpontaneousPlan(place),
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppTheme.primaryBrand, 
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                              ),
                                              child: const Text("¡VAMOS! 🚀"),
                                          )
                                      ],
                                  )
                              ],
                          ),
                      ),
                  )
              ],
          ),
      );
  }
}
