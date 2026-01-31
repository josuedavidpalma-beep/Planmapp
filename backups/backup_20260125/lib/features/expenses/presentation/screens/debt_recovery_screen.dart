import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/expenses/data/repositories/expense_repository.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:planmapp/core/services/plan_service.dart';
import 'package:planmapp/features/expenses/presentation/widgets/reminder_settings_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class DebtRecoveryScreen extends StatefulWidget {
  final String planId;

  const DebtRecoveryScreen({super.key, required this.planId});

  @override
  State<DebtRecoveryScreen> createState() => _DebtRecoveryScreenState();
}

class _DebtRecoveryScreenState extends State<DebtRecoveryScreen> {
  final _repository = ExpenseRepository(Supabase.instance.client);
  bool _isLoading = true;
  List<Map<String, dynamic>> _debts = [];
  int _reminderFrequency = 0;
  String _reminderChannel = 'whatsapp';
  final _currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
      setState(() => _isLoading = true);
      await Future.wait([
          _loadDebts(),
          _loadSettings()
      ]);
      if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadSettings() async {
      final plan = await PlanService().getPlanById(widget.planId);
      if (plan != null) {
          _reminderFrequency = plan.reminderFrequencyDays; // Using the field we added
          _reminderChannel = plan.reminderChannel;
      }
  }

  Future<void> _openSettings() async {
      final result = await showDialog<bool>(
          context: context, 
          builder: (_) => ReminderSettingsDialog(
              planId: widget.planId, 
              initialFrequency: _reminderFrequency,
              initialChannel: _reminderChannel
          )
      );
      if (result == true) {
          await _loadSettings(); // Reload to get fresh data
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Configuración actualizada")));
      }
  }

  Future<void> _loadDebts() async {
    setState(() => _isLoading = true);
    final data = await _repository.getReceivables(widget.planId);
    if (mounted) {
      setState(() {
        _debts = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _markPaid(Map<String, dynamic> debt) async {
      final confirm = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
              title: const Text("Confirmar Pago"),
              content: Text("¿Marcar la deuda de ${debt['guest_name'] ?? debt['profiles']['full_name']} como PAGADA?"),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancelar")),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Confirmar")),
              ],
          )
      );

      if (confirm == true) {
          await _repository.markDebtAsPaid(
              debt['expense_id'], 
              debt['user_id'], 
              debt['guest_name']
          );
          _loadDebts(); // Refresh
      }
  }

  void _sendReminder(Map<String, dynamic> debt) {
      final name = debt['guest_name'] ?? debt['profiles']?['full_name'] ?? 'Amigo';
      final amount = _currencyFormat.format(debt['amount_owed'] ?? 0);
      final expenseTitle = debt['expenses']?['title'] ?? 'Gasto';
      
      final phone = debt['profiles']?['phone'] as String?;
      final message = "Hola *$name*! 👋\nTe recuerdo que me debes *$amount* por el gasto de: *$expenseTitle* en Planmapp.\n\nPor favor envíame el comprobante cuando puedas. ✅";
      
      if (phone != null && phone.isNotEmpty) {
          // Send Directly
          _launchWhatsApp(phone, message);
      } else {
          // Share Sheet Fallback
          Share.share(message);
      }
  }

  Future<void> _launchWhatsApp(String phone, String message) async {
      // Cleanup phone (remove +, spaces)
      String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (!cleanPhone.startsWith('57') && cleanPhone.length == 10) {
          cleanPhone = '57$cleanPhone'; // Default Colombia if missing code
      }
      
      final url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
      try {
          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
              throw 'Could not launch $url';
          }
      } catch (e) {
          Share.share(message); // Fallback
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Por Cobrar"),
        centerTitle: true,
        actions: [
            IconButton(
                icon: const Icon(Icons.settings),
                tooltip: "Configurar Cobro Automático",
                onPressed: _openSettings,
            )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _debts.isEmpty 
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _debts.length,
                itemBuilder: (context, index) {
                    final debt = _debts[index];
                    return _buildDebtCard(debt);
                },
              ),
    );
  }

  Widget _buildEmptyState() {
      return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                  const SizedBox(height: 16),
                  const Text("¡Todo al día!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("Nadie te debe dinero por ahora.", style: TextStyle(color: Colors.grey)),
              ],
          ),
      );
  }

  Widget _buildDebtCard(Map<String, dynamic> debt) {
      final isGuest = debt['user_id'] == null;
      final name = isGuest ? (debt['guest_name'] ?? 'Invitado') : (debt['profiles']?['full_name'] ?? 'Usuario');
      final profileData = debt['profiles'] as Map<String, dynamic>?;
      final avatarUrl = (!isGuest && profileData != null) ? profileData['avatar_url'] as String? : null;
      final amount = (debt['amount_owed'] as num?)?.toDouble() ?? 0;
      final expenseTitle = debt['expenses']['title'];
      final status = debt['status'] ?? 'pending';
      
      Color statusColor = status == 'reminded' ? Colors.orange : Colors.red;
      
      return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                  // Avatar
                  Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                          border: Border.all(color: Colors.grey[300]!)
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: avatarUrl != null 
                          ? Image.network(avatarUrl, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.person))
                          : Center(child: Text(name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 12),
                  
                  // Info
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(expenseTitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              const SizedBox(height: 4),
                              Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8)
                                  ),
                                  child: Text(
                                      status == 'paid' ? 'Pagado' : 'Pendiente', 
                                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)
                                  ),
                              )
                          ],
                      ),
                  ),
                  
                  // Amount & Actions
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                          Text(_currencyFormat.format(amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryBrand)),
                          const SizedBox(height: 8),
                          Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                  IconButton(
                                      icon: Icon(debt['profiles']?['phone'] != null ? Icons.chat : Icons.share, color: Colors.blueAccent),
                                      onPressed: () => _sendReminder(debt),
                                      tooltip: "Recordar",
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                      icon: const Icon(Icons.check_circle, color: Colors.green),
                                      onPressed: () => _markPaid(debt),
                                      tooltip: "Marcar Pagado",
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                  ),
                              ],
                          )
                      ],
                  )
              ],
            ),
          ),
      );
  }
}
