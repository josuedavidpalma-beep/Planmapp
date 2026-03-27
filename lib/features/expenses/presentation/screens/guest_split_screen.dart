import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/core/utils/currency_formatter.dart';
import 'package:planmapp/features/expenses/presentation/screens/payment_summary_screen.dart';
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
  
  // Local state for the current guest: Set of item IDs they clicked 'Mío' on.
  Set<String> _mySelectedItems = {};

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
                  _mySelectedItems.add(iId);
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

  void _toggleMine(String itemId) {
      setState(() {
          if (_mySelectedItems.contains(itemId)) {
              _mySelectedItems.remove(itemId);
          } else {
              _mySelectedItems.add(itemId);
          }
      });
  }

  Future<void> _saveAndCalculate() async {
      setState(() => _isSaving = true);
      try {
          final supabase = Supabase.instance.client;
          // IMPORTANT: Because RLS or concurrent guests, a robust app would use an RPC or serverless function.
          // For MVP: We assume the anonymous user/guest has insert permissions or is bypassing via Edge Function.
          // Since we might hit an RLS wall with unauthenticated guest inserts, we'll try to insert using an RPC
          // or direct insert if policy allows.
          
          List<Map<String, dynamic>> newAssignments = [];
          for (var itemId in _mySelectedItems) {
              newAssignments.add({
                  'expense_item_id': itemId,
                  'user_id': widget.guestUid.startsWith('guest_') ? null : widget.guestUid,
                  'guest_name': widget.guestUid,
                  'quantity': 1.0, // Default 1 portion. Recalculated mathematically later by the owner or here.
              });
          }
          
          // Delete prior inserts from this guest
          await supabase.from('expense_assignments')
              .delete()
              .inFilter('expense_item_id', _items.map((e)=>e['id']).toList())
              .eq('guest_name', widget.guestUid);
              
          if (newAssignments.isNotEmpty) {
              await supabase.from('expense_assignments').insert(newAssignments);
          }

          // We'll calculate a local debt for the summary screen just for UX speed, 
          // or we can call a function. Local math is faster:
          double myDebt = 0.0;
          for (var itemId in _mySelectedItems) {
               final item = _items.firstWhere((i) => i['id'] == itemId);
               final itemPrice = (item['price'] as num).toDouble();
               
               // Count how many people include me in this item
               int peopleCount = 1; // Me
               for (var a in (_allAssignments[itemId] ?? [])) {
                   if (a['guest_name'] != widget.guestUid && a['user_id'] != widget.guestUid) {
                       peopleCount++;
                   }
               }
               myDebt += (itemPrice / peopleCount);
          }
          
          // Prorate taxes/tips
          final double subtotal = (_expenseData['subtotal'] as num?)?.toDouble() ?? 0.0;
          final double tax = (_expenseData['tax_amount'] as num?)?.toDouble() ?? 0.0;
          final double tip = (_expenseData['tip_amount'] as num?)?.toDouble() ?? 0.0;
          
          if (subtotal > 0 && (tax > 0 || tip > 0)) {
              final proportion = myDebt / subtotal;
              myDebt += ((tax + tip) * proportion);
          }

          // 3. Save my status
          await supabase.from('expense_participant_status')
              .delete()
              .eq('expense_id', widget.expenseId)
              .eq('guest_name', widget.guestUid);
              
          if (myDebt > 0) {
              await supabase.from('expense_participant_status').insert({
                  'expense_id': widget.expenseId,
                  'guest_name': widget.guestUid,
                  'amount_owed': myDebt,
                  'is_paid': false
              });
          }

          // Navigate to summary
          if (mounted) {
              final debtMap = {
                  'guest_name': widget.guestName,
                  'amount_owed': myDebt,
              };
              List<dynamic> paymentMethods = [];
              if (_expenseData['payment_method'] != null) {
                  try {
                      paymentMethods = jsonDecode(_expenseData['payment_method']);
                  } catch (_) {}
              }
              
              Navigator.pushReplacement(context, MaterialPageRoute(
                  builder: (_) => PaymentSummaryScreen(debtData: debtMap, paymentMethods: paymentMethods)
              ));
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
               Expanded(
                   child: ListView.builder(
                       padding: const EdgeInsets.all(16),
                       itemCount: _items.length,
                       itemBuilder: (ctx, i) {
                           final item = _items[i];
                           final isSelected = _mySelectedItems.contains(item['id']);
                           
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
                                           OutlinedButton(
                                               onPressed: () => _toggleMine(item['id']),
                                               style: OutlinedButton.styleFrom(
                                                   backgroundColor: isSelected ? AppTheme.primaryBrand : Colors.transparent,
                                                   foregroundColor: isSelected ? Colors.white : AppTheme.primaryBrand,
                                                   side: const BorderSide(color: AppTheme.primaryBrand),
                                               ),
                                               child: Text(isSelected ? "Seleccionado" : "Mío")
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
                           onPressed: _isSaving || _mySelectedItems.isEmpty ? null : _saveAndCalculate,
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
