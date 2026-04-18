import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/core/utils/currency_formatter.dart';
import 'package:planmapp/features/expenses/presentation/screens/payment_summary_screen.dart';
import 'package:planmapp/core/widgets/auth_guard.dart';
import 'package:planmapp/core/services/session_persistence_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GuestSplitScreen extends StatefulWidget {
  final String expenseId;
  final String guestName;
  final String guestUid;

  const GuestSplitScreen({
    super.key,
    required this.expenseId,
    required this.guestName,
    required this.guestUid,
  });

  @override
  State<GuestSplitScreen> createState() => _GuestSplitScreenState();
}

class _GuestSplitScreenState extends State<GuestSplitScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic> _expenseData = {};
  List<dynamic> _items = [];
  Map<String, List<dynamic>> _allAssignments = {};
  
  // Local state for the current guest: Map of item ID to quantity consumed
  Map<String, double> _mySelectedPortions = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final supabase = Supabase.instance.client;
      // Fetch expense info
      final expRes = await supabase.from('expenses').select('*').eq('id', widget.expenseId).single();
      
      // Fetch items
      final itemsRes = await supabase.from('expense_items').select('*').eq('expense_id', widget.expenseId);
      
      // Fetch all assignments to show who else took what
      final List<String> itemIds = (itemsRes as List).map((i) => i['id'] as String).toList();
      Map<String, List<dynamic>> assignmentsMap = {};
      
      if (itemIds.isNotEmpty) {
          final assignRes = await supabase.from('expense_assignments').select('*').inFilter('expense_item_id', itemIds);
          for (var item in itemIds) { assignmentsMap[item] = []; }
          
          for (var a in (assignRes as List)) {
              final String iId = a['expense_item_id'];
              assignmentsMap[iId]?.add(a);
              
              // If previously selected, select it
              if (a['guest_name'] == widget.guestUid || a['user_id'] == widget.guestUid) {
                  _mySelectedPortions[iId] = (a['quantity'] as num?)?.toDouble() ?? 1.0;
              }
          }
      }

      if (mounted) {
        setState(() {
          _expenseData = expRes;
          _items = itemsRes;
          _allAssignments = assignmentsMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando la vaca: $e')));
      }
    }
  }

  Future<void> _showPortionDialog(Map<String, dynamic> item) async {
      final itemId = item['id'];
      double currentQty = _mySelectedPortions[itemId] ?? 0.0;
      
      await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (ctx) {
              return StatefulBuilder(
                  builder: (ctx, setSheetState) {
                      return Padding(
                          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                  Text("Tu parte de", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                  Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                                  const SizedBox(height: 24),
                                  
                                  Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                          _buildQuickBtn("Nada", 0.0, currentQty, setSheetState),
                                          _buildQuickBtn("1/3", 0.33, currentQty, setSheetState),
                                          _buildQuickBtn("Mitad", 0.5, currentQty, setSheetState),
                                          _buildQuickBtn("Todo", 1.0, currentQty, setSheetState),
                                      ],
                                  ),
                                  const SizedBox(height: 24),
                                  const Text("O ajusta manualmente:", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                                  Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                          IconButton(
                                              icon: const Icon(Icons.remove_circle_outline, size: 32),
                                              onPressed: () => setSheetState(() => currentQty = (currentQty - 0.5).clamp(0.0, 99.0)),
                                          ),
                                          Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                              child: Text(currentQty.toStringAsFixed(1), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                                          ),
                                          IconButton(
                                              icon: const Icon(Icons.add_circle_outline, size: 32),
                                              onPressed: () => setSheetState(() => currentQty = currentQty + 0.5),
                                          ),
                                      ]
                                  ),
                                  const SizedBox(height: 32),
                                  ElevatedButton(
                                      onPressed: () {
                                          setState(() {
                                              if (currentQty > 0) {
                                                  _mySelectedPortions[itemId] = currentQty;
                                              } else {
                                                  _mySelectedPortions.remove(itemId);
                                              }
                                          });
                                          Navigator.pop(ctx);
                                      },
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryBrand,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16)
                                      ),
                                      child: const Text("Guardar Mi Parte", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  )
                              ]
                          )
                      );
                  }
              );
          }
      );
  }

  Widget _buildQuickBtn(String label, double val, double currentQty, StateSetter setSheetState) {
      final isSelected = (currentQty - val).abs() < 0.01;
      return OutlinedButton(
          onPressed: () => setSheetState(() => currentQty = val),
          style: OutlinedButton.styleFrom(
              backgroundColor: isSelected ? AppTheme.primaryBrand : Colors.transparent,
              foregroundColor: isSelected ? Colors.white : AppTheme.primaryBrand,
          ),
          child: Text(label)
      );
  }

  Future<void> _saveAndCalculate() async {
      setState(() => _isSaving = true);
      try {
          final supabase = Supabase.instance.client;
          // BEFORE processing, demand AUTHENTICATION!
          await SessionPersistenceService.setPendingExpenseAssignment(widget.expenseId, _mySelectedPortions);
          bool authenticated = await AuthGuard.ensureAuthenticated(context);
          if (!authenticated) {
              if (mounted) setState(() => _isSaving = false);
              return;
          }
          
          final user = supabase.auth.currentUser;
          final realUid = user!.id;
          final profile = await supabase.from('profiles').select('nickname, full_name').eq('id', realUid).maybeSingle();
          final realName = (profile?['nickname']?.toString().isNotEmpty == true ? profile!['nickname'] : profile?['full_name']) ?? 'Usuario';

          // Use atomic RPC to toggle assignments!
          for (var entry in _mySelectedPortions.entries) {
              final itemId = entry.key;
              final qty = entry.value;

              await supabase.rpc('toggle_expense_assignment', params: {
                  'p_item_id': itemId,
                  'p_user_id': realUid,
                  'p_guest_name': realName,
                  'p_qty': qty
              });
          }

          if (mounted) {
              // INSTEAD of going to PaymentSummary, go to Wait Room!
              context.go('/vaca/${widget.expenseId}/wait?name=${Uri.encodeComponent(realName)}');
          }

      } catch (e) {
          if (mounted) {
             setState(() => _isSaving = false);
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error guardando: $e')));
          }
      }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
        appBar: AppBar(title: Text("Hola, ${widget.guestName}", style: const TextStyle(fontWeight: FontWeight.bold))),
        body: Column(
            children: [
                Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.blue.withOpacity(0.1),
                    child: Row(
                        children: [
                            const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text("Toca 'Añadir' para seleccionar un ítem. Si solo consumiste una parte (ej. media pizza), podrás ajustarlo ahí mismo.", style: TextStyle(fontSize: 12, color: Colors.blue[800]))),
                        ],
                    ),
                ),
                Expanded(
                    child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                       itemCount: _items.length,
                       itemBuilder: (ctx, i) {
                           final item = _items[i];
                           final qty = _mySelectedPortions[item['id']] ?? 0.0;
                           final isSelected = qty > 0;
                           
                           // Other people names
                           final List<dynamic> assignees = _allAssignments[item['id']] ?? [];
                           final List<String> otherNames = assignees
                              .where((a) => a['guest_name'] != widget.guestUid && a['user_id'] != widget.guestUid)
                              .map((a) => (a['guest_name'] ?? 'Alguien').toString().replaceAll('guest_', ''))
                              .toList();

                           return Card(
                               shape: RoundedRectangleBorder(
                                   side: BorderSide(color: isSelected ? AppTheme.primaryBrand : Colors.transparent, width: 2),
                                   borderRadius: BorderRadius.circular(12)
                               ),
                               margin: const EdgeInsets.only(bottom: 12),
                               child: Padding(
                                   padding: const EdgeInsets.all(16.0),
                                   child: Row(
                                       children: [
                                           Expanded(
                                               child: Column(
                                                   crossAxisAlignment: CrossAxisAlignment.start,
                                                   children: [
                                                       Text(item['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                                       Text(CurrencyInputFormatter.format((item['price'] as num).toDouble())),
                                                       if (otherNames.isNotEmpty) 
                                                          Padding(
                                                              padding: const EdgeInsets.only(top: 8.0),
                                                              child: Wrap(
                                                                  spacing: 4,
                                                                  children: otherNames.map((n) => Chip(
                                                                      label: Text(n, style: const TextStyle(fontSize: 10)),
                                                                      visualDensity: VisualDensity.compact,
                                                                      backgroundColor: Colors.grey[200],
                                                                  )).toList()
                                                              )
                                                          )
                                                   ]
                                               )
                                           ),
                                           Column(
                                             children: [
                                               OutlinedButton(
                                                   onPressed: () => _showPortionDialog(item),
                                                   style: OutlinedButton.styleFrom(
                                                       backgroundColor: isSelected ? AppTheme.primaryBrand : Colors.transparent,
                                                       foregroundColor: isSelected ? Colors.white : AppTheme.primaryBrand,
                                                       side: const BorderSide(color: AppTheme.primaryBrand),
                                                   ),
                                                   child: Text(isSelected ? (qty == 1.0 ? "Mío" : "${qty}x Mio") : "Añadir")
                                               ),
                                               if (isSelected && qty < 1.0)
                                                 const Text("Parte parcial", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                             ],
                                           )
                                       ]
                                   )
                               )
                           );
                       }
                   )
               ),
               Container(
                   padding: const EdgeInsets.all(16),
                   decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)]),
                   child: SafeArea(
                       child: ElevatedButton(
                           onPressed: _isSaving || _mySelectedPortions.isEmpty ? null : _saveAndCalculate,
                           style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
                           child: _isSaving 
                              ? const CircularProgressIndicator(color: Colors.white) 
                              : const Text("Confirmar mi parte", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                       )
                   )
               )
            ]
        )
    );
  }
}
