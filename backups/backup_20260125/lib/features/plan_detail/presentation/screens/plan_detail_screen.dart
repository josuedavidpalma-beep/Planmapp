import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/plans/domain/models/plan_model.dart';
import 'package:intl/intl.dart';
import 'package:planmapp/core/services/plan_service.dart';
import 'package:planmapp/core/services/chat_service.dart';
import 'package:planmapp/features/plan_detail/domain/models/message_model.dart';
import 'package:planmapp/core/services/poll_service.dart';
import 'package:planmapp/features/plan_detail/domain/models/poll_model.dart';
import 'package:planmapp/features/expenses/presentation/screens/expenses_plan_tab.dart';
// import 'package:planmapp/features/expenses/presentation/screens/add_expense_screen.dart'; // Removed
import 'package:planmapp/features/expenses/domain/services/bill_service.dart';
import 'package:planmapp/features/expenses/presentation/screens/bill_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/expenses/presentation/screens/budget_plan_tab.dart'; // Import Budget Tab
import 'package:planmapp/features/plans/services/plan_members_service.dart';
import 'package:planmapp/features/plan_detail/presentation/widgets/participant_list_bottom_sheet.dart';

import 'package:planmapp/features/itinerary/presentation/screens/itinerary_plan_tab.dart';
import 'package:planmapp/core/widgets/auth_guard.dart';
import 'package:planmapp/core/presentation/widgets/dancing_empty_state.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:planmapp/features/games/presentation/widgets/wheel_spin_dialog.dart'; // NEW Wheel
import 'package:planmapp/features/plan_detail/presentation/screens/logistics_plan_tab.dart';
import 'package:planmapp/features/plan_detail/presentation/screens/games_plan_tab.dart';

class PlanDetailScreen extends StatefulWidget {
  final String planId;

  const PlanDetailScreen({super.key, required this.planId});

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}


class _PlanDetailScreenState extends State<PlanDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Plan? _plan;
  bool _isLoading = true;
  final _messageController = TextEditingController();
  final _chatScrollController = ScrollController();
  final _chatService = ChatService();
  final _pollService = PollService();

  Map<String, Map<String, dynamic>> _membersMap = {}; // Cache for user profiles
  late Stream<List<Message>> _chatStream;
  late Stream<List<Poll>> _pollsStream;

  String _myRole = 'member';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    
    // Initialize streams safely
    try {
        _chatStream = _chatService.getMessagesValues(widget.planId);
    } catch (_) {
        _chatStream = Stream.value([]);
    }
    
    try {
        _pollsStream = _pollService.getPollsStream(widget.planId);
    } catch (_) {
        _pollsStream = Stream.value([]);
    }
    
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    
    // Defer loading to ensure context is ready? No, initState is fine, but we use safe call.
    _loadAllData();
  }
  
  // ... dispose ...

  void _scrollToBottom() {
    if (_chatScrollController.hasClients) {
      _chatScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadAllData() async {
    try {
      final fetchedPlan = await PlanService().getPlanById(widget.planId);
      final uid = Supabase.instance.client.auth.currentUser?.id;
      
      String role = 'member';
      if (fetchedPlan != null && uid != null && fetchedPlan.creatorId == uid) {
          role = 'admin';
          } else {
              try {
                 role = await PlanMembersService().getMyRole(widget.planId);
              } catch (_) {}
          }

      await _loadMembers(); // Fetch profiles for chat
      
      if (mounted) {
        setState(() {
          _plan = fetchedPlan;
          _myRole = role;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
         setState(() => _isLoading = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error cargando plan: $e")));
      }
    }
  }

  // Fetch members for Chat avatars
  Future<void> _loadMembers() async {
      try {
          final members = await PlanMembersService().getMembers(widget.planId);
          final map = <String, Map<String, dynamic>>{};
          for (var m in members) {
              map[m.id] = {
                  'full_name': m.name,
                  'avatar_url': m.avatarUrl,
                  'role': m.role
              };
          }
          if (mounted) setState(() => _membersMap = map);
      } catch (_) {}
  }

  @override
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
       return const Scaffold(
           body: Center(child: CircularProgressIndicator())
       );
    }

    if (_plan == null) {
       return Scaffold(
           appBar: AppBar(title: const Text("Error")),
           body: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      const Icon(Icons.error_outline, size: 60, color: Colors.orange),
                      const SizedBox(height: 16),
                      const Text("No se pudo cargar el plan."),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadAllData, child: const Text("Reintentar"))
                  ],
              )
           ),
       );
    }

    // ROBUST LAYOUT: Standard Scaffold (No Slivers/NestedScrollView)
    return Scaffold(
      appBar: AppBar(
         title: Text(_plan?.title ?? "Detalle del Plan", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
         backgroundColor: AppTheme.primaryBrand,
         iconTheme: const IconThemeData(color: Colors.white),
         elevation: 0,
         flexibleSpace: Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppTheme.primaryBrand, AppTheme.secondaryBrand],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                ),
            ),
         ),
         actions: [
            IconButton(icon: const Icon(Icons.share), onPressed: () {}),
            IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
         ],
         bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
               color: Colors.white, // Tab Bar Background
               child: TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  labelColor: AppTheme.primaryBrand,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppTheme.primaryBrand,
                  tabs: const [
                      Tab(icon: Icon(Icons.chat_bubble_outline), text: "Resumen"),
                      Tab(icon: Icon(Icons.map_outlined), text: "Itinerario"),
                      Tab(icon: Icon(Icons.checklist_rtl_rounded), text: "Logística"),
                      Tab(icon: Icon(Icons.attach_money_rounded), text: "Gastos"),
                      Tab(icon: Icon(Icons.casino_outlined), text: "Juegos"),
                  ],
               ),
            ),
         ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
             _buildResumenTab(), 
             ItineraryPlanTab(planId: widget.planId, userRole: _myRole, planDate: _plan!.eventDate),
             LogisticsPlanTab(planId: widget.planId),
             ExpensesPlanTab(planId: widget.planId, userRole: _myRole),
             GamesPlanTab(planId: widget.planId),
          ],
        ),
      ),
      floatingActionButton: _getFabForTab(),
    );
  }

  // Merged Tab: Polls at top (collapsible/scrollable) + Chat
  Widget _buildResumenTab() {
     return Column(
       children: [
          // Active Polls Section
          StreamBuilder<List<Poll>>(
             stream: _pollsStream,
             builder: (context, snapshot) {
                 final polls = snapshot.data ?? [];
                 final activePolls = polls.where((p) => !p.isClosed && p.status != 'draft').toList();
                 
                 // Show Drafts helper?
                 final drafts = polls.where((p) => p.status == 'draft').toList();

                 if (activePolls.isEmpty && drafts.isEmpty) {
                     // Minimal "Create Poll" suggestion
                     return Container(
                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                         color: Colors.grey[50],
                         child: Row(
                             children: [
                                 const Icon(Icons.poll_outlined, color: Colors.grey, size: 20),
                                 const SizedBox(width: 8),
                                 const Expanded(child: Text("¿Indecisos? Crea una encuesta.", style: TextStyle(color: Colors.grey, fontSize: 12))),
                                 TextButton(
                                     onPressed: () {
                                         if (context.mounted) _showCreatePollDialog();
                                     }, 
                                     child: const Text("Crear")
                                 )
                             ],
                         ),
                     );
                 }

                 return Container(
                    constraints: const BoxConstraints(maxHeight: 220), // Limit height so chat isn't pushed too far
                    child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: [
                           // Drafts Banner
                           if (drafts.isNotEmpty)
                               Container(
                                   margin: const EdgeInsets.only(bottom: 8),
                                   decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(8)),
                                   child: ListTile(
                                       dense: true,
                                       leading: const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                                       title: Text("Tienes ${drafts.length} borrador(es)", style: const TextStyle(fontSize: 12)),
                                       trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                                       onTap: () {
                                            // Show drafts dialog or expand
                                            _showDraftsDialog(drafts);
                                       },
                                   ),
                               ),
                               
                           // Active Polls Horizontal List? Or Vertical Stack?
                           // Vertical Stack better for visibility
                           ...activePolls.map((p) => Container(
                               margin: const EdgeInsets.only(bottom: 8),
                               child: _buildPollCard(p), // Reusing card but maybe simplified
                           )),
                           
                           // Add Button
                           Center(
                               child: TextButton.icon(
                                   onPressed: _showCreatePollDialog, 
                                   icon: const Icon(Icons.add_circle_outline, size: 16), 
                                   label: const Text("Nueva Encuesta", style: TextStyle(fontSize: 12))
                               ),
                           )
                        ],
                    ),
                 );
             }
          ),
          
          const Divider(height: 1),
          
          // Chat Area
          Expanded(
              child: StreamBuilder<List<Message>>(
                stream: _chatStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snapshot.data ?? [];
                  if (messages.isEmpty) {
                     return const Center(child: DancingEmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: "El chat está vacío",
                        message: "Sé el primero en saludar. 👋",
                     ));
                  }
                  return ListView.builder(
                    controller: _chatScrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) => _buildMessageBubble(messages[index])
                        .animate().fade(duration: 300.ms).slideX(begin: 0.2, end: 0, curve: Curves.easeOut), 
                  );
                },
              ),
          ),
          _buildMessageInput(),
       ],
     );
  }

  void _showDraftsDialog(List<Poll> drafts) {
      showModalBottomSheet(context: context, builder: (context) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
              const Text("Borradores de Encuestas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...drafts.map((d) => ListTile(
                  title: Text(d.question),
                  onTap: () {
                      Navigator.pop(context);
                      _showCreatePollDialog(initialQuestion: d.question, draftId: d.id);
                  },
              ))
          ],
      ));
  }

  Widget? _getFabForTab() {
      switch (_tabController.index) {
          case 2: // Logística
              return FloatingActionButton(
                  onPressed: () {
                      // Add Task Logic - Handled inside Logistics Tab usually, but if here:
                      // _logisticsKey.currentState?.showAddDialog();
                  },
                  child: const Icon(Icons.add_task),
              );
          case 3: // Gastos
              if (_myRole == 'admin' || _myRole == 'treasurer') {
                  return FloatingActionButton(
                    onPressed: _createNewBill,
                    child: const Icon(Icons.note_add_outlined),
                  );
              }
              return null;
          default:
              return null;
      }
  }

  Future<void> _createNewBill() async {
      if (!await AuthGuard.ensureAuthenticated(context)) return;
      
      final titleController = TextEditingController();
      final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
          title: const Text("Nueva Cuenta"),
          content: TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Nombre (ej. Cena, Taxis)", hintText: "Cuenta"),
              autofocus: true,
          ),
          actions: [
              TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text("Cancelar")),
              ElevatedButton(onPressed: ()=>Navigator.pop(context, true), child: const Text("Crear")),
          ],
      ));
      
      if (confirm == true) {
           try {
               final currentUser = Supabase.instance.client.auth.currentUser!.id;
               final String title = titleController.text.isEmpty ? "Cuenta" : titleController.text;
               final newBill = await BillService().createBill(widget.planId, currentUser, title);
               
               if (mounted) {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => BillDetailScreen(billId: newBill.id, planId: widget.planId)));
               }
           } catch(e) {
               if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
           }
      }
  }
  






  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;
    if (!await AuthGuard.ensureAuthenticated(context)) return; // Guard
    HapticFeedback.lightImpact();
    try {
      await _chatService.sendMessage(widget.planId, _messageController.text);
      _messageController.clear();
      // Wait for frame to scroll
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  int _pollType = 0; // 0: Text, 1: Date, 2: Time

  Future<void> _showCreatePollDialog({String? initialQuestion, String? draftId}) async {
    final titleController = TextEditingController(text: initialQuestion);
    final optionControllers = [TextEditingController(), TextEditingController()];
    DateTime? selectedDeadline;

    // Auto-detect type from question if it's a draft
    if (draftId != null && initialQuestion != null) {
        final qLower = initialQuestion.toLowerCase();
        if (qLower.contains('cuándo') || qLower.contains('fecha') || qLower.contains('dia') || qLower.contains('día')) {
            _pollType = 1; // Date
        } else if (qLower.contains('hora') || qLower.contains('tiempo')) {
            _pollType = 2; // Time
        } else {
            _pollType = 0; // Text
        }
    } else {
        _pollType = 0; // Default new
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(  // Move StatefulBuilder to wrap the whole content for type switch
          builder: (context, setDialogState) => AlertDialog(
            scrollable: true,
            title: Text(draftId != null ? "Configurar Encuesta" : "Nueva Encuesta"),
            content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // POLL TYPE SELECTOR
                    if (draftId == null) // Only for new polls
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: SegmentedButton<int>(
                              segments: const [
                                  ButtonSegment(value: 0, label: Text("Texto"), icon: Icon(Icons.text_fields)),
                                  ButtonSegment(value: 1, label: Text("Fecha"), icon: Icon(Icons.calendar_today)),
                                  ButtonSegment(value: 2, label: Text("Hora"), icon: Icon(Icons.access_time)),
                              ],
                              selected: {_pollType},
                              onSelectionChanged: (Set<int> newSelection) {
                                  setDialogState(() {
                                      _pollType = newSelection.first;
                                      // Auto-set helpful questions
                                      if (titleController.text.isEmpty) {
                                          if (_pollType == 1) titleController.text = "¿Qué día les queda mejor?";
                                          if (_pollType == 2) titleController.text = "¿A qué hora nos vemos?";
                                      }
                                  });
                              },
                              showSelectedIcon: false,
                          ),
                        ),

                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(labelText: _pollType == 0 ? "¿Qué quieres preguntar?" : "Pregunta"),
                    ),
                    const SizedBox(height: 16),
                    ...optionControllers.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: TextField(
                        controller: entry.value,
                        readOnly: _pollType != 0, // Read-only for Date/Time to force picker
                        onTap: _pollType != 0 ? () async {
                             // Edit existing option
                             if (_pollType == 1) { // Date
                                 final date = await showDatePicker(
                                     context: context, 
                                     initialDate: DateTime.now(), 
                                     firstDate: DateTime.now(), 
                                     lastDate: DateTime.now().add(const Duration(days: 365))
                                 );
                                 if (date != null) {
                                     entry.value.text = DateFormat('EEE d MMM', 'es_CO').format(date); // e.g. Lun 24 Ene
                                 }
                             } else if (_pollType == 2) { // Time
                                 final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                 if (time != null) {
                                     entry.value.text = time.format(context); // e.g. 8:30 PM
                                 }
                             }
                        } : null,
                        decoration: InputDecoration(
                           labelText: "Opción ${entry.key + 1}",
                           suffixIcon: entry.key > 1 
                            ? IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => setDialogState(() => optionControllers.removeAt(entry.key)),
                              ) 
                            : (_pollType != 0 ? const Icon(Icons.touch_app, size: 16) : null),
                        ),
                      ),
                    )),
                    
                    // ADD OPTION BUTTON
                    TextButton.icon(
                      onPressed: () async {
                           if (_pollType == 0) {
                               // Text: Just add empty
                               setDialogState(() => optionControllers.add(TextEditingController()));
                           } else if (_pollType == 1) { 
                               // Date: Pick and Add
                               final date = await showDatePicker(
                                   context: context, 
                                   initialDate: DateTime.now(), 
                                   firstDate: DateTime.now(), 
                                   lastDate: DateTime.now().add(const Duration(days: 365))
                               );
                               if (date != null) {
                                   setDialogState(() => optionControllers.add(TextEditingController(text: DateFormat('EEE d MMM', 'es_CO').format(date))));
                               }
                           } else if (_pollType == 2) {
                               // Time: Pick and Add
                               final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                               if (time != null) {
                                   setDialogState(() => optionControllers.add(TextEditingController(text: time.format(context))));
                               }
                           }
                      },
                      icon: Icon(_pollType == 0 ? Icons.add : Icons.calendar_month),
                      label: Text(_pollType == 0 ? "Agregar opción" : "Seleccionar ${_pollType == 1 ? 'Fecha' : 'Hora'}"),
                    ),

                    // AI SUGGESTION (Only for Text)
                    if (_pollType == 0)
                        TextButton.icon(
                          onPressed: () async {
                              if (titleController.text.isEmpty) return; 
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✨ Pensando opciones...")));
                              
                              try {
                                  final supabase = Supabase.instance.client;
                                  final response = await supabase.functions.invoke('ai-assistant', body: {
                                       'action': 'suggest_poll_options',
                                       'payload': { 'question': titleController.text }
                                  });
                                  
                                  final List<dynamic> suggestions = response.data;
                                  setDialogState(() {
                                      for (var s in suggestions) {
                                          optionControllers.add(TextEditingController(text: s.toString()));
                                      }
                                  });
                              } catch(e) { /* Error handling */ }
                          },
                          icon: const Icon(Icons.auto_awesome, color: Colors.purple),
                          label: const Text("Sugerir Opciones (IA)", style: TextStyle(color: Colors.purple)),
                        ),
                        
                    const SizedBox(height: 16),
                    ListTile(
                        title: Text(selectedDeadline == null ? "Definir Límite de Tiempo (Opcional)" : "Cierra: ${DateFormat('dd MMM HH:mm').format(selectedDeadline!)}"),
                        leading: const Icon(Icons.timer_outlined),
                        trailing: selectedDeadline != null 
                            ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setDialogState(() => selectedDeadline = null)) 
                            : const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                            final date = await showDatePicker(
                                context: context, 
                                initialDate: DateTime.now().add(const Duration(days: 1)), 
                                firstDate: DateTime.now(), 
                                lastDate: DateTime.now().add(const Duration(days: 30))
                            );
                            if (date != null && context.mounted) {
                                final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 23, minute: 59));
                                if (time != null) {
                                    setDialogState(() {
                                        selectedDeadline = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                                    });
                                }
                            }
                        },
                    ),
                  ],
                ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isEmpty) return;
                  final options = optionControllers
                      .map((e) => e.text)
                      .where((t) => t.isNotEmpty)
                      .toList();
                  if (options.length < 2) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Agrega al menos 2 opciones")));
                      return;
                  }
    
                  if (draftId != null) {
                      try { await _pollService.deletePoll(draftId); } catch (_) {}
                  }
    
                  await _pollService.createPoll(widget.planId, titleController.text, options, expiresAt: selectedDeadline);
                  
                  if (context.mounted) {
                      Navigator.pop(context);
                      setState(() {
                          _pollsStream = _pollService.getPollsStream(widget.planId);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Encuesta lanzada! 🚀")));
                  }
                },
                child: const Text("Crear"),
              ),
            ],
          ),
      ),
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<Message>>(
            stream: _chatStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                 return const Center(child: DancingEmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: "El chat está vacío",
                    message: "Sé el primero en saludar. 👋",
                 ));
              }
              return ListView.builder(
                controller: _chatScrollController,
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) => _buildMessageBubble(messages[index])
                    .animate().fade(duration: 300.ms).slideX(begin: 0.2, end: 0, curve: Curves.easeOut), // Stagger logic slightly diff for reverse list
              );
            },
          ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildPollsTab() {
     return StreamBuilder<List<Poll>>(
        stream: _pollsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allPolls = snapshot.data ?? [];
          
          if (allPolls.isEmpty) {
            return const DancingEmptyState(
               icon: Icons.poll_outlined,
               title: "Haz escuchar tu voz",
               message: "¿No sabes qué comer o dónde ir?\nCrea una encuesta y decidan juntos.",
            );
          }

          final drafts = allPolls.where((p) => p.status == 'draft').toList();
          final activePolls = allPolls.where((p) => p.status != 'draft').toList();

          return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                  if (drafts.isNotEmpty) ...[
                      const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text("Sugerencias (Borradores)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 14)),
                      ),
                      ...drafts.map((poll) => Card(
                          color: Colors.amber.shade50,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.amber.shade200)),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                              leading: const Icon(Icons.lightbulb_outline, color: Colors.amber),
                              title: Text(poll.question, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: const Text("Toca para configurar opciones"),
                              trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, elevation: 0),
                                  onPressed: () {
                                      _showCreatePollDialog(initialQuestion: poll.question, draftId: poll.id);
                                  }, 
                                  child: const Text("Configurar")
                              ),
                          ),
                      )),
                      const SizedBox(height: 16),
                      const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text("Activas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                  ],

                  ...activePolls.map((poll) => _buildPollCard(poll).animate().fade().slideY(begin: 0.1)),
              ],
          );
        },
      );
  }

  Widget _buildPollCard(Poll poll) {
    // Creator Check
    final isCreator = _plan?.creatorId == _chatService.currentUserId;
    final int totalVotes = poll.options.fold(0, (sum, opt) => sum + opt.voteCount);
    
    // Check Expiration
    bool isExpired = false;
    if (poll.expiresAt != null && DateTime.now().isAfter(poll.expiresAt!)) {
        isExpired = true;
    }
    
    // CLOSED STATE (Manually Closed or Expired)
    if (poll.isClosed || isExpired) {
        // Find winner
        PollOption? winner;
        int max = -1;
        for (var opt in poll.options) {
            if (opt.voteCount > max) {
                max = opt.voteCount;
                winner = opt;
            }
        }
        final isTie = poll.options.where((o) => o.voteCount == max).length > 1;

        return Card(
           color: Colors.grey[100],
           margin: const EdgeInsets.only(bottom: 12),
           child: ListTile(
               leading: CircleAvatar(
                   backgroundColor: Colors.grey, 
                   child: Icon(isExpired ? Icons.timer_off : Icons.check, color: Colors.white)
               ),
               title: Text(poll.question, style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.lineThrough, color: Colors.grey)),
               subtitle: Text(
                   max > 0 ? (isTie ? "Empate ($max votos)" : "Ganador: ${winner?.text} ($max votos)") : "Sin votos",
                   style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)
               ),
               trailing: isCreator && isExpired && !poll.isClosed 
                    ? IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.blue),
                        tooltip: "Reabrir o Cerrar Definitivamente",
                        onPressed: () {
                             _pollService.closePoll(poll.id); // For now just mark as closed in DB to sync state
                        },
                    ) 
                    : null
           ),
        );
    }

    // ACTIVE STATE
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.poll_rounded, color: AppTheme.accentColor),
                      const SizedBox(width: 8),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text("Encuesta", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              if (poll.expiresAt != null)
                                Text(
                                    "Cierra: ${DateFormat('d MMM HH:mm').format(poll.expiresAt!)}",
                                    style: const TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold)
                                )
                          ],
                      )),
                    ],
                  ),
                ),
                if (isCreator)
                    SizedBox(
                        height: 24,
                        width: 24,
                        child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                            onSelected: (value) async {
                                if (value == 'close') {
                                     final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                                        title: const Text("¿Cerrar Encuesta?"),
                                        content: const Text("Ya no se podrán recibir más votos."),
                                        actions: [
                                            TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Cancelar")),
                                            TextButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("Cerrar")),
                                        ]
                                    ));
                                    if (confirm == true) {
                                        await _pollService.closePoll(poll.id);
                                        setState((){});
                                    }
                                } else if (value == 'promote') {
                                     final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                                        title: const Text("¿Crear Actividad?"),
                                        content: const Text("La opción ganadora se convertirá en una actividad del itinerario.\n\nLa encuesta se cerrará."),
                                        actions: [
                                            TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Cancelar")),
                                            ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.white),
                                                onPressed: ()=>Navigator.pop(c, true), 
                                                child: const Text("Convertir")
                                            ),
                                        ]
                                    ));
                                    if (confirm == true) {
                                        await _pollService.promotePollToActivity(poll.id);
                                        if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Actividad creada en el Itinerario! 🗺️")));
                                            setState((){});
                                        }
                                    }
                                }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(
                                    value: 'close',
                                    child: Row(children: [Icon(Icons.lock_outline, size: 18), SizedBox(width: 8), Text('Cerrar Encuesta')]),
                                ),
                                const PopupMenuItem<String>(
                                    value: 'promote',
                                    child: Row(children: [Icon(Icons.map, size: 18, color: AppTheme.primaryBrand), SizedBox(width: 8), Text('Convertir en Actividad', style: TextStyle(color: AppTheme.primaryBrand, fontWeight: FontWeight.bold))]),
                                ),
                            ],
                        ),
                    ),
                const SizedBox(width: 8),
                Text("$totalVotes ${totalVotes == 1 ? 'voto' : 'votos'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            Text(poll.question, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            for (var option in poll.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildPollOption(poll.id, option, totalVotes),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPollOption(String pollId, PollOption option, int totalVotes) {
    final double percent = totalVotes > 0 ? (option.voteCount / totalVotes) : 0.0;
    final bool isMyVote = option.isVotedByMe;

    return InkWell(
      onTap: () async {
        HapticFeedback.lightImpact();
        if (!await AuthGuard.ensureAuthenticated(context)) return; // Guard
        try {
          await _pollService.vote(pollId, option.id);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Voto registrado! 🗳️")));
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ya votaste por esta opción.")));
        }
      },
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isMyVote ? AppTheme.primaryBrand.withOpacity(0.05) : AppTheme.lightBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMyVote ? AppTheme.primaryBrand : Colors.grey.shade300,
            width: isMyVote ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
             FractionallySizedBox(
               widthFactor: percent, 
               child: Container(
                 decoration: BoxDecoration(
                   color: (isMyVote ? AppTheme.primaryBrand : AppTheme.secondaryBrand).withOpacity(0.2),
                   borderRadius: BorderRadius.circular(10),
                 ),
               ),
             ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      option.text, 
                      style: TextStyle(
                        fontWeight: isMyVote ? FontWeight.bold : FontWeight.w500,
                        color: isMyVote ? AppTheme.primaryBrand : Colors.black87,
                      )
                    )
                  ),
                  Row(
                    children: [
                      if (option.voteCount > 0)
                        Text(
                          "${(percent * 100).toInt()}%", 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 13,
                            color: isMyVote ? AppTheme.primaryBrand : Colors.black54,
                          )
                        ),
                      const SizedBox(width: 8),
                      Icon(
                        isMyVote ? Icons.check_circle : Icons.check_circle_outline, 
                        size: 20, 
                        color: isMyVote ? AppTheme.primaryBrand : Colors.grey.shade400,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message msg) {
    final String? myId = Supabase.instance.client.auth.currentUser?.id;
    final bool isMe = msg.userId == myId;
    final userProfile = _membersMap[msg.userId];
    String rawName = userProfile?['full_name'] ?? "Usuario";
    if (rawName.trim().isEmpty) rawName = "Usuario";
    final String senderName = rawName.split(' ')[0]; // First name
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
            // Avatar for others
            if (!isMe) ...[
                CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: userProfile?['avatar_url'] != null ? NetworkImage(userProfile!['avatar_url']) : null,
                    child: userProfile?['avatar_url'] == null 
                        ? Text(senderName[0].toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.black87)) 
                        : null,
                ),
                const SizedBox(width: 8),
            ],

            Flexible(
               child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                  decoration: BoxDecoration(
                    color: isMe ? AppTheme.primaryBrand : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 0),
                      bottomRight: Radius.circular(isMe ? 0 : 18),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))],
                  ),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                       // Sender Name (Only for others in Group Chat context)
                       if (!isMe)
                           Padding(
                               padding: const EdgeInsets.only(bottom: 4),
                               child: Text(senderName, style: TextStyle(color: Colors.pink[300], fontSize: 11, fontWeight: FontWeight.bold)),
                           ),
                       
                       Text(
                         msg.content, 
                         style: TextStyle(
                           color: isMe ? Colors.white : Colors.black87,
                           fontSize: 15,
                         ),
                       ),
                       const SizedBox(height: 2),
                       Text(
                         DateFormat('HH:mm').format(msg.createdAt),
                         style: TextStyle(
                           color: isMe ? Colors.white70 : Colors.black38,
                           fontSize: 10,
                         ),
                       ),
                    ],
                  ),
               ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(16),
        color: Theme.of(context).cardColor, // Adapts to Dark Mode
        child: Row(
          children: [
              IconButton(
                  icon: const Icon(Icons.casino_outlined, color: Colors.purple),
                  tooltip: "Ruleta de la Suerte",
                  onPressed: _openWheel,
              ),
            Expanded(
              child: TextField(
                controller: _messageController,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), // Explicit text color
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: "Escribe algo...",
                  hintStyle: TextStyle(color: Theme.of(context).hintColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.light 
                      ? Colors.grey[100] 
                      : Colors.grey[800], // Dark input background
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppTheme.primaryBrand,
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _openWheel() async {
      await showDialog(
          context: context, 
          builder: (context) => WheelSpinDialog(
              planId: widget.planId, 
              onSpinComplete: (result) async {
                   Navigator.pop(context); // Close dialog
                   // Send result to chat
                   final msg = "🎲 La ruleta ha decidido: **$result** 🎉";
                   try {
                       await _chatService.sendMessage(widget.planId, msg);
                       Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
                   } catch (_) {}
              }
          )
      );
  }

}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height + 16; // +16 for cleaner look
  @override
  double get maxExtent => _tabBar.preferredSize.height + 16;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor, // Match background
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
