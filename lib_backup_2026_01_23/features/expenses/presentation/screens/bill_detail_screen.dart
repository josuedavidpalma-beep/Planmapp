import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/expenses/domain/models/bill_model.dart';
import 'package:planmapp/features/expenses/domain/models/bill_item_model.dart';
import 'package:planmapp/features/expenses/domain/services/bill_service.dart';
import 'package:planmapp/features/expenses/domain/services/bill_calculator.dart';
import 'package:planmapp/core/utils/currency_formatter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:planmapp/features/plans/services/plan_members_service.dart'; // To pick assignees

class BillDetailScreen extends StatefulWidget {
  final String billId;
  final String planId;

  const BillDetailScreen({super.key, required this.billId, required this.planId});

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> with SingleTickerProviderStateMixin {
  final BillService _billService = BillService();
  final PlanMembersService _membersService = PlanMembersService();
  
  Bill? _bill;
  List<BillItem> _items = [];
  Map<String, Map<String, dynamic>> _members = {}; // Cache: id -> profile
  bool _isLoading = true;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final bill = await _billService.getBillRefreshed(widget.billId);
      final items = await _billService.getBillItems(widget.billId);
      final membersList = await _membersService.getMembers(widget.planId);
      
      // Convert members list to map for easier lookup
      final memberMap = <String, Map<String, dynamic>>{};
      for (var m in membersList) {
          memberMap[m.id] = {
             'full_name': m.name,
             'avatar_url': m.avatarUrl,
             'role': m.role
          };
      }

      if (mounted) {
        setState(() {
          _bill = bill;
          _items = items;
          _members = memberMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- ACTIONS ---

  void _addItem() async {
      // Show Dialog to add Item
      final nameCtrl = TextEditingController();
      final priceCtrl = TextEditingController();
      final qtyCtrl = TextEditingController(text: '1');
      
      await showDialog(
          context: context,
          builder: (context) => AlertDialog(
              title: const Text("Agregar Ítem"),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nombre (ej. Cerveza)")),
                      TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "Precio Unitario"), keyboardType: TextInputType.number),
                      TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: "Cantidad"), keyboardType: TextInputType.number),
                  ],
              ),
              actions: [
                  TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Cancelar")),
                  ElevatedButton(
                      onPressed: () async {
                          if(nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
                          
                          final price = double.tryParse(priceCtrl.text) ?? 0;
                          final qty = int.tryParse(qtyCtrl.text) ?? 1;
                          
                          await _billService.addBillItem(widget.billId, nameCtrl.text, price, qty);
                          if(mounted) {
                              Navigator.pop(context);
                              _loadData();
                          }
                      },
                      child: const Text("Agregar")
                  )
              ],
          )
      );
  }
  
  void _toggleAssignment(BillItem item, String userId) async {
       // Optimistic Update? For now wait for server
       await _billService.toggleAssignment(item.id, userId);
       _loadData();
  }

  void _editBillSettings() async {
      final tipCtrl = TextEditingController(text: ((_bill?.tipRate ?? 0) * 100).toStringAsFixed(0));
      final taxCtrl = TextEditingController(text: ((_bill?.taxRate ?? 0) * 100).toStringAsFixed(0));
      
      await showDialog(
          context: context,
          builder: (context) => AlertDialog(
              title: const Text("Configuración"),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      const Text("Define los porcentajes para el cálculo automático."),
                      const SizedBox(height: 16),
                      TextField(
                          controller: tipCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Propina (%)", suffixText: "%", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                          controller: taxCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Impuestos / IVA (%)", suffixText: "%", border: OutlineInputBorder()),
                      ),
                  ],
              ),
              actions: [
                  TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Cancelar")),
                  ElevatedButton(
                      onPressed: () async {
                          final tip = (double.tryParse(tipCtrl.text) ?? 0) / 100;
                          final tax = (double.tryParse(taxCtrl.text) ?? 0) / 100;
                          
                          await _billService.updateBillTotals(widget.billId, tipRate: tip, taxRate: tax);
                          if (mounted) {
                              Navigator.pop(context);
                              _loadData();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Configuración actualizada")));
                          }
                      },
                      child: const Text("Guardar")
                  )
              ],
          )
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _bill == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    // Calculate Split Live
    final participantIds = _members.keys.toList();
    // Ensure payer is in list if not member (unlikely)
    if (!participantIds.contains(_bill!.payerId)) participantIds.add(_bill!.payerId);
    
    final splitResults = BillCalculator.calculateSplit(_bill!, _items, participantIds);

    return Scaffold(
        appBar: AppBar(
            title: Text(_bill!.title),
            actions: [
                IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: "Configurar Cuenta",
                    onPressed: _editBillSettings,
                )
            ],
            bottom: TabBar(
                controller: _tabController,
                tabs: const [
                    Tab(text: "Ítems"),
                    Tab(text: "Resumen"),
                ],
            ),
        ),
        body: TabBarView(
            controller: _tabController,
            children: [
                _buildItemsTab(participantIds),
                _buildSummaryTab(splitResults),
            ],
        ),
        floatingActionButton: _tabController.index == 0 ? FloatingActionButton(
            onPressed: _addItem,
            child: const Icon(Icons.add),
        ) : null,
    );
  }

  Widget _buildItemsTab(List<String> participantIds) {
      return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: _items.length,
          itemBuilder: (context, index) {
              final item = _items[index];
              return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ExpansionTile(
                      title: Row(
                          children: [
                              Text("${item.quantity}x ", style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBrand)),
                              Expanded(child: Text(item.name)),
                              Text(CurrencyInputFormatter.format(item.totalPrice), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                      ),
                      subtitle: Text(
                          item.assigneeIds.isEmpty ? "Sin asignar (Todos pagan)" : "Asignado a: ${item.assigneeIds.length} persona(s)",
                          style: TextStyle(color: item.assigneeIds.isEmpty ? Colors.orange : Colors.grey, fontSize: 12),
                      ),
                      children: [
                          Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: participantIds.map((uid) {
                                  final isAssigned = item.assigneeIds.contains(uid);
                                  final profile = _members[uid];
                                  final name = profile?['full_name']?.split(' ')[0] ?? 'User';
                                  
                                  return FilterChip(
                                      label: Text(name),
                                      selected: isAssigned,
                                      avatar: profile?['avatar_url'] != null ? CircleAvatar(backgroundImage: NetworkImage(profile!['avatar_url'])) : null,
                                      onSelected: (_) => _toggleAssignment(item, uid),
                                  );
                              }).toList(),
                          ),
                          const SizedBox(height: 12),
                      ],
                  ),
              ).animate().fade().slideY(begin: 0.1);
          },
      );
  }

  Widget _buildSummaryTab(Map<String, UserBillShare> results) {
       return ListView(
           padding: const EdgeInsets.all(16),
           children: [
               // Header Card
               Card(
                   color: AppTheme.primaryBrand,
                   child: Padding(
                       padding: const EdgeInsets.all(16),
                       child: Column(
                           children: [
                               const Text("Total Cuenta", style: TextStyle(color: Colors.white70)),
                               Text(CurrencyInputFormatter.format(_bill!.totalAmount), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                               const Divider(color: Colors.white24),
                               Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceAround,
                                   children: [
                                       Column(children: [const Text("Items", style: TextStyle(color: Colors.white70, fontSize: 12)), Text(CurrencyInputFormatter.format(_bill!.subtotal), style: const TextStyle(color: Colors.white))]),
                                       Column(children: [const Text("Propina", style: TextStyle(color: Colors.white70, fontSize: 12)), Text(CurrencyInputFormatter.format(_bill!.tipAmount), style: const TextStyle(color: Colors.white))]),
                                       Column(children: [const Text("Impuesto", style: TextStyle(color: Colors.white70, fontSize: 12)), Text(CurrencyInputFormatter.format(_bill!.taxAmount), style: const TextStyle(color: Colors.white))]),
                                   ],
                               )
                           ],
                       ),
                   ),
               ),
               const SizedBox(height: 24),
               const Text("Quién debe cuánto", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
               const SizedBox(height: 12),
               ...results.values.map((share) {
                   final profile = _members[share.userId];
                   final name = profile?['full_name'] ?? 'Usuario';
                   
                   return ListTile(
                       contentPadding: EdgeInsets.zero,
                       leading: CircleAvatar(backgroundImage: profile?['avatar_url'] != null ? NetworkImage(profile!['avatar_url']) : null, child: profile?['avatar_url'] == null ? Text(name[0]) : null),
                       title: Text(name),
                       subtitle: Text("Subtotal: ${CurrencyInputFormatter.format(share.subtotal)} + Extras: ${CurrencyInputFormatter.format(share.taxShare + share.tipShare)}"),
                       trailing: Text(CurrencyInputFormatter.format(share.totalOwed), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                   );
               })
           ],
       );
  }
}
