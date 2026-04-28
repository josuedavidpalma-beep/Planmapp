import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/theme/app_theme.dart';

class RestaurantInsightsScreen extends StatefulWidget {
  final String token; // Can be a token hash or a restaurant_id
  const RestaurantInsightsScreen({Key? key, required this.token}) : super(key: key);

  @override
  State<RestaurantInsightsScreen> createState() => _RestaurantInsightsScreenState();
}

class _RestaurantInsightsScreenState extends State<RestaurantInsightsScreen> {
  bool _isLoading = true;
  String? _errorMsg;
  
  Map<String, dynamic> _restData = {};
  List<Map<String, dynamic>> _responses = [];
  
  double _avgFood = 0.0;
  double _avgService = 0.0;
  double _avgAmbiance = 0.0;
  double _avgGeneral = 0.0;
  double _avgTicket = 0.0;
  int _totalSurveys = 0;
  
  int _npsScore = 0;
  int _promoters = 0;
  int _passives = 0;
  int _detractors = 0;
  
  List<Map<String, dynamic>> _topDishes = [];
  List<Map<String, dynamic>> _menuMatrix = []; // Quadrants Data
  List<Map<String, dynamic>> _whales = [];
  final TextEditingController _validationCtrl = TextEditingController();
  bool _isValidating = false;
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  String? _aiRecommendation;
  bool _isGeneratingAi = false;
  
  bool _isAuthenticated = false;
  String? _expectedPin;
  final TextEditingController _pinCtrl = TextEditingController();
  bool _isPinError = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final supabase = Supabase.instance.client;
      // 1. Verify token or ID
      String? resId;
      final tokenRes = await supabase.from('restaurant_tokens').select('restaurant_id, access_pin').eq('token_hash', widget.token).maybeSingle();
      if (tokenRes != null) {
          resId = tokenRes['restaurant_id'];
          _expectedPin = tokenRes['access_pin'];
      } else {
          // Assume the token passed might be the restaurant UUID directly (Admin View)
          final checkRes = await supabase.from('restaurants').select('id').eq('id', widget.token).maybeSingle();
          if (checkRes != null) {
              resId = checkRes['id'];
              _isAuthenticated = true; // Admin bypass
          }
      }
      
      if (resId == null) {
          setState(() { _errorMsg = "Enlace inválido o expirado."; _isLoading = false; });
          return;
      }
      
      if (!_isAuthenticated && _expectedPin != null && _expectedPin!.isNotEmpty) {
          setState(() { _isLoading = false; });
          return;
      } else {
          _isAuthenticated = true;
      }
      
      // 2. Load restaurant info
      final restInfo = await supabase.from('restaurants').select('name, tier, features, logo_url').eq('id', resId).maybeSingle();
      
      // 3. Load past X days surveys based on filters
      final surveysRes = await supabase.from('survey_responses').select()
          .eq('restaurant_id', resId)
          .gte('created_at', _startDate.toIso8601String())
          .lte('created_at', _endDate.add(const Duration(days: 1)).toIso8601String()); // Include the whole end day
      final List<Map<String, dynamic>> rawResponses = List<Map<String, dynamic>>.from(surveysRes);
      
      _totalSurveys = rawResponses.length;
      
      double totalFood = 0;
      double totalService = 0;
      double totalAmbiance = 0;
      int countKpi = 0;
      
      double totalSpend = 0;
      int spendTxs = 0;
      
      Map<String, int> dishCounts = {};
      Map<String, double> dishTotalRatings = {};
      List<Map<String, dynamic>> whales = [];
      
      _promoters = 0;
      _passives = 0;
      _detractors = 0;
      
      for (var s in rawResponses) {
          final f = s['rating_food'] as int?;
          final sr = s['rating_service'] as int?;
          final a = s['rating_ambiance'] as int?;
          if (f != null && sr != null && a != null) {
              totalFood += f;
              totalService += sr;
              totalAmbiance += a;
              countKpi++;
              
              double localAvg = (f+sr+a)/3;
              if (localAvg >= 4.5) { _promoters++; } 
              else if (localAvg >= 4.0) { _passives++; } 
              else { _detractors++; }
              
              // Process ALL dishes for Menu Engineering Matrix
              if (s['receipt_items'] != null) {
                  final items = List<Map<String, dynamic>>.from(s['receipt_items']);
                  for (var it in items) {
                      final n = it['name'] as String;
                      dishCounts[n] = (dishCounts[n] ?? 0) + 1;
                      dishTotalRatings[n] = (dishTotalRatings[n] ?? 0.0) + (f);
                  }
              }
              
          double ticket = 0;
          if (s['responses'] != null && s['responses']['ai_raw_total'] != null) {
              double? aiTotal = double.tryParse(s['responses']['ai_raw_total'].toString());
              if (aiTotal != null && aiTotal > 0) {
                  ticket = aiTotal;
              }
          } 
          
          if (ticket == 0 && s['receipt_items'] != null) {
              final items = List<Map<String, dynamic>>.from(s['receipt_items']);
              for (var it in items) {
                  ticket += double.tryParse(it['price'].toString()) ?? 0;
              }
          }
          
          if (ticket > 0) {
                 totalSpend += ticket;
                 spendTxs++;
                 
                 // Try to record a whale mapping
                 if (s['user_id'] != null && s['user_id'].toString().isNotEmpty) {
                     whales.add({'user_id': s['user_id'], 'user_name': s['user_name'] ?? 'Usuario invitado', 'ticket': ticket, 'date': s['created_at']});
                 }
              }
          }
      }
      
      if (countKpi > 0) {
          _avgFood = totalFood / countKpi;
          _avgService = totalService / countKpi;
          _avgAmbiance = totalAmbiance / countKpi;
          _avgGeneral = (_avgFood + _avgService + _avgAmbiance) / 3;
          _npsScore = ((_promoters - _detractors) / countKpi * 100).round();
      }
      if (spendTxs > 0) {
          _avgTicket = totalSpend / spendTxs;
      }
      
      var sortedDishes = dishCounts.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
      _topDishes = sortedDishes.take(5).map((e) => {"name": e.key, "hits": e.value}).toList();
      
      // Calculate Menu Engineering Matrix
      if (dishCounts.isNotEmpty) {
          final sortedHits = dishCounts.values.toList()..sort();
          final medianHits = sortedHits[sortedHits.length ~/ 2];
          
          List<double> avgRatings = dishCounts.keys.map((k) => dishTotalRatings[k]! / dishCounts[k]!).toList()..sort();
          final medianRating = avgRatings[avgRatings.length ~/ 2];
          
          _menuMatrix = dishCounts.keys.map((k) {
              final hits = dishCounts[k]!;
              final avgR = dishTotalRatings[k]! / hits;
              
              String type;
              if (hits >= medianHits && avgR >= medianRating) type = "Estrella";
              else if (hits >= medianHits && avgR < medianRating) type = "Caballito";
              else if (hits < medianHits && avgR >= medianRating) type = "Rompecabezas";
              else type = "Perro";
              
              return { "name": k, "hits": hits, "rating": avgR, "type": type };
          }).toList();
          _menuMatrix.sort((a,b) => b['hits'].compareTo(a['hits']));
      } else {
          _menuMatrix = [];
      }
      
      whales.sort((a,b) => b['ticket'].compareTo(a['ticket']));
      _whales = whales.take(5).toList();
      
      if (mounted) {
          setState(() {
              _restData = restInfo ?? {'name': 'Restaurante'};
              if (resId != null) _restData['id'] = resId; // Ensure id is accessible for rewards
              _responses = rawResponses;
              _aiRecommendation = null; // Reset recommendation when data changes
              _isLoading = false;
          });
      }
    } catch (e) {
        if (mounted) {
            setState(() { _errorMsg = e.toString(); _isLoading = false; });
        }
    }
  }

  Future<void> _toggleFeature(String featureKey) async {
      try {
          final features = Map<String, dynamic>.from(_restData['features'] ?? {
              'google_maps_reviews': false,
              'menu_engineering': false,
              'ai_insights': false,
              'advanced_nps': false,
              'date_filters': false
          });
          
          features[featureKey] = !(features[featureKey] == true);
          
          // Optimistic UI update
          setState(() {
              _restData['features'] = features;
          });
          
          final resId = _restData['id'];
          if (resId != null) {
              await Supabase.instance.client.from('restaurants').update({'features': features}).eq('id', resId);
          }
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al cambiar módulo: $e")));
          _fetchData(); // rollback UI on fail
      }
  }

  Future<void> _rewardUser(Map<String, dynamic> whale) async {
       final code = "GVP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
       try {
           final sup = Supabase.instance.client;
           String resId = _restData['id'] ?? widget.token; 
           
           await sup.from('restaurant_rewards').insert({
              'restaurant_id': resId,
              'user_id': whale['user_id'],
              'promo_code': code,
              'discount_percentage': 10,
              'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String()
           });
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cupón 10% ($code) enviado a ${whale['user_name']}", style: const TextStyle(color: Colors.green))));
       } catch(e) {
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error enviando: $e", style: const TextStyle(color: Colors.red))));
       }
  }

  Future<void> _validateCoupon() async {
      final code = _validationCtrl.text.trim();
      if (code.isEmpty) return;
      setState(() => _isValidating = true);
      try {
           final sup = Supabase.instance.client;
           final resId = _restData['id']; 
           final res = await sup.from('restaurant_rewards').select().eq('promo_code', code).eq('restaurant_id', resId).maybeSingle();
           
           if (res == null) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cupón no encontrado o inválido.")));
           } else if (res['is_redeemed'] == true) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Este cupón YA fue usado.", style: TextStyle(color: Colors.red))));
           } else if (DateTime.parse(res['expires_at']).isBefore(DateTime.now())) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cupón expirado.", style: TextStyle(color: Colors.red))));
           } else {
               await sup.from('restaurant_rewards').update({'is_redeemed': true}).eq('id', res['id']);
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡CUPÓN VÁLIDO! 10% de descuento aplicado y quemado.", style: TextStyle(color: Colors.green))));
           }
      } catch(e) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error validador: $e")));
      } finally {
           setState(() { _isValidating = false; _validationCtrl.clear(); });
      }
  }

  Future<void> _exportActiveCoupons() async {
       final buffer = StringBuffer();
       buffer.writeln("Codigo_Cupon,Descuento,Estado,Fecha_Expiracion");
       try {
           final base = Supabase.instance.client;
           final active = await base.from('restaurant_rewards').select().eq('restaurant_id', _restData['id'] ?? widget.token);
           for (var c in List<Map<String,dynamic>>.from(active)) {
               final state = c['is_redeemed'] == true ? "Usado" : (DateTime.parse(c['expires_at']).isBefore(DateTime.now()) ? "Expirado" : "Activo");
               buffer.writeln("${c['promo_code']},${c['discount_percentage']}%,$state,${c['expires_at'].toString().split('T').first}");
           }
           final bytes = utf8.encode(buffer.toString());
           final blob = Uri.dataFromBytes(bytes, mimeType: 'text/csv').toString();
           await launchUrl(Uri.parse(blob), mode: LaunchMode.externalApplication);
       } catch (e) {
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error exportando cupones: $e")));
       }
  }

  Future<void> _generateRecommendation() async {
      setState(() => _isGeneratingAi = true);
      try {
          const apiKey = String.fromEnvironment('GEMINI_API_KEY');
          if (apiKey.isEmpty) throw "Llave de API no configurada (GEMINI_API_KEY)";

          final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
          
          final feedBacks = _responses.map((s) => s['feedback_text']).where((t) => t != null && t.toString().trim().isNotEmpty).join(' | ');
          
          final prompt = '''
Eres un Analista de Inteligencia de Negocios (BI) experto en la industria gastronómica.
Genera una conclusión profesional y recomendaciones accionables en español (máximo 150 palabras) usando esta data del restaurante "${_restData['name']}" (Últimos ${_endDate.difference(_startDate).inDays} días):
- Calificación media: ${_avgGeneral.toStringAsFixed(1)} / 5.0
- Valor del ticket promedio: \$${_avgTicket.toStringAsFixed(0)}
- Cantidad de encuestas recibidas: $_totalSurveys
- Platos más repetidos en experiencias 5 estrellas: ${_topDishes.map((d) => d['name']).join(', ')}
- Reseñas de clientes leales: ${feedBacks.isEmpty ? 'Sin comentarios.' : feedBacks}

Dame el texto directo, sin saludo, estructurado en 2 o 3 viñetas ágiles con los "Insights" o conclusiones fuertes y luego una "Sugerencia Estratégica" clara y asertiva.
          ''';
          
          final response = await model.generateContent([Content.text(prompt)]);
          setState(() => _aiRecommendation = response.text);
      } catch (e) {
          setState(() => _aiRecommendation = "Error de IA: $e\n\nAsegúrate de que estás ejecutando la app con el entorno correcto (ej: --dart-define=GEMINI_API_KEY=tu_llave)");
      } finally {
          setState(() => _isGeneratingAi = false);
      }
  }

  Future<void> _pickDateRange() async {
      final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
          builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.dark(
                      primary: AppTheme.primaryBrand,
                      onPrimary: Colors.black,
                      surface: AppTheme.darkBackground,
                      onSurface: Colors.white,
                  ),
              ),
              child: child!,
          ),
      );
      if (picked != null) {
          setState(() {
              _startDate = picked.start;
              _endDate = picked.end;
              _isLoading = true;
          });
          _fetchData();
      }
  }

  Future<void> _exportCsv() async {
      final buffer = StringBuffer();
      buffer.writeln("Fecha,Ticket_Total,Comida,Servicio,Ambiente,Promedio,Comentario");
      for (var s in _responses) {
          final f = s['rating_food'] ?? 0;
          final sr = s['rating_service'] ?? 0;
          final a = s['rating_ambiance'] ?? 0;
          final avg = ((f+sr+a)/3).toStringAsFixed(1);
          double ticket = 0;
          if (s['receipt_items'] != null) {
              for (var it in List<Map<String, dynamic>>.from(s['receipt_items'])) {
                  ticket += double.tryParse(it['price'].toString()) ?? 0;
              }
          }
          final date = s['created_at'].toString().split('T').first;
          final comment = (s['feedback_text']?.toString() ?? '').replaceAll('"', '""').replaceAll('\n', ' ');
          buffer.writeln("$date,$ticket,$f,$sr,$a,$avg,\"$comment\"");
      }
      try {
          final bytes = utf8.encode(buffer.toString());
          final blob = Uri.dataFromBytes(bytes, mimeType: 'text/csv').toString();
          await launchUrl(Uri.parse(blob), mode: LaunchMode.externalApplication);
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error exportando: $e")));
      }
  }

  Future<void> _exportPDF() async {
      final doc = pw.Document();
      pw.ImageProvider? logoImage;
      if (_restData['logo_url'] != null && _restData['logo_url'].toString().isNotEmpty) {
          try {
              logoImage = await networkImage(_restData['logo_url']);
          } catch(e) { print("Error cargando logo PDF: $e"); }
      }

      doc.addPage(
         pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
               return [
                  pw.Header(
                     level: 0,
                     child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                           pw.Text("Reporte B2B: ${_restData['name']}", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                           if (logoImage != null) pw.Container(width: 50, height: 50, child: pw.Image(logoImage)),
                        ]
                     )
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text("Resumen de Desempeno", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Bullet(text: "NPS (Net Promoter Score): $_npsScore"),
                  pw.Bullet(text: "Total Encuestas: $_totalSurveys"),
                  pw.Bullet(text: "Ticket Promedio Estimado: \$${_avgTicket.toStringAsFixed(0)}"),
                  pw.Bullet(text: "Calificacion Promedio: ${_avgGeneral.toStringAsFixed(1)} / 5.0"),
                  pw.SizedBox(height: 20),
                  
                  if (_aiRecommendation != null) ...[
                     pw.Text("Recomendacion Estrategica IA", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                     pw.SizedBox(height: 10),
                     pw.Text(_aiRecommendation!),
                     pw.SizedBox(height: 20),
                  ],

                  pw.Text("Platos Estrella (Favoritos)", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  ..._topDishes.take(5).map((d) => pw.Bullet(text: d['name'])),
               ];
            }
         )
      );
      
      await Printing.sharePdf(bytes: await doc.save(), filename: 'Reporte_Planmapp_${_restData['name'].toString().replaceAll(" ", "_")}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
       return const Scaffold(backgroundColor: AppTheme.darkBackground, body: Center(child: CircularProgressIndicator()));
    }
    if (_errorMsg != null) {
       return Scaffold(backgroundColor: AppTheme.darkBackground, body: Center(child: Text(_errorMsg!, style: const TextStyle(color: Colors.red))));
    }

    if (!_isAuthenticated) {
        return Scaffold(
            backgroundColor: AppTheme.darkBackground,
            body: Center(
                child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                const Icon(Icons.lock_outline, size: 64, color: AppTheme.primaryBrand),
                                const SizedBox(height: 24),
                                const Text("Acceso Protegido", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                const Text("Ingresa el PIN provisto por el administrador para acceder a las métricas del restaurante.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                                const SizedBox(height: 32),
                                TextField(
                                    controller: _pinCtrl,
                                    obscureText: true,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                        hintText: "••••",
                                        hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
                                        filled: true,
                                        fillColor: AppTheme.surfaceDark,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                        errorText: _isPinError ? "PIN incorrecto" : null
                                    ),
                                    onChanged: (v) {
                                        if (v.length >= 4 && _expectedPin != null && v == _expectedPin) {
                                            setState(() { _isAuthenticated = true; _isLoading = true; });
                                            _fetchData();
                                        } else if (v.length >= 4) {
                                            setState(() => _isPinError = true);
                                        } else {
                                            if (_isPinError) setState(() => _isPinError = false);
                                        }
                                    },
                                    onSubmitted: (v) {
                                        if (v == _expectedPin) {
                                            setState(() { _isAuthenticated = true; _isLoading = true; });
                                            _fetchData();
                                        } else {
                                            setState(() => _isPinError = true);
                                        }
                                    },
                                ),
                                const SizedBox(height: 48),
                            ],
                        )
                    )
                )
            )
        );
    }

    AppBar buildAppBar() {
        return AppBar(
            backgroundColor: AppTheme.darkBackground,
            title: Row(
                children: [
                    if (_restData['logo_url'] != null && _restData['logo_url'].toString().isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: CircleAvatar(
                                backgroundImage: NetworkImage(_restData['logo_url']),
                                radius: 16,
                            ),
                        ),
                    Expanded(child: Text("Resumen: ${_restData['name'] ?? ''}", overflow: TextOverflow.ellipsis)),
                ]
            ),
            actions: [
                IconButton(
                    onPressed: _exportPDF, 
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                    tooltip: "Descargar PDF",
                ),
                TextButton.icon(
                    onPressed: _exportCsv, 
                    icon: const Icon(Icons.download, color: Colors.greenAccent), 
                    label: const Text("CSV", style: TextStyle(color: Colors.greenAccent))
                ),
            ],
        );
    }
    
    return Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: buildAppBar(),
        body: LayoutBuilder(builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 900;
            
            final String tier = _restData['tier']?.toString().toLowerCase() ?? 'basic';
            final Map<String, dynamic> featuresMap = _restData['features'] ?? {};
            final bool isSuperAdmin = Supabase.instance.client.auth.currentUser?.email == 'josuedavidpalma@gmail.com';

            bool hasFeature(String key, bool defPrem, bool defGold) {
                if (tier == 'gold') return true;
                if (tier == 'premium') return defPrem;
                if (tier == 'basic') return false;
                return featuresMap[key] == true;
            }

            bool hasDateFilters = hasFeature('date_filters', true, true);
            bool hasAdvNps = hasFeature('advanced_nps', true, true);
            bool hasMenuEng = hasFeature('menu_engineering', false, true);
            bool hasAi = hasFeature('ai_insights', false, true);

            Widget titleWithLock(String title, String featureKey, bool isEnabled) {
               if (!isSuperAdmin || tier != 'custom') {
                   return Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold));
               }
               return Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                       Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                       const SizedBox(width: 8),
                       IconButton(
                           padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                           icon: Icon(isEnabled ? Icons.lock_open : Icons.lock, color: isEnabled ? Colors.greenAccent : Colors.redAccent, size: 20),
                           onPressed: () => _toggleFeature(featureKey),
                       )
                   ]
               );
            }

            final metricsHeader = Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    titleWithLock(
                        !hasDateFilters ? "Métricas Acumuladas" : "Métricas (${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d').format(_endDate)})", 
                        'date_filters', 
                        hasDateFilters
                    ),
                    if (!hasDateFilters)
                        TextButton.icon(
                            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Módulo inactivo para este Comercio.", style: TextStyle(color: Colors.orange)))), 
                            icon: const Icon(Icons.lock, color: Colors.orange, size: 18), 
                            label: const Text("Filtrar", style: TextStyle(color: Colors.orange))
                        )
                    else
                        TextButton.icon(
                            onPressed: _pickDateRange, 
                            icon: const Icon(Icons.date_range, color: AppTheme.primaryBrand, size: 18), 
                            label: const Text("Filtrar", style: TextStyle(color: AppTheme.primaryBrand))
                        )
                ],
            );
            
            final npsColor = _npsScore > 50 ? Colors.green : (_npsScore > 0 ? Colors.orange : Colors.red);
            
            final topCardsRow1 = Row(
                children: [
                    Expanded(child: !hasAdvNps 
                        ? _kpiCard("NPS Completo", "🔒", Icons.lock, Colors.grey) 
                        : _kpiCard("NPS Score", "$_npsScore", Icons.speed, npsColor)),
                    const SizedBox(width: 10),
                    Expanded(child: _kpiCard("Satisfacción", "${_avgGeneral.toStringAsFixed(1)}/5", Icons.star, Colors.orange)),
                ]
            );
            
            final topCardsRow2 = Row(
                children: [
                    Expanded(child: !hasAdvNps
                        ? _kpiCard("Ticket Análisis", "🔒", Icons.lock, Colors.grey)
                        : _kpiCard("Ticket Promedio", "\$${(_avgTicket/1000).toStringAsFixed(1)}k", Icons.receipt, Colors.green)),
                    const SizedBox(width: 10),
                    Expanded(child: _kpiCard("Encuestas", "$_totalSurveys", Icons.analytics, Colors.blue)),
                ]
            );
            
            final chartsCol = Column(
               crossAxisAlignment: CrossAxisAlignment.stretch,
               children: [
                  const Text("Desglose de Calidad (Comida/Servicio/Ambiente)", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                      height: 200,
                      child: _responses.isEmpty ? const Center(child: Text("Sin datos suficientes", style: TextStyle(color: Colors.grey))) : _buildBarChart(),
                  ),
               ]
            );
            
            final topDishesCol = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    titleWithLock("Ingeniería de Menú", 'menu_engineering', hasMenuEng),
                    const SizedBox(height: 16),
                    if (!hasMenuEng)
                       Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(16)),
                            child: const Column(
                                children: [
                                    Icon(Icons.lock, color: Colors.grey, size: 40),
                                    SizedBox(height: 12),
                                    Text("Módulo Reservado", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                ]
                            )
                       )
                    else if (_menuMatrix.isEmpty)
                       const Text("Sin datos suficientes", style: TextStyle(color: Colors.grey))
                    else
                       SizedBox(
                           height: 350,
                           child: SingleChildScrollView(
                               child: GridView.builder(
                                   shrinkWrap: true,
                                   physics: const NeverScrollableScrollPhysics(),
                                   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                       crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5
                                   ),
                                   itemCount: _menuMatrix.length,
                                   itemBuilder: (ctx, i) {
                                       final d = _menuMatrix[i];
                                       return _MenuMatrixFlipCard(data: d);
                                   }
                               )
                           )
                       )
                ]
            );
            
            final aiCol = Column(
               crossAxisAlignment: CrossAxisAlignment.stretch,
               children: [
                  titleWithLock("AI Business Insights ✨", 'ai_insights', hasAi),
                  const SizedBox(height: 16),
                  hasAi 
                      ? _buildAIPanel()
                      : Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.amber.withOpacity(0.3))
                          ),
                          child: Column(
                              children: [
                                  const Icon(Icons.auto_awesome, color: Colors.amber, size: 40),
                                  const SizedBox(height: 12),
                                  const Text("Desbloquea el Asesor IA", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 8),
                                  const Text("La inteligencia artificial analizará todos los sentimientos, detectará focos de pérdida y sugerirá planes de acción quirúrgicos.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Contacta a tu asesor para subir a Gold."))),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                                      child: const Text("Mejorar a Plan Gold 👑", style: TextStyle(fontWeight: FontWeight.bold)),
                                  )
                              ]
                          )
                      )
               ]
            );

            final crmCol = Column(
               crossAxisAlignment: CrossAxisAlignment.stretch,
               children: [
                   Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                           const Text("CRM & Recompensas", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                           TextButton.icon(
                               onPressed: _exportActiveCoupons, 
                               icon: const Icon(Icons.download, color: Colors.blueAccent), 
                               label: const Text("Exportar Códigos", style: TextStyle(color: Colors.blueAccent))
                           )
                       ],
                   ),
                   const SizedBox(height: 16),
                   Container(
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[800]!)),
                       child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                               const Text("Clientes VIP (Mayor consumo de este periodo)", style: TextStyle(color: Colors.grey, fontSize: 14)),
                               const SizedBox(height: 12),
                               if (_whales.isEmpty) const Text("Nadie registrado con app en las encuestas.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                               ..._whales.map((w) => ListTile(
                                   contentPadding: EdgeInsets.zero,
                                   leading: const CircleAvatar(backgroundColor: AppTheme.primaryBrand, child: Icon(Icons.star, color: Colors.black)),
                                   title: Text(w['user_name'].toString(), style: const TextStyle(color: Colors.white)),
                                   subtitle: Text("\$${(w['ticket']/1000).toStringAsFixed(1)}k - ${DateFormat('dd MMM').format(DateTime.parse(w['date']))}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                   trailing: ElevatedButton.icon(
                                       style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.black, visualDensity: VisualDensity.compact),
                                       icon: const Icon(Icons.card_giftcard, size: 16),
                                       label: const Text("Premiar"),
                                       onPressed: () => _rewardUser(w),
                                   ),
                               )).toList(),
                               const Divider(color: Colors.grey, height: 32),
                               const Text("Validar Código de Descuento en Caja", style: TextStyle(color: Colors.grey, fontSize: 14)),
                               const SizedBox(height: 8),
                               Row(
                                   children: [
                                       Expanded(child: TextField(
                                           controller: _validationCtrl,
                                           style: const TextStyle(color: Colors.white),
                                           decoration: const InputDecoration(
                                               hintText: "Ej. GVP-12345", hintStyle: TextStyle(color: Colors.grey),
                                               isDense: true, border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey))
                                           ),
                                       )),
                                       const SizedBox(width: 8),
                                       ElevatedButton(
                                           style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.black),
                                           onPressed: _isValidating ? null : _validateCoupon,
                                           child: _isValidating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black)) : const Text("Verificar")
                                       )
                                   ]
                               )
                           ]
                       )
                   )
               ]
            );

            if (isDesktop) {
               return SingleChildScrollView(
                   padding: const EdgeInsets.all(24),
                   child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                           metricsHeader,
                           const SizedBox(height: 24),
                           Row(
                               children: [
                                   Expanded(child: topCardsRow1),
                                   const SizedBox(width: 10),
                                   Expanded(child: topCardsRow2),
                               ],
                           ),
                           const SizedBox(height: 32),
                           Row(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                   Expanded(flex: 3, child: chartsCol),
                                   const SizedBox(width: 32),
                                   Expanded(flex: 2, child: topDishesCol),
                               ]
                           ),
                           const SizedBox(height: 32),
                           Row(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                   Expanded(flex: 2, child: aiCol),
                                   const SizedBox(width: 32),
                                   Expanded(flex: 2, child: crmCol),
                               ]
                           )
                       ]
                   )
               );
            }

            // Mobile layout
            return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        metricsHeader,
                        const SizedBox(height: 16),
                        topCardsRow1,
                        const SizedBox(height: 10),
                        topCardsRow2,
                        const SizedBox(height: 32),
                        chartsCol,
                        const SizedBox(height: 32),
                        topDishesCol,
                        const SizedBox(height: 32),
                        aiCol,
                        const SizedBox(height: 32),
                        crmCol,
                    ]
                )
            );
        })
    );
  }

  Widget _buildAIPanel() {
      return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.indigo.shade900.withOpacity(0.5), Colors.purple.shade900.withOpacity(0.5)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purpleAccent.withOpacity(0.3))
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Row(
                      children: [
                          const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                          const SizedBox(width: 8),
                          const Text("Recomendador Estratégico", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          const Spacer(),
                          if (_totalSurveys > 0 && _aiRecommendation == null && !_isGeneratingAi)
                             ElevatedButton(
                                 style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                                 onPressed: _generateRecommendation, 
                                 child: const Text("Analizar")
                             )
                      ],
                  ),
                  const SizedBox(height: 12),
                  if (_totalSurveys == 0)
                      const Text("Necesitas recolectar datos en este periodo para generar un análisis.", style: TextStyle(color: Colors.grey))
                  else if (_isGeneratingAi)
                      const Row(children: [SizedBox(width:20, height:20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent)), SizedBox(width: 12), Text("Gemini está analizando la data...", style: TextStyle(color: Colors.grey))])
                  else if (_aiRecommendation != null)
                      Text(_aiRecommendation!, style: const TextStyle(color: Colors.white, height: 1.5))
                  else
                      const Text("Presiona Analizar para que nuestra IA procese el ticket promedio, las preferencias de platos y los comentarios para sugerirte medidas concretas.", style: TextStyle(color: Colors.grey, fontSize: 13))
              ],
          ),
      );
  }

  Widget _kpiCard(String title, String val, IconData icon, Color color) {
     return Container(
         padding: const EdgeInsets.all(16),
         decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[800]!)),
         child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                 Row(
                     children: [
                         Icon(icon, color: color, size: 20),
                         const SizedBox(width: 8),
                         Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                     ]
                 ),
                 const SizedBox(height: 10),
                 Text(val, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
             ]
         )
     );
  }
  
  Widget _buildBarChart() {
      return BarChart(
         BarChartData(
            alignment: BarChartAlignment.spaceEvenly,
            maxY: 5.0,
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
               show: true,
               bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                     showTitles: true,
                     getTitlesWidget: (double value, TitleMeta meta) {
                        const style = TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12);
                        switch (value.toInt()) {
                           case 0: return const Text('Comida', style: style);
                           case 1: return const Text('Servicio', style: style);
                           case 2: return const Text('Ambiente', style: style);
                           default: return const Text('');
                        }
                     },
                  ),
               ),
               leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v,m)=>Text('${v.toInt()}★', style: const TextStyle(color: Colors.grey, fontSize: 10)))),
               topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
               rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
               show: true,
               drawVerticalLine: false,
               horizontalInterval: 1,
               getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[800], strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barGroups: [
               BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: _avgFood, color: Colors.orange, width: 20, borderRadius: BorderRadius.circular(4))]),
               BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: _avgService, color: Colors.blue, width: 20, borderRadius: BorderRadius.circular(4))]),
               BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: _avgAmbiance, color: Colors.purple, width: 20, borderRadius: BorderRadius.circular(4))]),
            ]
         )
      );
  }
}

class _MenuMatrixFlipCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const _MenuMatrixFlipCard({Key? key, required this.data}) : super(key: key);

  @override
  State<_MenuMatrixFlipCard> createState() => _MenuMatrixFlipCardState();
}

class _MenuMatrixFlipCardState extends State<_MenuMatrixFlipCard> {
  bool _isFlipped = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    Color c = d['type'] == 'Estrella' ? Colors.green : (d['type'] == 'Caballito' ? Colors.blue : (d['type'] == 'Rompecabezas' ? Colors.orange : Colors.red));
    String icon = d['type'] == 'Estrella' ? '✨' : (d['type'] == 'Caballito' ? '🐴' : (d['type'] == 'Rompecabezas' ? '🧩' : '🐕'));
    
    String description = '';
    if (d['type'] == 'Estrella') description = 'Alto margen, alta popularidad. Promociónalos.';
    else if (d['type'] == 'Caballito') description = 'Alta popularidad, bajo margen. Sube el precio sutilmente.';
    else if (d['type'] == 'Rompecabezas') description = 'Alto margen, baja popularidad. Renombra o promociona.';
    else description = 'Bajo margen, baja popularidad. Considera eliminarlos.';

    Widget frontCard = Container(
        key: const ValueKey(1),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withOpacity(0.3))),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                Text("$icon ${d['name']}", textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text("${d['hits']}x pedidos", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                Text("⭐ ${d['rating'].toStringAsFixed(1)}", style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ]
        )
    );

    Widget backCard = Container(
        key: const ValueKey(2),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: c.withOpacity(0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: c)),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                Text(d['type'], style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(description, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10)),
            ]
        )
    );

    return GestureDetector(
        onTap: () {
            setState(() => _isFlipped = !_isFlipped);
        },
        child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            transitionBuilder: (Widget child, Animation<double> animation) {
                final rotateAnim = Tween(begin: pi, end: 0.0).animate(animation);
                return AnimatedBuilder(
                    animation: rotateAnim,
                    child: child,
                    builder: (context, widget) {
                        final isUnder = (ValueKey(1) != child.key);
                        var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
                        tilt *= isUnder ? -1.0 : 1.0;
                        final value = isUnder ? min(rotateAnim.value, pi / 2) : rotateAnim.value;
                        return Transform(
                            transform: Matrix4.rotationY(value)..setEntry(3, 0, tilt),
                            alignment: Alignment.center,
                            child: widget,
                        );
                    },
                );
            },
            child: _isFlipped ? backCard : frontCard,
        )
    );
  }
}
