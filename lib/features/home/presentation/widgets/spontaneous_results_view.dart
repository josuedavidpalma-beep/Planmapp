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
import 'package:planmapp/features/explore/services/places_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SpontaneousResultsView extends StatefulWidget {
  final String category;
  final Position position;
  final String city;

  const SpontaneousResultsView({super.key, required this.category, required this.position, required this.city});

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
          
          List<String> userVibes = [];
          String? budgetLevel;
          int? userAge;
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
              final profile = await Supabase.instance.client.from('profiles').select('budget_level, birth_date, birthday, interests').eq('id', user.id).maybeSingle();
              if (profile != null) {
                  budgetLevel = profile['budget_level'];
                  if (profile['interests'] != null) {
                      userVibes = List<String>.from(profile['interests'] ?? []);
                  }
                  final birthStr = profile['birth_date'] ?? profile['birthday'];
                  if (birthStr != null) {
                      final birth = DateTime.tryParse(birthStr);
                      if (birth != null) userAge = DateTime.now().year - birth.year;
                  }
              }
          }

          // Fetch only EXACT PLANS from Daily Events! 
          final List<Event> dailyEvents = await EventsService().getDailyEvents(
             city: widget.city.isNotEmpty ? widget.city : 'Bogotá',
             userInterests: userVibes.isEmpty ? null : userVibes,
             budgetLevel: budgetLevel,
             userAge: userAge,
          );
          
          // Filter by the vibe selected in the dice/FAB
          List<Event> filtered = [];
          if (widget.category == 'Dados') {
              filtered = dailyEvents; // Any vibe goes
              filtered.shuffle(random);
          } else {
              String queryVibe = widget.category.toLowerCase();
              if (queryVibe.contains('rumba')) queryVibe = 'rumba';
              else if (queryVibe.contains('chill')) queryVibe = 'chill';
              else if (queryVibe.contains('comida')) queryVibe = 'gastronomia';
              else if (queryVibe.contains('aventura')) queryVibe = 'aventura';
              else if (queryVibe.contains('cultura')) queryVibe = 'cultura';
              else if (queryVibe.contains('deporte')) queryVibe = 'deporte';
              else queryVibe = queryVibe.replaceAll(' ', '');

              filtered = dailyEvents.where((e) {
                  final cat = (e.category ?? '').toLowerCase();
                  return cat.contains(queryVibe) || cat.contains(widget.category.toLowerCase());
              }).toList();
              
              // If not enough results for the exact category, backfill with others to avoid empty states
              if (filtered.length < 3) {
                  final otherEvents = dailyEvents.where((e) => !filtered.contains(e)).toList();
                  otherEvents.shuffle(random);
                  filtered.addAll(otherEvents.take(10 - filtered.length));
              }
          }

          List<Map<String, dynamic>> loaded = [];
          for (var e in filtered) {
               double distMeters = 0;
               if (e.latitude != null && e.longitude != null) {
                   distMeters = Geolocator.distanceBetween(
                       widget.position.latitude, widget.position.longitude,
                       e.latitude!, e.longitude!
                   );
               }
               String distStr = distMeters > 1000 
                   ? "${(distMeters/1000).toStringAsFixed(1)} km" 
                   : "${distMeters.round()} m";
               if (distMeters == 0) distStr = "En la ciudad";

               loaded.add({
                  'name': e.title,
                  'rating': e.ratingGoogle?.toString() ?? (random.nextDouble() * 1.0 + 4.0).toStringAsFixed(1),
                  'dist': distStr,
                  'dist_val': distMeters,
                  'tag': e.category?.toUpperCase() ?? 'PLANAZO ✨',
                  'desc': e.description ?? e.promoHighlights ?? e.title,
                  'image': e.imageUrl ?? e.displayImageUrl,
                  'reservation_link': e.reservationLink ?? e.sourceUrl,
                  'date': e.date,
                  'address': e.address ?? e.location,
                  'contact_phone': e.contactPhone,
                  'promo_highlights': e.promoHighlights,
                  'price_range': e.priceLevel,
                  'vibe_tag': e.category
               });
          }

          if (widget.category == 'Dados') {
             _places = loaded.isNotEmpty ? [loaded.first] : []; 
          } else {
             _places = loaded.length > 10 ? loaded.sublist(0, 10) : loaded;
          }

      } catch (e) {
          debugPrint("Error fetching spontaneous plans: $e");
          _places = [];
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

      final event = Event(
          id: row['id']?.toString() ?? 'temp_${title.hashCode}',
          title: title,
          description: desc,
          imageUrl: (row['image_url'] != null && row['image_url'].toString().isNotEmpty) ? row['image_url'] : null,
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
          'image': event.imageUrl ?? event.displayImageUrl,
          'reservation_link': row['reservation_link'] ?? row['source_url'],
          'date': row['date'],
          'address': row['address'] ?? row['venue_name'],
          'contact_phone': row['contact_phone'],
          'promo_highlights': row['promo_highlights'],
          'price_range': row['price_range'],
          'vibe_tag': row['vibe_tag']
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
                           icon: const Icon(Icons.casino, color: AppTheme.primaryBrand, size: 28)
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
                        : _places.isEmpty
                            ? _buildEmptyState()
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

  Widget _buildEmptyState() {
      return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                      child: const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  const Text("¡Ups! No hay planes aquí", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                          "En este momento no detectamos eventos de esta categoría en tu ciudad. ¡Prueba otra vibra!", 
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], height: 1.5)
                      ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context), 
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: const Text("Explorar otras opciones")
                  )
              ],
          )
      ).animate().fade().slideY(begin: 0.1);
  }

  Widget _buildPlaceCard(Map<String, dynamic> place) {
      return GestureDetector(
          onTap: () => _showPlaceDetails(place),
          child: Container(
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
                                          if (place['promo_highlights'] != null && place['promo_highlights'].toString().isNotEmpty)
                                            Container(
                                                margin: const EdgeInsets.only(bottom: 6),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: AppTheme.secondaryBrand, borderRadius: BorderRadius.circular(6)),
                                                child: Text(place['promo_highlights'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                            ),
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
                                          
                                          // SURPRISE BONUS: Inteligencia Artificial Direct Contact Toolbar
                                          if ((place['contact_phone'] != null && place['contact_phone'].toString().isNotEmpty) || 
                                              (place['reservation_link'] != null && place['reservation_link'].toString().isNotEmpty))
                                            Container(
                                                margin: const EdgeInsets.only(bottom: 8),
                                                child: Row(
                                                    children: [
                                                        if (place['reservation_link'] != null && place['reservation_link'].toString().isNotEmpty)
                                                           GestureDetector(
                                                               onTap: () async {
                                                                   final u = Uri.parse(place['reservation_link']);
                                                                   if (await canLaunchUrl(u)) await launchUrl(u, mode: LaunchMode.externalApplication);
                                                               },
                                                               child: Container(
                                                                   margin: const EdgeInsets.only(right: 8),
                                                                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                                   decoration: BoxDecoration(
                                                                       gradient: const LinearGradient(colors: [Colors.purpleAccent, Colors.pinkAccent]),
                                                                       borderRadius: BorderRadius.circular(12),
                                                                   ),
                                                                   child: Row(children: [
                                                                       Icon(place['vibe_tag'] == 'Preventa' || place['reservation_link'].toString().contains('tuboleta') || place['reservation_link'].toString().contains('taquilla') ? Icons.confirmation_number_outlined : Icons.language, color: Colors.white, size: 14), 
                                                                       const SizedBox(width: 6), 
                                                                       Text(
                                                                           place['vibe_tag'] == 'Preventa' || place['reservation_link'].toString().contains('tuboleta') || place['reservation_link'].toString().contains('taquilla') ? "COMPRAR TICKETS" : "LINK OFICIAL", 
                                                                           style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                                                                       )
                                                                   ]),
                                                               )
                                                           ),
                                                        if (place['contact_phone'] != null && place['contact_phone'].toString().isNotEmpty)
                                                           GestureDetector(
                                                               onTap: () async {
                                                                   final num = place['contact_phone'].toString().replaceAll(RegExp(r'[^\d+]'), '');
                                                                   final u = Uri.parse("https://wa.me/$num");
                                                                   if (await canLaunchUrl(u)) await launchUrl(u, mode: LaunchMode.externalApplication);
                                                               },
                                                               child: Container(
                                                                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                                   decoration: BoxDecoration(color: Colors.greenAccent[700], borderRadius: BorderRadius.circular(12)),
                                                                   child: const Row(children: [Icon(Icons.chat_bubble_outline, color: Colors.white, size: 14), SizedBox(width: 4), Text("WhatsApp IA", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))]),
                                                               )
                                                           )
                                                    ]
                                                )
                                            ),
                                            
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
      ));
  }

  void _showPlaceDetails(Map<String, dynamic> place) {
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Stack(
            children: [
              Container(
                 constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
                 decoration: const BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                 ),
                 child: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                             ClipRRect(
                                 borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                                 child: Image.network(
                                     place['image'], 
                                     height: 200, 
                                     width: double.infinity, 
                                     fit: BoxFit.cover,
                                     errorBuilder: (c,e,s) => Container(height: 200, color: Colors.grey[900])
                                 ),
                             ),
                             Padding(
                                 padding: const EdgeInsets.all(24.0),
                                 child: SafeArea(
                                   child: Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                           Text(place['name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                                           const SizedBox(height: 12),
                                           
                                           // DONDE Y CUANDO
                                           if (place['address'] != null)
                                              Row(children: [
                                                  const Icon(Icons.location_on, size: 18, color: AppTheme.secondaryBrand),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: Text(place['address'], style: const TextStyle(color: Colors.white70, fontSize: 15))),
                                              ]),
                                           const SizedBox(height: 8),
                                           if (place['date'] != null)
                                              Row(children: [
                                                  const Icon(Icons.calendar_month, size: 18, color: AppTheme.primaryBrand),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: Text('Fecha del Plan: ${place['date']}', style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold))),
                                              ]),
                                           const SizedBox(height: 16),
                                           
                                           // DESCRIPCION
                                           Text(place['desc'], style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.white)),
                                           const SizedBox(height: 24),
                                           
                                           // COMO VOY (CTAs)
                                           if (place['reservation_link'] != null && place['reservation_link']!.toString().isNotEmpty)
                                              Container(
                                                width: double.infinity,
                                                margin: const EdgeInsets.only(bottom: 12),
                                                child: ElevatedButton.icon(
                                                   onPressed: () async {
                                                       try {
                                                           final u = Uri.parse(place['reservation_link']);
                                                           if (await canLaunchUrl(u)) {
                                                               await launchUrl(u, mode: LaunchMode.externalApplication);
                                                           }
                                                       } catch (_) {}
                                                   },
                                                   icon: Icon(
                                                     place['vibe_tag'] == 'Master Fest' ? Icons.restaurant_menu 
                                                     : (place['vibe_tag'] == 'Local Promo' || place['vibe_tag'] == 'Descuento') ? Icons.local_offer 
                                                     : Icons.confirmation_number, 
                                                     color: Colors.white
                                                   ),
                                                   style: ElevatedButton.styleFrom(
                                                     backgroundColor: place['vibe_tag'] == 'Master Fest' ? Colors.orange[800] 
                                                                    : (place['vibe_tag'] == 'Local Promo' || place['vibe_tag'] == 'Descuento') ? Colors.green[600] 
                                                                    : AppTheme.secondaryBrand,
                                                     foregroundColor: Colors.white,
                                                     padding: const EdgeInsets.symmetric(vertical: 14),
                                                     elevation: 0,
                                                   ),
                                                   label: Text(
                                                     place['vibe_tag'] == 'Master Fest' ? "Ver Participantes Master" 
                                                     : (place['vibe_tag'] == 'Local Promo' || place['vibe_tag'] == 'Descuento') ? "Aprovechar Promo ${place['price_range'] != null ? '(${place['price_range']})' : ''}" 
                                                     : "🎟 Comprar Tickets ${place['price_range'] != null ? '(${place['price_range']})' : ''}", 
                                                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                                                   )
                                                ),
                                              ),
                                              
                                           // VAMOS BUTTON
                                           SizedBox(
                                               width: double.infinity,
                                               height: 54,
                                               child: ElevatedButton(
                                                   onPressed: () {
                                                       Navigator.pop(context); // Close detail sheet
                                                       _createSpontaneousPlan(place);
                                                   }, 
                                                   style: ElevatedButton.styleFrom(
                                                       backgroundColor: AppTheme.primaryBrand, 
                                                       foregroundColor: Colors.white,
                                                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                                                   ),
                                                   child: const Text("¡VAMOS! Crear el Plan 🚀", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                               ),
                                           ),
                                           const SizedBox(height: 16),
                                       ],
                                   ),
                                 ),
                             ),
                        ]
                    )
                 )
              ),
              Positioned(
                 top: 16, right: 16,
                 child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context)
                 )
              )
            ]
          )
      );
  }
}
