import 'package:flutter/material.dart';
import 'package:planmapp/core/utils/currency_formatter.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/expenses/data/models/expense_model.dart';
import 'package:planmapp/features/expenses/data/repositories/expense_repository.dart';
import 'package:planmapp/features/expenses/presentation/screens/debts_dashboard_screen.dart';
import 'package:planmapp/features/plans/services/plan_members_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class ExpenseSplitScreen extends StatefulWidget {
  final Map<String, dynamic> expenseData;
  final List<ExpenseItem> initialItems;
  final bool autoSplitAll;

  const ExpenseSplitScreen({super.key, required this.expenseData, required this.initialItems, this.autoSplitAll = false});

  @override
  State<ExpenseSplitScreen> createState() => _ExpenseSplitScreenState();
}

class _ExpenseSplitScreenState extends State<ExpenseSplitScreen> with SingleTickerProviderStateMixin {
  final _membersService = PlanMembersService();
  late ExpenseRepository _expenseRepository;
  
  List<PlanMember> _members = [];
  List<ExpenseItem> _items = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showShareBanner = true;

  final Map<String, List<AssignmentModel>> _assignments = {};
  final List<String> _tempGuests = [];
  late TabController _tabController;
  final Map<String, String> _dynamicNames = {};
  final Set<String> _fetchingKeys = {};

  @override
  void initState() {
    super.initState();
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final isCreator = widget.expenseData['created_by'] == currentUid;
    
    _tabController = TabController(length: isCreator ? 2 : 1, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    
    _expenseRepository = ExpenseRepository(Supabase.instance.client);
    _items = widget.initialItems;
    
    for (var item in _items) {
      _assignments[item.id] = [];
    }
    
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final planId = widget.expenseData['plan_id'];
    List<PlanMember> loaded = [];
    if (planId != null) {
        loaded = await _membersService.getMembers(planId);
    }
    
    // Ensure the current user (owner) is ALWAYS in the list, even if spontaneous plan or empty members
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    if (currentUid != null) {
        final hasMe = loaded.any((m) => m.id == currentUid);
        if (!hasMe) {
            try {
                final profile = await Supabase.instance.client.from('profiles').select('full_name').eq('id', currentUid).maybeSingle();
                loaded.insert(0, PlanMember(id: currentUid, name: profile?['full_name'] ?? 'Tú', isGuest: false));
            } catch (_) {
                loaded.insert(0, PlanMember(id: currentUid, name: 'Tú', isGuest: false));
            }
        }
    }
    
    // LAZY LOAD ITEMS IF COMING FROM DASHBOARD HISTORY
    if (_items.isEmpty && widget.expenseData['id'] != null) {
        final fullExpense = await _expenseRepository.getExpenseById(widget.expenseData['id']);
        if (fullExpense != null && fullExpense.items != null) {
            _items = fullExpense.items!;
            for (var item in _items) {
               _assignments[item.id] = item.assignments ?? [];
            }
        }
    }

    if (mounted) {
        setState(() => _members = loaded);
        if (widget.autoSplitAll) {
            for (var item in _items) _splitEqually(item.id);
        }
        setState(() => _isLoading = false);
    }
  }

  void _updateQuantity(String itemId, String? userId, String? guestName, double newQty) async {
    // Immediate DB Update (Live effect via atomic RPC)
    try {
        final supabase = Supabase.instance.client;
        await supabase.rpc('toggle_expense_assignment', params: {
            'p_item_id': itemId,
            'p_user_id': userId,
            'p_guest_name': guestName,
            'p_qty': newQty <= 0.001 ? 0 : newQty
        });
    } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // Gets explicitly assigned quantity (fraction of item)
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

  void _fetchDynamicName(String uId) async {
      if (_fetchingKeys.contains(uId)) return;
      _fetchingKeys.add(uId);
      try {
          final res = await Supabase.instance.client.from('profiles').select('nickname, full_name').eq('id', uId).maybeSingle();
          if (res != null) {
              if (mounted) setState(() => _dynamicNames[uId] = res['nickname'] ?? res['full_name'] ?? 'Usuario');
          }
      } catch (_) {}
  }

  String _getUserName(String? uId, String? gName) {
      if (uId != null) {
          if (uId == Supabase.instance.client.auth.currentUser?.id) return 'Tú';
          final m = _members.cast<PlanMember?>().firstWhere((m) => m?.id == uId, orElse: () => null);
          if (m != null) return m.name;
          return _dynamicNames[uId] ?? '...';
      }
      return gName ?? "?";
  }

  void _splitEqually(String itemId) {
      final count = _members.length + _tempGuests.length;
      if (count == 0) return;
      final item = _items.firstWhere((i) => i.id == itemId);
      final qtyPerPerson = item.quantity / count;
      
      setState(() {
          _assignments[itemId] = [];
          for (var m in _members) {
              _assignments[itemId]!.add(AssignmentModel(userId: m.id, quantity: qtyPerPerson));
          }
          for (var g in _tempGuests) {
               _assignments[itemId]!.add(AssignmentModel(guestName: g, quantity: qtyPerPerson));
          }
      });
  }

  void _markAsMine(String itemId, num itemQuantity) async {
      final currentUid = Supabase.instance.client.auth.currentUser?.id;
      if (currentUid == null) return;
      
      final currentList = _assignments[itemId] ?? <AssignmentModel>[];
      final exists = currentList.any((a) => a.userId == currentUid);
      
      setState(() {
          if (exists) {
              // Unassign
              currentList.removeWhere((a) => a.userId == currentUid);
          } else {
              // Assign full amount to self, override others
              currentList.clear();
              currentList.add(AssignmentModel(userId: currentUid, quantity: itemQuantity.toDouble()));
          }
          _assignments[itemId] = currentList;
      });

      if (widget.expenseData['id'] != null) {
          try {
              await _expenseRepository.updateItemAssignments(itemId, currentList);
          } catch (e) {
              print("Sync Error: $e");
          }
      }
  }

  void _markAsShared(ExpenseItem item) {
      final selectedUsers = <String>{};
      final selectedGuests = <String>{};
      
      showDialog(context: context, builder: (ctx) {
         return StatefulBuilder(builder: (ctx, setDialogState) {
            return AlertDialog(
                title: Text("¿Compartieron ${item.name}?"),
                content: SizedBox(
                    width: double.maxFinite,
                    child: ListView(
                        shrinkWrap: true,
                        children: [
                            ..._members.map((m) => CheckboxListTile(
                                title: Text(m.name),
                                dense: true,
                                value: selectedUsers.contains(m.id),
                                onChanged: (val) {
                                    setDialogState(() {
                                        if (val == true) selectedUsers.add(m.id);
                                        else selectedUsers.remove(m.id);
                                    });
                                }
                            )),
                            ..._tempGuests.map((g) => CheckboxListTile(
                                title: Text("$g (Inv)"),
                                dense: true,
                                value: selectedGuests.contains(g),
                                onChanged: (val) {
                                    setDialogState(() {
                                        if (val == true) selectedGuests.add(g);
                                        else selectedGuests.remove(g);
                                    });
                                }
                            )),
                        ]
                    )
                ),
                actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                    ElevatedButton(onPressed: () {
                        final totalSelected = selectedUsers.length + selectedGuests.length;
                        if (totalSelected > 0) {
                            final qtyPerPerson = item.quantity / totalSelected;
                            final newAssignments = <AssignmentModel>[];
                            for(var u in selectedUsers) newAssignments.add(AssignmentModel(userId: u, quantity: qtyPerPerson));
                            for(var g in selectedGuests) newAssignments.add(AssignmentModel(guestName: g, quantity: qtyPerPerson));
                            
                            setState(() {
                                _assignments[item.id] = newAssignments;
                            });
                            
                            if (widget.expenseData['id'] != null) {
                                _expenseRepository.updateItemAssignments(item.id, newAssignments)
                                    .catchError((e) => print("Sync Error: $e"));
                            }
                            
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text("División aplicada. Recuerda presionar 'Confirmar' abajo para guardarlo."),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                            ));
                        }
                        Navigator.pop(ctx);
                    }, child: const Text("Dividir"))
                ]
            );
         });
      });
  }

  // WIZARD
  void _openSplitWizard(ExpenseItem item) {
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: const Color(0xFF121212), // Dark mode base
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => _WizardSheet(
              item: item, 
              members: _members, 
              guests: _tempGuests,
              currentAssignments: _assignments[item.id] ?? [],
              onApply: (newAssignments) {
                  setState(() {
                      _assignments[item.id] = newAssignments;
                  });
                  if (widget.expenseData['id'] != null) {
                      _expenseRepository.updateItemAssignments(item.id, newAssignments)
                          .catchError((e) => print("Sync Error: $e"));
                  }
              }
          )
      );
  }

  Future<void> _saveExpense() async {
      setState(() => _isSaving = true);
      try {
          final expenseId = widget.expenseData['id'] as String;
          
          // 1. Update Item Assignments
          for (var item in _items) {
             await _expenseRepository.updateItemAssignments(item.id, _assignments[item.id] ?? []);
          }
          
          // 2. Recalculate debts globally
          await _expenseRepository.calculateAndUpdateDebts(expenseId);

          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cambios guardados exitosamente")));
              if (widget.expenseData['plan_id'] != null) {
                  await _checkAndShowSurvey(widget.expenseData['plan_id']);
              } else {
                  Navigator.pop(context, true);
              }
          }
      } catch (e) {
          if (mounted) {
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
          }
      } 
  }
  Future<void> _checkAndShowSurvey(String planId) async {
      final supabase = Supabase.instance.client;
      try {
          final planRes = await supabase.from('plans').select('restaurant_id').eq('id', planId).maybeSingle();
          if (planRes == null || planRes['restaurant_id'] == null) {
              if (mounted) Navigator.pop(context, true);
              return;
          }
          final resId = planRes['restaurant_id'];
          final restRes = await supabase.from('restaurants').select('name').eq('id', resId).maybeSingle();
          if (restRes == null) {
              if (mounted) Navigator.pop(context, true);
              return;
          }

          if (mounted) {
              int ratingFood = 0;
              int ratingService = 0;
              int ratingAmbiance = 0;
              final feedbackCtrl = TextEditingController();

              Widget buildStarRow(String title, int currentRating, Function(int) onUpdate) {
                 return Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                         Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                         Row(
                             children: List.generate(5, (index) => IconButton(
                                 onPressed: () => onUpdate(index + 1),
                                 icon: Icon(index < currentRating ? Icons.star : Icons.star_border, color: Colors.orange)
                             ))
                         ),
                         const SizedBox(height: 10),
                     ]
                 );
              }

              await showDialog(
                  barrierDismissible: false,
                  context: context,
                  builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.darkBackground,
                      title: Text("Califica a ${restRes['name']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      content: SizedBox(
                          width: double.maxFinite,
                          child: StatefulBuilder(
                              builder: (c, setStateModal) => SingleChildScrollView(
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                          buildStarRow("Comida", ratingFood, (r) => setStateModal(() => ratingFood = r)),
                                          buildStarRow("Servicio", ratingService, (r) => setStateModal(() => ratingService = r)),
                                          buildStarRow("Ambiente", ratingAmbiance, (r) => setStateModal(() => ratingAmbiance = r)),
                                          TextField(
                                              controller: feedbackCtrl,
                                              style: const TextStyle(color: Colors.white),
                                              maxLines: 2,
                                              decoration: const InputDecoration(
                                                  labelText: "Tus comentarios",
                                                  labelStyle: TextStyle(color: Colors.grey),
                                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                                                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryBrand)),
                                              )
                                          )
                                      ]
                                  )
                              )
                          ),
                      ),
                      actions: [
                          TextButton(onPressed: () { 
                             Navigator.pop(ctx); 
                             Navigator.pop(context, true); 
                          }, child: const Text("Omitir", style: TextStyle(color: Colors.grey))),
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand),
                              onPressed: () async {
                                  try {
                                      final itemsJson = _items.map((i) => {"name": i.name, "price": i.price, "qty": i.quantity, "id": i.id}).toList();
                                      await supabase.from('survey_responses').insert({
                                          'restaurant_id': resId,
                                          'plan_id': planId,
                                          'responses': {}, // Required NOT NULL field
                                          'rating_food': ratingFood > 0 ? ratingFood : null,
                                          'rating_service': ratingService > 0 ? ratingService : null,
                                          'rating_ambiance': ratingAmbiance > 0 ? ratingAmbiance : null,
                                          'feedback_text': feedbackCtrl.text,
                                          'receipt_items': itemsJson
                                      });
                                      if (ctx.mounted) {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Gracias por tu opinión!")));
                                          Navigator.pop(context, true); 
                                      }
                                  } catch (e) {
                                      if (ctx.mounted) {
                                           Navigator.pop(ctx);
                                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error interno enviando encuesta: $e"), duration: const Duration(seconds: 4)));
                                           Navigator.pop(context, true); 
                                      }
                                  }
                              },
                              child: const Text("Enviar", style: TextStyle(color: Colors.white))
                          )
                      ]
                  )
              );
          }
      } catch (e) {
          if (mounted) Navigator.pop(context, true);
      }
  }

  Future<void> _shareVacaLink() async {
      final planId = widget.expenseData['plan_id'];
      if (planId == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: No se encontró el ID del Plan')));
          return;
      }
      
      final title = widget.expenseData['title'] ?? 'La Vaca';
      final base = kIsWeb ? Uri.base.origin : "https://planmapp.app";
      final link = "$base/#/vaca/$planId"; 
      final msg = "¡Hey! Ya está lista la Vaca para *$title* 💸.\n\nEscoge qué consumiste en este link para saber cuánto te toca pagar:\n$link";
      
      await showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (c) => SafeArea(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("Compartir Enlace", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  ListTile(
                      leading: const Icon(Icons.notifications_active, color: AppTheme.primaryBrand),
                      title: const Text("Notificar por la App"),
                      subtitle: const Text("Avisará a todos los miembros registrados"),
                      onTap: () async {
                          Navigator.pop(c);
                          await _notifyMembersInApp(title, widget.expenseData['id']);
                      },
                  ),
                  ListTile(
                      leading: const Icon(Icons.message, color: Colors.green),
                      title: const Text("Enviar por WhatsApp"),
                      subtitle: const Text("Link genérico para cualquier persona"),
                      onTap: () async {
                          Navigator.pop(c);
                          final url = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(msg)}");
                          if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                          } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp')));
                          }
                      },
                  ),
                  const SizedBox(height: 16),
              ],
          ))
      );
  }

  Future<void> _notifyMembersInApp(String vacaTitle, String expenseId) async {
      try {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enviando Notificaciones...")));
          
          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
          final organizerName = Supabase.instance.client.auth.currentUser?.email?.split('@').first ?? 'El organizador';

          int sentCount = 0;
          for (var member in _members) {
              if (!member.isGuest && member.id != currentUserId) {
                  await Supabase.instance.client.from('notifications').insert({
                      'user_id': member.id,
                      'title': '¡La Vaca está lista! 🐮',
                      'body': '$organizerName te invita a revisar tu cuenta en $vacaTitle.',
                      'type': 'vaca_split',
                      'data': {'route': '/vaca/$expenseId'},
                      'is_read': false
                  });
                  sentCount++;
              }
          }

          if (mounted) {
              if (sentCount > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("¡$sentCount miembros notificados con éxito!", style: const TextStyle(color: Colors.white)), backgroundColor: Colors.green));
              } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay miembros registrados para notificar. Úsa WhatsApp.")));
              }
          }
      } catch (e) {
          print("Error enviando notificaciones internas: $e");
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al notificar: $e")));
      }
  }

  void _addItemManual() async {
      final nameCtrl = TextEditingController();
      final priceCtrl = TextEditingController();
      final qtyCtrl = TextEditingController(text: '1');
      
      await showDialog(
          context: context,
          builder: (context) => AlertDialog(
              title: const Text("Agregar Ítem"),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nombre (ej. Cerveza)")),
                      TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "Precio Unitario"), keyboardType: TextInputType.number),
                      TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: "Cantidad"), keyboardType: TextInputType.number),
                  ],
              ),
              actions: [
                  TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Cancelar")),
                  ElevatedButton(
                      onPressed: () async {
                          if(nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
                          
                          final price = double.tryParse(priceCtrl.text) ?? 0;
                          final qty = int.tryParse(qtyCtrl.text) ?? 1;
                          
                          setState(() => _isSaving = true);
                          Navigator.pop(context);
                          
                          try {
                              // Insert directly into the DB and fetch it back to get the ID
                              final res = await Supabase.instance.client.from('expense_items').insert({
                                  'expense_id': widget.expenseData['id'],
                                  'name': nameCtrl.text,
                                  'price': price * qty, // Total price for the line
                                  'quantity': qty,
                              }).select().single();
                              
                              final newItem = ExpenseItem.fromJson(res);
                              
                              if (mounted) {
                                  setState(() {
                                      _items.add(newItem);
                                      _assignments[newItem.id] = [];
                                      _isSaving = false;
                                  });
                              }
                          } catch (e) {
                              if (mounted) {
                                  setState(() => _isSaving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error agregando ítem: $e")));
                              }
                          }
                      },
                      child: const Text("Agregar")
                  )
              ],
          )
      );
  }

  @override
  void dispose() {
      _tabController.dispose();
      super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final isCreator = widget.expenseData['created_by'] == currentUid;

    return Scaffold(
        appBar: AppBar(
          title: const Text("Dividir Items"), 
          actions: [
              if (isCreator) ...[
                 if (widget.expenseData['id'] != null)
                     IconButton(icon: const Icon(Icons.share, color: Colors.green), onPressed: _shareVacaLink, tooltip: "Compartir Link 🔗"),
                 IconButton(icon: const Icon(Icons.person_add), onPressed: _addGuestName, tooltip: "Añadir Invitado"),
              ]
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              const Tab(text: "Ítems"),
              if (isCreator) const Tab(text: "Resumen"),
            ],
          ),
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _expenseRepository.getAssignmentsStream(widget.expenseData['id']),
              builder: (context, snapshot) {
                // Update internal state from stream
                if (snapshot.hasData) {
                    final allRaw = snapshot.data!;
                    // First clear
                    for (var key in _assignments.keys) { _assignments[key] = []; }
                    
                    final itemIds = _items.map((i) => i.id).toSet();
                    for (var raw in allRaw) {
                        final iid = raw['expense_item_id'] as String;
                        if (itemIds.contains(iid)) {
                            final checkModel = AssignmentModel.fromJson(raw);
                            _assignments[iid]!.add(checkModel);
                            if (checkModel.userId != null && !_dynamicNames.containsKey(checkModel.userId) && !_members.any((m) => m.id == checkModel.userId)) {
                                _fetchDynamicName(checkModel.userId!);
                            }
                        }
                    }
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                Column(
                  children: [
                      if (_showShareBanner)
                          Container(
                              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.withOpacity(0.3))
                          ),
                          child: Row(
                              children: [
                                  const Icon(Icons.share, color: Colors.green),
                                  const SizedBox(width: 12),
                                  const Expanded(child: Text("¡Invita a tus amigos por WhatsApp dándole al botón de arriba (🔗) para que ellos mismos seleccionen lo que consumieron!", style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold))),
                                  IconButton(
                                      icon: const Icon(Icons.close, color: Colors.green, size: 20),
                                      onPressed: () {
                                          setState(() => _showShareBanner = false);
                                      }
                                  )
                              ]
                          )
                      ),
                      Expanded(
                          child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (ctx, i) {
                            final item = _items[i];
                            final totalAssigned = (_assignments[item.id] ?? []).fold(0.0, (sum, a) => sum + a.quantity);
                            // Tolerance for float math
                            final missing = (item.quantity - totalAssigned);
                            final isComplete = missing.abs() < 0.05; 
                            
                            return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                shape: RoundedRectangleBorder(
                                    side: BorderSide(
                                        color: isComplete ? Colors.green.withOpacity(0.5) : Colors.orange.withOpacity(0.5), 
                                        width: 2
                                    ),
                                    borderRadius: BorderRadius.circular(12)
                                ),
                                child: Column(
                                  children: [
                                    Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                                Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                        Expanded(
                                                            child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                                    const SizedBox(height: 4),
                                                                    Text(
                                                                        "${item.quantity} x ${CurrencyInputFormatter.format(item.price / (item.quantity == 0 ? 1 : item.quantity))} = ${CurrencyInputFormatter.format(item.price)}",
                                                                        style: const TextStyle(fontSize: 13, color: Colors.grey)
                                                                    ),
                                                                    Builder(builder: (_) {
                                                                        String txt = '¡Cuenta Completa!';
                                                                        Color clr = Colors.green;
                                                                        if (!isComplete) {
                                                                            if (missing < 0) {
                                                                                txt = 'Sobra: ${missing.abs().toStringAsFixed(1)}';
                                                                                clr = Colors.red;
                                                                            } else {
                                                                                txt = 'Falta: ${missing.toStringAsFixed(1)}';
                                                                                clr = Colors.orange;
                                                                            }
                                                                        }
                                                                        return Text(txt, style: TextStyle(color: clr, fontSize: 12, fontWeight: FontWeight.bold));
                                                                    }),
                                                                ]
                                                            )
                                                        ),
                                                        IconButton(
                                                            onPressed: () => _openSplitWizard(item),
                                                            icon: const Icon(Icons.auto_fix_high, color: AppTheme.primaryBrand),
                                                            tooltip: "División Avanzada",
                                                        )
                                                    ]
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                    children: [
                                                        Expanded(
                                                            child: OutlinedButton(
                                                                onPressed: () => _markAsMine(item.id, item.quantity),
                                                                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryBrand, side: const BorderSide(color: AppTheme.primaryBrand)),
                                                                child: const Text("Mío", style: TextStyle(fontWeight: FontWeight.bold)),
                                                            )
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                            child: ElevatedButton(
                                                                onPressed: () => _markAsShared(item),
                                                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.white, elevation: 0),
                                                                child: const Text("Compartido"),
                                                            )
                                                        ),
                                                    ]
                                                )
                                            ]
                                        )
                                    ),
                                    // Mini preview of who pays
                                    if ((_assignments[item.id] ?? []).isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        child: Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: (_assignments[item.id] ?? []).map((a) {
                                                final name = _getUserName(a.userId, a.guestName);
                                                return Chip(
                                                    label: Text(
                                                        "$name: ${a.quantity < 1 ? '${(a.quantity*100).toInt()}%' : a.quantity.toStringAsFixed(1)}", // Show % if < 1 (fraction) or Qty if > 1
                                                        style: const TextStyle(fontSize: 10)
                                                    ),
                                                    backgroundColor: Colors.grey[100],
                                                    padding: EdgeInsets.zero,
                                                    visualDensity: VisualDensity.compact,
                                                );
                                            }).toList(),
                                        ),
                                      )
                                  ],
                                ),
                            );
                        },
                    )
                ),
                if (isCreator)
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: OutlinedButton.icon(
                            onPressed: _addItemManual,
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text("Agregar Tarea / Ítem", style: TextStyle(fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 44),
                                foregroundColor: AppTheme.primaryBrand,
                                side: const BorderSide(color: AppTheme.primaryBrand)
                            ),
                        )
                    ),
                Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)]),
                    child: SafeArea(
                        child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveExpense,
                            icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.cloud_done),
                            label: const Text("Confirmar y Guardar Vaca", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                                backgroundColor: AppTheme.primaryBrand,
                                foregroundColor: Colors.white
                            ),
                        )
                    )
                )
              ],
          ),
          if (isCreator) _buildSummaryTab(),
        ],
      );
    },
  ),
);
  }

  Widget _buildSummaryTab() {
     Map<String, double> debts = {};
     
     for (var item in _items) {
         final assigns = _assignments[item.id] ?? [];
         final totalAssignedQty = assigns.fold(0.0, (sum, a) => sum + a.quantity);
         
         if (totalAssignedQty > 0) {
             final pricePerQty = item.price / item.quantity;
             for (var a in assigns) {
                 final personKey = a.userId ?? a.guestName ?? 'Anónimo';
                 final itemCost = a.quantity * pricePerQty;
                 debts[personKey] = (debts[personKey] ?? 0.0) + itemCost;
             }
         }
     }
     
     // Dynamically calculate actual subtotal from current active items
     final dynamicSubtotal = _items.fold(0.0, (sum, i) => sum + i.price);
     
     final subtotal = dynamicSubtotal > 0 ? dynamicSubtotal : ((widget.expenseData['subtotal'] as num?)?.toDouble() ?? 0.0);
     final tax = (widget.expenseData['tax_amount'] as num?)?.toDouble() ?? 0.0;
     final tip = (widget.expenseData['tip_amount'] as num?)?.toDouble() ?? 0.0;
     
     if (subtotal > 0 && (tax > 0 || tip > 0)) {
         final extraMultiplier = (tax + tip) / subtotal;
         final keys = debts.keys.toList();
         for (var k in keys) {
             debts[k] = debts[k]! * (1 + extraMultiplier);
         }
     }
     
     final totalAccount = subtotal + tax + tip;
     
     return ListView(
         padding: const EdgeInsets.all(16),
         children: [
             Card(
                 color: AppTheme.primaryBrand,
                 child: Padding(
                     padding: const EdgeInsets.all(16),
                     child: Column(
                         children: [
                             const Text("Total Cuenta", style: TextStyle(color: Colors.white70)),
                             Text(CurrencyInputFormatter.format(totalAccount), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                             const Divider(color: Colors.white24),
                             Row(
                                 mainAxisAlignment: MainAxisAlignment.spaceAround,
                                 children: [
                                     Column(children: [Text("Items (${_items.length})", style: const TextStyle(color: Colors.white70, fontSize: 12)), Text(CurrencyInputFormatter.format(subtotal), style: const TextStyle(color: Colors.white))]),
                                     Column(children: [const Text("Propina", style: TextStyle(color: Colors.white70, fontSize: 12)), Text(CurrencyInputFormatter.format(tip), style: const TextStyle(color: Colors.white))]),
                                     Column(children: [const Text("Impuesto", style: TextStyle(color: Colors.white70, fontSize: 12)), Text(CurrencyInputFormatter.format(tax), style: const TextStyle(color: Colors.white))]),
                                 ],
                             )
                         ],
                     ),
                 ),
             ),
             const SizedBox(height: 24),
             if (debts.isEmpty) const Text("Aún no se ha asignado ningún ítem a nadie.", style: TextStyle(color: Colors.grey)),
             if (debts.isNotEmpty) ...[
                 const Text("Quién debe cuánto (estimado)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 12),
                 ...debts.entries.map((entry) {
                     final key = entry.key;
                     final amount = entry.value;
                     String name = key;
                     String? avatar;
                     
                     final member = _members.cast<PlanMember?>().firstWhere((m) => m?.id == key, orElse: () => null);
                     if (member != null) {
                         name = member.name;
                         avatar = member.avatarUrl;
                     } else if (key.startsWith('guest_')) {
                         name = key.replaceFirst('guest_', '') + " (Inv)";
                     } else {
                         name = _getUserName(key, null);
                     }
                     
                     return ListTile(
                         contentPadding: EdgeInsets.zero,
                         leading: CircleAvatar(backgroundImage: avatar != null ? NetworkImage(avatar) : null, child: avatar == null ? Text(name[0].toUpperCase()) : null),
                         title: Text(name),
                         trailing: Text(CurrencyInputFormatter.format(amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                     );
                 })
             ],
             const SizedBox(height: 32),
             Container(
                 decoration: BoxDecoration(
                     color: Colors.blue.withOpacity(0.1),
                     borderRadius: BorderRadius.circular(16),
                     border: Border.all(color: Colors.blue.withOpacity(0.3))
                 ),
                 child: ListTile(
                     leading: const Icon(Icons.dashboard_customize, color: Colors.blue),
                     title: const Text("Ver mis cuentas globales", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                     subtitle: const Text("Ir al Dashboard Financiero"),
                     trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
                     onTap: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtsDashboardScreen()));
                     },
                 ),
             ),
             const SizedBox(height: 32),
         ],
     );
  }
}

// ----------------------
// WIZARD WIDGET
// ----------------------
class _WizardSheet extends StatefulWidget {
  final ExpenseItem item;
  final List<PlanMember> members;
  final List<String> guests;
  final List<AssignmentModel> currentAssignments;
  final Function(List<AssignmentModel>) onApply;

  const _WizardSheet({required this.item, required this.members, required this.guests, required this.currentAssignments, required this.onApply});

  @override
  State<_WizardSheet> createState() => _WizardSheetState();
}

class _WizardSheetState extends State<_WizardSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, double> _tempValues = {}; // Holds Qty, Percent, or Amount depending on tab

  @override
  void initState() {
      super.initState();
      _tabController = TabController(length: 4, vsync: this); // NEW Length 4
      
      // Initialize with current quantities
      _initValuesFromCurrent();
  }

  @override
  void dispose() {
      _tabController.dispose();
      super.dispose();
  }

  void _initValuesFromCurrent() {
      for (var a in widget.currentAssignments) {
          if (a.userId != null) {
              _tempValues["u_${a.userId}"] = a.quantity;
          } else if (a.guestName != null) {
              _tempValues["g_${a.guestName}"] = a.quantity;
          }
      }
  }

  void _save() {
      List<AssignmentModel> result = [];
      
      final unitPrice = widget.item.price / widget.item.quantity; 

      // Pre-calculation for Mode -1 (Checkbox)
      double splitShare = 0;
      if (_tabController.index == 0) { // Checkbox Mode is now Index 0
          final selectedCount = _tempValues.values.where((v) => v > 0).length;
          if (selectedCount > 0) {
              splitShare = widget.item.quantity / selectedCount;
          }
      }

      _tempValues.forEach((key, val) {
          if (val <= 0) return;
          
          double finalQty = 0;
          
          if (_tabController.index == 0) { // Checkbox
              // If val > 0 (checked), assign share
              finalQty = splitShare;
          } else if (_tabController.index == 1) { // Units (Previously 0)
              finalQty = val;
          } else if (_tabController.index == 2) { // % (Previously 1)
              finalQty = (val / 100) * widget.item.quantity;
          } else { // Amount (Previously 2)
              if (unitPrice > 0) finalQty = val / unitPrice;
          }

          if (key.startsWith("u_")) {
              result.add(AssignmentModel(userId: key.substring(2), quantity: finalQty));
          } else if (key.startsWith("g_")) {
               result.add(AssignmentModel(guestName: key.substring(2), quantity: finalQty));
          }
      });
      
      widget.onApply(result);
      if (mounted && Navigator.canPop(context)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Ajuste aplicado. Recuerda presionar 'Confirmar y Guardar' abajo para salvar todo."),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
          ));
          Navigator.pop(context);
      }
  }

  @override
  Widget build(BuildContext context) {
      return Theme(
          data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: AppTheme.primaryBrand, surface: Color(0xFF121212)),
              scaffoldBackgroundColor: const Color(0xFF121212),
              dialogBackgroundColor: const Color(0xFF2A2A2A),
              bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Color(0xFF121212)),
          ),
          child: Container(
              color: const Color(0xFF121212),
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9), // Prevent overflowing top
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      const SizedBox(height: 16),
                      Text("Dividir: ${widget.item.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(CurrencyInputFormatter.format(widget.item.price), style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      TabBar(
                          controller: _tabController,
                          labelColor: AppTheme.primaryBrand,
                          indicatorColor: AppTheme.primaryBrand,
                          isScrollable: true, // Allow more tabs
                          onTap: (index) {
                              setState(() {
                                  final newValues = <String, double>{};
                                  _tempValues.clear();
                                  _tempValues.addAll(newValues);
                              });
                          },
                          tabs: const [
                              Tab(text: "Selección"),
                              Tab(text: "Unidades"),
                              Tab(text: "%"),
                              Tab(text: "\$"),
                          ]
                      ),
                      SizedBox(
                          height: 300,
                          child: TabBarView(
                              controller: _tabController,
                              children: [
                                  _buildList(mode: -1), // Checkbox mode
                                  _buildList(mode: 0),
                                  _buildList(mode: 1),
                                  _buildList(mode: 2),
                              ],
                          ),
                      ),
                          Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: ElevatedButton(
                                  onPressed: _save,
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
                                  child: const Text("Aplicar División", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                          )
                      ],
                  ),
              )
          ),
      );
  }

  Widget _buildList({required int mode}) {
      // mode -1: Checkbox (Select multiple)
      // mode 0: Qty (Counter)
      // mode 1: Percent (Slider/Input)
      // mode 2: Amount (Currency Input)
      
      final keys = [...widget.members.map((m) => "u_${m.id}"), ...widget.guests.map((g) => "g_$g")];
      
      return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: keys.length,
          separatorBuilder: (_,__) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
              final key = keys[i];
              final name = key.startsWith("u_") 
                  ? widget.members.firstWhere((m) => m.id == key.substring(2)).name
                  : "${key.substring(2)} (Inv)";
              
              final val = _tempValues[key] ?? 0.0;

              return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                      children: [
                          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
                          if (mode == -1) ...[
                               Checkbox(
                                  value: val > 0, 
                                  activeColor: AppTheme.primaryBrand,
                                  onChanged: (isSelected) {
                                      setState(() {
                                          _tempValues[key] = (isSelected == true) ? 1.0 : 0.0;
                                      });
                                  }
                               )
                          ] else if (mode == 0) ...[
                               IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setState(() => _tempValues[key] = (val - 0.5).clamp(0, 999))),
                               Text(val.toStringAsFixed(1), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                               IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => _tempValues[key] = val + 0.5)),
                          ] else if (mode == 1) ...[
                               Expanded(
                                   flex: 2,
                                   child: Slider(
                                       value: val.clamp(0, 100), 
                                       max: 100, 
                                       onChanged: (v) => setState(() => _tempValues[key] = v),
                                       activeColor: AppTheme.primaryBrand,
                                       inactiveColor: Colors.grey.withOpacity(0.3),
                                   )
                               ),
                               Text("${val.toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ] else ...[
                               SizedBox(
                                   width: 100,
                                   child: TextField(
                                       keyboardType: TextInputType.number,
                                       decoration: const InputDecoration(prefixText: "\$", isDense: true, contentPadding: EdgeInsets.all(8), border: OutlineInputBorder()),
                                       onChanged: (str) {
                                            final parsed = double.tryParse(str) ?? 0;
                                            _tempValues[key] = parsed;
                                       },
                                       // No controller sync for simplicity in this MVP snippet, relying on onChanged
                                   )
                               )
                          ]
                      ],
                  ),
              );
          },
      );
  }
}
