import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  String? _aiRecommendation;
  bool _isGeneratingAi = false;

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
      final tokenRes = await supabase.from('restaurant_tokens').select('restaurant_id').eq('token_hash', widget.token).maybeSingle();
      if (tokenRes != null) {
          resId = tokenRes['restaurant_id'];
      } else {
          // Assume the token passed might be the restaurant UUID directly (Admin View)
          final checkRes = await supabase.from('restaurants').select('id').eq('id', widget.token).maybeSingle();
          if (checkRes != null) resId = checkRes['id'];
      }
      
      if (resId == null) {
          setState(() { _errorMsg = "Enlace inválido o expirado."; _isLoading = false; });
          return;
      }
      
      // 2. Load restaurant info
      final restInfo = await supabase.from('restaurants').select('name').eq('id', resId).maybeSingle();
      
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
              
              // Process dishes if it was a good experience overall (>= 4.0)
              if ((f+sr+a)/3 >= 4.0 && s['receipt_items'] != null) {
                  final items = List<Map<String, dynamic>>.from(s['receipt_items']);
                  for (var it in items) {
                      final n = it['name'] as String;
                      dishCounts[n] = (dishCounts[n] ?? 0) + 1;
                  }
              }
          }
          
          if (s['receipt_items'] != null) {
              final items = List<Map<String, dynamic>>.from(s['receipt_items']);
              double ticket = 0;
              for (var it in items) {
                  ticket += double.tryParse(it['price'].toString()) ?? 0;
              }
              if (ticket > 0) {
                 totalSpend += ticket;
                 spendTxs++;
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
      
      if (mounted) {
          setState(() {
              _restData = restInfo ?? {'name': 'Restaurante'};
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
       return const Scaffold(backgroundColor: AppTheme.darkBackground, body: Center(child: CircularProgressIndicator()));
    }
    if (_errorMsg != null) {
       return Scaffold(backgroundColor: AppTheme.darkBackground, body: Center(child: Text(_errorMsg!, style: const TextStyle(color: Colors.red))));
    }

    AppBar buildAppBar() {
        return AppBar(
            backgroundColor: AppTheme.darkBackground,
            title: Text("Resumen: ${_restData['name']}"),
            actions: [
                TextButton.icon(
                    onPressed: _exportCsv, 
                    icon: const Icon(Icons.download, color: Colors.greenAccent), 
                    label: const Text("Exportar CSV", style: TextStyle(color: Colors.greenAccent))
                ),
                const SizedBox(width: 8)
            ],
        );
    }
    
    return Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: buildAppBar(),
        body: LayoutBuilder(builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 900;
            
            final metricsHeader = Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Text(
                        "Métricas (${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d').format(_endDate)})", 
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                    ),
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
                    Expanded(child: _kpiCard("NPS Score", "$_npsScore", Icons.speed, npsColor)),
                    const SizedBox(width: 10),
                    Expanded(child: _kpiCard("Satisfacción", "${_avgGeneral.toStringAsFixed(1)}/5", Icons.star, Colors.orange)),
                ]
            );
            
            final topCardsRow2 = Row(
                children: [
                    Expanded(child: _kpiCard("Ticket Promedio", "\$${(_avgTicket/1000).toStringAsFixed(1)}k", Icons.receipt, Colors.green)),
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
                    const Text("Estrellas de la casa", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (_topDishes.isEmpty) const Text("Sin platos top aún", style: TextStyle(color: Colors.grey)),
                    ..._topDishes.map((d) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.restaurant_menu, color: AppTheme.primaryBrand),
                        title: Text(d['name'], style: const TextStyle(color: Colors.white)),
                        trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                            child: Text("${d['hits']}x", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                        ),
                    )).toList()
                ]
            );
            
            final aiCol = Column(
               crossAxisAlignment: CrossAxisAlignment.stretch,
               children: [
                  const Text("AI Business Insights ✨", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildAIPanel(),
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
                           aiCol,
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
