import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/expenses/presentation/screens/budget_plan_tab.dart';
import 'package:planmapp/features/expenses/presentation/screens/scan_receipt_screen.dart';
import 'package:planmapp/features/expenses/presentation/screens/debts_dashboard_screen.dart';
import 'package:planmapp/core/services/plan_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:planmapp/features/expenses/data/repositories/expense_repository.dart';
import 'package:planmapp/features/expenses/data/models/expense_model.dart';
import 'package:planmapp/core/utils/currency_formatter.dart';
import 'package:planmapp/features/expenses/presentation/screens/expense_split_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = false;
  String? _toolsPlanId;

  @override
  void initState() {
    super.initState();
    _loadToolsPlan();
  }

  Future<void> _loadToolsPlan() async {
      try {
          final id = await PlanService().getOrCreateToolsPlan();
          if (mounted) setState(() => _toolsPlanId = id);
      } catch (e) {
          debugPrint("Error loading tools plan: $e");
      }
  }

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
      await showModalBottomSheet(
          context: context, 
          useRootNavigator: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (c) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      const Text("Seleccionar Factura", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 20),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                              InkWell(
                                  onTap: () { Navigator.pop(c); _processImage(ImageSource.camera); },
                                  child: Column(children: const [Icon(Icons.camera_alt, size: 40, color: Colors.blue), Text("Cámara")]),
                              ),
                              InkWell(
                                  onTap: () { Navigator.pop(c); _processImage(ImageSource.gallery); },
                                  child: Column(children: const [Icon(Icons.photo_library, size: 40, color: Colors.purple), Text("Galería")]),
                              ),
                          ],
                      ),
                  ]
              )
            )
          )
      );
  }

  Future<void> _processImage(ImageSource source) async {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      
      if (image == null) return;
      
      setState(() => _isLoading = true);
      try {
          final toolsPlanId = await PlanService().getOrCreateToolsPlan();
          if (mounted) {
              Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
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
          builder: (context) => const DebtsDashboardScreen(planId: null) // Global mode
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
                    title: "Escaneo Automático de Factura",
                    subtitle: "Toma la foto a un ticket de restaurante y deja que planmapp procese la cuenta.",
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
                
                const SizedBox(height: 32),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text("Historial de Cuentas Rápidas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 16),
                
                if (_toolsPlanId != null)
                   StreamBuilder<List<Expense>>(
                      stream: ExpenseRepository(Supabase.instance.client).getExpensesStream(_toolsPlanId!),
                      builder: (context, snapshot) {
                         if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                         if (!snapshot.hasData || snapshot.data!.isEmpty) {
                             return Container(
                                padding: const EdgeInsets.all(24),
                                child: const Center(child: Text("No has creado divisiones directas aún.", style: TextStyle(color: Colors.grey))),
                             );
                         }
                         
                         final expenses = snapshot.data!;
                         return ListView.separated(
                             shrinkWrap: true,
                             physics: const NeverScrollableScrollPhysics(),
                             itemCount: expenses.length,
                             separatorBuilder: (c, i) => const SizedBox(height: 12),
                             itemBuilder: (c, i) {
                                 final ex = expenses[i];
                                 return InkWell(
                                     onTap: () {
                                         // Reopen the Split screen
                                         Navigator.push(context, MaterialPageRoute(
                                             builder: (context) => ExpenseSplitScreen(
                                                 expenseData: ex.toJson(),
                                                 initialItems: ex.items ?? [],
                                             )
                                         ));
                                     },
                                     borderRadius: BorderRadius.circular(16),
                                     child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                            borderRadius: BorderRadius.circular(16)
                                        ),
                                        child: Row(
                                           children: [
                                              Container(
                                                 padding: const EdgeInsets.all(12),
                                                 decoration: BoxDecoration(color: AppTheme.primaryBrand.withOpacity(0.1), shape: BoxShape.circle),
                                                 child: const Icon(Icons.receipt_long, color: AppTheme.primaryBrand),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                  child: Column(
                                                     crossAxisAlignment: CrossAxisAlignment.start,
                                                     children: [
                                                         Text(ex.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                         Text(CurrencyInputFormatter.format(ex.totalAmount), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                                                     ],
                                                  )
                                              ),
                                              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                           ],
                                        )
                                     )
                                 );
                             }
                         );
                      }
                   )
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

