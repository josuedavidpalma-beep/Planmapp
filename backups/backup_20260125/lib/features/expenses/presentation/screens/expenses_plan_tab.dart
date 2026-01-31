import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/utils/currency_formatter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/expenses/domain/models/bill_model.dart';
import 'package:planmapp/features/expenses/domain/services/bill_service.dart';
import 'package:planmapp/features/expenses/presentation/screens/bill_detail_screen.dart';
import 'package:planmapp/core/widgets/auth_guard.dart';
import 'package:planmapp/features/games/presentation/screens/games_hub_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:planmapp/core/presentation/widgets/dancing_empty_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpensesPlanTab extends StatefulWidget {
  final String planId;
  final String userRole;

  const ExpensesPlanTab({super.key, required this.planId, this.userRole = 'member'});

  @override
  State<ExpensesPlanTab> createState() => _ExpensesPlanTabState();
}

class _ExpensesPlanTabState extends State<ExpensesPlanTab> {
  final BillService _billService = BillService();
  bool _isLoading = true;
  List<Bill> _bills = [];

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    try {
      final bills = await _billService.getBillsForPlan(widget.planId);
      if (mounted) {
        setState(() {
          _bills = bills;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando cuentas: $e')));
      }
    }
  }
  
  Future<void> _createNewBill() async {
      if (!await AuthGuard.ensureAuthenticated(context)) return;
      
      final titleController = TextEditingController();
      final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
          title: const Text("Nueva Cuenta"),
          content: TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Nombre (ej. Cena, Taxis)", hintText: "Cuenta"),
              autofocus: true,
          ),
          actions: [
              TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text("Cancelar")),
              ElevatedButton(onPressed: ()=>Navigator.pop(context, true), child: const Text("Crear")),
          ],
      ));
      
      if (confirm == true) {
           try {
               final currentUser = Supabase.instance.client.auth.currentUser!.id;
               final String title = titleController.text.isEmpty ? "Cuenta" : titleController.text;
               final newBill = await _billService.createBill(widget.planId, currentUser, title);
               
               if (mounted) {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => BillDetailScreen(billId: newBill.id, planId: widget.planId))).then((_) => _loadBills());
               }
           } catch(e) {
               if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
           }
          }
  }

  void _sharePaymentLink() {
      // Use localhost port for dev or real domain for prod. 
      // For now, assume a base URL.
      const baseUrl = "https://planmapp.app"; // Or use window.location in web
      final url = "$baseUrl/pago/${widget.planId}";
      
      Share.share("Hola! Entra aquí para ver cuánto debes del plan: $url");
      // Also Copy to clipboard for easy testing
      Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link de cobro copiado!")));
  }

  @override
  Widget build(BuildContext context) {
    // Total Summary logic
    final double totalPlan = _bills.fold(0.0, (sum, item) => sum + item.totalAmount);

    return CustomScrollView(
        slivers: [
             // Header
             SliverToBoxAdapter(
                 child: Padding(
                     padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                     child: Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                             Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                     const Text("Cuentas Claras", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                     if (totalPlan > 0)
                                        Text("${_bills.length} cuentas • ${CurrencyInputFormatter.format(totalPlan)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                                 ],
                             ),
                             Row(
                               children: [
                                   IconButton(
                                       onPressed: _sharePaymentLink,
                                       icon: const Icon(Icons.link_rounded, color: AppTheme.primaryBrand),
                                       tooltip: "Cobrar a todos (Link de Pago)",
                                   ),
                                   IconButton(
                                    icon: const Icon(Icons.casino_rounded, color: Colors.purple),
                                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GamesHubScreen(planId: widget.planId))),
                                    tooltip: "¿Quién Paga?",
                                 ),
                                   TextButton.icon(
                                       onPressed: () => context.push('/plan/${widget.planId}/balances'),
                                       icon: const Icon(Icons.handshake_outlined, size: 20),
                                       label: const Text("Saldar"),
                                       style: TextButton.styleFrom(
                                            foregroundColor: AppTheme.primaryBrand,
                                            backgroundColor: AppTheme.primaryBrand.withOpacity(0.1),
                                       )
                                   )
                               ],
                             )
                         ],
                     ),
                 ),
             ),

             // List
              if (_isLoading) 
                 const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (_bills.isEmpty)
                 SliverFillRemaining(
                     hasScrollBody: false,
                     child: DancingEmptyState(
                        icon: Icons.receipt_long_rounded,
                        title: "¡Aún no hay cuentas!",
                        message: "Crea una cuenta para empezar a dividir gastos con tus amigos.",
                        onButtonPressed: _createNewBill,
                        buttonLabel: "Crear Cuenta",
                     ),
                 )
              else 
                 SliverList(
                     delegate: SliverChildBuilderDelegate(
                         (context, index) {
                             final bill = _bills[index];
                             return Padding(
                                 padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                                 child: Card(
                                    elevation: 2,
                                    child: ListTile(
                                        title: Text(bill.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Text(bill.status == 'draft' ? 'Borrador' : 'Confirmada', style: TextStyle(color: bill.status == 'draft' ? Colors.orange : Colors.green)),
                                        trailing: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                                Text(CurrencyInputFormatter.format(bill.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey)
                                            ],
                                        ),
                                        onTap: () {
                                            Navigator.push(context, MaterialPageRoute(builder: (_) => BillDetailScreen(billId: bill.id, planId: widget.planId)))
                                                .then((_) => _loadBills());
                                        },
                                    ),
                                 ).animate().slideX(),
                             );
                         },
                         childCount: _bills.length,
                     ),
                 ),
             
             const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
    );
  }
}
