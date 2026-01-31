import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  double _totalOwedToMe = 0;
  double _totalIOwe = 0;

  @override
  void initState() {
    super.initState();
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
      // TODO: Implement real aggregation query across all plans
      // For now, simulating data or fetching basic stats if possible.
      // Real implementation requires complex joins:
      // - Find all expenses where I am a debtor (BillSplit) -> Add to IOwe
      // - Find all expenses where I am the payer (Bill) AND have splits not paid -> Add to OwedToMe
      
      await Future.delayed(const Duration(seconds: 1)); // Sim network

      if (mounted) {
          setState(() {
              _isLoading = false;
              // Mock Values for Visualization based on User Request
              _totalOwedToMe = 150000; 
              _totalIOwe = 45000;
          });
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Resumen Financiero", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
            IconButton(icon: const Icon(Icons.history), onPressed: (){})
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
                // 1. GLOBAL BALANCE CARDS
                Row(
                    children: [
                        Expanded(child: _buildBalanceCard("Por Cobrar", _totalOwedToMe, Colors.green)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildBalanceCard("Por Pagar", _totalIOwe, Colors.redAccent)),
                    ],
                ),
                const SizedBox(height: 24),
                
                // 2. NET BALANCE
                Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: AppTheme.primaryBrand.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primaryBrand.withOpacity(0.3))
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            const Text("Balance Total", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(
                                NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0).format(_totalOwedToMe - _totalIOwe),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.primaryBrand)
                            )
                        ],
                    ),
                ),
                const SizedBox(height: 32),
                
                // 3. RECENT ACTIVITY (Last month)
                const Text("Actividad Reciente (30 días)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                
                _buildActivityItem("Asado en mi casa", "Carne y Bebidas", "Tú pagaste", 250000, DateTime.now().subtract(const Duration(days: 2))),
                _buildActivityItem("Salida a Cine", "Boletas", "Debes a Juan", 25000, DateTime.now().subtract(const Duration(days: 5))),
                _buildActivityItem("Viaje a Melgar", "Gasolina", "Debes a Miguel", 40000, DateTime.now().subtract(const Duration(days: 12))),
                
                const SizedBox(height: 20),
                Center(child: TextButton(onPressed: (){}, child: const Text("Ver todo el historial")))
            ],
        ),
    );
  }

  Widget _buildBalanceCard(String title, double amount, Color color) {
      return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Row(
                      children: [
                          Icon(title == "Por Cobrar" ? Icons.trending_up : Icons.trending_down, color: color, size: 20),
                          const SizedBox(width: 8),
                          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                      NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0).format(amount),
                      style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)
                  )
              ],
          ),
      );
  }

  Widget _buildActivityItem(String planName, String itemTitle, String status, double amount, DateTime date) {
      final isDebt = status.contains("Debes");
      return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: Colors.grey[50],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          child: ListTile(
              leading: CircleAvatar(
                  backgroundColor: isDebt ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  child: Icon(isDebt ? Icons.arrow_upward : Icons.arrow_downward, color: isDebt ? Colors.red : Colors.green, size: 18),
              ),
              title: Text(itemTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("$planName • ${DateFormat('d MMM').format(date)}"),
              trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                      Text(
                          NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0).format(amount),
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDebt ? Colors.red : Colors.green)
                      ),
                      Text(status, style: const TextStyle(fontSize: 10, color: Colors.grey))
                  ],
              ),
          ),
      );
  }
}
