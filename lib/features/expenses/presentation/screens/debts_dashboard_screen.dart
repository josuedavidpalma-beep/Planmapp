import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/expenses/data/repositories/expense_repository.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

import 'package:planmapp/core/services/plan_service.dart';
import 'package:planmapp/features/expenses/presentation/widgets/reminder_settings_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

class DebtsDashboardScreen extends StatefulWidget {
  final String? planId;

  const DebtsDashboardScreen({super.key, this.planId});

  @override
  State<DebtsDashboardScreen> createState() => _DebtsDashboardScreenState();
}

class _DebtsDashboardScreenState extends State<DebtsDashboardScreen> with SingleTickerProviderStateMixin {
  final _repository = ExpenseRepository(Supabase.instance.client);
  late TabController _tabController;
  RealtimeChannel? _debtsSubscription;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _receivables = []; // Who owes me
  List<Map<String, dynamic>> _payables = [];    // Who I owe
  
  int _reminderFrequency = 0;
  String _reminderChannel = 'whatsapp';
  final _currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _setupRealtime();
  }

  void _setupRealtime() {
      _debtsSubscription = Supabase.instance.client
          .channel('public:payment_trackers:dashboard')
          .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'payment_trackers',
              callback: (payload) {
                  print("🔄 Realtime Update: Debts changed, reloading dashboard!");
                  if (mounted) _loadData();
              }
          ).subscribe();
  }

  @override
  void dispose() {
    _debtsSubscription?.unsubscribe();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
      setState(() => _isLoading = true);
      await Future.wait([
          _loadReceivables(),
          _loadPayables(),
          if (widget.planId != null) _loadSettings()
      ]);
      if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadSettings() async {
      if (widget.planId == null) return;
      final plan = await PlanService().getPlanById(widget.planId!);
      if (plan != null) {
          _reminderFrequency = plan.reminderFrequencyDays; 
          _reminderChannel = plan.reminderChannel;
      }
  }

  Future<void> _openSettings() async {
      if (widget.planId == null) return;
      final result = await showDialog<bool>(
          context: context, 
          builder: (_) => ReminderSettingsDialog(
              planId: widget.planId!, 
              initialFrequency: _reminderFrequency,
              initialChannel: _reminderChannel
          )
      );
      if (result == true) {
          await _loadSettings(); 
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Configuración actualizada")));
      }
  }

  Future<void> _loadReceivables() async {
      try {
          final data = await _repository.getReceivables(widget.planId);
          if (mounted) setState(() => _receivables = data);
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error Receivables: $e"), backgroundColor: Colors.red));
      }
  }

  Future<void> _loadPayables() async {
      try {
          final data = await _repository.getPayables(widget.planId);
          if (mounted) setState(() => _payables = data);
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error Payables: $e"), backgroundColor: Colors.red));
      }
  }

  // ============== RECEIVABLES ACTIONS (Por Cobrar) ============== //

  Future<void> _markPaid(Map<String, dynamic> debt) async {
      final isReported = debt['status'] == 'reported';
      final receiptUrl = debt['receipt_url'];
      final nameStr = debt['guest_name'] ?? debt['profiles']['full_name'];
      
      final title = isReported ? "Aprobar Pago" : "Confirmar Pago Manual";
      
      final confirm = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
              title: Text(title),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      Text(isReported 
                          ? "¿Confirmas que has recibido el dinero de $nameStr?"
                          : "¿Marcar la deuda de $nameStr como PAGADA manualmente?"
                      ),
                      if (receiptUrl != null) ...[
                          const SizedBox(height: 16),
                          const Text("Comprobante adjunto:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 8),
                          ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(receiptUrl, height: 200, fit: BoxFit.cover),
                          ),
                      ]
                  ],
              ),
              actions: [
                  if (isReported) TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Rechazar Pago", style: TextStyle(color: Colors.red))),
                  if (!isReported) TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancelar")),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Aprobar")),
              ],
          )
      );

      if (confirm == false && isReported) {
          // If they explicitly hit reject reported 
          await _denyPayment(debt);
      } else if (confirm == true) {
          await _repository.markDebtAsPaid(debt['expense_id'], debt['user_id'], debt['guest_name']);
          await _loadData(); 
      }
  }

  Future<void> _denyPayment(Map<String, dynamic> debt) async {
      final confirm = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
              title: const Text("Rechazar Pago"),
              content: Text("¿Aún no has recibido el dinero de ${debt['guest_name'] ?? debt['profiles']['full_name']}?"),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancelar")),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Rechazar y alertar")),
              ],
          )
      );

      if (confirm == true) {
          await _repository.denyPayment(debt['expense_id'], debt['user_id'], debt['guest_name']);
          await _loadData(); 
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pago rechazado.")));
      }
  }

  void _sendBulkReminder(List<Map<String, dynamic>> debts, String name, String? phone, double totalAmount) {
      final formattedTotal = _currencyFormat.format(totalAmount);
      
      String message = "Hola *$name*! 👋\nTe recuerdo que me debes un total de *$formattedTotal* en Planmapp.\n\nDetalle:\n";
      for (var d in debts) {
          final amt = _currencyFormat.format(d['amount_owed'] ?? 0);
          final title = d['expenses']?['title'] ?? 'Gasto';
          message += "- $title: *$amt*\n";
      }
      message += "\nPor favor usa la app para notificarme el pago o envíame el comprobante. ✅";
      
      if (phone != null && phone.isNotEmpty) {
          _launchWhatsApp(phone, message);
      } else {
          Share.share(message);
      }
  }

  // ============== PAYABLES ACTIONS (Por Pagar) ============== //

  Future<void> _notifyMyPayment(Map<String, dynamic> debt) async {
      final picker = ImagePicker();
      
      final result = await showModalBottomSheet<String>(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (c) => SafeArea(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("Reportar Pago", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text("¿Deseas adjuntar una captura de tu transferencia Nequi/Banco? Ayuda al organizador a validarlo más rápido. (Se borrará en 30 días)", style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                      leading: const Icon(Icons.photo_library, color: AppTheme.primaryBrand),
                      title: const Text("Subir Comprobante (Recomendado)"),
                      onTap: () => Navigator.pop(c, 'photo'),
                  ),
                  ListTile(
                      leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                      title: const Text("Reportar sin comprobante"),
                      onTap: () => Navigator.pop(c, 'without_photo'),
                  ),
                  const SizedBox(height: 16),
              ],
          ))
      );

      if (result == null) return;

      String? uploadedUrl;
      setState(() => _isLoading = true);

      try {
          if (result == 'photo') {
              final xFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50); // Heavily compress image (max 500kb usually)
              if (xFile != null) {
                  final bytes = await xFile.readAsBytes();
                  final ext = xFile.name.split('.').last;
                  final path = '${Supabase.instance.client.auth.currentUser!.id}/${const Uuid().v4()}.$ext';
                  
                  await Supabase.instance.client.storage.from('payment_vouchers').uploadBinary(path, bytes);
                  uploadedUrl = Supabase.instance.client.storage.from('payment_vouchers').getPublicUrl(path);
              }
          }

          await _repository.reportPayment(debt['expense_id'], receiptUrl: uploadedUrl);
          await _loadData(); 
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pago notificado al organizador!")));
          
      } catch (e) {
          setState(() => _isLoading = false);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
  }

  // ============== UTILS ============== //

  Future<void> _launchWhatsApp(String phone, String message) async {
      String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (!cleanPhone.startsWith('57') && cleanPhone.length == 10) cleanPhone = '57$cleanPhone'; 
      
      final url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
      try {
          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) throw 'Could not launch WhatsApp';
      } catch (e) {
          Share.share(message); 
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.planId == null ? "Dashboard Financiero" : "Estado de Cuenta"),
        centerTitle: true,
        bottom: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryBrand,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryBrand,
            tabs: const [
              Tab(text: "Me Deben", icon: Icon(Icons.download)),
              Tab(text: "Yo Debo", icon: Icon(Icons.upload)),
            ],
        ),
        actions: [
            if (widget.planId != null)
                IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: "Configuración Automática",
                    onPressed: _openSettings,
                )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
                _buildList(_receivables, true),
                _buildList(_payables, false),
            ],
          ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupDebts(List<Map<String, dynamic>> flatList, bool isReceivable) {
      Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var item in flatList) {
          String key;
          if (isReceivable) {
              final isGuest = item['user_id'] == null;
              key = isGuest ? "guest_${item['guest_name']}" : "user_${item['user_id']}";
          } else {
              key = "creditor_${item['expenses']['created_by']}";
          }
          if (!grouped.containsKey(key)) grouped[key] = [];
          grouped[key]!.add(item);
      }
      return grouped;
  }

  Widget _buildList(List<Map<String, dynamic>> items, bool isReceivable) {
      if (items.isEmpty) return _buildEmptyState(isReceivable);
      
      final grouped = _groupDebts(items, isReceivable);
      final grandTotal = items.fold(0.0, (sum, item) => sum + ((item['amount_owed'] as num?)?.toDouble() ?? 0.0));
      
      return Column(
          children: [
             Padding(
                 padding: const EdgeInsets.all(16),
                 child: Container(
                     width: double.infinity,
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(color: AppTheme.primaryBrand, borderRadius: BorderRadius.circular(16)),
                     child: Column(
                         children: [
                             Text(isReceivable ? "Gran Total Me Deben" : "Gran Total Yo Debo", style: const TextStyle(color: Colors.white70)),
                             Text(_currencyFormat.format(grandTotal), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                         ]
                     )
                 )
             ),
             Expanded(
                 child: ListView.builder(
                     padding: const EdgeInsets.symmetric(horizontal: 16),
                     itemCount: grouped.keys.length,
                     itemBuilder: (context, index) {
                         final key = grouped.keys.elementAt(index);
                         final personDebts = grouped[key]!;
                         return isReceivable 
                             ? _buildGroupedReceivableCard(personDebts) 
                             : _buildGroupedPayableCard(personDebts);
                     },
                 )
             )
          ]
      );
  }

  Widget _buildGroupedReceivableCard(List<Map<String, dynamic>> personDebts) {
      final firstDebt = personDebts.first;
      final isGuest = firstDebt['user_id'] == null;
      final name = isGuest ? (firstDebt['guest_name'] ?? 'Invitado') : (firstDebt['profiles']?['full_name'] ?? 'Usuario');
      final profileData = firstDebt['profiles'] as Map<String, dynamic>?;
      final avatarUrl = (!isGuest && profileData != null) ? profileData['avatar_url'] as String? : null;
      final phone = (!isGuest && profileData != null) ? profileData['phone'] as String? : null;
      
      final totalAmount = personDebts.fold(0.0, (sum, debt) => sum + ((debt['amount_owed'] as num?)?.toDouble() ?? 0.0));
      
      return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ExpansionTile(
              leading: _buildAvatar(avatarUrl, name),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text(_currencyFormat.format(totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBrand)),
              children: [
                  ...personDebts.map((debt) => ListTile(
                      title: Text(debt['expenses']['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: _buildDebtItemsFuture(debt),
                      trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              Text(_currencyFormat.format(debt['amount_owed'] ?? 0)),
                              IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: () => _markPaid(debt),
                              )
                          ]
                      )
                  )).toList(),
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                          onPressed: () => _sendBulkReminder(personDebts, name, phone, totalAmount),
                          icon: const Icon(Icons.share),
                          label: const Text("Enviar Resumen de Cobro"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 40))
                      )
                  )
              ],
          ),
      );
  }

  Widget _buildGroupedPayableCard(List<Map<String, dynamic>> personDebts) {
      final firstDebt = personDebts.first;
      final profileData = firstDebt['profiles'] as Map<String, dynamic>?;
      final name = profileData?['full_name'] ?? 'Organizador';
      final avatarUrl = profileData?['avatar_url'] as String?;
      final paymentMethods = profileData?['payment_methods'] as List<dynamic>? ?? [];
      
      final totalAmount = personDebts.fold(0.0, (sum, debt) => sum + ((debt['amount_owed'] as num?)?.toDouble() ?? 0.0));
      
      return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ExpansionTile(
              leading: _buildAvatar(avatarUrl, name),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text(_currencyFormat.format(totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
              children: [
                  ...personDebts.map((debt) => ListTile(
                      title: Text(debt['expenses']['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: _buildDebtItemsFuture(debt),
                      trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              Text(_currencyFormat.format(debt['amount_owed'] ?? 0)),
                              IconButton(
                                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                  onPressed: () => _notifyMyPayment(debt),
                              )
                          ]
                      )
                  )).toList(),
                  if (paymentMethods.isNotEmpty)
                      Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.grey.shade50),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  const Text("Medios de Pago del Organizador:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                  const SizedBox(height: 8),
                                  ...paymentMethods.map((pm) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.account_balance_wallet, color: AppTheme.primaryBrand),
                                      title: Text(pm['type'] ?? 'Banco'),
                                      subtitle: Text(pm['details'] ?? ''),
                                      trailing: IconButton(
                                          icon: const Icon(Icons.copy, color: Colors.blue),
                                          onPressed: () {
                                              Clipboard.setData(ClipboardData(text: pm['details'] ?? ''));
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Copiado: ${pm['details']}")));
                                          }
                                      )
                                  )).toList()
                              ]
                          )
                      )
                  else
                      const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text("El organizador no ha registrado medios de pago.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                      )
              ],
          ),
      );
  }

  Widget _buildDebtItemsFuture(Map<String, dynamic> debt) {
      final expenseId = debt['expense_id'];
      final userId = debt['user_id'];
      final guestName = debt['guest_name'];
      
      return FutureBuilder<List<Map<String, dynamic>>>(
          future: _repository.getDebtItemsDetailed([expenseId], userId: userId, guestName: guestName),
          builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Text("Cargando detalles...", style: TextStyle(fontSize: 12, color: Colors.grey));
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
              
              final itemsStr = snapshot.data!.map((a) {
                  final qty = (a['quantity'] as num).toDouble();
                  final name = a['expense_items']['name'] ?? '';
                  return qty < 1 ? "Parte de $name" : "${qty.toInt()}x $name";
              }).join(', ');
              
              return Text(itemsStr, style: const TextStyle(fontSize: 12, color: Colors.grey));
          }
      );
  }

  Widget _buildEmptyState(bool isReceivable) {
      return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  Icon(isReceivable ? Icons.sentiment_satisfied_alt : Icons.check_circle_outline, size: 80, color: Colors.green),
                  const SizedBox(height: 16),
                  Text(isReceivable ? "Nadie te debe" : "¡Todo al día!", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(isReceivable ? "Todos han pagado su parte." : "Estás a paz y salvo con tus amigos.", style: const TextStyle(color: Colors.grey)),
              ],
          ),
      );
  }

  Widget _buildAvatar(String? url, String initialName) {
      return Container(
          width: 50, height: 50,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[200], border: Border.all(color: Colors.grey[300]!)),
          clipBehavior: Clip.antiAlias,
          child: url != null 
              ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.person))
              : Center(child: Text(initialName.isNotEmpty ? initialName[0].toUpperCase() : 'U', style: const TextStyle(fontWeight: FontWeight.bold))),
      );
  }

  Widget _buildStatusBadge(String status) {
      Color color;
      String text;
      
      switch (status) {
          case 'reported':
              color = Colors.orange;
              text = 'Esperando revisión';
              break;
          case 'reminded':
              color = Colors.redAccent;
              text = 'Cobro enviado';
              break;
          default:
              color = Colors.red;
              text = 'Pendiente de pago';
      }
      
      return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      );
  }
}
