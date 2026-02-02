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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedFilter = "Todo";

  @override
  Widget build(BuildContext context) {
    // Placeholder for "Active Plan" logic
    // final hasActivePlan = false; // TODO: Fetch from provider

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
             Text("Explorar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
             Text("Colombia", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w400)),
          ],
        ),
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
          const SizedBox(width: 16),
        ],
      ),
      body: FutureBuilder<List<Event>>(
        future: EventsService().getDailyEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return Center(child: Text("Error cargando eventos: ${snapshot.error}"));
          }

          final allEvents = snapshot.data ?? [];
          
          // Filter logic
          final filteredEvents = allEvents.where((event) {
             if (_selectedFilter == "Todo") return true;
             
             // Map UI filter to backend category
             final category = event.category?.toLowerCase() ?? "";
             switch (_selectedFilter) {
               case "Comida": return category == "food";
               case "Rumba": return category == "party";
               case "Aire Libre": return category == "outdoors";
               case "Cultura": return category == "culture";
               case "Música": return category == "music"; // Added extra
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
                const Text(
                  "¿Qué sale hoy?",
                  style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.w500),
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
                    ],
                  ),
                ),
                 const SizedBox(height: 24),
    
                // FEED CARDS
                if (filteredEvents.isEmpty)
                   const Padding(
                     padding: EdgeInsets.all(32.0),
                     child: Center(child: Text("No hay eventos en esta categoría por ahora.", style: TextStyle(color: Colors.grey))),
                   )
                else
                   ...filteredEvents.map((event) => _buildContextCard(
                      context, 
                      event.title, 
                      "${event.location ?? 'Ubicación desconocida'} • ${event.date ?? ''}", 
                      event.imageUrl ?? "https://via.placeholder.com/600",
                      event
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

  Widget _buildContextCard(BuildContext context, String title, String subtitle, String imageUrl, Event event) {
    return GestureDetector(
      onTap: () {
          _showPlanPreview(context, title, subtitle, imageUrl, event);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          image: DecorationImage(
            image: CachedNetworkImageProvider(imageUrl),
            fit: BoxFit.cover,
          ),
          boxShadow: [
             BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))
          ]
        ),
        child: Stack(
           children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
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
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                         const Icon(Icons.location_on, color: AppTheme.secondaryBrand, size: 16),
                         const SizedBox(width: 4),
                         Expanded(child: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 1)),
                      ],
                    )
                  ],
                ),
              )
           ],
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
                            child: CachedNetworkImage(imageUrl: imageUrl, height: 200, width: double.infinity, fit: BoxFit.cover),
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
                                            Text(event.endDate != null && event.endDate != event.date ? "Del ${event.date} al ${event.endDate}" : "${event.date}", style: const TextStyle(color: Colors.black87)),
                                          ]),
                                        ),
                                      if (event.contactInfo != null)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(children: [
                                            const Icon(Icons.phone, size: 16, color: Colors.grey),
                                            const SizedBox(width: 8),
                                            Text(event.contactInfo!, style: const TextStyle(color: Colors.black87)),
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
