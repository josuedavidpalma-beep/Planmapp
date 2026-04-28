import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../b2b/presentation/screens/restaurant_insights_screen.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  int _currentIndex = 0;
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text("Planmapp Super-Admin", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _AdminRestaurantsTab(),
          _AdminQRTab(),
          _AdminAnalyticsTab(),
          _AdminCuraduriaTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: AppTheme.primaryBrand,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Restaurantes'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'QRs'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Métricas'),
          BottomNavigationBarItem(icon: Icon(Icons.playlist_add_check), label: 'Curaduría'),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 1. RESTAURANTS TAB (CRUD)
// ------------------------------------------------------------
class _AdminRestaurantsTab extends StatefulWidget {
  const _AdminRestaurantsTab();
  @override
  State<_AdminRestaurantsTab> createState() => _AdminRestaurantsTabState();
}

class _AdminRestaurantsTabState extends State<_AdminRestaurantsTab> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _restaurants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    setState(() => _isLoading = true);
    final res = await _supabase.from('restaurants').select().order('created_at');
    setState(() {
      _restaurants = res;
      _isLoading = false;
    });
  }

  void _addRestaurant() async {
    String name = '';
    String tier = 'basic';
    
    await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
      title: const Text("Nuevo Restaurante"),
      content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
              TextField(onChanged: (v) => name = v, decoration: const InputDecoration(hintText: "Nombre")),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                  value: tier,
                  decoration: const InputDecoration(labelText: "Nivel de Suscripción"),
                  items: const [
                      DropdownMenuItem(value: 'basic', child: Text("Básico")),
                      DropdownMenuItem(value: 'premium', child: Text("Premium")),
                      DropdownMenuItem(value: 'gold', child: Text("Gold")),
                      DropdownMenuItem(value: 'custom', child: Text("Personalizado")),
                  ],
                  onChanged: (v) => setSt(() => tier = v!),
              )
          ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancelar")),
        ElevatedButton(onPressed: () async {
          if (name.isNotEmpty) {
            await _supabase.from('restaurants').insert({'name': name, 'tier': tier});
            Navigator.pop(c);
            _loadRestaurants();
          }
        }, child: const Text("Crear"))
      ],
    )));
  }

  Future<void> _copyB2BLink(Map<String, dynamic> r) async {
    final resId = r['id'];
    try {
        var tokenRes = await _supabase.from('restaurant_tokens').select('token_hash').eq('restaurant_id', resId).maybeSingle();
        if (tokenRes == null) {
             tokenRes = await _supabase.from('restaurant_tokens').insert({'restaurant_id': resId}).select('token_hash').single();
        }
        final token = tokenRes['token_hash'];
        final link = 'https://planmapp.app/#/b2b/$token';
        
        await Clipboard.setData(ClipboardData(text: link));
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text("¡Copiado! Enlace con Hash: $token"),
                backgroundColor: Colors.green,
            ));
        }
    } catch(e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _restaurants.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton.icon(
              onPressed: _addRestaurant,
              icon: const Icon(Icons.add),
              label: const Text("Añadir Restaurante", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.black, padding: const EdgeInsets.all(16)),
            ),
          );
        }
        final r = _restaurants[index - 1];
        return Card(
          color: AppTheme.surfaceDark,
          child: ListTile(
            leading: IconButton(
                icon: const Icon(Icons.settings, color: Colors.blue),
                onPressed: () async {
                    String currentJson = "{}";
                    String currentTier = r['tier'] ?? 'basic';
                    String mapsUrl = r['maps_url'] ?? r['google_maps_url'] ?? '';
                    String googlePlaceId = r['google_place_id'] ?? '';
                    bool isVerified = r['is_verified'] ?? false;
                    bool isFeatured = r['is_featured'] ?? false;
                    String whatsappLink = r['whatsapp_link'] ?? '';
                    String promoText = r['promo_text'] ?? '';
                    String logoUrl = r['logo_url'] ?? '';
                    String ownerEmail = r['owner_email'] ?? '';
                    String currentPin = '';
                    
                    try {
                        var tokenRes = await _supabase.from('restaurant_tokens').select('access_pin').eq('restaurant_id', r['id']).maybeSingle();
                        if (tokenRes == null) {
                             tokenRes = await _supabase.from('restaurant_tokens').insert({'restaurant_id': r['id']}).select('access_pin').single();
                        }
                        currentPin = tokenRes['access_pin'] ?? '';
                    } catch(_) {}
                    
                    try {
                        currentJson = jsonEncode(r['survey_settings'] ?? {"questions": []});
                    } catch(_) {}
                    
                    final ctrl = TextEditingController(text: currentJson);
                    final mapsCtrl = TextEditingController(text: mapsUrl);
                    final pinCtrl = TextEditingController(text: currentPin);
                    final placeIdCtrl = TextEditingController(text: googlePlaceId);
                    final waCtrl = TextEditingController(text: whatsappLink);
                    final promoCtrl = TextEditingController(text: promoText);
                    final logoCtrl = TextEditingController(text: logoUrl);
                    final ownerEmailCtrl = TextEditingController(text: ownerEmail);
                    
                    final save = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
                        title: const Text("Ajustes del Comercio B2B"),
                        content: SizedBox(
                            width: double.maxFinite,
                            child: SingleChildScrollView(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        DropdownButtonFormField<String>(
                                            value: currentTier,
                                            decoration: const InputDecoration(labelText: "Suscripción B2B (Tier)"),
                                            items: const [
                                                DropdownMenuItem(value: 'basic', child: Text("Básico")),
                                                DropdownMenuItem(value: 'premium', child: Text("Premium")),
                                                DropdownMenuItem(value: 'gold', child: Text("Gold")),
                                                DropdownMenuItem(value: 'custom', child: Text("A la Carta (Personalizado)")),
                                            ],
                                            onChanged: (v) => setSt(() => currentTier = v!),
                                        ),
                                        const Divider(height: 30),
                                        const Text("Personalidad de Marca", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBrand)),
                                        TextField(
                                            controller: logoCtrl,
                                            decoration: const InputDecoration(labelText: "URL del Logo (Opcional)"),
                                        ),
                                        const Divider(height: 30),
                                        const Text("Integración Explorar", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBrand)),
                                        TextField(
                                            controller: placeIdCtrl,
                                            decoration: const InputDecoration(labelText: "Google Place ID (Obligatorio para Feed)"),
                                        ),
                                        SwitchListTile(
                                            title: const Text("Perfil Verificado"),
                                            value: isVerified,
                                            onChanged: (v) => setSt(() => isVerified = v),
                                        ),
                                        SwitchListTile(
                                            title: const Text("Destacado (Posición Top)"),
                                            value: isFeatured,
                                            onChanged: (v) => setSt(() => isFeatured = v),
                                        ),
                                        TextField(
                                            controller: waCtrl,
                                            decoration: const InputDecoration(labelText: "Link WhatsApp (Ej: https://wa.me/...)"),
                                        ),
                                        TextField(
                                            controller: promoCtrl,
                                            decoration: const InputDecoration(labelText: "Texto Promo (Ej: 2x1 Cócteles)"),
                                        ),
                                        const Divider(height: 30),
                                        const Text("Dashboard & Alertas", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryBrand)),
                                        TextField(
                                            controller: ownerEmailCtrl,
                                            decoration: const InputDecoration(labelText: "Correo del Dueño (Para Alertas de 1-2 estrellas)"),
                                        ),
                                        const SizedBox(height: 16),
                                        TextField(
                                            controller: mapsCtrl,
                                            decoration: const InputDecoration(labelText: "Google Maps URL (Para Cosechador)"),
                                        ),
                                        const SizedBox(height: 16),
                                        TextField(
                                            controller: pinCtrl,
                                            decoration: const InputDecoration(labelText: "PIN de Acceso (B2B Dashboard)"),
                                        ),
                                    ]
                                )
                            ),
                        ),
                        actions: [
                           TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancelar")),
                           ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text("Guardar"))
                        ]
                    )));
                    
                    if (save == true) {
                        try {
                            final decoded = currentJson.isNotEmpty ? jsonDecode(ctrl.text) : {};
                            await _supabase.from('restaurants').update({
                                'survey_settings': decoded,
                                'google_maps_url': mapsCtrl.text,
                                'tier': currentTier,
                                'google_place_id': placeIdCtrl.text.isEmpty ? null : placeIdCtrl.text,
                                'is_verified': isVerified,
                                'is_featured': isFeatured,
                                'whatsapp_link': waCtrl.text,
                                'promo_text': promoCtrl.text,
                                'logo_url': logoCtrl.text.isEmpty ? null : logoCtrl.text,
                                'owner_email': ownerEmailCtrl.text.isEmpty ? null : ownerEmailCtrl.text,
                            }).eq('id', r['id']);
                            
                            if (pinCtrl.text != currentPin) {
                                await _supabase.from('restaurant_tokens')
                                  .update({'access_pin': pinCtrl.text.isEmpty ? null : pinCtrl.text})
                                  .eq('restaurant_id', r['id']);
                            }
                            
                            _loadRestaurants();
                        } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("JSON Invalido: $e")));
                        }
                    }
                }
            ),
            title: Text(r['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text("Tier: ${r['tier']?.toString().toUpperCase() ?? 'BASIC'} | ID: ${r['id']}", style: const TextStyle(color: Colors.white54, fontSize: 11)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.analytics, color: Colors.greenAccent),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RestaurantInsightsScreen(token: r['id'])));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.link, color: Colors.blueAccent),
                  onPressed: () => _copyB2BLink(r),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () async {
                    await _supabase.from('restaurants').delete().eq('id', r['id']);
                    _loadRestaurants();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------
// 2. GENERADOR QR TAB
// ------------------------------------------------------------
class _AdminQRTab extends StatefulWidget {
  const _AdminQRTab();
  @override
  State<_AdminQRTab> createState() => _AdminQRTabState();
}

class _AdminQRTabState extends State<_AdminQRTab> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _restaurants = [];
  String? _selectedResId;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    final res = await _supabase.from('restaurants').select();
    if (mounted) setState(() => _restaurants = res);
  }

  @override
  Widget build(BuildContext context) {
    String qrData = '';
    if (_selectedResId != null) {
      // Usamos planmapp.app/#/scan porque tu web utiliza Hash-Routing
      qrData = 'https://planmapp.app/#/scan?rid=$_selectedResId';
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Generador de QR por Local", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            dropdownColor: AppTheme.surfaceDark,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: "Selecciona Restaurante", filled: true, fillColor: AppTheme.surfaceDark),
            items: _restaurants.map<DropdownMenuItem<String>>((r) => DropdownMenuItem(value: r['id'], child: Text(r['name']))).toList(),
            onChanged: (v) => setState(() => _selectedResId = v),
          ),
          const SizedBox(height: 40),
          if (_selectedResId != null) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                  foregroundColor: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(qrData, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                Share.share(
                  "🔥 Hey! Abre tu cuenta temporal en nuestra mesa y divide la cuenta sin instalar la app: $qrData",
                  subject: "Paga fácil en Planmapp",
                );
              },
              icon: const Icon(Icons.share),
              label: const Text("Compartir URL a WhatsApp", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.black, padding: const EdgeInsets.all(16)),
            )
          ]
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 3. ANALÍTICAS TAB
// ------------------------------------------------------------
class _AdminAnalyticsTab extends StatefulWidget {
  const _AdminAnalyticsTab();
  @override
  State<_AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

class _AdminAnalyticsTabState extends State<_AdminAnalyticsTab> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  DateTimeRange? _dateRange;

  // KPIs
  int _totalUsers = 0;
  int _qrUsers = 0;
  int _totalPlans = 0;
  int _abandonedPlans = 0;
  int _aiPlans = 0;
  int _totalSurveys = 0;
  double _totalRevenueB2B = 0; // Simulated using Tiers

  @override
  void initState() {
    super.initState();
    // Default to last 30 days
    _dateRange = DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now());
    _loadMectrics();
  }

  Future<void> _loadMectrics() async {
    setState(() => _isLoading = true);
    try {
      final startIso = _dateRange?.start.toIso8601String() ?? DateTime(2000).toIso8601String();
      final endIso = _dateRange?.end.add(const Duration(days: 1)).toIso8601String() ?? DateTime.now().toIso8601String();

      List<dynamic> usersReq = [];
      try {
          usersReq = await _supabase.from('profiles').select('created_at, origin').gte('created_at', startIso).lte('created_at', endIso);
      } catch (e) {
          print("Profiles fetch error: $e");
          // Fallback without created_at filter if it fails
          try {
             usersReq = await _supabase.from('profiles').select('origin');
          } catch(e2) { print("Profiles fallback error: $e2"); }
      }

      List<dynamic> plansReq = [];
      try {
          plansReq = await _supabase.from('plans').select('created_at, status, plan_type').gte('created_at', startIso).lte('created_at', endIso);
      } catch (e) {
          print("Plans fetch error: $e");
          try {
             plansReq = await _supabase.from('plans').select('status, plan_type');
          } catch(e2) {}
      }

      List<dynamic> surveyReq = [];
      try {
          surveyReq = await _supabase.from('survey_responses').select('id, created_at').gte('created_at', startIso).lte('created_at', endIso);
      } catch (e) {
          print("Surveys fetch error: $e");
          try {
             surveyReq = await _supabase.from('survey_responses').select('id');
          } catch(e2) {}
      }

      List<dynamic> restReq = [];
      try {
          restReq = await _supabase.from('restaurants').select('created_at, tier'); 
      } catch (e) {
          print("Restaurants fetch error: $e");
          try {
             restReq = await _supabase.from('restaurants').select('tier');
          } catch(e2) {}
      }

      final now = DateTime.now();

      int qrU = 0;
      for (var u in usersReq) {
          if (u['origin'] == 'qr') qrU++;
      }

      int abPlans = 0;
      int aiP = 0;
      for (var p in plansReq) {
          if (p['plan_type'] == 'ai_suggestion') aiP++;
          
          if (p['status'] == 'draft') {
              if (p['created_at'] != null) {
                  try {
                      final created = DateTime.parse(p['created_at'].toString());
                      if (now.difference(created).inHours > 48) {
                          abPlans++;
                      }
                  } catch(_) {}
              } else {
                  abPlans++; // Assume abandoned if no date
              }
          }
      }

      double rev = 0;
      for (var r in restReq) {
          final t = r['tier'] ?? 'basic';
          if (t == 'gold') rev += 299000;
          else if (t == 'premium') rev += 149000;
          else if (t == 'basic') rev += 49000;
      }

      if (mounted) {
          setState(() {
              _totalUsers = usersReq.length;
              _qrUsers = qrU;
              _totalPlans = plansReq.length;
              _abandonedPlans = abPlans;
              _aiPlans = aiP;
              _totalSurveys = surveyReq.length;
              _totalRevenueB2B = rev;
              _isLoading = false;
          });
      }

    } catch (e) {
      print('SuperAdmin Dashboard Error: $e');
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error cargando métricas: $e")));
          setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDateRange() async {
      final res = await showDateRangePicker(
          context: context,
          initialDateRange: _dateRange,
          firstDate: DateTime(2023),
          lastDate: DateTime.now(),
          builder: (context, child) => Theme(
              data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(primary: AppTheme.primaryBrand, onPrimary: Colors.black, surface: AppTheme.surfaceDark)
              ),
              child: child!,
          )
      );
      if (res != null) {
          setState(() => _dateRange = res);
          _loadMectrics();
      }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                  const Text("Analíticas Globales", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                      onPressed: _pickDateRange, 
                      icon: const Icon(Icons.date_range, color: AppTheme.primaryBrand), 
                      label: Text(
                          _dateRange != null ? "${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}" : "Filtro Global",
                          style: const TextStyle(color: AppTheme.primaryBrand)
                      )
                  )
              ]
          ),
          const SizedBox(height: 24),
          if (_isLoading) 
              const Center(child: CircularProgressIndicator())
          else
              Expanded(
                  child: SingleChildScrollView(
                      child: Column(
                          children: [
                              GridView.count(
                                  crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 1.2,
                                  children: [
                                      _StatCard(title: "Nuevos Usuarios", value: _totalUsers.toString(), subtitle: "$_qrUsers entraron por QR", icon: Icons.people, color: Colors.blue),
                                      _StatCard(title: "Planes Creados", value: _totalPlans.toString(), subtitle: "$_aiPlans sugeridos por IA", icon: Icons.rocket_launch, color: Colors.purple),
                                      _StatCard(title: "Planes Abandonados", value: _abandonedPlans.toString(), subtitle: "Drafts > 48h", icon: Icons.warning_amber_rounded, color: Colors.orange),
                                      _StatCard(title: "Encuestas B2B", value: _totalSurveys.toString(), subtitle: "Tickets escaneados", icon: Icons.receipt_long, color: Colors.green),
                                      _StatCard(title: "MRR Estimado (B2B)", value: "\$${(_totalRevenueB2B/1000).toStringAsFixed(1)}k", subtitle: "Suscripciones Activas", icon: Icons.monetization_on, color: Colors.amber),
                                  ],
                              )
                          ],
                      )
                  )
              )
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
    final String title;
    final String value;
    final String subtitle;
    final IconData icon;
    final Color color;

    const _StatCard({required this.title, required this.value, required this.subtitle, required this.icon, required this.color});

    @override
    Widget build(BuildContext context) {
        return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.3))
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    Icon(icon, color: color, size: 28),
                    const Spacer(),
                    Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
                ]
            )
        );
    }
}

class _AdminCuraduriaTab extends StatefulWidget {
  const _AdminCuraduriaTab();
  @override
  State<_AdminCuraduriaTab> createState() => _AdminCuraduriaTabState();
}

class _AdminCuraduriaTabState extends State<_AdminCuraduriaTab> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _pendingEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingEvents();
  }

  Future<void> _loadPendingEvents() async {
    setState(() => _isLoading = true);
    final res = await _supabase.from('local_events').select().eq('status', 'pending').order('created_at', ascending: false);
    setState(() {
      _pendingEvents = res;
      _isLoading = false;
    });
  }

  Future<void> _approveEvent(String id) async {
    await _supabase.from('local_events').update({'status': 'active'}).eq('id', id);
    _loadPendingEvents();
  }

  Future<void> _rejectEvent(String id) async {
    await _supabase.from('local_events').delete().eq('id', id);
    _loadPendingEvents();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_pendingEvents.isEmpty) {
        return const Center(child: Text('No hay eventos pendientes por revisar.', style: TextStyle(color: Colors.white70)));
    }
    return ListView.builder(
      itemCount: _pendingEvents.length,
      itemBuilder: (ctx, i) {
        final ev = _pendingEvents[i];
        return Card(
          color: Colors.white10,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: ev['image_url'] != null ? Image.network(ev['image_url'], width: 50, height: 50, fit: BoxFit.cover) : const Icon(Icons.event),
            title: Text(ev['event_name'] ?? 'Sin título', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text('Lugar: ${ev["location"] ?? "Desconocido"} • Fecha: ${ev["date"] ?? "N/A"}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    if (ev['source_url'] != null)
                      Text('Origen: ${ev["source_url"]}', style: const TextStyle(color: AppTheme.primaryBrand, fontSize: 10)),
                ]
            ),
            trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                    IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _rejectEvent(ev['id'].toString())),
                    IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _approveEvent(ev['id'].toString())),
                ]
            ),
          )
        );
      }
    );
  }
}

