import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/core/utils/currency_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentSummaryScreen extends StatelessWidget {
  final Map<String, dynamic> debtData;
  final List<dynamic> paymentMethods;

  const PaymentSummaryScreen({
    super.key,
    required this.debtData,
    required this.paymentMethods,
  });

  @override
  Widget build(BuildContext context) {
    final double totalOwed = (debtData['amount_owed'] as num).toDouble();
    final String name = debtData['guest_name'] ?? debtData['user_id'] ?? 'Invitado';

    return Scaffold(
      appBar: AppBar(title: const Text("Tu Parte", style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              "¡Todo listo, $name!",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Este es el resumen de tu consumo con los impuestos y propinas prorrateados.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryBrand.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryBrand.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  const Text("Total a Pagar", style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyInputFormatter.format(totalOwed),
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.primaryBrand),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text("Medios de Pago Disponibles", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (paymentMethods.isEmpty)
              const Text("El dueño de la vaca no especificó medios de pago. Pregúntale.")
            else
              ...paymentMethods.map((pm) {
                final method = pm['method'] ?? 'Desconocido';
                final account = pm['account'] ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.account_balance_wallet, color: AppTheme.primaryBrand)),
                    title: Text(method, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(account, style: const TextStyle(fontSize: 16, letterSpacing: 1)),
                    trailing: const Icon(Icons.copy, size: 20),
                    onTap: () {
                      // Clipboard logic would go here
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$method copiado al portapapeles")));
                    },
                  ),
                );
              }),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                 // Return to home or close
                 context.go('/home');
              },
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: AppTheme.primaryBrand,
                  foregroundColor: Colors.white,
              ),
              child: const Text("Hecho"),
            )
          ],
        ),
      ),
    );
  }
}
