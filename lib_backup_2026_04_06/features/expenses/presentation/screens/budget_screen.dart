
import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/expenses/data/models/budget_model.dart';
import 'package:planmapp/features/expenses/data/repositories/budget_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BudgetScreen extends StatefulWidget {
  final String planId;

  const BudgetScreen({super.key, required this.planId});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repository = BudgetRepository(Supabase.instance.client);
  
  List<BudgetItem> _budgetItems = [];
  List<PaymentTracker> _trackers = [];
  bool _isLoading = true;
  double _totalBudget = 0.0;
  double _amountCollected = 0.0;
  double _quotaPerPerson = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _repository.syncMembersToTrackers(widget.planId); // Ensure everyone is in the list
    
    final items = await _repository.getBudgetItems(widget.planId);
    final trackers = await _repository.getPaymentTrackers(widget.planId);
    
    // Calculate Stats
    final total = items.fold(0.0, (sum, i) => sum + i.estimatedAmount);
    // If quotas are outdated, we should recalc, but for now calculate locally for display
    final validTrackers = trackers.length;
    final quota = validTrackers > 0 ? total / validTrackers : 0.0;
    
    final collected = trackers
        .where((t) => t.status == PaymentStatus.paid)
        .fold(0.0, (sum, t) => sum + (t.amountOwe > 0 ? t.amountOwe : quota)); // Use cached or calculated

    if (mounted) {
      setState(() {
        _budgetItems = items;
        _trackers = trackers;
        _totalBudget = total;
        _amountCollected = collected;
        _quotaPerPerson = quota;
        _isLoading = false;
      });
    }
  }
  
  Future<void> _addItem() async {
      final descController = TextEditingController();
      final amountController = TextEditingController();
      String selectedCat = 'Hospedaje';
      
      await showDialog(context: context, builder: (ctx) => AlertDialog(
          title: const Text("Agregar al Presupuesto"),
          content: StatefulBuilder(builder: (ctx, setSt) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  DropdownButton<String>(
                      value: selectedCat,
                      isExpanded: true,
                      items: ['Hospedaje', 'Alimentación', 'Transporte', 'Entretenimiento', 'Otros'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setSt(() => selectedCat = v!),
                  ),
                  TextField(controller: descController, decoration: const InputDecoration(labelText: "Descripción (Opcional)")),
                  TextField(controller: amountController, decoration: const InputDecoration(labelText: "Monto Estimado"), keyboardType: TextInputType.number),
              ],
          )),
          actions: [
              TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")),
              ElevatedButton(onPressed: () async {
                  if (amountController.text.isEmpty) return;
                  try {
                    await _repository.addBudgetItem({
                       'plan_id': widget.planId,
                       'category': selectedCat,
                       'description': descController.text,
                       'estimated_amount': double.tryParse(amountController.text) ?? 0,
                    });
                    // Auto Recalc Quotas? ideally yes.
                    await _repository.recalculateQuotas(widget.planId);
                    Navigator.pop(ctx);
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Item agregado")));
                  } catch(e) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                    print("ERROR ADDING BUDGET ITEM: $e");
                  }
              }, child: const Text("Agregar"))
          ],
      ));
  }
  
  Future<void> _addGuest() async {
      final nameCtrl = TextEditingController();
      await showDialog(context: context, builder: (ctx) => AlertDialog(
          title: const Text("Agregar Participante (Invitado)"),
          content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nombre")),
          actions: [
               TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")),
               ElevatedButton(onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  try {
                    await _repository.addGuestTracker(widget.planId, nameCtrl.text);
                    await _repository.recalculateQuotas(widget.planId); // Update quotas since N changed
                    Navigator.pop(ctx);
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Participante agregado")));
                  } catch(e) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                    print("ERROR ADDING GUEST: $e");
                  }
               }, child: const Text("Agregar"))
          ],
      ));
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalBudget > 0 ? (_amountCollected / _totalBudget) : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text("Presupuesto & Recaudo")),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : Column(
        children: [
          // SUMMARY HEADER
          Container(
             padding: const EdgeInsets.all(20),
             margin: const EdgeInsets.all(16),
             decoration: BoxDecoration(
                 gradient: const LinearGradient(colors: [AppTheme.primaryBrand, AppTheme.secondaryBrand]),
                 borderRadius: BorderRadius.circular(20),
                 boxShadow: [BoxShadow(color: AppTheme.primaryBrand.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
             ),
             child: Row(
               children: [
                   // Progress Circle
                   SizedBox(
                       width: 80, height: 80,
                       child: Stack(
                           fit: StackFit.expand,
                           children: [
                               CircularProgressIndicator(value: progress, color: Colors.white, backgroundColor: Colors.white24, strokeWidth: 8),
                               Center(child: Text("${(progress*100).toInt()}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                           ],
                       ),
                   ),
                   const SizedBox(width: 20),
                   Expanded(child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                           Text("\$${_totalBudget.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                           const Text("Presupuesto Total", style: TextStyle(color: Colors.white70, fontSize: 12)),
                           const SizedBox(height: 8),
                           Container(
                               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                               decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                               child: Text("Cuota: \$${_quotaPerPerson.toStringAsFixed(0)} / pers", style: const TextStyle(color: Colors.white, fontSize: 13)),
                           )
                       ],
                   ))
               ],
             ),
          ),
          
          // TABS
          TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryBrand,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryBrand,
              tabs: const [Tab(text: "Calculadora"), Tab(text: "Participantes")],
          ),
          
          Expanded(
              child: TabBarView(
                  controller: _tabController,
                  children: [
                      // TAB 1: CALCULATOR
                      ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                              ..._budgetItems.map((item) => Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                      leading: CircleAvatar(
                                          backgroundColor: Colors.blue[50], 
                                          child: Icon(_getIconForCat(item.category), color: Colors.blue[800])
                                      ),
                                      title: Text(item.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: item.description != null ? Text(item.description!) : null,
                                      trailing: Text("\$${item.estimatedAmount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 16)),
                                      onLongPress: () async {
                                          await _repository.deleteBudgetItem(item.id);
                                          _loadData();
                                      },
                                  ),
                              )),
                              
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                  onPressed: _addItem, 
                                  icon: const Icon(Icons.add_circle_outline), 
                                  label: const Text("Agregar Item al Presupuesto"),
                                  style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      backgroundColor: Colors.grey[100],
                                      foregroundColor: Colors.black87,
                                      elevation: 0
                                  ),
                              )
                          ],
                      ),
                      
                      // TAB 2: PARTICIPANTS
                      ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                              ..._trackers.map((t) => Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      leading: CircleAvatar(
                                          backgroundColor: _getColorForStatus(t.status).withOpacity(0.1),
                                          child: Text(t.displayName[0].toUpperCase(), style: TextStyle(color: _getColorForStatus(t.status))),
                                      ),
                                      title: Text(t.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text(
                                          _getTextForStatus(t.status).toUpperCase(), 
                                          style: TextStyle(fontSize: 10, color: _getColorForStatus(t.status), fontWeight: FontWeight.bold)
                                      ),
                                      trailing: t.status == PaymentStatus.paid 
                                        ? const Icon(Icons.check_circle, color: Colors.green)
                                        : PopupMenuButton<PaymentStatus>(
                                            onSelected: (s) async {
                                                await _repository.updatePaymentStatus(t.id, s);
                                                _loadData();
                                            },
                                            itemBuilder: (c) => [
                                                const PopupMenuItem(value: PaymentStatus.pending, child: Text("Pendiente 🔴")),
                                                const PopupMenuItem(value: PaymentStatus.verifying, child: Text("Verificando 🟡")),
                                                const PopupMenuItem(value: PaymentStatus.paid, child: Text("Pagado 🟢")),
                                            ],
                                            child: Chip(label: const Text("Cambiar"), backgroundColor: Colors.grey[100]),
                                        ),
                                  ),
                              )),
                              
                              ElevatedButton.icon(
                                  onPressed: _addGuest, 
                                  icon: const Icon(Icons.person_add), 
                                  label: const Text("Agregar Participante Extra"),
                              )
                          ],
                      )
                  ],
              )
          )
        ],
      )
    );
  }
  
  IconData _getIconForCat(String cat) {
      switch(cat) {
          case 'Hospedaje': return Icons.hotel;
          case 'Alimentación': return Icons.restaurant;
          case 'Transporte': return Icons.directions_bus;
          case 'Entretenimiento': return Icons.attractions;
          default: return Icons.category;
      }
  }
  
  Color _getColorForStatus(PaymentStatus s) {
      switch(s) {
          case PaymentStatus.paid: return Colors.green;
          case PaymentStatus.verifying: return Colors.orange;
          default: return Colors.red;
      }
  }
  
  String _getTextForStatus(PaymentStatus s) {
      switch(s) {
          case PaymentStatus.paid: return "Pagado";
          case PaymentStatus.verifying: return "Verificando Pago";
          default: return "Pendiente";
      }
  }
}
