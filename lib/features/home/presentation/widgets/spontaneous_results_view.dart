import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:planmapp/core/services/plan_service.dart';
import 'package:planmapp/features/plan_detail/presentation/screens/plan_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/explore/data/models/event_model.dart';

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

  final Random random = Random();
  
  @override
  void initState() {
    super.initState();
    _fetchCuratedPlaces();
  }

  Future<void> _fetchCuratedPlaces() async {
      try {
          if (mounted) setState(() => _isLoading = true);
          
          List<String> targetVibes = [];
          if (widget.category == 'Dados') {
              final allVibes = ["Rumba/Party", "Chill/Café", "Comida/Gastro", "Aventura/Outdoor", "Cine/Cultura"];
              targetVibes = [allVibes[random.nextInt(allVibes.length)], allVibes[random.nextInt(allVibes.length)]];
          } else {
              targetVibes = [widget.category]; // For legacy, mapping happens below
          }

          // Combined Results
          List<Map<String, dynamic>> loaded = [];

          // 1. Fetch from 'local_events' (The new AI discoveries)
          var localQuery = Supabase.instance.client.from('local_events').select('*');
          if (widget.category != 'Dados') {
              // Map UI labels to DB vibe_tags
              String vibeMapping = widget.category;
              if (widget.category == 'Rumba') vibeMapping = 'Rumba/Party';
              else if (widget.category == 'Chill') vibeMapping = 'Chill/Café';
              else if (widget.category == 'Comida') vibeMapping = 'Comida/Gastro';
              else if (widget.category == 'Aventura') vibeMapping = 'Aventura/Outdoor';
              else if (widget.category == 'Cultura') vibeMapping = 'Cine/Cultura';
              localQuery = localQuery.ilike('vibe_tag', '%$vibeMapping%');
          }
          
          final localRes = await localQuery.limit(20);
          for (var row in localRes) {
              _processRow(row, loaded, isLocal: true);
          }

          // 2. Fetch from legacy 'events' if needed
          if (loaded.length < 5) {
              String dbCategory = 'food';
              if (widget.category == 'Rumba') dbCategory = 'party';
              else if (widget.category == 'Chill') dbCategory = 'cafe';
              else if (widget.category == 'Cultura') dbCategory = 'culture';
              else if (widget.category == 'Aventura') dbCategory = 'outdoors';

              final res = await Supabase.instance.client
                  .from('events')
                  .select('*')
                  .eq('category', dbCategory)
                  .limit(10);
              
              for (var row in res) {
                  _processRow(row, loaded, isLocal: false);
              }
          }

          // Sort by distance
          loaded.sort((a, b) => (a['dist_val'] as double).compareTo(b['dist_val'] as double));
          
          _places = loaded.length > 8 ? loaded.sublist(0, 8) : loaded;

          if (_places.isEmpty) {
              _places = [{ 'name': 'Vibe Tranquilo', 'rating': '5.0', 'dist': 'Pronto', 'tag': 'Tip Planmapp', 'desc': 'No hay eventos masivos ahora, pero es el momento perfecto para una caminata por el Malecón del Río.', 'image': 'https://images.unsplash.com/photo-1519331379826-f947873d63bd?auto=format&fit=crop&w=500' }];
          }

      } catch (e) {
         print("Error fetching spontaneous places: $e");
         _places = [{ 'name': 'Error de conexión', 'rating': '0.0', 'dist': '0 m', 'tag': 'Error', 'desc': 'Verifica tu conexión a internet.', 'image': 'https://images.unsplash.com/photo-1519331379826-f947873d63bd?auto=format&fit=crop&w=500' }];
      }

      if (mounted) setState(() => _isLoading = false);
  }

  void _processRow(Map<String, dynamic> row, List<Map<String, dynamic>> loaded, {required bool isLocal}) {
      double? lat = double.tryParse(row['latitude']?.toString() ?? '');
      double? lng = double.tryParse(row['longitude']?.toString() ?? '');
      
      double distMeters = 0;
      if (lat != null && lng != null) {
          distMeters = Geolocator.distanceBetween(
              widget.position.latitude, widget.position.longitude,
              lat, lng
          );
      }
      
      String distStr = distMeters > 1000 
          ? "${(distMeters/1000).toStringAsFixed(1)} km" 
          : "${distMeters.round()} m";
      if (distMeters == 0) distStr = "Cerca";

      final title = row['event_name'] ?? row['title'] ?? 'Lugar';
      final desc = row['description'] ?? title;
      bool hasDiscount = desc.toLowerCase().contains('desc') || desc.toLowerCase().contains('%') || desc.toLowerCase().contains('promo');

      // NEW: Use Event model logic for images
      final event = Event(
          id: row['id']?.toString() ?? 'temp_${title.hashCode}',
          title: title,
          description: desc,
          imageUrl: row['image_url'],
          visualKeyword: row['visual_keyword'],
          category: row['category'] ?? row['vibe_tag'],
      );

      loaded.add({
          'name': title,
          'rating': row['rating_google']?.toString() ?? (random.nextDouble() * 1.0 + 4.0).toStringAsFixed(1),
          'dist': distStr,
          'dist_val': distMeters,
          'tag': hasDiscount ? 'OFERTA 🏷️' : (isLocal ? 'FRESH ✨' : 'TOP 🔥'),
          'desc': desc,
          'image': event.displayImageUrl,
          'reservation_link': row['reservation_link'] ?? row['source_url']
      });
  }

  Future<void> _createSpontaneousPlan(Map<String, dynamic> place) async {
       // 1. Show processing
       showDialog(barrierDismissible: false, context: context, builder: (_) => const Center(child: CircularProgressIndicator()));
       
       try {
           final session = Supabase.instance.client.auth.currentSession;
           if (session == null) {
               throw Exception("Debes iniciar sesión para crear un plan.");
           }
           final userId = session.user.id;
           
           final title = "Plan Espontáneo en ${place['name']}";
           final desc = "Mood: ${widget.category}\nLugar: ${place['name']} (${place['tag']})\n${place['desc']}";
           
            final planData = {
                'title': title,
                'description': desc,
                'location_name': place['name'],
                'event_date': DateTime.now().toIso8601String(), // NOW!
                'payment_mode': 'individual',
                'creator_id': userId,
                'image_url': place['image'],
                'reservation_link': place['reservation_link']?.toString(), // PERSIST ACTIONABLE DATA
                'contact_info': place['contact_phone']?.toString(), // IF AVAILABLE
                'promo_highlights': place['promo_highlights']?.toString(),
                'status': 'active' 
            };

           final res = await Supabase.instance.client.from('plans').insert(planData).select().single();
           final planId = res['id'];
           
           // Add creator as member
           await Supabase.instance.client.from('plan_members').insert({
               'plan_id': planId,
               'user_id': userId,
               'role': 'admin',
               'status': 'confirmed' 
           });

           if (mounted) {
               HapticFeedback.heavyImpact();
               Navigator.of(context, rootNavigator: true).pop(); // Cerramos el dialog de carga 
               
               // Animación de Éxito 🎉
               showDialog(
                   barrierColor: Colors.black.withOpacity(0.8),
                   context: context, 
                   builder: (_) => Center(
                       child: Container(
                           padding: const EdgeInsets.all(32),
                           decoration: BoxDecoration(
                               color: AppTheme.darkBackground, 
                               borderRadius: BorderRadius.circular(32),
                               border: Border.all(color: AppTheme.primaryBrand.withOpacity(0.3), width: 2),
                               boxShadow: [BoxShadow(color: AppTheme.primaryBrand.withOpacity(0.2), blurRadius: 40)]
                           ),
                           child: Column(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                   const Text("🚀", style: TextStyle(fontSize: 80)).animate().scale(curve: Curves.elasticOut, duration: 800.ms),
                                   const SizedBox(height: 24),
                                   const Text("¡Plan Iniciado!", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, decoration: TextDecoration.none)).animate().fade(delay: 300.ms),
                                   const SizedBox(height: 8),
                                   Text("Prepara a tu grupo...", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, decoration: TextDecoration.none)).animate().fade(delay: 500.ms),
                               ]
                           )
                       )
                   )
               );
               
               await Future.delayed(const Duration(milliseconds: 1800));
               
               if (mounted) {
                   Navigator.pop(context); // Pop Success Dialog
                   Navigator.pop(context); // Pop Sheet actual
                   
                   // Navigate to Detail
                   Navigator.push(context, MaterialPageRoute(builder: (_) => PlanDetailScreen(planId: planId)));
               }
           }

       } catch (e) {
           if (mounted) {
               Navigator.of(context, rootNavigator: true).pop(); // Pop loading
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error creando plan: $e")));
           }
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
                 Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Text(
                       widget.category == 'Dados' ? "Suerte del día 🎲" : "Top Picks: ${widget.category}", 
                       style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                     ),
                     if (widget.category == 'Dados') ...[
                       const SizedBox(width: 8),
                       IconButton(
                           onPressed: _fetchCuratedPlaces, 
                           icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryBrand)
                       ).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 2.seconds)
                     ]
                   ],
                 ),
                 const SizedBox(height: 4),
                 Text(
                   widget.category == 'Dados' ? "Algo diferente cada vez que tiras." : "Cerca de ti • Abierto ahora", 
                   style: TextStyle(color: Colors.grey[600], fontSize: 13)
                 ),
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
              color: Colors.black, // Fallback dark
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))]
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
              fit: StackFit.expand,
              children: [
                  // Full Background Image
                  Image.network(
                      place['image'], 
                      fit: BoxFit.cover, 
                      errorBuilder: (c,e,s) => Container(color: Colors.grey[900])
                  ),
                  
                  // Gradient Overlay for readability
                  Container(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                  Colors.black.withOpacity(0.8),
                              ],
                              stops: const [0.3, 0.6, 1.0],
                          )
                      ),
                  ),

                  // Tag Badge (Top Right)
                  Positioned(
                      top: 16, right: 16,
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), border: Border.all(color: Colors.white24)),
                                  child: Text(place['tag'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                          ),
                      )
                  ),
                  
                  // Glassmorphism Info Panel (Bottom)
                  Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: ClipRRect(
                          child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      border: const Border(top: BorderSide(color: Colors.white12))
                                  ),
                                  child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                          Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                  Expanded(child: Text(place['name'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                                      child: Row(children: [const Icon(Icons.star, size: 14, color: Colors.amber), const SizedBox(width: 4), Text("${place['rating']}", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))]),
                                                  )
                                              ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(place['desc'], style: TextStyle(color: Colors.white.withOpacity(0.8), height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 16),
                                          Row(
                                              children: [
                                                  Container(
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                                                      child: const Icon(Icons.directions_walk, size: 16, color: Colors.white70)
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text("${place['dist']}", style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                                                  const Spacer(),
                                                  ElevatedButton(
                                                      onPressed: () => _createSpontaneousPlan(place),
                                                      style: ElevatedButton.styleFrom(
                                                          backgroundColor: AppTheme.primaryBrand, 
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                          elevation: 0,
                                                      ),
                                                      child: const Text("¡VAMOS! 🚀", style: TextStyle(fontWeight: FontWeight.bold)),
                                                  )
                                              ],
                                          )
                                      ],
                                  ),
                              ),
                          ),
                      )
                  )
              ],
          ),
      );
  }
}
