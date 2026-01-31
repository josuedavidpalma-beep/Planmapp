import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/expenses/data/models/expense_model.dart';
import 'package:planmapp/features/expenses/data/repositories/expense_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final Expense expense;

  const ExpenseDetailScreen({super.key, required this.expense});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  // We need to fetch the PARTICIPANT STATUS from the new table
  // For MVP, we'll just use the granular assignments to calculate "Who Owes What"
  // And we need a way to track "Paid". 
  // Since we haven't built the full "ExpenseParticipantStatus" fetching logic in repo yet,
  // I'll add a simple local toggling or basic implementation.
  // Actually, let's implement the basic view first.

  late double _myShare;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _calculateShare();
  }

  void _calculateShare() {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      double myTotal = 0;
      
      // Iterate all items -> assignments
      // This requires the expense object to have items loaded with assignments (nested).
      // The current list view might not return deep nested data. 
      // We might need to fetch details.
      
      for (var item in widget.expense.items ?? []) {
          // Calculate item unit price (Price / Sum of quantities)
          double assignedQtySum = item.assignments.fold(0.0, (sum, a) => sum + a.quantity);
          if (assignedQtySum == 0) continue; // Avoid div by zero
          
          double costPerUnit = item.price / assignedQtySum; // We assume price is total price of item row
          
          // Find my assignment
          for (var a in item.assignments) {
              if (a.userId == uid) {
                  myTotal += (a.quantity * costPerUnit);
              }
          }
      }
      _myShare = myTotal;
  }

  @override
  Widget build(BuildContext context) {
    final date = "${widget.expense.createdAt.day}/${widget.expense.createdAt.month}";
    
    return Scaffold(
      appBar: AppBar(title: const Text("Detalle del Gasto")),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // Header Card
                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [AppTheme.primaryBrand, AppTheme.secondaryBrand],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                              BoxShadow(color: AppTheme.primaryBrand.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))
                          ]
                      ),
                      child: Column(
                          children: [
                              Text(widget.expense.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black26, blurRadius: 4)])),
                              const SizedBox(height: 8),
                              Text("\$${widget.expense.totalAmount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 12),
                              Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                          const Icon(Icons.credit_card, color: Colors.white, size: 16),
                                          const SizedBox(width: 8),
                                          Text("Pagado con: ${widget.expense.paymentMethod ?? 'Efectivo'}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                      ],
                                  ),
                              )
                          ],
                      ),
                  ),
                  
                  const SizedBox(height: 16),
                  if (widget.expense.createdBy == Supabase.instance.client.auth.currentUser?.id)
                     SizedBox(
                         width: double.infinity,
                         child: OutlinedButton.icon(
                             icon: const Icon(Icons.delete_forever, color: Colors.red),
                             style: OutlinedButton.styleFrom(
                                 side: const BorderSide(color: Colors.red),
                                 foregroundColor: Colors.red
                             ),
                             onPressed: _deleteExpense,
                             label: const Text("Eliminar Gasto")
                         ),
                     ),

                  const SizedBox(height: 32),
                  const Text("Participantes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  if (widget.expense.items == null || widget.expense.items!.isEmpty)
                      const Center(child: Text("No hay detalles de ítems.", style: TextStyle(color: Colors.grey))),
                      
                  ..._buildParticipantsList(),
              ],
          ),
      ),
    );
  }

  List<Widget> _buildParticipantsList() {
      // We need to aggregate by User/Guest across all items
      Map<String, double> userTotals = {};
      Map<String, String> userNames = {}; // ID -> Name
      
      // Initialize with self
      // Iterate items
      for (var item in widget.expense.items ?? []) {
          double assignedQtySum = item.assignments.fold(0.0, (sum, a) => sum + a.quantity);
          if (assignedQtySum == 0) continue;
          double costPerUnit = item.price / assignedQtySum;

          for (var a in item.assignments) {
              String key = a.userId ?? "guest_${a.guestName}";
              String name = a.guestName ?? "Usuario";
              if (name.trim().isEmpty) name = "Usuario"; // Safety
              
              userTotals[key] = (userTotals[key] ?? 0) + (a.quantity * costPerUnit);
              userNames[key] = name;
          }
      }

      return userTotals.entries.map((e) {
         final isMe = e.key == Supabase.instance.client.auth.currentUser?.id;
         final name = isMe ? "Tú" : (userNames[e.key] == "Usuario" ? "Participante" : userNames[e.key]!);
         final initial = name.isNotEmpty ? name[0].toUpperCase() : "?";
         
         // Find status
         final status = widget.expense.participantStatuses?.firstWhere(
             (s) {
                 if (isMe) return s.userId == e.key;
                 // Hacky check for guests: key starts with "guest_" or matches name if no guest_ prefix
                 // Actually the key IS the ID or formatted guest key.
                 // In _buildParticipantsList we used: String key = a.userId ?? "guest_${a.guestName}";
                 if (s.guestName != null) return "guest_${s.guestName}" == e.key;
                 return s.userId == e.key;
             },
             orElse: () => const ParticipantStatus(amountOwed: 0, isPaid: false)
         );
         
         final isPaid = status?.isPaid ?? false;
         
         return Container(
             margin: const EdgeInsets.only(bottom: 12),
             decoration: BoxDecoration(
                 color: Colors.white,
                 borderRadius: BorderRadius.circular(16),
                 boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                 border: isPaid ? Border.all(color: Colors.green, width: 2) : null,
             ),
             child: ListTile(
                 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 leading: CircleAvatar(
                     radius: 24,
                     backgroundColor: isPaid ? Colors.green.withOpacity(0.1) : (isMe ? AppTheme.primaryBrand.withOpacity(0.1) : Colors.grey[100]),
                     child: isPaid 
                        ? const Icon(Icons.check, color: Colors.green)
                        : Text(initial, style: TextStyle(
                         color: isMe ? AppTheme.primaryBrand : Colors.grey[700], 
                         fontWeight: FontWeight.bold,
                         fontSize: 18
                     )),
                 ),
                 title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                 subtitle: Text(
                     isPaid ? "¡Pagado!" : (isMe ? "Te corresponde pagar" : "Debe pagar"),
                     style: TextStyle(color: isPaid ? Colors.green : (isMe ? AppTheme.primaryBrand : Colors.grey[600]), fontSize: 12, fontWeight: isPaid ? FontWeight.bold : FontWeight.normal)
                 ),
                 trailing: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                         Text("\$${e.value.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                         if (!isPaid && _canManagePayment()) ...[ // Only creator can mark as paid
                            const SizedBox(width: 8),
                            IconButton(
                                icon: const Icon(Icons.check_circle_outline, color: Colors.grey),
                                tooltip: "Marcar como pagado",
                                onPressed: () => _markAsPaid(e.key, status?.userId, status?.guestName),
                            )
                         ]
                     ],
                 ),
             ),
         );
      }).toList();
  }

  bool _canManagePayment() {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      return widget.expense.createdBy == myId; // Only creator can mark others as paid
  }

  Future<void> _markAsPaid(String key, String? userId, String? guestName) async {
       // Ideally we would pass just userId or guestName. 
       // If status object was not found, we can't really update it. 
       // But we constructed the key carefully.
       
       String? finalUserId = userId;
       String? finalGuestName = guestName;

       // Fallback if status was empty but we have the key from assignments
       if (userId == null && guestName == null) {
           if (key.startsWith("guest_")) {
               finalGuestName = key.replaceAll("guest_", "");
           } else {
               finalUserId = key;
           }
       }

       try {
           final repo = ExpenseRepository(Supabase.instance.client);
           await repo.markDebtAsPaid(widget.expense.id, finalUserId, finalGuestName);
           
           if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Marcado como pagado")));
               Navigator.pop(context, true); // Go back and reload
           }
       } catch (e) {
           if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
       }
  }
  void _deleteExpense() async {
      final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
              title: const Text("¿Eliminar Gasto?"),
              content: const Text("Esta acción no se puede deshacer. Se borrarán todos los ítems y registros de deuda."),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
              ],
          )
      );

      if (confirm == true) {
          try {
              final repo = ExpenseRepository(Supabase.instance.client);
              await repo.deleteExpense(widget.expense.id);
              if (mounted) {
                  Navigator.pop(context, true); // Return true to trigger refresh
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gasto eliminado")));
              }
          } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
          }
      }
  }
}
