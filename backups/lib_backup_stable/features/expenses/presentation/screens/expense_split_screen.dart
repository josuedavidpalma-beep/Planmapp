
import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/expenses/data/models/expense_model.dart';
import 'package:planmapp/features/expenses/data/repositories/expense_repository.dart';
import 'package:planmapp/features/plans/services/plan_members_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpenseSplitScreen extends StatefulWidget {
  final Map<String, dynamic> expenseData; // passed from Add/Scan screen
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

  // State: Map ItemID -> List of Assignments
  final Map<String, List<AssignmentModel>> _assignments = {};

  // Temporary guests just for this session
  final List<String> _tempGuests = [];

  @override
  void initState() {
    super.initState();
    _expenseRepository = ExpenseRepository(Supabase.instance.client);
    _items = widget.initialItems;
    
    // Initialize empty assignments
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
            
            // AUTO SPLIT LOGIC
            if (widget.autoSplitAll) {
                // Wait a microtask to ensure state is settled or just run it
                for (var item in _items) {
                    _splitEqually(item.id);
                }
            }
        }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // Logic to update assignment quantity
  void _updateQuantity(String itemId, String? userId, String? guestName, double delta) {
    setState(() {
      final list = _assignments[itemId]!;
      // Find existing
      final index = list.indexWhere((a) => (userId != null && a.userId == userId) || (guestName != null && a.guestName == guestName));
      
      if (index != -1) {
        final current = list[index];
        final newQty = current.quantity + delta;
        if (newQty <= 0) {
          list.removeAt(index);
        } else {
          list[index] = AssignmentModel(userId: userId, guestName: guestName, quantity: newQty);
        }
      } else if (delta > 0) {
        list.add(AssignmentModel(userId: userId, guestName: guestName, quantity: delta));
      }
    });
  }

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
      // Find total participants
      final count = _members.length + _tempGuests.length;
      if (count == 0) return;
      
      // We assume Item Quantity is always 1 for things like Tips.
      // But if it's 10 beers, we split 10 beers.
      // Current Assignment logic uses specific quantities.
      // Strategy: Give everyone (TotalQty / Count)
      // Simplification: We use quantity 1 for assignments if item.quantity is 1?
      // No, let's just do: Amount per person = ItemQty / Count.
      
      final item = _items.firstWhere((i) => i.id == itemId);
      final qtyPerPerson = item.quantity / count;
      
      setState(() {
          _assignments[itemId] = []; // Reset first
          for (var m in _members) {
              _assignments[itemId]!.add(AssignmentModel(userId: m.id, quantity: qtyPerPerson));
          }
          for (var g in _tempGuests) {
               _assignments[itemId]!.add(AssignmentModel(guestName: g, quantity: qtyPerPerson));
          }
      });
  }

  Future<void> _saveExpense() async {
      setState(() => _isSaving = true);
      try {
          // Prepare items with assignments
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
              Navigator.pop(context, true); // Return success
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
                            final missing = item.quantity - totalAssigned;
                            final isComplete = missing <= 0.1 && missing >= -0.1;
                            
                            return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                shape: RoundedRectangleBorder(
                                    side: BorderSide(color: isComplete ? Colors.green.withOpacity(0.5) : Colors.orange.withOpacity(0.5), width: 2),
                                    borderRadius: BorderRadius.circular(12)
                                ),
                                child: ExpansionTile(
                                    initiallyExpanded: true,
                                    title: Row(children: [
                                        Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                                        Text("\$${item.price.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        IconButton(
                                            icon: const Icon(Icons.groups, color: AppTheme.primaryBrand),
                                            tooltip: "Dividir entre todos",
                                            onPressed: () => _splitEqually(item.id),
                                        )
                                    ]),
                                    subtitle: Text(
                                        "Cant: ${item.quantity} | Asignado: ${totalAssigned.toStringAsFixed(1)}",
                                        style: TextStyle(color: isComplete ? Colors.green : Colors.orange)
                                    ),
                                    children: [
                                        // List Members
                                        Column(children: _members.map((m) {
                                            if (m.isGuest) {
                                                // Handle mocked guests from service (e.g. "guest_1")
                                                // We treat them as guests, using their name/ID as guestName, NOT userId
                                                return _buildRow(item.id, m.name, guestName: m.name); // Use Name as key
                                            }
                                            return _buildRow(item.id, m.name, userId: m.id);
                                        }).toList()),
                                        if (_tempGuests.isNotEmpty) const Divider(),
                                        // List Guests
                                        Column(children: _tempGuests.map((g) => _buildRow(item.id, "$g (Inv)", guestName: g)).toList()),
                                        const SizedBox(height: 12),
                                    ],
                                ),
                            );
                        },
                    )
                ),
                Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)]),
                    child: SafeArea(
                        child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveExpense,
                            style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                backgroundColor: AppTheme.primaryBrand,
                                foregroundColor: Colors.white
                            ),
                            child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Guardar Gasto", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        )
                    )
                )
            ],
        ),
    );
  }

  Widget _buildRow(String itemId, String name, {String? userId, String? guestName}) {
      final qty = _getAssignedQty(itemId, userId, guestName);
      final isAssigned = qty > 0;
      
      return Container(
          color: isAssigned ? Colors.blue.withOpacity(0.05) : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
              children: [
                  Expanded(child: Text(name, style: TextStyle(fontWeight: isAssigned ? FontWeight.bold : FontWeight.normal))),
                  if (isAssigned) Text(qty.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(width: 8),
                  IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.grey), 
                      onPressed: () => _updateQuantity(itemId, userId, guestName, -0.5),
                      constraints: const BoxConstraints(),
                  ),
                  IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.blue), 
                      onPressed: () => _updateQuantity(itemId, userId, guestName, 0.5),
                      constraints: const BoxConstraints(),
                  ),
              ],
          ),
      );
  }
}
