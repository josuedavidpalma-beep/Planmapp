import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/core/theme/theme_provider.dart';
import 'package:planmapp/features/notifications/presentation/widgets/notification_badge.dart';

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
    final hasActivePlan = false; // TODO: Fetch from provider

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
             Text("Explorar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
             Text("Bogotá, CO", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
           IconButton(
             icon: Icon(ref.watch(themeProvider) == ThemeMode.light ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
             onPressed: () {
                 ref.read(themeProvider.notifier).toggle();
             },
          ),
          const NotificationBadge(),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
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

            // FEED CARDS (Mockup) - Filter based on selection logic would go here
            if (_selectedFilter == "Todo" || _selectedFilter == "Rumba")
                _buildContextCard(context, "Noche de Cócteles 🍸", "Zona T - Abierto ahora", "https://images.unsplash.com/photo-1514362545857-3bc16549766b?auto=format&fit=crop&q=80&w=600"),
            if (_selectedFilter == "Todo" || _selectedFilter == "Comida")
                _buildContextCard(context, "Brunch Dominical 🥞", "Usaquén - 10:00 AM", "https://images.unsplash.com/photo-1533777857889-4be7c70b33f7?auto=format&fit=crop&q=80&w=600"),
            if (_selectedFilter == "Todo" || _selectedFilter == "Aire Libre")
                _buildContextCard(context, "Senderismo La Chorrera 🌲", "Choachí - Mañana", "https://images.unsplash.com/photo-1551632811-561732d1e306?auto=format&fit=crop&q=80&w=600"),
          ],
        ),
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

  Widget _buildContextCard(BuildContext context, String title, String subtitle, String imageUrl) {
    return GestureDetector(
      onTap: () {
          _showPlanPreview(context, title, subtitle, imageUrl);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
          ),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
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
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                         const Icon(Icons.location_on, color: AppTheme.secondaryBrand, size: 16),
                         const SizedBox(width: 4),
                         Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
  
  void _showPlanPreview(BuildContext context, String title, String subtitle, String imageUrl) {
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
                            child: Image.network(imageUrl, height: 200, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: SafeArea( // Protects against bottom navigation bar overlap
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                                      const SizedBox(height: 24),
                                      SizedBox(
                                          width: double.infinity,
                                          height: 50,
                                          child: ElevatedButton(
                                              onPressed: () {
                                                  Navigator.pop(context);
                                                  context.push('/create-plan'); 
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Creando plan: $title")));
                                              }, 
                                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.white),
                                              child: const Text("¡Me apunto! Crear Plan"),
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
