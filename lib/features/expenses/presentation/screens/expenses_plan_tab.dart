import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/utils/currency_formatter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:image_picker/image_picker.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/expenses/data/models/expense_model.dart';
import 'package:planmapp/features/expenses/data/repositories/expense_repository.dart';
import 'package:planmapp/features/expenses/presentation/screens/expense_split_screen.dart';
import 'package:planmapp/features/expenses/presentation/screens/scan_receipt_screen.dart';
import 'package:planmapp/features/expenses/presentation/screens/debts_dashboard_screen.dart';
import 'package:planmapp/core/widgets/auth_guard.dart';
import 'package:planmapp/features/games/presentation/widgets/wheel_spin_dialog.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:planmapp/core/presentation/widgets/dancing_empty_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ExpensesPlanTab extends StatefulWidget {
  final String planId;
  final String userRole;
  final bool showTutorial;

  const ExpensesPlanTab({super.key, required this.planId, this.userRole = 'member', this.showTutorial = false});

  @override
  State<ExpensesPlanTab> createState() => _ExpensesPlanTabState();
}

class _ExpensesPlanTabState extends State<ExpensesPlanTab> {
  late final ExpenseRepository _expenseRepository;
  bool _isLoading = true;
  List<Expense> _expenses = [];
  String? _paymentMode; // Loaded from plan

  @override
  void initState() {
    super.initState();
    _expenseRepository = ExpenseRepository(Supabase.instance.client);
    _loadData();
    
    if (widget.showTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showB2B2CTutorial();
      });
    }
  }

  void _showB2B2CTutorial() {
      showDialog(
          context: context, 
          builder: (c) => AlertDialog(
              title: const Text("Toma foto a la cuenta"),
              content: const Text("Toca el botón mágico del escáner abajo a la derecha para escanear tu factura y nosotros nos encargamos de dividir e identificar a quién le toca cada cosa automáticamente."),
              actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c), 
                      child: const Text("¡Entendido!")
                  )
              ]
          )
      );
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
      final expenses = await _expenseRepository.getExpensesForPlan(widget.planId);
      if (mounted) {
        setState(() {
          _expenses = expenses;
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
      final ImagePicker picker = ImagePicker();

      final source = await showModalBottomSheet<String>(
          context: context,
          builder: (ctx) => SafeArea(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      const ListTile(title: Text("¿Cómo registrarás el gasto?", style: TextStyle(fontWeight: FontWeight.bold))),
                      ListTile(
                          leading: const Icon(Icons.camera_alt),
                          title: const Text("Tomar foto a la factura"),
                          onTap: () => Navigator.pop(ctx, 'camera'),
                      ),
                      ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: const Text("Subir foto de la galería"),
                          onTap: () => Navigator.pop(ctx, 'gallery'),
                      ),
                      ListTile(
                          leading: const Icon(Icons.edit),
                          title: const Text("Ingresar datos manualmente"),
                          onTap: () => Navigator.pop(ctx, 'manual'),
                      ),
                  ]
              )
          )
      );
      
      // If user tapped outside
      if (source == null) return;

      // Escáner (Camera / Gallery)
      if (source != 'manual') {
          final ImageSource imgSource = source == 'camera' ? ImageSource.camera : ImageSource.gallery;
          final XFile? image = await picker.pickImage(source: imgSource, maxWidth: 1080, imageQuality: 80);
          if (image == null) return;
          
          if (mounted) {
              Navigator.push(context, MaterialPageRoute(
                  builder: (context) => ScanReceiptScreen(
                      planId: widget.planId,
                      imageFile: image,
                      isImportMode: false,
                  )
              )).then((_) => _loadBills());
          }
          return;
      }
      
      // Modo Manual
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
               
               // Create a draft Expense
               final newExpense = await _expenseRepository.createDraftExpense(
                   expenseData: {
                       'plan_id': widget.planId,
                       'title': title,
                       'created_by': currentUser,
                       'total_amount': 0,
                       'currency': 'COP',
                       'status': 'draft'
                   },
                   itemsData: []
               );
               
               if (mounted) {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseSplitScreen(
                       expenseData: newExpense.toJson(),
                       initialItems: [],
                   ))).then((_) => _loadBills());
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
      final url = "$baseUrl/#/vaca/${widget.planId}";
      
      Share.share("¡Hola! Entra aquí para ayudarnos a dividir la cuenta: $url");
      // Also Copy to clipboard for easy testing
      Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link de invitación a la cuenta copiado!")));
  }

  @override
  Widget build(BuildContext context) {
    // Total Summary logic
    final double totalPlan = _expenses.fold(0.0, (sum, item) => sum + item.totalAmount);

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
                         if (_paymentMode == 'split' && _expenses.isEmpty)
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
                                            Text("${_expenses.length} cuentas • ${CurrencyInputFormatter.format(totalPlan)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                                     ],
                                 ),
                                 Row(
                                   children: [
                                       IconButton(
                                           icon: const Icon(Icons.account_balance_wallet, color: Colors.orange),
                                           onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DebtsDashboardScreen(planId: widget.planId))),
                                           tooltip: "Estado de Pagos",
                                       ),
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
              else if (_expenses.isEmpty)
                 SliverFillRemaining(
                     hasScrollBody: false,
                     child: DancingEmptyState(
                        icon: Icons.document_scanner_outlined,
                        title: "¡Escanea tu primera factura!",
                        message: "Toca el botón mágico flotante abajo a la derecha, tómale foto a la cuenta y nosotros nos encargamos del resto.",
                        onButtonPressed: _createNewBill,
                        buttonLabel: "Crear Manualmente",
                     ),
                 )
              else 
                 SliverList(
                     delegate: SliverChildBuilderDelegate(
                         (context, index) {
                             final expense = _expenses[index];
                             return Padding(
                                 padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                                 child: Card(
                                    elevation: 2,
                                    child: ListTile(
                                        title: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Text(expense.status == 'draft' ? 'Borrador' : 'Confirmada', style: TextStyle(color: expense.status == 'draft' ? Colors.orange : Colors.green)),
                                        trailing: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                                Text(CurrencyInputFormatter.format(expense.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey)
                                            ],
                                        ),
                                        onTap: () {
                                            Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseSplitScreen(
                                                expenseData: expense.toJson(),
                                                initialItems: expense.items ?? [],
                                            ))).then((_) => _loadBills());
                                        },
                                    ),
                                 ).animate().slideX(),
                             );
                         },
                         childCount: _expenses.length,
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
