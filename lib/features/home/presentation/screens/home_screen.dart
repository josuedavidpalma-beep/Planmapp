import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/core/theme/theme_provider.dart';
import 'package:planmapp/features/notifications/services/notification_service.dart';
import 'package:planmapp/features/notifications/services/push_notification_service.dart';
import 'package:planmapp/features/explore/services/events_service.dart';
import 'package:planmapp/features/explore/data/models/event_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planmapp/core/services/session_persistence_service.dart';
import 'package:planmapp/core/presentation/widgets/premium_empty_state.dart';
import 'package:planmapp/core/presentation/widgets/guest_barrier.dart';
import 'package:planmapp/core/presentation/widgets/skeleton_loader.dart';
import 'package:planmapp/features/home/presentation/widgets/discover_map.dart';
import 'package:planmapp/features/home/presentation/widgets/pwa_guide_tooltip.dart';
import 'package:planmapp/features/profile/presentation/widgets/profile_drawer.dart';
import 'package:planmapp/core/utils/web_utils.dart';
import 'package:planmapp/features/profile/presentation/screens/submit_ticket_screen.dart';
import 'package:planmapp/core/widgets/pwa_install_prompt.dart';

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
  String _userName = "";
  bool _showCompleteProfileBanner = false;
  bool _isMapView = false;
  bool _showPwaTip = true;
  bool _isGuest = false;
  List<String> _userInterests = [];
  String? _budgetLevel;
  int? _userAge;
  
  // Search state
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = "";
  List<Event> _searchResults = [];
  bool _isSearchLoading = false;
  int _refreshCounter = 0;
  
  List<Map<String, dynamic>> _dbPendingInvites = [];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadPersistedCity();
    _fetchUserData();
    _checkPendingActions();
  }

  Future<void> _checkPendingActions() async {
      final pendingExpense = await SessionPersistenceService.getPendingExpenseAssignment();
      if (pendingExpense != null && pendingExpense['expenseId'] != null) {
          final expenseId = pendingExpense['expenseId'];
          final portions = pendingExpense['portions'] as Map<String, double>;
          
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null && !user.isAnonymous) {
              await SessionPersistenceService.clearPendingExpenseAssignment();
              
              // Process the background RPCs since we are logged in!
              final profile = await Supabase.instance.client.from('profiles').select('nickname, full_name').eq('id', user.id).maybeSingle();
              final realName = (profile?['nickname']?.toString().isNotEmpty == true ? profile!['nickname'] : profile?['full_name']) ?? 'Usuario';
              for (var entry in portions.entries) {
                  await Supabase.instance.client.rpc('toggle_expense_assignment', params: {
                      'p_item_id': entry.key,
                      'p_user_id': user.id,
                      'p_guest_name': realName,
                      'p_qty': entry.value
                  });
              }
              // Redirect to wait screen
              if (mounted) {
                 context.push('/guest/wait/$expenseId');
                 return;
              }
          }
      }

      // Check pending plan join
      final pendingPlan = await SessionPersistenceService.getPendingPlanJoin();
      if (pendingPlan != null) {
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null && !user.isAnonymous) {
              await SessionPersistenceService.clearPendingPlanJoin();
              if (mounted) context.push('/invite/$pendingPlan');
          }
      }
  }

  Future<void> _fetchUserData() async {
      try {
          final user = Supabase.instance.client.auth.currentUser;
          if (user == null) return;
          final isAnon = user.isAnonymous ?? false;
          
          if (!isAnon) {
              // Wait for auth initialization
          }

          final data = await Supabase.instance.client
              .from('profiles')
              .select('full_name, display_name, nickname, interests, preferences, budget_level, birth_date, birthday')
              .eq('id', user.id)
              .maybeSingle();
              
          if (data == null) return;
          
          final nickname = data['nickname'] as String?;
          final name = nickname?.isNotEmpty == true
              ? nickname!
              : (data['display_name'] ?? data['full_name'] ?? "");
              
          int? age;
          final birthStr = data['birth_date'] ?? data['birthday'];
          if (birthStr != null) {
              final birth = DateTime.tryParse(birthStr);
              if (birth != null) {
                  age = DateTime.now().year - birth.year;
                  if (DateTime.now().month < birth.month || (DateTime.now().month == birth.month && DateTime.now().day < birth.day)) {
                      age--;
                  }
              }
          }

          if (mounted) {
              setState(() {
                _isGuest = isAnon;
                _userName = name.split(" ")[0];
                _userInterests = List<String>.from(data['preferences'] ?? data['interests'] ?? []);
                _budgetLevel = data['budget_level'];
                _userAge = age;
                _showCompleteProfileBanner = !isAnon && (nickname == null || nickname.isEmpty);
              });
              
              // NEW: Solicitar permiso automáticamente al iniciar sesión a usuarios antiguos
              if (!isAnon) {
                 final granted = await PushNotificationService().requestPermissionAndSaveToken();
                 if (!granted && kIsWeb && !isNotificationGranted) {
                     if (mounted) {
                         final isIos = defaultTargetPlatform == TargetPlatform.iOS;
                         final titleInfo = !isPwaStandalone ? "Instala la App" : "Activa las Alertas";
                         final iconInfo = !isPwaStandalone ? Icons.add_to_home_screen : Icons.notifications_off;
                         final contentInfo = !isPwaStandalone
                                ? (isIos 
                                    ? "Para que tu iPhone suene y recibas notificaciones de chat o cobros, debes instalar Planmapp:\n\n1. Toca en 'Compartir' (el cuadrado con flecha abajo en Safari).\n2. Selecciona 'Agregar a inicio'.\n3. Abre Planmapp desde tu pantalla de inicio."
                                    : "Para la mejor experiencia y notificaciones, instala Planmapp: Toca los 3 puntos del navegador y selecciona 'Instalar aplicación' o 'Agregar a la pantalla principal'.")
                                : "Estás usando Planmapp app pero tienes las notificaciones bloqueadas. Para enterarte de respuestas de chat y cobros, es necesario habilitarlas en la configuración de la app de tu teléfono (Settings).";

                         showDialog(
                             context: context, 
                             builder: (c) => AlertDialog(
                                 backgroundColor: AppTheme.darkBackground,
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                 title: Row(
                                    children: [
                                        Icon(iconInfo, color: Colors.orange),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(titleInfo, style: const TextStyle(color: Colors.white, fontSize: 18)))
                                    ]
                                 ),
                                 content: Text(
                                     contentInfo,
                                     style: const TextStyle(color: Colors.white70)
                                 ),
                                 actions: [
                                     TextButton(
                                        onPressed: () => Navigator.pop(c), 
                                        child: const Text("Entendido", style: TextStyle(color: Colors.grey))
                                     ),
                                 ]
                             )
                         );
                     }
                 }
              }
          }

          // Fetch internal database invites
          if (!isAnon) {
              try {
                  final pendingRes = await Supabase.instance.client
                      .from('plan_members')
                      .select('plan_id, plans!inner(title, event_date)')
                      .eq('user_id', user.id)
                      .eq('status', 'pending');
                      
                  if (mounted) {
                      setState(() {
                          _dbPendingInvites = (pendingRes as List<dynamic>).cast<Map<String,dynamic>>();
                      });
                  }
              } catch (e) {
                 // Ignore
              }
          }
      } catch (e) {
          print("Error fetching user data: $e");
      }
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
      key: _scaffoldKey,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: FloatingActionButton(
          onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SubmitTicketScreen()));
          },
          backgroundColor: AppTheme.primaryBrand,
          child: const Icon(Icons.bug_report_rounded, color: Colors.white),
        ),
      ),
      drawer: const ProfileDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, size: 28),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
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
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _searchQuery = "";
                  }
                });
            },
          ),
          IconButton(
            icon: Icon(_isMapView ? Icons.view_agenda_rounded : Icons.map_rounded, color: AppTheme.primaryBrand),
            onPressed: () {
                setState(() => _isMapView = !_isMapView);
            },
          ),
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
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppTheme.primaryBrand,
            backgroundColor: AppTheme.darkBackground,
            onRefresh: () async {
                setState(() {
                    _refreshCounter++;
                });
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              key: ValueKey("$_selectedCity-$_isSearching-$_searchQuery-$_refreshCounter"),
            slivers: [
              if (_isSearching)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: "Buscar un lugar (ej. Phortos, McDonald's...)",
                          prefixIcon: Icon(Icons.search, color: AppTheme.primaryBrand),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                        ),
                        onSubmitted: (val) async {
                          if (val.isEmpty) return;
                          setState(() {
                            _searchQuery = val;
                            _isSearchLoading = true;
                          });
                          final results = await EventsService().searchPlaces(query: val, city: _selectedCity);
                          setState(() {
                            _searchResults = results;
                            _isSearchLoading = false;
                          });
                        },
                      ),
                    ),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isSearching) ...[
                        Text(
                          _userName.isNotEmpty ? "Hola, $_userName 👋" : "Hola 👋",
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          "¿Qué sale hoy en $_selectedCity?",
                          style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 24),
                        if (_isGuest) _buildGuestBanner(),
                        if (_showCompleteProfileBanner)
                          GestureDetector(
                            onTap: () => context.push('/profile'),
                            child: _buildCompleteProfileBanner(),
                          ),
                        if (_dbPendingInvites.isNotEmpty)
                          _buildPendingInvites(),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),

              if (!_isSearching)
                 SliverPersistentHeader(
                   pinned: true,
                   delegate: _FilterHeaderDelegate(
                     child: Container(
                       color: Theme.of(context).scaffoldBackgroundColor,
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                       child: SizedBox(
                         height: 40,
                         child: ListView(
                           scrollDirection: Axis.horizontal,
                           children: [
                             _buildFilterChip("Todo"),
                             _buildFilterChip("Gastronomía"),
                             _buildFilterChip("Vida Nocturna"),
                             _buildFilterChip("Cultura & Ocio"),
                             _buildFilterChip("Bienestar & Deporte"),
                             _buildFilterChip("Aventura"),
                             _buildFilterChip("Grandes Eventos"),
                           ],
                         ),
                       ),
                     ),
                   ),
                 ),

              if (_isSearching && _searchQuery.isNotEmpty)
                _isSearchLoading 
                ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                : _searchResults.isEmpty
                  ? const SliverFillRemaining(
                      child: PremiumEmptyState(
                        icon: Icons.sentiment_dissatisfied,
                        title: "No encontramos ese lugar",
                        subtitle: "Intenta con otro nombre o revisa la ciudad.",
                      )
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _AnimatedPlanCard(
                            title: _searchResults[i].title,
                            subtitle: _searchResults[i].address ?? "",
                            imageUrl: _searchResults[i].imageUrl ?? _searchResults[i].displayImageUrl,
                            event: _searchResults[i],
                            onTap: () => _showPlanPreview(context, _searchResults[i].title, _searchResults[i].address ?? "", _searchResults[i].imageUrl ?? _searchResults[i].displayImageUrl, _searchResults[i]),
                          ),
                          childCount: _searchResults.length,
                        ),
                      ),
                    )
              else 
                SliverToBoxAdapter(
                  child: Builder(
                    builder: (context) {
                      final eventsAsyncValue = ref.watch(feedEventsProvider(jsonEncode({
                        'city': _selectedCity,
                        'category': _selectedFilter == "Todo" ? null : _getPlacesCategory(_selectedFilter),
                        'userInterests': _userInterests,
                        'budgetLevel': _budgetLevel,
                      })));

                      return eventsAsyncValue.when(
                        loading: () => const Padding(
                           padding: EdgeInsets.all(16.0), 
                           child: SkeletonList(count: 3)
                        ),
                        error: (error, stack) => Padding(
                           padding: const EdgeInsets.all(16),
                           child: Center(child: Text("Error: $error")),
                        ),
                        data: (feedData) {
                          final viralEvents = feedData.viralEvents;
                          final recommendedPlaces = feedData.recommendedPlaces;
            
                      if (_isMapView) {
                         return Padding(
                           padding: const EdgeInsets.all(16),
                           child: SizedBox(
                               height: MediaQuery.of(context).size.height * 0.6,
                               child: ClipRRect(
                                   borderRadius: BorderRadius.circular(20),
                                   child: DiscoverMap(
                                       events: recommendedPlaces,
                                       city: _selectedCity,
                                       onEventTap: (event) => _showPlanPreview(context, event.title, "${event.ratingGoogle != null ? '⭐ ${event.ratingGoogle} • ' : ''}${event.address ?? ''}", event.imageUrl ?? event.displayImageUrl, event)
                                   )
                               )
                           ),
                         );
                      }
                      
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              if (viralEvents.isNotEmpty) ...[
                                  const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: Text("Eventos & Virales 🔥", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                  SizedBox(
                                      height: 250,
                                      child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          itemCount: viralEvents.length,
                                          itemBuilder: (context, i) {
                                              final event = viralEvents[i];
                                              return Container(
                                                  width: 320,
                                                  margin: const EdgeInsets.only(right: 16),
                                                  child: _AnimatedPlanCard(
                                                      title: event.title,
                                                      subtitle: event.promoHighlights ?? event.category ?? '',
                                                      imageUrl: event.imageUrl ?? event.displayImageUrl,
                                                      event: event,
                                                      onTap: () => _showPlanPreview(context, event.title, "${event.address ?? ''}", event.imageUrl ?? event.displayImageUrl, event)
                                                  ),
                                              );
                                          }
                                      ),
                                  ),
                              ],
                              const SizedBox(height: 16),
                              const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Text("Locales Recomendados 📍", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                              if (recommendedPlaces.isEmpty)
                                  const SizedBox(
                                    height: 200,
                                    child: PremiumEmptyState(
                                      icon: Icons.search_off_rounded,
                                      title: "Mmm, está muy tranquilo",
                                      subtitle: "No encontramos locales para esta categoría en tu zona.",
                                    ),
                                  )
                              else
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Column(
                                      children: recommendedPlaces.map((event) => Padding(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: _AnimatedPlanCard(
                                           title: event.title, 
                                           subtitle: "${event.ratingGoogle != null ? '⭐ ${event.ratingGoogle} • ' : ''}${event.address ?? ''}", 
                                           imageUrl: event.imageUrl ?? event.displayImageUrl,
                                           event: event,
                                           isRecommended: _userInterests.isNotEmpty,
                                           onTap: () => _showPlanPreview(context, event.title, "${event.address ?? ''}", event.imageUrl ?? event.displayImageUrl, event)
                                        ),
                                      )).toList(),
                                    ),
                                  )
                          ]
                      );
                    }
                  );
                    }
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          ),
          
          // Subtle PWA Guide Tooltip
          if (_showPwaTip && _isGuest && kIsWeb)
            PwaGuideTooltip(
              onDismiss: () => setState(() => _showPwaTip = false),
            ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(child: PwaInstallPrompt()),
          ),
        ],
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

  String _getPlacesCategory(String filter) {
    switch (filter) {
      case "Gastronomía": return "restaurant";
      case "Vida Nocturna": return "bar";
      case "Cultura & Ocio": return "movie_theater";
      case "Bienestar & Deporte": return "gym";
      case "Aventura": return "park";
      case "Grandes Eventos": return "preventas";
      default: return "restaurant";
    }
  }

  void _showPlanPreview(BuildContext context, String title, String subtitle, String imageUrl, Event event) {
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
                            child: CachedNetworkImage(
                                imageUrl: imageUrl, 
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
                            child: SafeArea(
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
                                            Expanded(child: Text(event.address ?? event.location!, style: const TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis, maxLines: 2)),
                                          ]),
                                        ),
                                      if (event.date != null)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(children: [
                                            const Icon(Icons.calendar_month, size: 16, color: AppTheme.primaryBrand),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(event.endDate != null && event.endDate != event.date ? "Del ${event.date} al ${event.endDate}" : "${event.date}", style: const TextStyle(color: Colors.white70), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                          ]),
                                        ),

                                      // NEW: Creative Promo Highlights in Preview
                                      if (event.promoHighlights != null && event.promoHighlights!.isNotEmpty)
                                        Builder(
                                          builder: (context) {
                                            final (icon, color) = _getPromoBadgeInfo_Static(event.promoHighlights!);
                                            return Container(
                                              margin: const EdgeInsets.symmetric(vertical: 12),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: color.withOpacity(0.2)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(icon, color: color, size: 20),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      event.promoHighlights!,
                                                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                        ),

                                      const SizedBox(height: 12),
                                      if (event.description != null)
                                          Text(event.description!, style: const TextStyle(fontSize: 14, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 24),
                                      
                                      // DYNAMIC CTAs
                                      if (event.sourceUrl != null && event.sourceUrl!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: SizedBox(
                                            width: double.infinity,
                                            height: 50,
                                            child: ElevatedButton.icon(
                                              onPressed: event.sourceUrl!.contains('No publicado') ? null : () async {
                                                final u = Uri.parse(event.sourceUrl!);
                                                if (await canLaunchUrl(u)) {
                                                  await launchUrl(u, mode: LaunchMode.externalApplication);
                                                }
                                              },
                                              icon: Icon(
                                                event.sourceUrl!.contains('No publicado') 
                                                ? Icons.link_off
                                                : event.sourceUrl!.contains('tuboleta') || event.sourceUrl!.contains('eticket') || event.sourceUrl!.contains('entradas') 
                                                  ? Icons.local_activity
                                                  : event.sourceUrl!.contains('wa.me') || event.sourceUrl!.contains('whatsapp')
                                                    ? Icons.chat
                                                    : Icons.open_in_browser,
                                                color: event.sourceUrl!.contains('No publicado') ? Colors.grey : AppTheme.primaryBrand
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.primaryBrand.withOpacity(0.1),
                                                foregroundColor: AppTheme.primaryBrand,
                                                elevation: 0,
                                              ),
                                              label: Text(
                                                event.sourceUrl!.contains('No publicado')
                                                ? "Enlace no disponible"
                                                : event.sourceUrl!.contains('tuboleta') || event.sourceUrl!.contains('eticket') || event.sourceUrl!.contains('entradas') 
                                                  ? "Comprar Entradas"
                                                  : event.sourceUrl!.contains('wa.me') || event.sourceUrl!.contains('whatsapp')
                                                    ? "Reservar por WhatsApp"
                                                    : "Ver sitio oficial",
                                                style: const TextStyle(fontWeight: FontWeight.bold)
                                              )
                                            ),
                                          ),
                                        ),

                                      SizedBox(
                                          width: double.infinity,
                                          height: 50,
                                          child: ElevatedButton(
                                              onPressed: () {
                                                  Navigator.pop(context);
                                                  DateTime? parsedDate;
                                                  try {
                                                      if (event.date != null) {
                                                          parsedDate = DateTime.parse(event.date!);
                                                      }
                                                  } catch (_) {}

                                                  GuestBarrier.protect(context, () {
                                                      context.push('/create-plan', extra: {
                                                          'initialTitle': title,
                                                          'initialAddress': event.address ?? event.location,
                                                          'initialDate': parsedDate,
                                                          'initialImageUrl': imageUrl,
                                                      }); 
                                                  });
                                              }, 
                                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.white),
                                              child: const Text("¡Me apunto! Crear Plan"),
                                          ),
                                      ),
                                      const SizedBox(height: 16),
                                  ],
                              ),
                            ),
                        ),
                    ],
                ),
                      ),
                  ),

                  // Floating Close Icon (Premium Navigation)
                  Positioned(
                    top: 20,
                    right: 20,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
          );
  }
  Widget _buildGuestBanner() {
      return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppTheme.secondaryBrand.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.secondaryBrand.withOpacity(0.3))
          ),
          child: Row(
              children: [
                  const Icon(Icons.person_outline, color: AppTheme.secondaryBrand, size: 30),
                  const SizedBox(width: 16),
                  const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text("Explorando como invitado 👀", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                              SizedBox(height: 4),
                              Text("Regístrate para guardar tus favoritos y crear tus vacas.", style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                      )
                  ),
                  TextButton(
                      onPressed: () => context.push('/register'),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.secondaryBrand),
                      child: const Text("Registrarme", style: TextStyle(fontWeight: FontWeight.bold)),
                  )
              ],
          ),
      );
  }

  Widget _buildCompleteProfileBanner() {
    // ... logic omitted ...
    return Container(); // Placeholder or actual logic
  }

  Widget _buildPendingInvites() {
      return Column(
          children: _dbPendingInvites.map((invite) {
              final plan = invite['plans'] as Map<String,dynamic>?;
              final title = plan?['title'] ?? 'Plan en Planmapp';
              final pid = invite['plan_id'];

              return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppTheme.primaryBrand, AppTheme.secondaryBrand]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: AppTheme.primaryBrand.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
                  ),
                  child: Row(
                      children: [
                          Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.mail_outline_rounded, color: Colors.white)
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      const Text("¡Tienes una invitación!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text("Te invitaron a '$title'", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13), maxLines: 1),
                                  ],
                              )
                          ),
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppTheme.primaryBrand,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                              ),
                              onPressed: () {
                                  setState(() {
                                      _dbPendingInvites.removeWhere((i) => i['plan_id'] == pid);
                                  });
                                  context.push('/invite/$pid');
                              },
                              child: const Text("Ver", style: TextStyle(fontWeight: FontWeight.bold))
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                              onPressed: () async {
                                  // Update UI immediately
                                  setState(() {
                                      _dbPendingInvites.removeWhere((i) => i['plan_id'] == pid);
                                  });
                                  
                                  // Update backend
                                  final user = Supabase.instance.client.auth.currentUser;
                                  if (user != null) {
                                      try {
                                          await Supabase.instance.client
                                              .from('plan_members')
                                              .update({'status': 'declined'})
                                              .eq('plan_id', pid)
                                              .eq('user_id', user.id);
                                      } catch (e) {
                                          debugPrint("Error dismissing invite: $e");
                                      }
                                  }
                              }, 
                              icon: const Icon(Icons.close, color: Colors.white),
                              tooltip: "Ocultar",
                          )
                      ],
                  ),
              ).animate().fade().slideY(begin: 0.1, end: 0);
          }).toList()
      );
  }

  // Static version of the helper for state management if needed or just use consistent logic
  static (IconData, Color) _getPromoBadgeInfo_Static(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('%') || lower.contains('dcto') || lower.contains('off') || lower.contains('descuento')) {
      return (Icons.local_offer_rounded, Colors.redAccent);
    }
    if (lower.contains('2x1') || lower.contains('3x2') || lower.contains('combo') || lower.contains('paga 1')) {
      return (Icons.people_alt_rounded, Colors.orangeAccent);
    }
    if (lower.contains('happy') || lower.contains('copa') || lower.contains('cóctel') || lower.contains('bar')) {
      return (Icons.local_bar_rounded, Colors.purpleAccent);
    }
    if (lower.contains('gratis') || lower.contains('free') || lower.contains('regalo') || lower.contains('cortesía')) {
      return (Icons.card_giftcard_rounded, Colors.greenAccent);
    }
    return (Icons.flash_on_rounded, AppTheme.primaryBrand);
  }
}

class _AnimatedPlanCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final Event event;
  final bool isRecommended;
  final VoidCallback onTap;

  const _AnimatedPlanCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.event,
    this.isRecommended = false,
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
                    imageUrl: widget.imageUrl, 
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

                  // Premium Badges (Price & Status) - TOP LEFT
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.event.priceLevel != null)
                          _buildPremiumGlassBadge(widget.event.priceLevel!, Icons.payments_outlined, Colors.black.withOpacity(0.3)),
                        const SizedBox(height: 8),
                        if (widget.event.isOpen != null)
                          _buildPremiumGlassBadge(
                            widget.event.isOpen! ? "Abierto" : "Cerrado", 
                            widget.event.isOpen! ? Icons.fiber_manual_record : Icons.cancel, 
                            widget.event.isOpen! ? Colors.greenAccent.withOpacity(0.4) : Colors.redAccent.withOpacity(0.4)
                          ),
                        const SizedBox(height: 8),
                        if (widget.isRecommended)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppTheme.primaryBrand, AppTheme.primaryBrand.withOpacity(0.7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                 BoxShadow(color: AppTheme.primaryBrand.withOpacity(0.5), blurRadius: 8)
                              ],
                            ),
                            child: Row(
                              children: [
                                  const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    "RECOMENDADO PARA TI",
                                    style: TextStyle(
                                      color: Colors.white, 
                                      fontSize: 9, 
                                      fontWeight: FontWeight.w900, 
                                      letterSpacing: 0.5,
                                      shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 2)]
                                    ),
                                  ),
                                ],
                              ),
                            ).animate(onPlay: (ctrl) => ctrl.repeat())
                             .shimmer(duration: 2.seconds, delay: 15.seconds)
                             .scale(duration: 400.ms, curve: Curves.elasticOut, delay: 15.seconds),
                      ],
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
                      Row(
                          children: [
                              Flexible(child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1)),
                              if (widget.event.isVerified) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.verified, color: Colors.blue, size: 20),
                              ]
                          ],
                      ),
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
                ),
                
                // NEW: Creative Promo Badge on Card
                if (widget.event.promoHighlights != null && widget.event.promoHighlights!.isNotEmpty)
                  Builder(
                    builder: (context) {
                      final (icon, color) = _getPromoBadgeInfo(widget.event.promoHighlights!);
                      return Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4),
                              BoxShadow(color: color.withOpacity(0.5), blurRadius: 10, spreadRadius: -2)
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                widget.event.promoHighlights!.toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                            ],
                          ).animate().shimmer(duration: 2.seconds, color: Colors.white.withOpacity(0.3)),
                        ).animate().scale(delay: 400.ms, duration: 400.ms, curve: Curves.elasticOut),
                      );
                    }
                  ),
                
                
                // (Moved Recommended badge to top-left Column)
               ]
            ),
          ),
        ),
      ),
    );
  }
  (IconData, Color) _getPromoBadgeInfo(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('%') || lower.contains('dcto') || lower.contains('off') || lower.contains('descuento')) {
      return (Icons.percent_rounded, Colors.redAccent);
    }
    if (lower.contains('2x1') || lower.contains('3x2') || lower.contains('combo') || lower.contains('paga 1')) {
      return (Icons.style_rounded, Colors.orangeAccent);
    }
    if (lower.contains('happy') || lower.contains('copa') || lower.contains('cóctel') || lower.contains('bar') || lower.contains('trago')) {
      return (Icons.local_bar_rounded, Colors.purpleAccent);
    }
    if (lower.contains('gratis') || lower.contains('free') || lower.contains('regalo') || lower.contains('cortesía') || lower.contains('\$0')) {
      return (Icons.confirmation_num_rounded, Colors.greenAccent);
    }
    if (lower.contains('almuerzo') || lower.contains('brunch') || lower.contains('menú') || lower.contains('desayuno')) {
      return (Icons.restaurant_menu_rounded, Colors.blueAccent);
    }
    return (Icons.flash_on_rounded, AppTheme.primaryBrand);
  }

  Widget _buildPremiumGlassBadge(String text, IconData icon, Color baseColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: baseColor.withOpacity(0.2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: icon == Icons.fiber_manual_record ? Colors.greenAccent : Colors.white),
              const SizedBox(width: 4),
              Text(
                text, 
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _FilterHeaderDelegate({required this.child});
  
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
     return child;
  }
  
  @override
  double get maxExtent => 56.0;
  
  @override
  double get minExtent => 56.0;
  
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}
