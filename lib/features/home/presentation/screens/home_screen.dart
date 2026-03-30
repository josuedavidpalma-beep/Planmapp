import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/core/theme/theme_provider.dart';
import 'package:planmapp/features/notifications/services/notification_service.dart';
import 'package:planmapp/features/explore/services/events_service.dart';
import 'package:planmapp/features/explore/data/models/event_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planmapp/features/venues/presentation/widgets/instagram_reel_feed.dart';
import 'package:planmapp/core/presentation/widgets/premium_empty_state.dart';
import 'package:planmapp/core/presentation/widgets/skeleton_loader.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedFilter = "Todo";
  String _selectedCity = "Bogotá";
  final List<String> _cities = ["Bogotá", "Medellín", "Cali", "Barranquilla", "Cartagena"];
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _loadPersistedCity();
  }

  Future<void> _loadPersistedCity() async {
      final prefs = await SharedPreferences.getInstance();
      final savedCity = prefs.getString('home_city');
      if (savedCity != null && _cities.contains(savedCity)) {
          setState(() { _selectedCity = savedCity; });
      } else {
          _requestAutoLocation();
      }
  }

  Future<void> _requestAutoLocation() async {
      setState(() => _isLocating = true);
      try {
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) throw Exception("Ubicación apagada");
          
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
              permission = await Geolocator.requestPermission();
              if (permission == LocationPermission.denied) throw Exception("Permiso denegado");
          }
          if (permission == LocationPermission.deniedForever) throw Exception("Permiso denegado permanentemente");

          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
          
          final map = {
              "Bogotá": [4.711, -74.072],
              "Medellín": [6.244, -75.581],
              "Cali": [3.451, -76.532],
              "Barranquilla": [10.963, -74.796],
              "Cartagena": [10.391, -75.479],
          };
          
          String nearest = "Bogotá";
          double minD = double.infinity;

          for (final city in map.keys) {
              final d = Geolocator.distanceBetween(pos.latitude, pos.longitude, map[city]![0], map[city]![1]);
              if (d < minD) {
                  minD = d;
                  nearest = city;
              }
          }
          
          if (mounted) {
              setState(() => _selectedCity = nearest);
              final prefs = await SharedPreferences.getInstance();
              prefs.setString('home_city', nearest);
          }
      } catch (e) {
         // Fallback estático en caso de error
      } finally {
         if (mounted) setState(() => _isLocating = false);
      }
  }

  @override
  Widget build(BuildContext context) {
    // Placeholder for "Active Plan" logic
    // final hasActivePlan = false; // TODO: Fetch from provider

    return Scaffold(
      appBar: AppBar(
        title: PopupMenuButton<String>(
          onSelected: (value) {
            setState(() {
              _selectedCity = value;
            });
          },
          position: PopupMenuPosition.under,
          child: Column(
            children: [
               Text(_isLocating ? "Ubicando..." : "Explorar", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
               Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Text(_selectedCity, style: const TextStyle(fontSize: 13, color: AppTheme.primaryBrand, fontWeight: FontWeight.bold)),
                   const Icon(Icons.keyboard_arrow_down, size: 16, color: AppTheme.primaryBrand)
                 ],
               ),
            ],
          ),
          itemBuilder: (context) => _cities.map((city) => PopupMenuItem(
            value: city,
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: city == _selectedCity ? AppTheme.primaryBrand : Colors.grey),
                const SizedBox(width: 8),
                Text(city, style: TextStyle(fontWeight: city == _selectedCity ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
          )).toList(),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(ref.watch(themeProvider) == ThemeMode.light ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
             onPressed: () {
                 ref.read(themeProvider.notifier).toggle();
             },
          ),
          StreamBuilder<int>(
            stream: NotificationService().getUnreadCountStream(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return IconButton(
                onPressed: () => context.push('/notifications'),
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              );
            }
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<Event>>(
        key: ValueKey(_selectedCity), // Refresh when city changes
        future: EventsService().getDailyEvents(city: _selectedCity),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Padding(
               padding: EdgeInsets.all(16.0), 
               child: SkeletonList(count: 3)
             );
          }
          if (snapshot.hasError) {
             return Center(child: Text("Error cargando eventos: ${snapshot.error}"));
          }

          final allEvents = snapshot.data ?? [];
          
          // Filter logic
          final filteredEvents = allEvents.where((event) {
// ... rest of logic
             if (_selectedFilter == "Todo") return true;
             
             // Map UI filter to backend category
             final category = event.category?.toLowerCase() ?? "";
             switch (_selectedFilter) {
               case "Comida": return category == "food";
               case "Rumba": return category == "party"; // Corrected this line implicitly by context
               case "Aire Libre": return category == "outdoors";
               case "Cultura": return category == "culture";
               case "Música": return category == "music"; 
               default: return true;
             }
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADING
                const Text(
                  "Hola, Josué 👋",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
                Text(
                  "¿Qué sale hoy en $_selectedCity?",
                  style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 24),
    
                // CHIPS / FILTERS
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip("Todo"),
                      _buildFilterChip("Comida"),
                      _buildFilterChip("Rumba"),
                      _buildFilterChip("Aire Libre"),
                      _buildFilterChip("Cultura"),
                      _buildFilterChip("📸 Reels"),
                    ],
                  ),
                ),
                 const SizedBox(height: 24),
    
                // SWITCHING VISUALIZATION FOR TIKTOK FEED
                if (_selectedFilter == "📸 Reels")
                   SizedBox(
                       height: MediaQuery.of(context).size.height * 0.65, // Adjust vertical fill
                       child: InstagramEmbedFeed(
                           instagramUrls: const [
                              "https://www.instagram.com/reel/DE-R9bSR20Q/",
                              "https://www.instagram.com/p/DBhCHf7y6I-/",
                              "https://www.instagram.com/p/DB4f1Q8SiB5/"
                           ] // Mock URLs para MVP, idealmente vienen de DB para locales
                       ),
                   )
                // CLASIC FEED CARDS
                else if (filteredEvents.isEmpty)
                   const PremiumEmptyState(
                     icon: Icons.search_off_rounded,
                     title: "Mmm, está muy tranquilo",
                     subtitle: "No encontramos planes para esta categoría hoy. ¿Por qué no creas tu propio plan?",
                   )
                else
                   ...filteredEvents.map((event) => _AnimatedPlanCard(
                      title: event.title, 
                      subtitle: "${event.location ?? 'Ubicación desconocida'} • ${event.date ?? ''}", 
                      imageUrl: event.imageUrl ?? "https://via.placeholder.com/600",
                      event: event,
                      onTap: () => _showPlanPreview(context, event.title, "${event.location ?? 'Ubicación desconocida'} • ${event.date ?? ''}", event.imageUrl ?? "https://via.placeholder.com/600", event)
                   )),

                const SizedBox(height: 80), // Bottom padding
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () {
            setState(() {
                _selectedFilter = label;
            });
        },
        child: Container(
           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
           decoration: BoxDecoration(
             color: isSelected ? AppTheme.primaryBrand : Colors.transparent,
             borderRadius: BorderRadius.circular(20),
             border: Border.all(color: isSelected ? Colors.transparent : Colors.grey[300]!)
           ),
           child: Text(
             label, 
             style: TextStyle(
               color: isSelected ? Colors.white : Colors.grey, 
               fontWeight: FontWeight.bold
             )
           ),
        ),
      ),
    );
  }

  void _showPlanPreview(BuildContext context, String title, String subtitle, String imageUrl, Event event) {
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85), // Allow it to be taller if needed
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min, // Shrink to fit content
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                            child: CachedNetworkImage(
                                imageUrl: imageUrl.startsWith('http') ? imageUrl : 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&q=80&w=800', 
                                height: 200, 
                                width: double.infinity, 
                                fit: BoxFit.cover,
                                errorWidget: (context, url, err) => Container(
                                    height: 200,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [AppTheme.primaryBrand.withOpacity(0.5), AppTheme.secondaryBrand.withOpacity(0.5)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    ),
                                    child: const Center(child: Icon(Icons.flash_on_rounded, size: 50, color: Colors.white))
                                ),
                            ),
                        ),
                        Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: SafeArea( // Protects against bottom navigation bar overlap
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),

                                      // NEW: Location & Date Info
                                      if (event.address != null || event.location != null)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(children: [
                                            const Icon(Icons.location_on, size: 16, color: AppTheme.secondaryBrand),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(event.address ?? event.location!, style: const TextStyle(color: Colors.black87), overflow: TextOverflow.ellipsis, maxLines: 2)),
                                          ]),
                                        ),
                                      if (event.date != null)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(children: [
                                            const Icon(Icons.calendar_month, size: 16, color: AppTheme.primaryBrand),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(event.endDate != null && event.endDate != event.date ? "Del ${event.date} al ${event.endDate}" : "${event.date}", style: const TextStyle(color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                          ]),
                                        ),
                                      if (event.contactInfo != null)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(children: [
                                            const Icon(Icons.phone, size: 16, color: Colors.grey),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(event.contactInfo!, style: const TextStyle(color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                          ]),
                                        ),

                                      const SizedBox(height: 12),
                                      if (event.description != null)
                                          Text(event.description!, style: const TextStyle(fontSize: 14, height: 1.5)),
                                      const SizedBox(height: 24),

                                      SizedBox(
                                          width: double.infinity,
                                          height: 50,
                                          child: ElevatedButton(
                                              onPressed: () {
                                                  Navigator.pop(context);
                                                  
                                                  // Parse date if possible
                                                  DateTime? parsedDate;
                                                  try {
                                                      if (event.date != null) {
                                                          parsedDate = DateTime.parse(event.date!);
                                                      }
                                                  } catch (_) {}

                                                  context.push('/create-plan', extra: {
                                                      'initialTitle': title,
                                                      'initialAddress': event.address ?? event.location,
                                                      'initialDate': parsedDate
                                                  }); 
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Creando plan: $title")));
                                              }, 
                                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.white),
                                              child: const Text("¡Me apunto! Crear Plan"),
                                          ),
                                      ),
                                      
                                      // NEW: More Info Link
                                      if (event.sourceUrl != null && (event.sourceUrl?.isNotEmpty ?? false))
                                          Padding(
                                            padding: const EdgeInsets.only(top: 12),
                                            child: SizedBox(
                                              width: double.infinity,
                                              height: 50,
                                              child: OutlinedButton.icon(
                                                  onPressed: () async {
                                                      final uri = Uri.parse(event.sourceUrl!);
                                                      if (await canLaunchUrl(uri)) {
                                                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                                                      } else {
                                                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo abrir el enlace")));
                                                      } 
                                                  },
                                                  icon: const Icon(Icons.public, size: 18),
                                                  label: const Text("Ver más información"),
                                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.black),
                                              ),
                                            ),
                                          ),
                                      const SizedBox(height: 16), // Extra bottom padding
                                  ],
                              ),
                            ),
                        )
                    ],
                ),
              ),
          )
      );
  }
}

class _AnimatedPlanCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final Event event;
  final VoidCallback onTap;

  const _AnimatedPlanCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.event,
    required this.onTap,
  });

  @override
  State<_AnimatedPlanCard> createState() => _AnimatedPlanCardState();
}

class _AnimatedPlanCardState extends State<_AnimatedPlanCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
               BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
            ]
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
               children: [
                  CachedNetworkImage(
                    imageUrl: widget.imageUrl.startsWith('http') ? widget.imageUrl : 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&q=80&w=800', 
                    fit: BoxFit.cover, 
                    width: double.infinity, 
                    height: double.infinity,
                    placeholder: (context, url) => Container(color: Theme.of(context).cardColor),
                    errorWidget: (context, url, err) => Container(
                         decoration: BoxDecoration(
                           gradient: LinearGradient(
                             colors: [AppTheme.primaryBrand.withOpacity(0.5), AppTheme.secondaryBrand.withOpacity(0.5)],
                             begin: Alignment.topLeft,
                             end: Alignment.bottomRight,
                           )
                         ),
                         child: const Center(child: Icon(Icons.flash_on_rounded, size: 50, color: Colors.white))
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                           const Icon(Icons.location_on, color: AppTheme.secondaryBrand, size: 16),
                           const SizedBox(width: 4),
                           Expanded(child: Text(widget.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 1)),
                        ],
                      )
                    ],
                  ),
                ) // Missing a closing parenthesis and padding? No, Positioned closes fine.
               ]
            ),
          ),
        ),
      ),
    );
  }
}
