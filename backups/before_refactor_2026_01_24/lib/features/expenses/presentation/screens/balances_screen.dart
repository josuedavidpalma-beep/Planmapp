
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/expenses/domain/services/balance_service.dart';
import 'package:planmapp/features/expenses/data/models/payment_model.dart';
import 'package:planmapp/features/plans/services/plan_members_service.dart';
import 'package:intl/intl.dart';

// Provider to fetch member details (names, avatars) for the plan
final planMembersProvider = FutureProvider.family<Map<String, PlanMember>, String>((ref, planId) async {
  final members = await PlanMembersService().getMembers(planId);
  return {for (var m in members) m.id: m};
});

class BalancesScreen extends ConsumerWidget {
  final String planId;

  const BalancesScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch both balances and member profiles
    final balancesAsync = ref.watch(planBalancesProvider(planId));
    final membersAsync = ref.watch(planMembersProvider(planId));

    final currentUserId =  Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Cuentas Claras"),
        centerTitle: true,
      ),
      body: balancesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
        data: (balances) {
           return membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => const Center(child: Text("Error cargando perfiles")), // Should degrade gracefully though
              data: (membersMap) {
                  if (balances.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                          const SizedBox(height: 16),
                          Text("¡Todo Saldado!", style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          const Text("Nadie le debe nada a nadie en este plan.", style: TextStyle(color: Colors.grey)),
                        ],
                      ).animate().scale(duration: 500.ms),
                    );
                  }

                  // Filter my debts and credits
                  final myDebts = balances.where((b) => b.fromUserId == currentUserId).toList();
                  final owedToMe = balances.where((b) => b.toUserId == currentUserId).toList();
                  final others = balances.where((b) => b.fromUserId != currentUserId && b.toUserId != currentUserId).toList();

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSummaryCard(context, myDebts, owedToMe),
                      const SizedBox(height: 24),
                      
                      if (myDebts.isNotEmpty) ...[
                          const Text("Tus Deudas (Por Pagar)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 8),
                          ...myDebts.map((b) => _DebtCard(
                            balance: b, 
                            isMeDebtor: true, 
                            planId: planId,
                            otherUserName: membersMap[b.toUserId]?.name ?? "Usuario Desconocido",
                          )),
                      ],

                      if (owedToMe.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text("Te Deben (Por Cobrar)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 8),
                          ...owedToMe.map((b) => _DebtCard(
                            balance: b, 
                            isMeDebtor: false, 
                            planId: planId,
                            otherUserName: membersMap[b.fromUserId]?.name ?? "Usuario Desconocido",
                          )),
                      ],

                      if (others.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text("Deudas de Otros", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
                          const SizedBox(height: 8),
                          ...others.map((b) => _DebtCard(
                            balance: b, 
                            isMeDebtor: false, 
                            isReadOnly: true, 
                            planId: planId,
                            otherUserName: "${membersMap[b.fromUserId]?.name} le debe a ${membersMap[b.toUserId]?.name}",
                          )),
                      ]
                    ],
                  );
              }
           );
        },
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, List<UserBalance> myDebts, List<UserBalance> owedToMe) {
     final totalDebt = myDebts.fold(0.0, (sum, b) => sum + b.amount);
     final totalCredit = owedToMe.fold(0.0, (sum, b) => sum + b.amount);
     final net = totalCredit - totalDebt;

     return Container(
       padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(
         gradient: LinearGradient(
           colors: [AppTheme.primaryBrand, AppTheme.primaryBrand.withOpacity(0.8)],
           begin: Alignment.topLeft,
           end: Alignment.bottomRight,
         ),
         borderRadius: BorderRadius.circular(20),
         boxShadow: [BoxShadow(color: AppTheme.primaryBrand.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
       ),
       child: Column(
         children: [
            const Text("Balance Personal", style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(net),
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              net > 0 ? "A favor (Te deben)" : (net < 0 ? "En contra (Debes)" : "Al día"),
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500),
            ),
         ],
       ),
     );
  }
}

class _DebtCard extends ConsumerWidget {
  final UserBalance balance;
  final bool isMeDebtor;
  final bool isReadOnly;
  final String planId;
  final String otherUserName;

  const _DebtCard({
    required this.balance, 
    required this.isMeDebtor, 
    required this.planId, 
    required this.otherUserName,
    this.isReadOnly = false
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
             CircleAvatar(
               backgroundColor: isReadOnly ? Colors.grey[200] : (isMeDebtor ? Colors.red[50] : Colors.green[50]),
               child: Icon(
                 isReadOnly ? Icons.people_outline : (isMeDebtor ? Icons.call_made : Icons.call_received),
                 color: isReadOnly ? Colors.grey : (isMeDebtor ? Colors.red : Colors.green),
                 size: 20,
               ),
             ),
             const SizedBox(width: 16),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     isReadOnly 
                       ? "Otros Participantes" 
                       : (isMeDebtor ? "Le debes a" : "Te debe"),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                   ),
                   const SizedBox(height: 4),
                   Text(
                     otherUserName, 
                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                   ),
                 ],
               ),
             ),
             Column(
               crossAxisAlignment: CrossAxisAlignment.end,
               children: [
                  Text(
                    NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(balance.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 16,
                      color: isReadOnly ? Colors.grey : (isMeDebtor ? Colors.red : Colors.green)
                    ),
                  ),
                  if (!isReadOnly && isMeDebtor)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppTheme.primaryBrand,
                      ),
                      onPressed: () => _showPaymentDialog(context, ref, otherUserName),
                      child: const Text("Registrar Pago"),
                    ),
               ],
             )
          ],
        ),
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref, String creditorName) {
     final noteController = TextEditingController();
     String selectedMethod = 'Efectivo';
     final methods = ['Efectivo', 'Nequi', 'DaviPlata', 'Transferencia', 'Zelle'];

     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
         title: const Text("Registrar Pago"),
         content: StatefulBuilder(
           builder: (context, setState) => Column(
             mainAxisSize: MainAxisSize.min,
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text("Vas a registrar un pago a $creditorName por:", style: const TextStyle(fontSize: 14)),
               const SizedBox(height: 8),
               Text(
                 NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(balance.amount),
                 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppTheme.primaryBrand),
               ),
               const SizedBox(height: 16),
               const Text("Método de Pago:", style: TextStyle(fontWeight: FontWeight.bold)),
               DropdownButton<String>(
                 value: selectedMethod,
                 isExpanded: true,
                 items: methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                 onChanged: (val) {
                   if (val != null) setState(() => selectedMethod = val);
                 },
               ),
               const SizedBox(height: 12),
               TextField(
                 controller: noteController,
                 decoration: const InputDecoration(
                    labelText: "Nota (Opcional)",
                    hintText: "Ej: Pago del almuerzo",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                 ),
               )
             ],
           ),
         ),
         actions: [
            TextButton(
               onPressed: () => Navigator.pop(ctx), 
               child: const Text("Cancelar", style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton(
              onPressed: () async {
                 Navigator.pop(ctx);
                 final payment = PaymentModel(
                    id: '', 
                    planId: planId,
                    fromUserId: balance.fromUserId,
                    toUserId: balance.toUserId,
                    amount: balance.amount,
                    method: selectedMethod,
                    note: noteController.text.isEmpty ? null : noteController.text,
                    createdAt: DateTime.now(),
                    confirmedAt: DateTime.now(), 
                 );
                 
                 await ref.read(balanceServiceProvider).recordPayment(payment);
                 ref.invalidate(planBalancesProvider(planId)); 
                 
                 if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pago registrado exitosamente")));
                 }
              }, 
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBrand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
              child: const Text("Confirmar Pago")
            ),
         ],
       )
     );
  }
}
