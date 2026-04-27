import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
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
                    String mapsUrl = r['maps_url'] ?? '';
                    
                    try {
                        currentJson = jsonEncode(r['survey_settings'] ?? {"questions": []});
                    } catch(_) {}
                    
                    final ctrl = TextEditingController(text: currentJson);
                    final mapsCtrl = TextEditingController(text: mapsUrl);
                    
                    final save = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
                        title: const Text("Ajustes del Comercio"),
                        content: SingleChildScrollView(
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
                                    const SizedBox(height: 16),
                                    TextField(
                                        controller: mapsCtrl,
                                        decoration: const InputDecoration(labelText: "Google Maps URL", hintText: "https://g.page/..."),
                                    ),
                                    const SizedBox(height: 16),
                                    TextField(
                                        controller: ctrl,
                                        maxLines: 4,
                                        decoration: const InputDecoration(labelText: "JSON Encuesta (Fase 2)"),
                                    ),
                                ]
                            )
                        ),
                        actions: [
                           TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancelar")),
                           ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text("Guardar"))
                        ]
                    )));
                    
                    if (save == true) {
                        try {
                            final decoded = jsonDecode(ctrl.text);
                            await _supabase.from('restaurants').update({
                                'survey_settings': decoded,
                                'maps_url': mapsCtrl.text,
                                'tier': currentTier
                            }).eq('id', r['id']);
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
  int _totalEncuestas = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMectrics();
  }

  Future<void> _loadMectrics() async {
    try {
      final res = await _supabase.from('survey_responses').select('id');
      setState(() {
        _totalEncuestas = res.length;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Analíticas Globales", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Card(
            color: AppTheme.surfaceDark,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                   const Icon(Icons.insert_chart, size: 50, color: AppTheme.primaryBrand),
                   const SizedBox(height: 12),
                   Text("$_totalEncuestas", style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                   const Text("Encuestas Recolectadas", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
