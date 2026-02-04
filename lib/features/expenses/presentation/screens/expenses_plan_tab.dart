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
import 'package:planmapp/features/games/presentation/widgets/wheel_spin_dialog.dart'; // NEW
// import 'package:planmapp/features/games/presentation/screens/games_hub_screen.dart'; // REMOVED
import 'package:flutter_animate/flutter_animate.dart';
import 'package:planmapp/core/presentation/widgets/dancing_empty_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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
  String? _paymentMode; // Loaded from plan

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
      await Future.wait([
          _loadBills(),
          _fetchPlanMode()
      ]);
  }

  Future<void> _fetchPlanMode() async {
      try {
          final res = await Supabase.instance.client.from('plans').select('payment_mode').eq('id', widget.planId).single();
          if (mounted) setState(() => _paymentMode = res['payment_mode']);
      } catch (_) {}
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
      }
    }
  }
  
  Future<void> _createNewBill({String? initialTitle}) async {
      if (!await AuthGuard.ensureAuthenticated(context)) return;
      
      final titleController = TextEditingController(text: initialTitle);
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
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.stretch,
                       children: [
                         // SMART SUGGESTION FOR SPLIT BILL (DIVIDIR CUENTA)
                         // "Vaca" (pool) is now handled in Budget Tab, so here we focus on "Dividir"
                         if (_paymentMode == 'split' && _bills.isEmpty)
                             Container(
                                 margin: const EdgeInsets.only(bottom: 16),
                                 padding: const EdgeInsets.all(16),
                                 decoration: BoxDecoration(
                                     gradient: LinearGradient(colors: [Colors.green.withOpacity(0.2), Colors.green.withOpacity(0.05)]),
                                     borderRadius: BorderRadius.circular(16),
                                     border: Border.all(color: Colors.green.withOpacity(0.3))
                                 ),
                                 child: Row(
                                     children: [
                                         Container(
                                             padding: const EdgeInsets.all(10),
                                             decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                             child: const Icon(Icons.receipt_long, color: Colors.green, size: 24),
                                         ),
                                         const SizedBox(width: 16),
                                         Expanded(
                                             child: Column(
                                                 crossAxisAlignment: CrossAxisAlignment.start,
                                                 children: [
                                                     const Text("Modo 'Dividir Cuenta' Activo", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                                     const SizedBox(height: 4),
                                                     const Text("Registra aquí los gastos que vaya haciendo cada uno para dividirlos al final.", style: TextStyle(fontSize: 12)),
                                                     const SizedBox(height: 8),
                                                     SizedBox(
                                                         height: 32,
                                                         child: ElevatedButton(
                                                             style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16)),
                                                             onPressed: () => _createNewBill(initialTitle: "Primer Gasto"),
                                                             child: const Text("Registrar Gasto"),
                                                         ),
                                                     )
                                                 ],
                                             )
                                         )
                                     ],
                                 ),
                             ).animate().fade().slideY(begin: 0.2, end: 0),

                         Row(
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
                                           onPressed: _openWheel,
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

  // GAME LOGIC (Copied/Shared from PlanDetailScreen)
  Future<void> _openWheel() async {
      final mode = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: Colors.transparent, 
          builder: (context) => Container(
              decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 16),
                      const Text("Juegos de Azar 🎲", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      
                      _buildGameOption(
                          icon: Icons.attach_money, 
                          color: Colors.green, 
                          title: "¿Quién Paga?", 
                          subtitle: "Sorteo entre los participantes",
                          onTap: () => Navigator.pop(context, 'who_pays')
                      ),
                      _buildGameOption(
                          icon: Icons.fastfood, 
                          color: Colors.orange, 
                          title: "¿Qué Comemos?", 
                          subtitle: "Pizza, Sushi, Hamburguesa...",
                          onTap: () => Navigator.pop(context, 'food')
                      ),
                      _buildGameOption(
                          icon: Icons.casino, 
                          color: Colors.purple, 
                          title: "Decisión Abierta", 
                          subtitle: "Opciones personalizadas",
                          onTap: () => Navigator.pop(context, 'custom')
                      ),
                      const SizedBox(height: 20),
                  ],
              ),
          )
      );

      if (mode == null) return;

      List<String> options = [];
      
      if (mode == 'who_pays') {
           // FETCH MEMBERS for "Who Pays"
           try {
               final members = await Supabase.instance.client
                    .from('plan_members')
                    .select('profiles(full_name)')
                    .eq('plan_id', widget.planId);
               
               if (members != null && (members as List).isNotEmpty) {
                   options = members.map((m) => (m['profiles']['full_name'] as String).split(' ')[0]).toList();
               } else {
                   options = ["Yo", "Tú"];
               }
           } catch (e) {
               options = ["Yo", "Tú"]; // Fallback
           }
      } else if (mode == 'food') {
          options = ["Pizza 🍕", "Sushi 🍣", "Hamburguesa 🍔", "Tacos 🌮", "Pollo 🍗", "Chino 🥢"];
      }

      if (mounted) {
          await showDialog(
              context: context, 
              builder: (context) => WheelSpinDialog(
                  planId: widget.planId, 
                  initialOptions: options,
                  onSpinComplete: (result) {
                       // Handled internally by dialog
                  }
              )
          );
      }
  }

  Widget _buildGameOption({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
       return ListTile(
            leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: onTap,
       );
  }
}
