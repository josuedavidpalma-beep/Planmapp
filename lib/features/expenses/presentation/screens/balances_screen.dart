
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/expenses/domain/services/balance_service.dart';
import 'package:planmapp/features/expenses/data/models/payment_model.dart';
import 'package:intl/intl.dart';
import 'package:planmapp/core/services/chat_service.dart';

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
    final paymentsAsync = ref.watch(planPaymentsProvider(planId));

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
            return paymentsAsync.when(
               loading: () => const Center(child: CircularProgressIndicator()),
               error: (err, _) => const Center(child: Text("Error cargando pagos")),
               data: (allPayments) {
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
                                    member: membersMap[b.toUserId],
                                    fallbackName: "Usuario Desconocido",
                                    allPayments: allPayments,
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
                                    member: membersMap[b.fromUserId],
                                    fallbackName: "Usuario Desconocido",
                                    allPayments: allPayments,
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
                                    fallbackName: "${membersMap[b.fromUserId]?.name} le debe a ${membersMap[b.toUserId]?.name}",
                                    allPayments: allPayments,
                                  )),
                              ]
                            ],
                          );
                      }
                   );
               });
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
  final PlanMember? member;
  final String? fallbackName;
  final List<PaymentModel> allPayments;

  const _DebtCard({
    required this.balance, 
    required this.isMeDebtor, 
    required this.planId, 
    this.member,
    this.fallbackName,
    this.isReadOnly = false,
    required this.allPayments,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Find if there is a pending payment for this exact debt
    final pendingPayment = allPayments.where((p) => p.fromUserId == balance.fromUserId && p.toUserId == balance.toUserId && p.status == 'pending').firstOrNull;
    final isPending = pendingPayment != null;

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
                   Row(
                     children: [
                       Flexible(
                         child: Text(
                           member?.name ?? fallbackName ?? 'Usuario', 
                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                           maxLines: 1,
                           overflow: TextOverflow.ellipsis,
                         ),
                       ),
                       if (member != null) ...[
                           const SizedBox(width: 8),
                           if (member!.reputationScore >= 105)
                               const Tooltip(message: "🌟 Élite VIP: Súper Paga", child: Text("🌟", style: TextStyle(fontSize: 14))),
                           if (member!.reputationScore >= 95 && member!.reputationScore < 105)
                               const Tooltip(message: "🟢 Buen Paga", child: Text("🟢", style: TextStyle(fontSize: 14))),
                           if (member!.reputationScore < 95)
                               const Tooltip(message: "⚠️ Moroso Riesgoso", child: Text("⚠️", style: TextStyle(fontSize: 14))),
                       ],
                     ],
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
                      color: isReadOnly ? Colors.grey : (isPending ? Colors.orange[800] : (isMeDebtor ? Colors.red : Colors.green))
                    ),
                  ),
                  if (isPending && isMeDebtor)
                     const Text("En Espera...", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold))
                  else if (isPending && !isMeDebtor && !isReadOnly)
                     Row(
                        children: [
                            IconButton(
                                icon: const Icon(Icons.check_circle, color: Colors.green),
                                tooltip: "Confirmar Pago",
                                onPressed: () => _updatePayment(context, ref, pendingPayment.id, 'confirmed', member?.name ?? fallbackName, balance.amount)
                            ),
                            IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.red),
                                tooltip: "Rechazar Pago",
                                onPressed: () => _updatePayment(context, ref, pendingPayment.id, 'rejected', member?.name ?? fallbackName, balance.amount)
                            )
                        ]
                     )
                  else if (!isReadOnly && isMeDebtor)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBrand,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      icon: const Icon(Icons.credit_card, size: 16),
                      onPressed: () => _showPaymentDialog(context, ref, member, fallbackName),
                      label: const Text("Pagar"),
                    ),
               ],
             )
          ],
        ),
      ),
    );
  }

  Future<void> _updatePayment(BuildContext context, WidgetRef ref, String paymentId, String status, String? debtorName, double amount) async {
       try {
           await ref.read(balanceServiceProvider).updatePaymentStatus(paymentId, status);
           
           // Notify to chat
           final chat = ChatService();
           if (status == 'confirmed') {
               await chat.sendMessage(planId, "✅ He confirmado tu pago de \$${amount.toStringAsFixed(0)}.", type: 'payment_confirmed');
           } else {
               await chat.sendMessage(planId, "❌ Hola $debtorName, hubo un problema con el pago de \$${amount.toStringAsFixed(0)}. Revisa los datos y vuelve a intentarlo.", type: 'payment_rejected');
           }
           
           ref.invalidate(planBalancesProvider(planId));
           ref.invalidate(planPaymentsProvider(planId));
       } catch (e) {
           if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
       }
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref, PlanMember? creditor, String? fallbackName) {
     final creditorName = creditor?.name ?? fallbackName ?? 'Usuario';
     final noteController = TextEditingController();
     String selectedMethod = 'Efectivo';
     final originMethods = ['Efectivo', 'Mi Nequi', 'Mi DaviPlata', 'Mi Bancolombia', 'Mi Davivienda', 'Otro Banco', 'Zelle'];

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
               const Text("Transferir a:", style: TextStyle(fontWeight: FontWeight.bold)),
               if (creditor != null && creditor.paymentMethods.isNotEmpty)
                  Container(
                     margin: const EdgeInsets.only(top: 8, bottom: 8),
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                     child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: creditor.paymentMethods.map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(children: [
                                  Icon(Icons.monetization_on, size: 14, color: AppTheme.primaryBrand),
                                  const SizedBox(width: 6),
                                  Expanded(child: SelectableText("${m['type']}: ${m['details']}", style: const TextStyle(fontWeight: FontWeight.bold))),
                            ]),
                        )).toList(),
                     ),
                  )
               else
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("Esta persona no tiene Nequi/Daviplata configurados en su perfil.", style: TextStyle(fontSize: 12, color: Colors.grey))),
               
               const SizedBox(height: 16),
               const Text("Indica desde dónde TÚ enviaste el dinero:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
               DropdownButton<String>(
                 value: selectedMethod,
                 isExpanded: true,
                 items: originMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
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
                    status: 'pending',
                    confirmedAt: null,
                    createdAt: DateTime.now(), 
                 );
                 
                 await ref.read(balanceServiceProvider).recordPayment(payment);
                 
                 // Notify to Chat
                 final chat = ChatService();
                 await chat.sendMessage(
                     planId, 
                     "💸 He registrado un pago de \$${balance.amount.toStringAsFixed(0)} vía $selectedMethod. Por favor, confirma si lo recibiste en la pestaña de Cuentas.", 
                     type: 'payment_claim'
                 );

                 ref.invalidate(planBalancesProvider(planId)); 
                 ref.invalidate(planPaymentsProvider(planId)); 
                 
                 if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aviso de pago enviado. Esperando confirmación.")));
                 }

                 // ============================================
                 // DEEP LINKING LOGIC
                 // ============================================
                 if (selectedMethod == 'Nequi' || selectedMethod == 'DaviPlata') {
                     final phone = creditor?.phone;
                     if (phone != null && phone.isNotEmpty) {
                         await Clipboard.setData(ClipboardData(text: phone));
                         
                         if (context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                 content: Text("Número $phone copiado. Abriendo app..."),
                                 backgroundColor: AppTheme.primaryBrand,
                             ));
                         }
                         
                         if (selectedMethod == 'Nequi') {
                             final Uri appUri = Uri.parse('nequi://');
                             if (await canLaunchUrl(appUri)) {
                                 await launchUrl(appUri, mode: LaunchMode.externalApplication);
                             } else {
                                 await launchUrl(Uri.parse('https://recarga.nequi.com.co'), mode: LaunchMode.externalApplication);
                             }
                         } else if (selectedMethod == 'DaviPlata') {
                             final Uri appUri = Uri.parse('daviplata://');
                             if (await canLaunchUrl(appUri)) {
                                 await launchUrl(appUri, mode: LaunchMode.externalApplication);
                             }
                         }
                     }
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
