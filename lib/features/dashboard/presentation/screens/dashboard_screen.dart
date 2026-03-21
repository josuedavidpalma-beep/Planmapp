import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/expenses/presentation/screens/budget_plan_tab.dart';
import 'package:planmapp/features/expenses/presentation/screens/scan_receipt_screen.dart';
import 'package:planmapp/features/expenses/presentation/screens/debt_recovery_screen.dart';
import 'package:planmapp/core/services/plan_service.dart';
import 'package:image_picker/image_picker.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = false;

  Future<void> _openBudgetTool() async {
      setState(() => _isLoading = true);
      try {
          final toolsPlanId = await PlanService().getOrCreateToolsPlan();
          if (mounted) {
              Navigator.push(context, MaterialPageRoute(
                  builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text("Presupuesto Libre")),
                      body: BudgetPlanTab(planId: toolsPlanId)
                  )
              ));
          }
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
          if (mounted) setState(() => _isLoading = false);
      }
  }

  Future<void> _openScannerTool() async {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      
      if (image == null) return;
      
      setState(() => _isLoading = true);
      try {
          final toolsPlanId = await PlanService().getOrCreateToolsPlan();
          if (mounted) {
              Navigator.push(context, MaterialPageRoute(
                  builder: (context) => ScanReceiptScreen(
                      planId: toolsPlanId, 
                      imageFile: image,
                      isImportMode: false,
                  )
              ));
          }
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
          if (mounted) setState(() => _isLoading = false);
      }
  }

  void _openGlobalDebts() {
      Navigator.push(context, MaterialPageRoute(
          builder: (context) => const DebtRecoveryScreen(planId: null) // Global mode
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Herramientas", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
                const Text("Tus herramientas para organizarte mejor sin necesidad de armar un plan completo.", style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 24),
                
                _buildToolCard(
                    context,
                    title: "Presupuesto Rápido",
                    subtitle: "Calcula los gastos de un viaje o fiesta rápidamente y divídelo entre tus amigos.",
                    icon: Icons.calculate_outlined,
                    color: Colors.blueAccent,
                    onTap: _openBudgetTool,
                ),
                _buildToolCard(
                    context,
                    title: "Dividir Factura con IA",
                    subtitle: "Toma la foto a un ticket de restaurante y deja que escaneemos y dividamos la cuenta.",
                    icon: Icons.document_scanner_outlined,
                    color: Colors.deepPurpleAccent,
                    onTap: _openScannerTool,
                ),
                _buildToolCard(
                    context,
                    title: "Cobro Automático Global",
                    subtitle: "Revisa quién te debe dinero de TODOS tus planes organizados y envíales un recordatorio.",
                    icon: Icons.request_quote_outlined,
                    color: Colors.orangeAccent,
                    onTap: _openGlobalDebts,
                ),
            ],
        ),
    );
  }

  Widget _buildToolCard(BuildContext context, {
      required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap
  }) {
      return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.withOpacity(0.1))),
          elevation: 2,
          shadowColor: color.withOpacity(0.2),
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                      children: [
                          Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                              child: Icon(icon, color: color, size: 32),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                      const SizedBox(height: 6),
                                      Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12, height: 1.3)),
                                  ],
                              )
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                      ],
                  ),
              ),
          ),
      );
  }
}

