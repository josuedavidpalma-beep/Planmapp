
import 'package:flutter/material.dart';
import 'package:planmapp/core/utils/currency_formatter.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/expenses/data/models/expense_model.dart';
import 'package:planmapp/features/expenses/data/repositories/expense_repository.dart';
import 'package:planmapp/features/plans/services/plan_members_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpenseSplitScreen extends StatefulWidget {
  final Map<String, dynamic> expenseData;
  final List<ExpenseItem> initialItems;
  final bool autoSplitAll;

  const ExpenseSplitScreen({super.key, required this.expenseData, required this.initialItems, this.autoSplitAll = false});

  @override
  State<ExpenseSplitScreen> createState() => _ExpenseSplitScreenState();
}

class _ExpenseSplitScreenState extends State<ExpenseSplitScreen> {
  final _membersService = PlanMembersService();
  late ExpenseRepository _expenseRepository;
  
  List<PlanMember> _members = [];
  List<ExpenseItem> _items = [];
  bool _isLoading = true;
  bool _isSaving = false;

  final Map<String, List<AssignmentModel>> _assignments = {};
  final List<String> _tempGuests = [];

  @override
  void initState() {
    super.initState();
    _expenseRepository = ExpenseRepository(Supabase.instance.client);
    _items = widget.initialItems;
    
    for (var item in _items) {
      _assignments[item.id] = [];
    }
    
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final planId = widget.expenseData['plan_id'];
    if (planId != null) {
        final members = await _membersService.getMembers(planId);
        if (mounted) {
            setState(() => _members = members);
            if (widget.autoSplitAll) {
                for (var item in _items) _splitEqually(item.id);
            }
        }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _updateQuantity(String itemId, String? userId, String? guestName, double newQty) {
    setState(() {
      final list = _assignments[itemId]!;
      final index = list.indexWhere((a) => (userId != null && a.userId == userId) || (guestName != null && a.guestName == guestName));
      
      if (newQty <= 0.001) {
        if (index != -1) list.removeAt(index);
      } else {
        if (index != -1) {
          list[index] = AssignmentModel(userId: userId, guestName: guestName, quantity: newQty);
        } else {
          list.add(AssignmentModel(userId: userId, guestName: guestName, quantity: newQty));
        }
      }
    });
  }

  // Gets explicitly assigned quantity (fraction of item)
  double _getAssignedQty(String itemId, String? userId, String? guestName) {
      final list = _assignments[itemId]!;
      final found = list.firstWhere(
          (a) => (userId != null && a.userId == userId) || (guestName != null && a.guestName == guestName), 
          orElse: () => const AssignmentModel(quantity: 0)
      );
      return found.quantity;
  }
  
  void _addGuestName() async {
      final c = TextEditingController();
      await showDialog(context: context, builder: (ctx) => AlertDialog(
          title: const Text("Nombre del Invitado"),
          content: TextField(controller: c, decoration: const InputDecoration(hintText: "Ej. Primo de Ana")),
          actions: [
              TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")),
              ElevatedButton(onPressed: (){
                  if(c.text.isNotEmpty) {
                      setState(() => _tempGuests.add(c.text));
                      Navigator.pop(ctx);
                  }
              }, child: const Text("Agregar"))
          ],
      ));
  }

  void _splitEqually(String itemId) {
      final count = _members.length + _tempGuests.length;
      if (count == 0) return;
      final item = _items.firstWhere((i) => i.id == itemId);
      final qtyPerPerson = item.quantity / count;
      
      setState(() {
          _assignments[itemId] = [];
          for (var m in _members) {
              _assignments[itemId]!.add(AssignmentModel(userId: m.id, quantity: qtyPerPerson));
          }
          for (var g in _tempGuests) {
               _assignments[itemId]!.add(AssignmentModel(guestName: g, quantity: qtyPerPerson));
          }
      });
  }

  // WIZARD
  void _openSplitWizard(ExpenseItem item) {
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => _WizardSheet(
              item: item, 
              members: _members, 
              guests: _tempGuests,
              currentAssignments: _assignments[item.id] ?? [],
              onApply: (newAssignments) {
                  setState(() {
                      _assignments[item.id] = newAssignments;
                  });
              }
          )
      );
  }

  Future<void> _saveExpense() async {
      setState(() => _isSaving = true);
      try {
          final itemsToSave = _items.map((item) {
             return item.toMap()..addAll({
                 'assignments': _assignments[item.id] ?? [],
             });
          }).toList();

          await _expenseRepository.createFullExpense(
              expenseData: widget.expenseData, 
              itemsData: itemsToSave
          );

          if (mounted) {
              Navigator.pop(context, true);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gasto guardado exitosamente")));
          }
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
          if (mounted) setState(() => _isSaving = false);
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dividir Items"), actions: [
          IconButton(icon: const Icon(Icons.person_add), onPressed: _addGuestName),
      ]),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
                Expanded(
                    child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (ctx, i) {
                            final item = _items[i];
                            final totalAssigned = (_assignments[item.id] ?? []).fold(0.0, (sum, a) => sum + a.quantity);
                            // Tolerance for float math
                            final missing = (item.quantity - totalAssigned);
                            final isComplete = missing.abs() < 0.05; 
                            
                            return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                shape: RoundedRectangleBorder(
                                    side: BorderSide(
                                        color: isComplete ? Colors.green.withOpacity(0.5) : Colors.orange.withOpacity(0.5), 
                                        width: 2
                                    ),
                                    borderRadius: BorderRadius.circular(12)
                                ),
                                child: Column(
                                  children: [
                                    ListTile(
                                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Text(
                                            "${item.quantity} x ${CurrencyInputFormatter.format(item.price / (item.quantity == 0 ? 1 : item.quantity))} = ${CurrencyInputFormatter.format(item.price)}\n"
                                            "${isComplete ? 'Completo' : 'Faltan: ${missing.toStringAsFixed(1)}'}",
                                            style: TextStyle(color: isComplete ? Colors.green : Colors.orange, fontSize: 12)
                                        ),
                                        trailing: ElevatedButton.icon(
                                            onPressed: () => _openSplitWizard(item),
                                            icon: const Icon(Icons.auto_fix_high, size: 16),
                                            label: const Text("Asistente"),
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.primaryBrand.withOpacity(0.1),
                                                foregroundColor: AppTheme.primaryBrand,
                                                elevation: 0
                                            ),
                                        ),
                                    ),
                                    // Mini preview of who pays
                                    if ((_assignments[item.id] ?? []).isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        child: Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: (_assignments[item.id] ?? []).map((a) {
                                                final name = a.userId != null 
                                                    ? (_members.firstWhere((m) => m.id == a.userId, orElse: () => PlanMember(id: '', name: '?', isGuest: false)).name)
                                                    : (a.guestName ?? "?");
                                                return Chip(
                                                    label: Text(
                                                        "$name: ${a.quantity < 1 ? '${(a.quantity*100).toInt()}%' : a.quantity.toStringAsFixed(1)}", // Show % if < 1 (fraction) or Qty if > 1
                                                        style: const TextStyle(fontSize: 10)
                                                    ),
                                                    backgroundColor: Colors.grey[100],
                                                    padding: EdgeInsets.zero,
                                                    visualDensity: VisualDensity.compact,
                                                );
                                            }).toList(),
                                        ),
                                      )
                                  ],
                                ),
                            );
                        },
                    )
                ),
                Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)]),
                    child: SafeArea(
                        child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveExpense,
                            style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                backgroundColor: AppTheme.primaryBrand,
                                foregroundColor: Colors.white
                            ),
                            child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Guardar Todo", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        )
                    )
                )
            ],
        ),
    );
  }
}

// ----------------------
// WIZARD WIDGET
// ----------------------
class _WizardSheet extends StatefulWidget {
  final ExpenseItem item;
  final List<PlanMember> members;
  final List<String> guests;
  final List<AssignmentModel> currentAssignments;
  final Function(List<AssignmentModel>) onApply;

  const _WizardSheet({required this.item, required this.members, required this.guests, required this.currentAssignments, required this.onApply});

  @override
  State<_WizardSheet> createState() => _WizardSheetState();
}

class _WizardSheetState extends State<_WizardSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, double> _tempValues = {}; // Holds Qty, Percent, or Amount depending on tab

  @override
  void initState() {
      super.initState();
      _tabController = TabController(length: 4, vsync: this); // NEW Length 4
      
      // Initialize with current quantities
      _initValuesFromCurrent();
  }

  // ... (existing code)

  void _save() {
      List<AssignmentModel> result = [];
      
      final unitPrice = widget.item.price / widget.item.quantity; 

      // Pre-calculation for Mode -1 (Checkbox)
      double splitShare = 0;
      if (_tabController.index == 0) { // Checkbox Mode is now Index 0
          final selectedCount = _tempValues.values.where((v) => v > 0).length;
          if (selectedCount > 0) {
              splitShare = widget.item.quantity / selectedCount;
          }
      }

      _tempValues.forEach((key, val) {
          if (val <= 0) return;
          
          double finalQty = 0;
          
          if (_tabController.index == 0) { // Checkbox
              // If val > 0 (checked), assign share
              finalQty = splitShare;
          } else if (_tabController.index == 1) { // Units (Previously 0)
              finalQty = val;
          } else if (_tabController.index == 2) { // % (Previously 1)
              finalQty = (val / 100) * widget.item.quantity;
          } else { // Amount (Previously 2)
              if (unitPrice > 0) finalQty = val / unitPrice;
          }

          if (key.startsWith("u_")) {
              result.add(AssignmentModel(userId: key.substring(2), quantity: finalQty));
          } else if (key.startsWith("g_")) {
               result.add(AssignmentModel(guestName: key.substring(2), quantity: finalQty));
          }
      });
      
      widget.onApply(result);
      Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
      return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  const SizedBox(height: 16),
                  Text("Dividir: ${widget.item.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(CurrencyInputFormatter.format(widget.item.price), style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  TabBar(
                      controller: _tabController,
                      labelColor: AppTheme.primaryBrand,
                      indicatorColor: AppTheme.primaryBrand,
                      isScrollable: true, // Allow more tabs
                      onTap: (index) {
                          setState(() {
                              final newValues = <String, double>{};
                              // Reset values when switching tabs to avoid confusion
                              // In a real app we might try to convert, but for simplicity we reset.
                              _tempValues.clear();
                              _tempValues.addAll(newValues);
                          });
                      },
                      tabs: const [
                          Tab(text: "Selección"), // New 0
                          Tab(text: "Unidades"), // Old 0 -> 1
                          Tab(text: "%"), // Old 1 -> 2
                          Tab(text: "\$"), // Old 2 -> 3
                      ]
                  ),
                  SizedBox(
                      height: 300,
                      child: TabBarView(
                          controller: _tabController,
                          children: [
                              _buildList(mode: -1), // Checkbox mode
                              _buildList(mode: 0),
                              _buildList(mode: 1),
                              _buildList(mode: 2),
                          ],
                      ),
                  ),
                  Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
                          child: const Text("Aplicar División"),
                      ),
                  )
              ],
          ),
      );
  }

  Widget _buildList({required int mode}) {
      // mode -1: Checkbox (Select multiple)
      // mode 0: Qty (Counter)
      // mode 1: Percent (Slider/Input)
      // mode 2: Amount (Currency Input)
      
      final keys = [...widget.members.map((m) => "u_${m.id}"), ...widget.guests.map((g) => "g_$g")];
      
      return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: keys.length,
          separatorBuilder: (_,__) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
              final key = keys[i];
              final name = key.startsWith("u_") 
                  ? widget.members.firstWhere((m) => m.id == key.substring(2)).name
                  : "${key.substring(2)} (Inv)";
              
              final val = _tempValues[key] ?? 0.0;

              return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                      children: [
                          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
                          if (mode == -1) ...[
                               Checkbox(
                                  value: val > 0, 
                                  activeColor: AppTheme.primaryBrand,
                                  onChanged: (isSelected) {
                                      setState(() {
                                          _tempValues[key] = (isSelected == true) ? 1.0 : 0.0;
                                      });
                                  }
                               )
                          ] else if (mode == 0) ...[
                               IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setState(() => _tempValues[key] = (val - 0.5).clamp(0, 999))),
                               Text(val.toStringAsFixed(1), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                               IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => _tempValues[key] = val + 0.5)),
                          ] else if (mode == 1) ...[
                               Expanded(
                                   flex: 2,
                                   child: Slider(
                                       value: val.clamp(0, 100), 
                                       max: 100, 
                                       onChanged: (v) => setState(() => _tempValues[key] = v),
                                       activeColor: AppTheme.primaryBrand,
                                   )
                               ),
                               Text("${val.toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ] else ...[
                               SizedBox(
                                   width: 100,
                                   child: TextField(
                                       keyboardType: TextInputType.number,
                                       decoration: const InputDecoration(prefixText: "\$", isDense: true, contentPadding: EdgeInsets.all(8), border: OutlineInputBorder()),
                                       onChanged: (str) {
                                            final parsed = double.tryParse(str) ?? 0;
                                            _tempValues[key] = parsed;
                                       },
                                       // No controller sync for simplicity in this MVP snippet, relying on onChanged
                                   )
                               )
                          ]
                      ],
                  ),
              );
          },
      );
  }
}
