
import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/expenses/data/models/budget_model.dart';
import 'package:planmapp/features/expenses/data/repositories/budget_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:planmapp/core/utils/currency_formatter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class BudgetPlanTab extends StatefulWidget {
  final String planId;

  const BudgetPlanTab({super.key, required this.planId});

  @override
  State<BudgetPlanTab> createState() => _BudgetPlanTabState();
}

class _BudgetPlanTabState extends State<BudgetPlanTab> {
  final _repository = BudgetRepository(Supabase.instance.client);
  
  List<BudgetItem> _budgetItems = [];
  List<PaymentTracker> _trackers = [];
  bool _isLoading = true;
  double _totalBudget = 0.0;
  double _amountCollected = 0.0;
  double _quotaPerPerson = 0.0;
  
  DateTime? _deadline;
  int _remindFreq = 0; // 0 = Off
  DateTime? _lastRemind;
  String _planTitle = "";
  bool _showAutoBanner = false;
  bool _isCurrentUserCreator = false;
  String? _creatorIdDebug;
  String _paymentMode = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (_budgetItems.isEmpty) setState(() => _isLoading = true);
      
      await _repository.syncMembersToTrackers(widget.planId); 
      
      // Load Plan Info (Deadline, Title, Reminders)
      Map<String, dynamic> planRes = {};
      bool isCreator = false;
      String? cId;

      try {
        planRes = await Supabase.instance.client.from('plans').select().eq('id', widget.planId).single();
        final currentUid = Supabase.instance.client.auth.currentUser?.id;
        final creatorId = planRes['creator_id'];
        cId = creatorId;
        isCreator = currentUid == creatorId;
      } catch (e) {
        print("ERROR FETCHING PLAN DETAILS: $e");
      }

      final items = await _repository.getBudgetItems(widget.planId);
      final trackers = await _repository.getPaymentTrackers(widget.planId);
      
      final total = items.fold(0.0, (sum, i) => sum + i.estimatedAmount);
      final validTrackers = trackers.length;
      final quota = validTrackers > 0 ? total / validTrackers : 0.0;
      
      final collected = trackers
          .where((t) => t.status == PaymentStatus.paid)
          .fold(0.0, (sum, t) => sum + (t.amountOwe > 0 ? t.amountOwe : quota));

      // Auto-reminder check
      final freq = planRes['reminder_frequency_days'] as int? ?? 0;
      final lastR = planRes['last_reminder_sent'] != null ? DateTime.parse(planRes['last_reminder_sent']) : null;
      bool showBanner = false;
      
      if (freq > 0 && isCreator) {
          final now = DateTime.now();
          if (lastR == null || now.difference(lastR).inDays >= freq) {
              // Check if there are pending people
              if (trackers.any((t) => t.status == PaymentStatus.pending)) {
                  showBanner = true;
              }
          }
      }

      if (mounted) {
        setState(() {
          _budgetItems = items;
          _trackers = trackers;
          _totalBudget = total;
          _amountCollected = collected;
          _quotaPerPerson = quota;
          _deadline = planRes['budget_deadline'] != null ? DateTime.parse(planRes['budget_deadline']) : null;
          _remindFreq = freq;
          _lastRemind = lastR;
          _planTitle = planRes['title'] ?? "Viaje";
          _showAutoBanner = showBanner;
          _isCurrentUserCreator = isCreator;
          _creatorIdDebug = cId;
          _isLoading = false;
          _paymentMode = planRes['payment_mode'] ?? '';
        });
      }
    } catch (e) {
      print("CRITICAL ERROR LOADING BUDGET DATA: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        // Optional: Show error
      }
    }
  }

  // Reminder Logic
  Future<void> _remindAll() async {
      final pendingRaw = _trackers.where((t) => t.status == PaymentStatus.pending).toList();
      final currentUid = Supabase.instance.client.auth.currentUser?.id;
      final pending = pendingRaw.where((t) => t.userId != currentUid).toList();

      if (pending.isEmpty) return;
      
      final names = pending.map((e) => e.displayName).join(", ");
      final quota = _quotaPerPerson;
      // Encode for URL
      final message = "¡Hola equipo! 👋 Recordatorio de pago para '$_planTitle': ${CurrencyInputFormatter.format(quota)}. ${_deadline != null ? 'Límite: ${DateFormat('dd MMM').format(_deadline!)}' : ''}. ¡Gracias!";
      final url = "https://wa.me/?text=${Uri.encodeComponent(message)}";
      
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (e) {
        // Fallback to share
        await Share.share(message);
      }

      await Supabase.instance.client.from('plans').update({
          'last_reminder_sent': DateTime.now().toIso8601String()
      }).eq('id', widget.planId);
      
      setState(() => _showAutoBanner = false);
  }

  Future<void> _saveConfig() async {
      await Supabase.instance.client.from('plans').update({
          'budget_deadline': _deadline?.toIso8601String(),
          'reminder_frequency_days': _remindFreq,
      }).eq('id', widget.planId);
  }
  
  void _openConfig() async {
      if (!_isCurrentUserCreator) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Solo el organizador puede configurar esto")));
          return;
      }

      await showModalBottomSheet(context: context, builder: (c) => StatefulBuilder(
          builder: (context, setSt) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                   const Text("Configuración del Cobro", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 20),
                   ListTile(
                       leading: const Icon(Icons.calendar_today, color: Colors.blue),
                       title: Text(_deadline == null ? "Definir Fecha Límite" : "Límite: ${DateFormat('dd MMM yyyy').format(_deadline!)}"),
                       trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                       onTap: () async {
                           final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2030), initialDate: _deadline ?? DateTime.now());
                           if (d != null) {
                               setSt(() => _deadline = d);
                               _saveConfig();
                               setState((){});
                           }
                       },
                   ),
                   const Divider(),
                   const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text("Recordatorios Automáticos", style: TextStyle(fontWeight: FontWeight.bold))),
                   Row(
                       mainAxisAlignment: MainAxisAlignment.spaceAround,
                       children: [
                           _freqBtn("Off", 0, setSt),
                           _freqBtn("Diario", 1, setSt),
                           _freqBtn("Cada 3 días", 3, setSt),
                           _freqBtn("Semanal", 7, setSt),
                       ],
                   ),
                   const SizedBox(height: 40),
              ],
          ),
      )));
  }

  Widget _freqBtn(String label, int val, Function setSt) {
      final active = _remindFreq == val;
      return InkWell(
          onTap: () {
              setSt(() => _remindFreq = val);
              _saveConfig();
              setState((){});
          },
          child: Chip(
              label: Text(label, style: TextStyle(color: active ? Colors.white : Colors.black, fontSize: 11)),
              backgroundColor: active ? AppTheme.primaryBrand : Colors.grey[200],
          ),
      );
  }

  void _remindUser(PaymentTracker t) async {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Abriendo WhatsApp..."), duration: Duration(seconds: 1)));
       
       final quota = t.amountOwe > 0 ? t.amountOwe : _quotaPerPerson;
       final message = "¡Hola ${t.displayName}! 👋 Recuerda realizar tu pago de ${CurrencyInputFormatter.format(quota)} para el plan '$_planTitle'. ${_deadline != null ? 'Fecha límite: ${DateFormat('dd MMM').format(_deadline!)}' : ''}. ¡Gracias!";
       
       String url = "https://wa.me/?text=${Uri.encodeComponent(message)}"; // Default generic

       // Try to find phone number
       if (t.userId != null) {
           try {
               final profile = await Supabase.instance.client.from('profiles').select('phone, country_code').eq('id', t.userId!).single();
               final phone = profile['phone'] as String?;
               final code = profile['country_code'] as String? ?? '';
               
               if (phone != null && phone.isNotEmpty) {
                   final cleanPhone = phone.replaceAll(RegExp(r'\D'), ''); // Remove all non-digits
                   final cleanCode = code.replaceAll(RegExp(r'\D'), '');
                   url = "https://wa.me/$cleanCode$cleanPhone?text=${Uri.encodeComponent(message)}";
                   print("DEBUG: Sending to $cleanCode$cleanPhone");
               }
           } catch (e) {
               print("Error fetching phone: $e");
           }
       }

       try {
         await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
       } catch (e) {
         // Fallback 
         await Share.share(message);
       }
  }

  Future<void> _addItem() async {
      final descController = TextEditingController();
      final amountController = TextEditingController();
      String selectedCat = 'Hospedaje';
      
      await showDialog(context: context, builder: (ctx) => AlertDialog(
          title: const Text("Agregar al Presupuesto"),
          content: StatefulBuilder(builder: (ctx, setSt) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  DropdownButton<String>(
                      value: selectedCat,
                      isExpanded: true,
                      items: ['Hospedaje', 'Alimentación', 'Transporte', 'Entretenimiento', 'Otros'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setSt(() => selectedCat = v!),
                  ),
                  TextField(controller: descController, decoration: const InputDecoration(labelText: "Descripción (Opcional)")),
                  TextField(controller: amountController, decoration: const InputDecoration(labelText: "Monto Estimado"), keyboardType: TextInputType.number),
              ],
          )),
          actions: [
              TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")),
              ElevatedButton(onPressed: () async {
                  if (amountController.text.isEmpty) return;
                  try {
                    await _repository.addBudgetItem({
                       'plan_id': widget.planId,
                       'category': selectedCat,
                       'description': descController.text,
                       'estimated_amount': double.tryParse(amountController.text) ?? 0,
                    });
                    await _repository.recalculateQuotas(widget.planId);
                    if (mounted) {
                        Navigator.pop(ctx);
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Item agregado")));
                    }
                  } catch(e) {
                     if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                     }
                  }
              }, child: const Text("Agregar"))
          ],
      ));
  }
  
  Future<void> _addGuest() async {
      final nameCtrl = TextEditingController();
      await showDialog(context: context, builder: (ctx) => AlertDialog(
          title: const Text("Agregar Participante Extra"),
          content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nombre (ej. Novia de Juan)")),
          actions: [
               TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")),
               ElevatedButton(onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  try {
                    await _repository.addGuestTracker(widget.planId, nameCtrl.text);
                    await _repository.recalculateQuotas(widget.planId);
                    if (mounted) {
                        Navigator.pop(ctx);
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Participante agregado")));
                    }
                  } catch(e) {
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                      }
                  }
               }, child: const Text("Agregar"))
          ],
      ));
  }
  
  Future<void> _deleteItem(String id) async {
       try {
           await _repository.deleteBudgetItem(id);
           await _repository.recalculateQuotas(widget.planId);
           _loadData();
           if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Eliminado")));
       } catch (e) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
       }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeletonLoading();

    final rawProgress = _totalBudget > 0 ? (_amountCollected / _totalBudget) : 0.0;
    final progress = rawProgress.isNaN || rawProgress.isInfinite ? 0.0 : rawProgress.clamp(0.0, 1.0);

    return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
                // SUMMARY CARD (ANIMATED)
                Container(
                   padding: const EdgeInsets.all(20),
                   decoration: BoxDecoration(
                       gradient: const LinearGradient(colors: [AppTheme.primaryBrand, AppTheme.secondaryBrand]),
                       borderRadius: BorderRadius.circular(24), // Softer corners
                       boxShadow: [
                           BoxShadow(color: AppTheme.primaryBrand.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))
                       ]
                   ),
                   child: Column(
                     children: [
                       Row(
                         children: [
                             // Animated Progress Ring
                             SizedBox(
                                 width: 80, height: 80,
                                 child: TweenAnimationBuilder<double>(
                                     tween: Tween<double>(begin: 0, end: progress),
                                     duration: const Duration(seconds: 1),
                                     curve: Curves.easeOutCubic,
                                     builder: (context, value, _) => Stack(
                                         fit: StackFit.expand,
                                         children: [
                                             CircularProgressIndicator(value: value, color: Colors.white, backgroundColor: Colors.white24, strokeWidth: 8),
                                             Center(child: Text("${(value*100).toInt()}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                                         ],
                                     ),
                                 ),
                             ),
                             const SizedBox(width: 20),
                             Expanded(child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                     // Animated Total Count
                                     TweenAnimationBuilder<double>(
                                         tween: Tween<double>(begin: 0, end: _totalBudget),
                                         duration: const Duration(seconds: 1),
                                         curve: Curves.easeOut,
                                         builder: (context, val, _) => Text(
                                            CurrencyInputFormatter.format(val), 
                                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black26, blurRadius: 4)])
                                         )
                                     ),
                                     
                                     Row(children: [
                                       const Text("Presupuesto Total", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                       if (_isCurrentUserCreator) 
                                         Container(
                                             margin: const EdgeInsets.only(left: 8),
                                             padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                             decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                                             child: const Text("ADMIN", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                         )
                                     ]),
                                     const SizedBox(height: 8),
                                     Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                         decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                                         child: Text("Cuota: ${CurrencyInputFormatter.format(_quotaPerPerson)} / pers", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                     )
                                 ],
                             )),
                             IconButton(onPressed: _openConfig, icon: const Icon(Icons.settings, color: Colors.white70))
                         ],
                       ),
                       
                       // DEBUG IDs - REMOVE LATER
                       if (!_isCurrentUserCreator)
                           Padding(
                               padding: const EdgeInsets.only(top: 8),
                               child: SelectableText(
                                   "Debug: Yo=${Supabase.instance.client.auth.currentUser?.id?.substring(0,5)}... Creador=${_creatorIdDebug?.substring(0,5) ?? 'NULL'}",
                                   style: const TextStyle(color: Colors.white38, fontSize: 10),
                               ),
                           ),

                       if (_deadline != null) ...[
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white24),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                  const Icon(Icons.timer_outlined, color: Colors.white70, size: 14),
                                  const SizedBox(width: 4),
                                  Text("Límite: ${DateFormat('dd MMM').format(_deadline!)}", style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  if (_remindFreq > 0) ...[
                                      const SizedBox(width: 12),
                                      const Icon(Icons.notifications_active, color: Colors.white70, size: 14),
                                      const SizedBox(width: 4),
                                      Text("Autos: $_remindFreq d", style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  ]
                              ],
                          )
                       ]
                     ],
                   ),
                ),
                
                if (_showAutoBanner)
                    Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue[100]!)),
                            child: Row(
                                children: [
                                    const Icon(Icons.info_outline, color: Colors.blue),
                                    const SizedBox(width: 12),
                                    const Expanded(child: Text("Es momento de recordar los pagos pendientes.", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                    TextButton(onPressed: _remindAll, child: const Text("Recordar a todos"))
                                ],
                            ),
                        ),
                    ),

                // SMART SUGGESTION FOR VACA
                if (_paymentMode == 'pool' && _budgetItems.isEmpty)
                   Container(
                        margin: const EdgeInsets.only(top: 24), // Add spacing
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.orange.withOpacity(0.2), Colors.orange.withOpacity(0.05)]),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.orange.withOpacity(0.3))
                        ),
                        child: Row(
                            children: [
                                Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: const Icon(Icons.savings, color: Colors.orange, size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                            const Text("Modo Vaca Activado 🐮", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                            const SizedBox(height: 4),
                                            const Text("Define la meta o el costo total para empezar a recoger el dinero.", style: TextStyle(fontSize: 12)),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                                height: 32,
                                                child: ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16)),
                                                    onPressed: _addItem,
                                                    child: const Text("Definir Meta / Agregar Gasto"),
                                                ),
                                            )
                                        ],
                                    )
                                )
                            ],
                        ),
                    ).animate().fade().slideY(begin: 0.2, end: 0),
                
                const SizedBox(height: 24),
                
                // SECTION 1: BUDGET ITEMS
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Calculadora de Gastos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: _addItem, icon: const Icon(Icons.add_circle, color: AppTheme.primaryBrand))
                ]),
                
                if (_budgetItems.isEmpty) 
                    const Padding(padding: EdgeInsets.all(16), child: Text("Agrega rubros como Hotel, Gasolina, etc.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),

                ..._budgetItems.map((item) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                        leading: CircleAvatar(
                            backgroundColor: Colors.blue[50], 
                            child: Icon(_getIconForCat(item.category), color: Colors.blue[800], size: 20)
                        ),
                        title: Text(item.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: item.description != null ? Text(item.description!) : null,
                          trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(CurrencyInputFormatter.format(item.estimatedAmount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            InkWell(
                                onTap: () => _deleteItem(item.id),
                                child: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                            )
                          ],
                        ),
                    ),
                )),
                
                const SizedBox(height: 24),

                // SECTION 2: PARTICIPANTS
                 Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Seguimiento de Pagos (Vaca)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: _addGuest, icon: const Icon(Icons.person_add, color: AppTheme.primaryBrand))
                ]),
                
                ..._trackers.map((t) {
                    final currentUid = Supabase.instance.client.auth.currentUser?.id;
                    final isMe = t.userId != null && t.userId == currentUid;
                    
                    return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: t.status == PaymentStatus.paid ? Colors.green.shade200 : Colors.transparent)),
                    child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                             backgroundColor: _getColorForStatus(t.status).withOpacity(0.1),
                             child: Text(t.displayName[0].toUpperCase(), style: TextStyle(color: _getColorForStatus(t.status), fontWeight: FontWeight.bold)),
                        ),
                        title: Text(isMe ? "Tú (${t.displayName})" : t.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            _getTextForStatus(t.status).toUpperCase(), 
                            style: TextStyle(fontSize: 10, color: _getColorForStatus(t.status), fontWeight: FontWeight.bold)
                        ),
                        trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                // Remind Button (Only if Pending)
                                // MODIFIED FOR TESTING: Allow "me" to remind "myself" to test the button
                                if (t.status == PaymentStatus.pending)
                                    IconButton(
                                        icon: const Icon(Icons.send_rounded, color: Colors.blue, size: 20), 
                                        onPressed: () => _remindUser(t)
                                    ),

                                // Case 1: Paid (Green Check)
                                if (t.status == PaymentStatus.paid)
                                   IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () async {
                                        if (_isCurrentUserCreator) {
                                            await _repository.updatePaymentStatus(t.id, PaymentStatus.pending); 
                                            _loadData();
                                        }
                                   }),
                                
                                // Case 2: Verifying (Yellow) -> Creator approves
                                if (t.status == PaymentStatus.verifying)
                                   ElevatedButton(
                                       onPressed: () async {
                                           if (_isCurrentUserCreator) {
                                              await _repository.updatePaymentStatus(t.id, PaymentStatus.paid);
                                              _loadData();
                                              if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pago Aprobado")));
                                           } else if (isMe) {
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Esperando aprobación del organizador.")));
                                           }
                                       },
                                       style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8)),
                                       child: const Text("Aprobar?", style: TextStyle(fontSize: 12)),
                                   ),

                                 // Case 3: Pending (Red) -> User pays
                                if (t.status == PaymentStatus.pending)
                                   isMe 
                                     ? OutlinedButton(
                                         onPressed: () async {
                                             await _repository.updatePaymentStatus(t.id, PaymentStatus.verifying);
                                             _loadData();
                                         },
                                         child: const Text("Ya Pagué"),
                                     )
                                     : IconButton( // Organizer can force pay manually
                                         icon: const Icon(Icons.more_vert, color: Colors.grey),
                                         onPressed: () async {
                                             if (_isCurrentUserCreator) { // Only creator context menu
                                                  await _showStatusMenu(context, t.id);
                                             } else {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Solo el creador puede editar esto.")));
                                             }
                                         }
                                     )
                            ],
                        ),
                    ),
                );
              }),
                
                // Bottom Padding
                const SizedBox(height: 100),
            ],
        )
    );
  }
  
  Future<void> _showStatusMenu(BuildContext context, String trackerId) async {
       // Simple dialog or bottom sheet
       await showModalBottomSheet(context: context, builder: (c) => Column(
           mainAxisSize: MainAxisSize.min,
           children: [
               ListTile(title: const Text("Marcar como Pagado"), onTap: () {
                   _repository.updatePaymentStatus(trackerId, PaymentStatus.paid);
                   _loadData();
                   Navigator.pop(c);
               }),
               ListTile(title: const Text("Marcar como Pendiente"), onTap: () {
                   _repository.updatePaymentStatus(trackerId, PaymentStatus.pending);
                   _loadData();
                   Navigator.pop(c);
               }),
           ],
       ));
  }

  IconData _getIconForCat(String cat) {
      switch(cat) {
          case 'Hospedaje': return Icons.hotel;
          case 'Alimentación': return Icons.restaurant;
          case 'Transporte': return Icons.directions_bus;
          case 'Entretenimiento': return Icons.attractions;
          default: return Icons.category;
      }
  }
  
  Color _getColorForStatus(PaymentStatus s) {
      switch(s) {
          case PaymentStatus.paid: return Colors.green;
          case PaymentStatus.verifying: return Colors.orange;
          default: return Colors.red;
      }
  }
  
  String _getTextForStatus(PaymentStatus s) {
      switch(s) {
          case PaymentStatus.paid: return "Recibido";
          case PaymentStatus.verifying: return "Verificando";
          default: return "Pendiente";
      }
  }

  Widget _buildSkeletonLoading() {
      return ListView(
          padding: const EdgeInsets.all(16),
          children: [
              // Summary Skeleton
              Container(
                 height: 180,
                 width: double.infinity,
                 decoration: BoxDecoration(
                     color: Colors.grey[200],
                     borderRadius: BorderRadius.circular(20),
                 ),
              ),
              const SizedBox(height: 24),
              // List Skeletons
              for (int i=0; i<3; i++)
                  Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      height: 70,
                      decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                      ),
                  ),
               const SizedBox(height: 24),
               for (int i=0; i<3; i++)
                  Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      height: 60,
                      decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                      ),
                  ),
          ],
      );
  }
}
