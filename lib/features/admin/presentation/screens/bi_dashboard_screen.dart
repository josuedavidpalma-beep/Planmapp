import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'dart:math';

// --- MOCK DATA MODEL ---
class MockTransaction {
  final DateTime date;
  final double amount;
  final int foodRating;
  final int serviceRating;
  final int ambianceRating;

  MockTransaction({
    required this.date,
    required this.amount,
    required this.foodRating,
    required this.serviceRating,
    required this.ambianceRating,
  });
}

// --- DASHBOARD SCREEN ---
class BiDashboardScreen extends StatefulWidget {
  final String restaurantName;
  final String restaurantId;

  const BiDashboardScreen({
    super.key, 
    required this.restaurantName,
    required this.restaurantId,
  });

  @override
  State<BiDashboardScreen> createState() => _BiDashboardScreenState();
}

class _BiDashboardScreenState extends State<BiDashboardScreen> {
  List<MockTransaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateMockData();
  }

  void _generateMockData() {
    final random = Random();
    final List<MockTransaction> data = [];
    final now = DateTime.now();
    
    // Simulate last 30 days
    for (int i = 0; i < 100; i++) {
      // Random day in the last 30 days
      final daysAgo = random.nextInt(30);
      final txDate = now.subtract(Duration(days: daysAgo));
      
      // Simulate higher amounts on weekends
      final isWeekend = txDate.weekday == DateTime.saturday || txDate.weekday == DateTime.sunday;
      final baseAmount = isWeekend ? 150000.0 : 60000.0;
      final amount = baseAmount + random.nextDouble() * 50000.0;
      
      // Simulated ratings (1 to 5)
      data.add(MockTransaction(
        date: txDate,
        amount: amount,
        foodRating: 3 + random.nextInt(3), // 3, 4, or 5
        serviceRating: 2 + random.nextInt(4), // 2 to 5 (Service varies more)
        ambianceRating: 4 + random.nextInt(2), // 4 or 5
      ));
    }

    // Sort by date ascending
    data.sort((a, b) => a.date.compareTo(b.date));

    setState(() {
      _transactions = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text("BI: ${widget.restaurantName}"),
        backgroundColor: AppTheme.primaryBrand,
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                // Responsive layout logic
                final isDesktop = constraints.maxWidth > 800;
                
                if (isDesktop) {
                  return _buildDesktopLayout();
                } else {
                  return _buildMobileLayout();
                }
              },
            ),
    );
  }

  // --- RESPONSIVE LAYOUTS ---
  
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Content (Charts)
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderMetrics(),
                const SizedBox(height: 32),
                _buildRevenueChart(),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildSatisfactionChart()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildRecentTransactions()),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Sidebar (AI Insights)
        Container(
          width: 350,
          color: AppTheme.surfaceDark,
          child: _buildAiInsightsPanel(),
        )
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderMetrics(),
          const SizedBox(height: 24),
          _buildAiInsightsPanel(),
          const SizedBox(height: 24),
          _buildRevenueChart(),
          const SizedBox(height: 24),
          _buildSatisfactionChart(),
          const SizedBox(height: 24),
          _buildRecentTransactions(),
        ],
      ),
    );
  }

  // --- COMPONENTS ---

  Widget _buildHeaderMetrics() {
    final totalRevenue = _transactions.fold(0.0, (sum, tx) => sum + tx.amount);
    final avgFood = _transactions.map((t) => t.foodRating).reduce((a, b) => a + b) / _transactions.length;
    
    return Row(
      children: [
        Expanded(child: _MetricCard(title: "Ingresos (30d)", value: "\$${(totalRevenue / 1000).toStringAsFixed(0)}k", icon: Icons.attach_money, color: Colors.green)),
        const SizedBox(width: 16),
        Expanded(child: _MetricCard(title: "Tickets", value: "${_transactions.length}", icon: Icons.receipt_long, color: Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: _MetricCard(title: "Calidad", value: "${avgFood.toStringAsFixed(1)} ★", icon: Icons.star, color: Colors.amber)),
      ],
    );
  }

  Widget _buildRevenueChart() {
    // Group transactions by day for chart
    final Map<int, double> dailyRevenue = {};
    for (var tx in _transactions) {
      final day = tx.date.day;
      dailyRevenue[day] = (dailyRevenue[day] ?? 0) + tx.amount;
    }
    
    final sortedDays = dailyRevenue.keys.toList()..sort();
    final spots = sortedDays.map((d) => FlSpot(d.toDouble(), dailyRevenue[d]!)).toList();

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Tendencia de Consumo", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white10, strokeWidth: 1)),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10)))),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primaryBrand,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primaryBrand.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSatisfactionChart() {
    final avgFood = _transactions.map((t) => t.foodRating).reduce((a, b) => a + b) / _transactions.length;
    final avgService = _transactions.map((t) => t.serviceRating).reduce((a, b) => a + b) / _transactions.length;
    final avgAmbiance = _transactions.map((t) => t.ambianceRating).reduce((a, b) => a + b) / _transactions.length;

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Métricas de Satisfacción", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 5,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        switch (value.toInt()) {
                          case 0: return const Text('Comida', style: TextStyle(color: Colors.white, fontSize: 12));
                          case 1: return const Text('Servicio', style: TextStyle(color: Colors.white, fontSize: 12));
                          case 2: return const Text('Ambiente', style: TextStyle(color: Colors.white, fontSize: 12));
                          default: return const Text('');
                        }
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: avgFood, color: Colors.green, width: 20, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: avgService, color: Colors.orange, width: 20, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: avgAmbiance, color: Colors.blue, width: 20, borderRadius: BorderRadius.circular(4))]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    final recent = _transactions.reversed.take(5).toList();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Últimas Evaluaciones", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...recent.map((tx) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryBrand.withOpacity(0.1),
              child: const Icon(Icons.receipt, color: AppTheme.primaryBrand, size: 16),
            ),
            title: Text(DateFormat('MMM dd, hh:mm a').format(tx.date), style: const TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: Text("Comida: ${tx.foodRating}★ | Serv: ${tx.serviceRating}★", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            trailing: Text("\$${(tx.amount/1000).toStringAsFixed(0)}k", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          )).toList()
        ],
      ),
    );
  }

  Widget _buildAiInsightsPanel() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amber),
              const SizedBox(width: 8),
              const Text("Planmapp AI Insights", style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          _buildAiCard(
            "Pico de Demanda Identificado", 
            "La inteligencia artificial detectó que los días viernes entre 7 PM y 9 PM generas el 45% de tus ingresos, pero el puntaje de servicio cae a 3.2 estrellas. Recomendación: Reforzar turnos en ese horario.",
            Icons.trending_up, 
            Colors.orange
          ),
          const SizedBox(height: 16),
          _buildAiCard(
            "Éxito de Fidelización", 
            "Los usuarios que usan Planmapp para dividir su cuenta gastan un 22% más que el promedio. Tu ambiente tiene calificación casi perfecta (4.8). ¡Aprovecha promociones grupales!",
            Icons.celebration, 
            Colors.blue
          ),
          const SizedBox(height: 16),
          _buildAiCard(
            "Campaña Sugerida", 
            "Tienes 35 clientes que no han vuelto en las últimas 3 semanas. Generar una notificación Push con un 10% de descuento te traería un retorno estimado de \$500k.",
            Icons.campaign, 
            Colors.green
          ),
        ],
      ),
    );
  }

  Widget _buildAiCard(String title, String desc, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14))),
            ],
          ),
          const SizedBox(height: 12),
          Text(desc, style: TextStyle(color: Colors.grey[300], fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
