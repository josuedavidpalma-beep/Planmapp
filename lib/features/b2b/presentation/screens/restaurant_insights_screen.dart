import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';

class RestaurantInsightsScreen extends StatefulWidget {
  final String token;
  const RestaurantInsightsScreen({Key? key, required this.token}) : super(key: key);

  @override
  State<RestaurantInsightsScreen> createState() => _RestaurantInsightsScreenState();
}

class _RestaurantInsightsScreenState extends State<RestaurantInsightsScreen> {
  bool _isLoading = true;
  String? _errorMsg;
  
  Map<String, dynamic> _restData = {};
  List<Map<String, dynamic>> _responses = [];
  
  double _avgGeneral = 0.0;
  double _avgTicket = 0.0;
  int _totalSurveys = 0;
  List<Map<String, dynamic>> _topDishes = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final supabase = Supabase.instance.client;
      // 1. Verify token
      final tokenRes = await supabase.from('restaurant_tokens').select('restaurant_id').eq('token_hash', widget.token).maybeSingle();
      if (tokenRes == null) {
          setState(() { _errorMsg = "Enlace inválido o expirado."; _isLoading = false; });
          return;
      }
      
      final resId = tokenRes['restaurant_id'];
      
      // 2. Load restaurant info
      final restInfo = await supabase.from('restaurants').select('name').eq('id', resId).maybeSingle();
      
      // 3. Load past 30 days surveys
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final surveysRes = await supabase.from('survey_responses').select().eq('restaurant_id', resId).gte('created_at', thirtyDaysAgo);
      final List<Map<String, dynamic>> rawResponses = List<Map<String, dynamic>>.from(surveysRes);
      
      _totalSurveys = rawResponses.length;
      
      double totalFood = 0;
      double totalService = 0;
      double totalAmbiance = 0;
      int countKpi = 0;
      
      double totalSpend = 0;
      int spendTxs = 0;
      
      Map<String, int> dishCounts = {};
      
      for (var s in rawResponses) {
          final f = s['rating_food'] as int?;
          final sr = s['rating_service'] as int?;
          final a = s['rating_ambiance'] as int?;
          if (f != null && sr != null && a != null) {
              totalFood += f;
              totalService += sr;
              totalAmbiance += a;
              countKpi++;
              
              // Process dishes if it was a 5-star experience overall
              if ((f+sr+a)/3 >= 4.5 && s['receipt_items'] != null) {
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
          _avgGeneral = (totalFood + totalService + totalAmbiance) / (3 * countKpi);
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
              _isLoading = false;
          });
      }
    } catch (e) {
        if (mounted) {
            setState(() { _errorMsg = e.toString(); _isLoading = false; });
        }
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

    return Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: AppBar(
            backgroundColor: AppTheme.darkBackground,
            title: Text("Resumen: ${_restData['name']}"),
        ),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    const Text("Métricas Clave (Últimos 30 dís)", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                        children: [
                            Expanded(child: _kpiCard("Satisfacción", "${_avgGeneral.toStringAsFixed(1)} / 5.0", Icons.star, Colors.orange)),
                            const SizedBox(width: 10),
                            Expanded(child: _kpiCard("Ticket Promedio", "\$${(_avgTicket/1000).toStringAsFixed(1)}k", Icons.receipt, Colors.green)),
                        ]
                    ),
                    const SizedBox(height: 10),
                    Row(
                        children: [
                            Expanded(child: _kpiCard("Encuestas", "$_totalSurveys recibidas", Icons.analytics, Colors.blue)),
                        ]
                    ),
                    const SizedBox(height: 32),
                    const Text("Tendencia Gasto vs Felicidad", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                        height: 250,
                        child: _responses.isEmpty ? const Center(child: Text("Sin datos suficientes", style: TextStyle(color: Colors.grey))) : _buildScatterChart(),
                    ),
                    const SizedBox(height: 32),
                    const Text("Estrellas de la casa (Platos top en encuestas de 5★)", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ..._topDishes.map((d) => ListTile(
                        leading: const Icon(Icons.restaurant_menu, color: AppTheme.primaryBrand),
                        title: Text(d['name'], style: const TextStyle(color: Colors.white)),
                        trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                            child: Text("${d['hits']} veces", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                        ),
                    )).toList()
                ]
            )
        )
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
  
  Widget _buildScatterChart() {
      // Y = Rating, X = Spend index
      List<ScatterSpot> spots = [];
      for (var s in _responses) {
          if (s['rating_food'] == null || s['receipt_items'] == null) continue;
          double avgRating = ((s['rating_food'] as int) + (s['rating_service'] as int)) / 2;
          double ticket = 0;
          for (var it in List<Map<String, dynamic>>.from(s['receipt_items'])) {
              ticket += double.tryParse(it['price'].toString()) ?? 0;
          }
          if (ticket > 0) {
             spots.add(ScatterSpot(ticket, avgRating, dotPainter: FlDotCirclePainter(color: AppTheme.primaryBrand, radius: 4)));
          }
      }
      
      return ScatterChart(
          ScatterChartData(
              scatterSpots: spots,
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) => Text("\$${(v/1000).toInt()}k", style: const TextStyle(color: Colors.grey, fontSize: 10)))),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) => Text("${v.toInt()}★", style: const TextStyle(color: Colors.grey, fontSize: 10)))),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey[800]!)),
          )
      );
  }
}
