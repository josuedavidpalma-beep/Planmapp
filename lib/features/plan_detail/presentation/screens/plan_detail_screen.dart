import 'package:flutter/material.dart';
import 'dart:convert';
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
import 'package:planmapp/features/plan_detail/presentation/widgets/roulette_message_bubble.dart';
import 'package:planmapp/features/plan_detail/presentation/widgets/final_confirmation_bubble.dart';
import 'package:planmapp/features/plan_detail/presentation/widgets/participants_list_sheet.dart'; 
import 'package:url_launcher/url_launcher.dart';
import 'package:planmapp/core/services/invitation_service.dart';
// import 'package:planmapp/features/plan_detail/presentation/screens/games_plan_tab.dart'; // REMOVED

class PlanDetailScreen extends StatefulWidget {
  final String planId;

  const PlanDetailScreen({super.key, required this.planId});

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}


class _PlanDetailScreenState extends State<PlanDetailScreen> with TickerProviderStateMixin {
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
    // We initialize with 1 tab initially (Chat), will update when data loads
    _tabController = TabController(length: 1, vsync: this);
    
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
        _updateTabs();
      }
    } catch (e) {
      if (mounted) {
         setState(() => _isLoading = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error cargando plan: $e")));
      }
    }
  }

  void _updateTabs() {
      if (_plan == null) return;
      int requiredLength = 1; // Chat
      
      final bool hasItinerary = _plan!.eventDate != null || _plan!.locationName.isNotEmpty;
      if (hasItinerary) {
          requiredLength++;
          final String payMode = _plan!.paymentMode ?? 'individual';
          if (payMode == 'split' || payMode == 'pool') {
              requiredLength++;
          }
      }
      
      if (_tabController.length != requiredLength) {
          final int oldIndex = _tabController.index;
          _tabController.dispose();
          _tabController = TabController(
             length: requiredLength, 
             vsync: this, 
             initialIndex: oldIndex < requiredLength ? oldIndex : 0
          );
          _tabController.addListener(() {
              if (!_tabController.indexIsChanging) setState((){});
          });
          if (mounted) setState(() {});
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

  Future<void> _confirmDeletePlan() async {
      final confirm = await showDialog<bool>(
          context: context, 
          builder: (context) => AlertDialog(
              title: const Text("Eliminar Plan"),
              content: const Text("¿Estás seguro? Esta acción no se puede deshacer."),
              actions: [
                  TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text("Cancelar")),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: ()=>Navigator.pop(context, true), 
                      child: const Text("Eliminar")
                  )
              ],
          )
      );

      if (confirm == true) {
           try {
               await PlanService().deletePlan(widget.planId);
               if (mounted) context.pop(); // Go back
           } catch (e) {
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
           }
      }
  }  Future<void> _exportToCalendar() async {
      if (_plan == null || _plan!.eventDate == null) return;
      
      final title = "Planmapp: ${_plan!.title}";
      final loc = _plan!.locationName;
      final details = "Enlace del plan: https://planmapp.app/invite/${_plan!.id}";
      final start = _plan!.eventDate!.toUtc();
      final end = start.add(const Duration(hours: 3));

      // Build ICS content
      final icsContent = 
          "BEGIN:VCALENDAR\n"
          "VERSION:2.0\n"
          "BEGIN:VEVENT\n"
          "DTSTART:${_formatICSDate(start)}\n"
          "DTEND:${_formatICSDate(end)}\n"
          "SUMMARY:$title\n"
          "LOCATION:$loc\n"
          "DESCRIPTION:$details\n"
          "END:VEVENT\n"
          "END:VCALENDAR";

      try {
          // On Web, use file download approach
          final bytes = utf8.encode(icsContent);
          final blob = Uri.dataFromBytes(bytes, mimeType: 'text/calendar').toString();
          
          if (!await launchUrl(Uri.parse(blob), mode: LaunchMode.externalApplication)) {
              // Fallback to Google Calendar URL if data URI fails
              final startDateStr = _formatICSDate(start);
              final endDateStr = _formatICSDate(end);
              final gUrl = Uri.parse("https://calendar.google.com/calendar/render?action=TEMPLATE&text=${Uri.encodeComponent(title)}&dates=$startDateStr/$endDateStr&details=${Uri.encodeComponent(details)}&location=${Uri.encodeComponent(loc)}");
              await launchUrl(gUrl, mode: LaunchMode.externalApplication);
          }
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el calendario.')));
      }
  }

  String _formatICSDate(DateTime date) {
      return "${date.year}${date.month.toString().padLeft(2,'0')}${date.day.toString().padLeft(2,'0')}T${date.hour.toString().padLeft(2,'0')}${date.minute.toString().padLeft(2,'0')}00Z";
  }

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        
        // On Desktop, the main view is the nested scroll view (Left)
        // The right side is the persistent chat.
        
        final bodyContent = NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
             return [
                 _buildSliverAppBar(context, isDesktop)
             ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
               isDesktop ? const Center(child: Text("El chat está abierto en el panel derecho 👉", style: TextStyle(color: Colors.grey))) : _buildChatAndPolls(), 
               if (_plan?.eventDate != null || (_plan?.locationName.isNotEmpty ?? false))
                   ItineraryPlanTab(planId: widget.planId, userRole: _myRole, planDate: _plan!.eventDate),
               if ((_plan?.eventDate != null || (_plan?.locationName.isNotEmpty ?? false)) && _plan?.paymentMode == 'pool')
                   BudgetPlanTab(planId: widget.planId),
               if ((_plan?.eventDate != null || (_plan?.locationName.isNotEmpty ?? false)) && _plan?.paymentMode == 'split')
                   ExpensesPlanTab(planId: widget.planId, userRole: _myRole),
            ],
          ),
        );

        if (isDesktop) {
            return Scaffold(
                body: Row(
                    children: [
                        Expanded(child: bodyContent),
                        Container(width: 1, color: Colors.grey.shade300), // Divider
                        SizedBox(
                            width: 400,
                            child: Scaffold(
                                appBar: AppBar(title: const Text("Chat & Encuestas"), automaticallyImplyLeading: false, elevation: 0),
                                body: _buildChatAndPolls(),
                            ),
                        )
                    ],
                ),
                floatingActionButton: _getFabForTab(), // FAB might need to move to Left side?
            );
        }

        return Scaffold(
           body: bodyContent,
           floatingActionButton: _getFabForTab(),
        );
      }
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context, bool isDesktop) {
      return SliverAppBar(
              expandedHeight: 120.0, 
              floating: false,
              pinned: true,
              backgroundColor: AppTheme.primaryBrand,
              iconTheme: const IconThemeData(color: Colors.white),
              flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(_plan?.title ?? "Detalle", 
                      style: const TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold,
                          fontSize: 16 
                      )
                  ),
                  background: Hero(
                      tag: 'plan_bg_${widget.planId}', 
                      child: Container(
                        decoration: const BoxDecoration(
                            gradient: LinearGradient(
                                colors: [AppTheme.primaryBrand, AppTheme.secondaryBrand],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                            ),
                        ),
                      ),
                  ),
              ),
              actions: [
                IconButton(
                    icon: const Icon(Icons.share), 
                    onPressed: () {
                        if (_plan != null) InvitationService.inviteToPlan(_plan!);
                    }
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) async {
                      if (value == 'delete') {
                          _confirmDeletePlan();
                      } else if (value == 'participants') {
                          showModalBottomSheet(
                              context: context,
                              isScrollControlled: true, 
                              backgroundColor: Colors.transparent,
                              builder: (context) => ParticipantsListBottomSheet(
                                  planId: widget.planId, 
                                  isAdmin: _myRole == 'admin',
                                  isCancelled: _plan?.status == PlanStatus.cancelled
                              )
                          );
                      } else if (value == 'calendar') {
                          _exportToCalendar();
                      }
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      const PopupMenuItem<String>(
                        value: 'calendar',
                        child: Row(
                            children: [Icon(Icons.calendar_month, color: Colors.orange), SizedBox(width: 8), Text('Añadir a Google Calendar')],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'participants',
                        child: Row(
                            children: [Icon(Icons.people, color: Colors.blue), SizedBox(width: 8), Text('Participantes')],
                        ),
                      ),
                      if (_myRole == 'admin')
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                              children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Eliminar Plan')],
                          ),
                        ),
                    ];
                  },
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                   color: Theme.of(context).scaffoldBackgroundColor, 
                   child: TabBar(
                      controller: _tabController,
                      isScrollable: false,
                      labelColor: AppTheme.primaryBrand,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: AppTheme.primaryBrand,
                      tabs: [
                          const Tab(icon: Icon(Icons.chat_bubble_outline), text: "Resumen"),
                          if (_plan?.eventDate != null || (_plan?.locationName.isNotEmpty ?? false))
                              const Tab(icon: Icon(Icons.map_outlined), text: "Itinerario"),
                          if ((_plan?.eventDate != null || (_plan?.locationName.isNotEmpty ?? false)) && _plan?.paymentMode == 'pool')
                              const Tab(icon: Icon(Icons.savings_rounded), text: "Vaca/Cuota"),
                          if ((_plan?.eventDate != null || (_plan?.locationName.isNotEmpty ?? false)) && _plan?.paymentMode == 'split')
                              const Tab(icon: Icon(Icons.receipt_long_rounded), text: "Gastos"),
                      ],
                   ),
                ),
              ),
            );
  }

  Widget _buildActionBanner() {
      return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.primaryBrand.withOpacity(0.15), AppTheme.secondaryBrand.withOpacity(0.15)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryBrand.withOpacity(0.3))
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Row(
                      children: [
                          const Icon(Icons.flash_on_rounded, color: AppTheme.primaryBrand, size: 20),
                          const SizedBox(width: 8),
                          const Text("Acciones Rápidas", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBrand)),
                          const Spacer(),
                          Text("¡Asegura el plan!", style: TextStyle(fontSize: 11, color: AppTheme.primaryBrand.withOpacity(0.7))),
                      ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                      children: [
                          if (_plan?.reservationLink != null && _plan!.reservationLink!.isNotEmpty)
                              Expanded(
                                  child: ElevatedButton.icon(
                                      onPressed: () => launchUrl(Uri.parse(_plan!.reservationLink!)),
                                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                                      label: const Text("RESERVAR"),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryBrand,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                      ),
                                  ),
                              ),
                          if (_plan?.reservationLink != null && _plan!.reservationLink!.isNotEmpty && _plan?.contactInfo != null && _plan!.contactInfo!.isNotEmpty)
                              const SizedBox(width: 8),
                          if (_plan?.contactInfo != null && _plan!.contactInfo!.isNotEmpty)
                              Expanded(
                                  child: OutlinedButton.icon(
                                      onPressed: () => launchUrl(Uri.parse("https://wa.me/${_plan!.contactInfo!.replaceAll(RegExp(r'[^0-9]'), '')}")),
                                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                                      label: const Text("WHATSAPP"),
                                      style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: AppTheme.primaryBrand),
                                          foregroundColor: AppTheme.primaryBrand,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                      ),
                                  ),
                              ),
                      ],
                  )
              ],
          )
      );
  }

  // Merged Tab: Polls at top + Chat (Now named generic for re-use)
  Widget _buildChatAndPolls() {
     return Column(
       children: [
          // Action Banner (Reservar / Contactar)
          if ((_plan?.reservationLink != null && _plan!.reservationLink!.isNotEmpty) || (_plan?.contactInfo != null && _plan!.contactInfo!.isNotEmpty))
             _buildActionBanner(),

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

                 // If we have polls, show them but handle constraints better
                 return AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                        // Remove fixed height constraint that causes overflow with keyboard
                        constraints: const BoxConstraints(maxHeight: 250), 
                        child: ListView(
                            shrinkWrap: true, // Only take needed space
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
                                   
                               // Active Polls
                               ...activePolls.map((p) => Padding(
                                   padding: const EdgeInsets.only(bottom: 8),
                                   child: _buildPollCard(p), 
                               )),
                               
                                // Add Button
                                Center(
                                    child: TextButton.icon(
                                        onPressed: _showCreatePollDialog, 
                                        icon: const Icon(Icons.add_circle_outline, size: 16), 
                                        label: const Text("Nueva Encuesta", style: TextStyle(fontSize: 12))
                                    ),
                                ),
                                const SizedBox(height: 10),
                            ],
                        ),
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
                  if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.refresh_rounded, color: Colors.grey),
                            const SizedBox(height: 8),
                            const Text("Error de conexión al chat", style: TextStyle(color: Colors.grey)),
                            TextButton(onPressed: () => setState(() {
                                _chatStream = _chatService.getMessagesValues(widget.planId);
                            }), child: const Text("Reconectar"))
                          ],
                        ),
                      );
                  }
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
      if (_tabController.index == 2 && _plan?.paymentMode == 'split') {
          if (_myRole == 'admin' || _myRole == 'treasurer') {
              return FloatingActionButton(
                onPressed: _createNewBill,
                child: const Icon(Icons.note_add_outlined),
              );
          }
      }
      return null;
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
      final text = _messageController.text;
      await _chatService.sendMessage(widget.planId, text);
      _messageController.clear();
      // Wait for frame to scroll
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      
      if (text.toLowerCase().contains('@planmapp')) {
          _chatService.triggerAgent(widget.planId, text);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showCreatePollDialog({String? initialQuestion, String? draftId}) async {
    final titleController = TextEditingController(text: initialQuestion);
    // Each option is a tuple of (NameController, QuantityController)
    final List<Map<String, TextEditingController>> options = [
        {'name': TextEditingController(), 'qty': TextEditingController(text: '1')},
        {'name': TextEditingController(), 'qty': TextEditingController(text: '1')}
    ];
    
    DateTime? selectedDeadline;
    int localPollType = 0; // 0: Text, 1: Date, 2: Time, 3: Items

    if (draftId != null && initialQuestion != null) {
         // Auto-detect type based on question
         final qLower = initialQuestion.toLowerCase();
         if (qLower.contains('fecha') || qLower.contains('cuándo') || qLower.contains('cuando')) {
             localPollType = 1; // Date
         } else if (qLower.contains('hora') || qLower.contains('qué hora')) {
             localPollType = 2; // Time
         } else if (qLower.contains('traer') || qLower.contains('llev') || qLower.contains('quién')) {
             localPollType = 3; // Items
         }
         // Note: Location usually fits in "Text" (0) or specialized logic, but standard text is fine for voting on places.
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
              
              void addOption() {
                  if (localPollType == 1) { // Date
                      showDatePicker(
                            context: context, 
                            initialDate: DateTime.now(), 
                            firstDate: DateTime.now(), 
                            lastDate: DateTime.now().add(const Duration(days: 365))
                        ).then((date) {
                            if (date != null) {
                                setDialogState(() => options.add({'name': TextEditingController(text: DateFormat('EEE d MMM', 'es_CO').format(date)), 'qty': TextEditingController(text: '1')}));
                            }
                        });
                  } else if (localPollType == 2) { // Time
                       showTimePicker(
                           context: context, 
                           initialTime: TimeOfDay.now(),
                           builder: (context, child) => MediaQuery(
                               data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
                               child: child!,
                           ),
                       ).then((time) {
                           if (time != null && context.mounted) {
                               final dt = DateTime(2022, 1, 1, time.hour, time.minute);
                               setDialogState(() => options.add({'name': TextEditingController(text: DateFormat('h:mm a').format(dt)), 'qty': TextEditingController(text: '1')}));
                           }
                       });
                  } else {
                      setDialogState(() => options.add({'name': TextEditingController(), 'qty': TextEditingController(text: '1')}));
                  }
              }

              return AlertDialog(
                scrollable: true,
                title: Text(draftId != null ? "Configurar Encuesta" : "Nueva Encuesta"),
                content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (draftId == null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SegmentedButton<int>(
                                    segments: const [
                                        ButtonSegment(value: 0, label: Text("Gral"), icon: Icon(Icons.chat_bubble_outline)),
                                        ButtonSegment(value: 1, label: Text("Fecha"), icon: Icon(Icons.calendar_month)),
                                        ButtonSegment(value: 2, label: Text("Hora"), icon: Icon(Icons.access_time)),
                                        ButtonSegment(value: 4, label: Text("Lugar"), icon: Icon(Icons.place)), 
                                        ButtonSegment(value: 3, label: Text("Cosas"), icon: Icon(Icons.checklist)),
                                    ],
                                    selected: {localPollType},
                                    onSelectionChanged: (Set<int> newSelection) {
                                        setDialogState(() {
                                            localPollType = newSelection.first;
                                            
                                            // UX FIX: Clear/Reset options when switching types
                                            options.clear();
                                            // Add default placeholders
                                            if (localPollType == 1 || localPollType == 2) {
                                                options.add({'name': TextEditingController(), 'qty': TextEditingController(text: '1')});
                                                options.add({'name': TextEditingController(), 'qty': TextEditingController(text: '1')});
                                            } else {
                                                options.add({'name': TextEditingController(), 'qty': TextEditingController(text: '1')});
                                                options.add({'name': TextEditingController(), 'qty': TextEditingController(text: '1')});
                                            }

                                            if (titleController.text.isEmpty) {
                                                if (localPollType == 1) titleController.text = "¿Cuándo vamos?";
                                                if (localPollType == 2) titleController.text = "¿A qué hora?";
                                                if (localPollType == 4) titleController.text = "¿Dónde vamos?";
                                                if (localPollType == 3) titleController.text = "Lista de cosas para llevar";
                                                if (localPollType == 5) titleController.text = "¿Cómo pagamos? / Presupuesto";
                                            }
                                        });
                                    },
                                    showSelectedIcon: false,
                                    style: ButtonStyle(
                                        padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 4)),
                                        visualDensity: VisualDensity.compact,
                                    ),
                                ),
                              ),
                            ),

                        TextField(
                          controller: titleController,
                          decoration: InputDecoration(labelText: localPollType == 0 ? "¿Qué quieres preguntar?" : (localPollType == 3 ? "Título de la lista" : "Pregunta")),
                        ),
                        const SizedBox(height: 16),
                        
                        // HEADERS for Items
                        if (localPollType == 3) 
                            const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
                                child: Row(
                                    children: [
                                        Expanded(flex: 2, child: Text("Artículo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                        SizedBox(width: 8),
                                        Expanded(flex: 1, child: Text("Cant.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                        SizedBox(width: 40),
                                    ],
                                ),
                            ),

                        ...options.asMap().entries.map((entry) {
                           final index = entry.key;
                           final controllers = entry.value;
                           
                           return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                                children: [
                                    Expanded(
                                        flex: 2,
                                        child: TextField(
                                            controller: controllers['name'],
                                            readOnly: localPollType == 1 || localPollType == 2,
                                            canRequestFocus: !(localPollType == 1 || localPollType == 2), // Prevent keyboard
                                            onTap: (localPollType == 1 || localPollType == 2) 
                                                ? () async {
                                                     // DIRECT TAP HANDLER (UX FIX)
                                                     if (localPollType == 1) { // DATE
                                                         final date = await showDatePicker(
                                                             context: context, 
                                                             initialDate: DateTime.now(), 
                                                             firstDate: DateTime.now(), 
                                                             lastDate: DateTime.now().add(const Duration(days: 365))
                                                         );
                                                         if (date != null) {
                                                              controllers['name']!.text = DateFormat('EEE d MMM', 'es_CO').format(date);
                                                         }
                                                     } else if (localPollType == 2) { // TIME
                                                         final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                                         if (time != null && context.mounted) {
                                                              controllers['name']!.text = time.format(context);
                                                         }
                                                     }
                                                } 
                                                : null,
                                            decoration: InputDecoration(
                                               labelText: localPollType == 3 ? null : "Opción ${index + 1}",
                                               hintText: localPollType == 1 ? "Toca para elegir fecha" : (localPollType == 2 ? "Toca para elegir hora" : (localPollType == 3 ? "Ej. Hielo" : null)),
                                               isDense: true,
                                               suffixIcon: (localPollType == 1 || localPollType == 2) ? const Icon(Icons.touch_app, size: 16) : null,
                                            ),
                                        ),
                                    ),
                                    if (localPollType == 3) ...[
                                        const SizedBox(width: 8),
                                        Expanded(
                                            flex: 1,
                                            child: TextField(
                                                controller: controllers['qty'],
                                                keyboardType: TextInputType.number,
                                                textAlign: TextAlign.center,
                                                decoration: const InputDecoration(
                                                   isDense: true,
                                                   hintText: "1"
                                                ),
                                            ),
                                        ),
                                    ],
                                    IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                        onPressed: () => setDialogState(() => options.removeAt(index)),
                                    )
                                ],
                            ),
                          );
                        }),
                        
                        TextButton.icon(
                          onPressed: addOption,
                          icon: Icon(localPollType == 0 || localPollType == 3 ? Icons.add : Icons.calendar_month),
                          label: Text(localPollType == 0 || localPollType == 3 ? "Agregar opción" : (localPollType == 1 ? "Seleccionar Fecha" : "Seleccionar Hora")),
                        ),

                        // AI SUGGESTION (Only for Text)
                        if (localPollType == 0)
                            
                        // Use existing Deadline Logic
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
                      // Transform options
                      final validOptions = options
                          .where((o) => o['name']!.text.isNotEmpty)
                          .map((o) => {
                              'text': o['name']!.text,
                              'quantity': int.tryParse(o['qty']!.text) ?? 1
                          })
                          .toList();
                          
                      if (validOptions.length < (localPollType == 3 ? 1 : 2)) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(localPollType == 3 ? "Agrega al menos 1 artículo" : "Agrega al menos 2 opciones")));
                          return;
                      }
        
                      if (draftId != null) {
                          try { await _pollService.deletePoll(draftId); } catch (_) {}
                      }
                      
                      String typeStr = 'text';
                      if (localPollType == 1) typeStr = 'date';
                      if (localPollType == 2) typeStr = 'time';
                      if (localPollType == 3) typeStr = 'items';
                      if (localPollType == 4) typeStr = 'location'; // NEW
                      if (localPollType == 5) typeStr = 'budget';   // NEW

                      try {
                          await _pollService.createPoll(
                              widget.planId, 
                              titleController.text, 
                              validOptions, 
                              expiresAt: selectedDeadline,
                              type: typeStr 
                          );
                      } catch (e) {
                          if (context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text("Error al crear: ${e.toString().replaceAll('Exception: ', '')}"),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 5),
                             ));
                          }
                          return; // Stop if failed
                      }

                      // Notify removed as per user request to avoid spam
                      // The poll itself appearing in the list is sufficient notification.
                      
                      if (context.mounted) {
                          Navigator.pop(context);
                          setState(() {
                              _pollsStream = _pollService.getPollsStream(widget.planId);
                              // Switch to polls tab automatically? Maybe subtle blink is enough.
                              // Or if msg is sent, users see it in chat.
                          });
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Encuesta lanzada! 🚀")));
                      }
                    },
                    child: const Text("Crear"),
                  ),
                ],
              );
          }
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
              if (snapshot.hasError) {
                return Center(child: Text("Error al cargar chat: ${snapshot.error}"));
              }
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
          if (snapshot.hasError) {
             return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)))); 
          }
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
                          child: Text("Sugerencias de la IA", style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.accentColor, fontSize: 13, letterSpacing: 1.2)),
                      ),
                      ...drafts.map((poll) => Card(
                          color: const Color(0xFF1A1F2E), 
                          elevation: 8,
                          shadowColor: Colors.black.withOpacity(0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppTheme.accentColor.withOpacity(0.3))),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _showCreatePollDialog(initialQuestion: poll.question, draftId: poll.id),
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                          Row(
                                              children: [
                                                  const Icon(Icons.auto_awesome, color: AppTheme.accentColor, size: 20),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: Text(poll.question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white, height: 1.3))),
                                              ],
                                          ),
                                          const SizedBox(height: 12),
                                          SizedBox(
                                              width: double.infinity,
                                              height: 44,
                                              child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                                  icon: const Icon(Icons.settings, size: 18),
                                                  onPressed: () {
                                                      _showCreatePollDialog(initialQuestion: poll.question, draftId: poll.id);
                                                  }, 
                                                  label: const Text("Configurar Opciones", style: TextStyle(fontWeight: FontWeight.bold))
                                              ),
                                          )
                                      ],
                                  )
                              )
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
    final bool isItemsType = poll.type == 'items';
    
    // Check Expiration
    bool isExpired = false;
    if (poll.expiresAt != null && DateTime.now().isAfter(poll.expiresAt!)) {
        isExpired = true;
    }
    
    // CLOSED STATE (Manually Closed or Expired)
    if (poll.isClosed || isExpired) {
        // ... (Keep existing logic for closed state or adapt for items needed?)
        // For items, closed just means final list.
        return Card(
           // ... (Same for now, logic below works for winner but for items show different?)
           color: Colors.grey[100],
           margin: const EdgeInsets.only(bottom: 12),
           child: ListTile(
               leading: const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.check, color: Colors.white)),
               title: Text(poll.question, style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.lineThrough)),
               subtitle: Text(isItemsType ? "Lista cerrada" : "Encuesta finalizada"),
           )
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
                      Icon(isItemsType ? Icons.shopping_bag_outlined : Icons.poll_rounded, color: AppTheme.accentColor),
                      const SizedBox(width: 8),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text(isItemsType ? "Lista de Ítems" : "Encuesta", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                // ADMIN MENU
                if (isCreator)
                    SizedBox(
                        height: 24,
                        width: 24,
                        child: PopupMenuButton<String>(
                            // ... (Existing menu logic)
                             onSelected: (value) async {
                                 if (value == 'edit_poll') {
                                     _showCreatePollDialog(initialQuestion: poll.question, draftId: poll.id);
                                 } else if (value == 'close') {
                                     final confirm = await showDialog<bool>(
                                         context: context, 
                                         builder: (context) => AlertDialog(
                                             title: const Text("¿Cerrar Votación?"),
                                             content: const Text("Se elegirá la opción más votada y se actualizará el plan."),
                                             actions: [
                                                 TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text("Cancelar")),
                                                 ElevatedButton(onPressed: ()=>Navigator.pop(context, true), child: const Text("Cerrar")),
                                             ],
                                         )
                                     );
                                     if (confirm != true) return;

                                     // SMART CLOSE: Use Service to analyze and update plan
                                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🤖 Analizando resultados...")));
                                     try {
                                         await _pollService.promotePollToActivity(poll.id);
                                         if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ ¡Plan actualizado con la decisión!")));
                                            // Optional: Send a chat message confirming
                                            await _chatService.sendMessage(widget.planId, "🗳️ Votación cerrada. El itinerario ha sido actualizado.", type: 'system');
                                         }
                                     } catch (e) {
                                         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                                     }
                                     
                                     setState(() {
                                         _pollsStream = _pollService.getPollsStream(widget.planId);
                                     });
                                 } else if (value == 'delete_poll') {
                                     final confirm = await showDialog<bool>(
                                         context: context,
                                         builder: (c) => AlertDialog(
                                             title: const Text("Eliminar Encuesta"),
                                             content: const Text("¿Estás seguro? Se borrarán los votos."),
                                             actions: [
                                                 TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Cancelar")),
                                                 ElevatedButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("Eliminar")),
                                             ]
                                         )
                                     );
                                     if (confirm == true) {
                                         await _pollService.deletePoll(poll.id);
                                         if (mounted) setState(() {});
                                     }
                                 }
                             },
                             itemBuilder: (context) => [
                                if (totalVotes == 0)
                                    const PopupMenuItem(value: 'edit_poll', child: Row(children: [Icon(Icons.edit, color: Colors.green), SizedBox(width: 8), Text("Editar Encuesta")])),
                                const PopupMenuItem(value: 'close', child: Row(children: [Icon(Icons.check_circle, color: Colors.blue), SizedBox(width: 8), Text("Cerrar Encuesta")])),
                                const PopupMenuItem(value: 'delete_poll', child: Row(children: [Icon(Icons.delete_outline, color: Colors.orange), SizedBox(width: 8), Text("Eliminar Encuesta")])),
                             ]
                        )
                    )
              ],
            ),
            const SizedBox(height: 12),
            Text(poll.question, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            
            // OPTIONS LIST
            if (isItemsType)
                // ITEMS RENDER
                Column(
                    children: poll.options.map((opt) => _buildItemOption(poll.id, opt)).toList(),
                )
            else
                // STANDARD RENDER
                Column(
                    children: poll.options.map((opt) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildPollOption(poll.id, opt, totalVotes),
                    )).toList(),
                )
          ],
        ),
      ),
    );
  }

  // NEW: Item Option Widget (Card style)
  Widget _buildItemOption(String pollId, PollOption option) {
      final isClaimed = option.assigneeProfile != null;
      final isReallyMe = option.isVotedByMe;
      
      return InkWell(
          onTap: () async { 
                HapticFeedback.lightImpact();
                // Allow tapping even if claimed (to verify/unclaim if me, or see info)
                if (isClaimed && !isReallyMe) {
                     // Maybe show a toast "Claimed by X"?
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                         content: Text("Asignado a ${option.assigneeProfile?['full_name'] ?? 'alguien'}. Toca de nuevo para robar (WIP) o ignorar."),
                         duration: const Duration(seconds: 1),
                     ));
                     return; // For now, strict claim. Or allow override? User said "doesn't allow select".
                     // Ideally, if I tap, I want to claim it or UNclaim it. 
                     // If someone else has it, I can't take it unless I'm admin?
                     // Let's stick to: If claimed by ONE person, blocked?
                     // BUT wait, user said "Doesn't allow select". Maybe they mean UNSELECTing?
                     // The previous code had `onTap: isClaimed && !isReallyMe ? null : ...`
                     // This means if I claimed it, I CAN tap (good).
                     // If NO ONE claimed it, I CAN tap (good).
                     // If SOMEONE ELSE claimed it, I can NOT tap (good).
                     // Maybe the state `isClaimed` is wrong?
                     
                     // Let's simplify: Always allow tap, let Service handle logic (it throws if taken).
                }
                
                if (!await AuthGuard.ensureAuthenticated(context)) return;
                try {
                    await _pollService.toggleVote(pollId, option.id, 'items');
                    if (mounted) setState((){}); // Optimistic update
                } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))));
                }
          },
          child: Container(
              width: double.infinity, // Full width for list feel
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                  children: [
                      // CHECKBOX / CIRCLE
                      Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isClaimed ? (isReallyMe ? AppTheme.primaryBrand : Colors.grey[300]) : Colors.transparent,
                              border: Border.all(
                                  color: isClaimed ? (isReallyMe ? AppTheme.primaryBrand : Colors.grey[300]!) : Colors.grey[400]!,
                                  width: 2
                              )
                          ),
                          child: isClaimed 
                              ? Icon(Icons.check, size: 16, color: isReallyMe ? Colors.white : Colors.grey[600])
                              : null,
                      ),
                      const SizedBox(width: 12),
                      
                      // TEXT
                      Expanded(
                          child: Text(
                              "${option.text} (${option.quantity})", 
                              style: TextStyle(
                                  fontSize: 15,
                                  decoration: isClaimed ? TextDecoration.lineThrough : null,
                                  color: isClaimed ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color
                              )
                          )
                      ),

                      // AVATAR IF CLAIMED
                      if (isClaimed) ...[
                          const SizedBox(width: 8),
                          CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: option.assigneeProfile?['avatar_url'] != null ? NetworkImage(option.assigneeProfile!['avatar_url']) : null,
                              child: option.assigneeProfile?['avatar_url'] == null 
                                  ? Text((option.assigneeProfile?['full_name'] ?? "U")[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.black87)) 
                                  : null,
                          ),
                      ]
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
          await _pollService.toggleVote(pollId, option.id, 'text'); // Default text for standard polls
          if (mounted) setState((){}); // Refresh UI immediately (stream will update too) -> Optimistic
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      },
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isMyVote ? AppTheme.primaryBrand.withOpacity(0.05) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMyVote ? AppTheme.primaryBrand : Colors.grey.withOpacity(0.2),
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
                        color: isMyVote ? AppTheme.primaryBrand : Theme.of(context).textTheme.bodyLarge?.color,
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
    if (msg.type == 'roulette') {
        return RouletteMessageBubble(
            message: msg, 
            isMe: msg.userId == _chatService.currentUserId
        );
    } else if (msg.type == 'final_confirmation') {
        return FinalConfirmationBubble(
            message: msg,
            isMe: msg.userId == _chatService.currentUserId,
            onViewItinerary: () {
                // Switch tab to Itinerary (Index 1)
                DefaultTabController.of(context)?.animateTo(1);
            }
        );
    }
  
    final String? myId = Supabase.instance.client.auth.currentUser?.id;
    final bool isMe = msg.userId == myId;
    final bool isSystem = msg.type == 'system';
    
    final userProfile = _membersMap[msg.userId];
    String rawName = userProfile?['full_name'] ?? "Usuario";
    if (isSystem) rawName = "✨ Planmapp Bot";
    if (rawName.trim().isEmpty) rawName = "Usuario";
    final String senderName = isSystem ? rawName : rawName.split(' ')[0]; // First name
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isSystem ? MainAxisAlignment.center : (isMe ? MainAxisAlignment.end : MainAxisAlignment.start),
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
            // Avatar for others
            if (!isMe && !isSystem) ...[
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
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * (isSystem ? 0.85 : 0.7)),
                  decoration: BoxDecoration(
                    gradient: isSystem ? LinearGradient(colors: [AppTheme.primaryBrand.withOpacity(0.1), AppTheme.secondaryBrand.withOpacity(0.1)]) : null,
                    color: isSystem ? null : (isMe ? AppTheme.primaryBrand : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isSystem ? 18 : 18),
                      topRight: Radius.circular(isSystem ? 18 : 18),
                      bottomLeft: Radius.circular(isSystem ? 18 : (isMe ? 18 : 0)),
                      bottomRight: Radius.circular(isSystem ? 18 : (isMe ? 0 : 18)),
                    ),
                    border: isSystem ? Border.all(color: AppTheme.primaryBrand.withOpacity(0.5)) : null,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))],
                  ),
                  child: Column(
                    crossAxisAlignment: isSystem ? CrossAxisAlignment.center : (isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start),
                    children: [
                       // Sender Name
                       if (!isMe || isSystem)
                           Padding(
                               padding: const EdgeInsets.only(bottom: 4),
                               child: Text(
                                   senderName, 
                                   style: TextStyle(
                                       color: isSystem ? AppTheme.primaryBrand : Colors.pink[300], 
                                       fontSize: isSystem ? 13 : 11, 
                                       fontWeight: FontWeight.bold
                                   )
                               ),
                           ),
                       
                       Text(
                         msg.content, 
                         textAlign: isSystem ? TextAlign.center : TextAlign.start,
                         style: TextStyle(
                           color: isSystem ? Colors.white : (isMe ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color),
                           fontSize: 15,
                         ),
                       ),
                       
                       // Event metadata (Suggested Card)
                       if (isSystem && msg.metadata != null && msg.metadata!['suggested_event'] != null) ...[
                           const SizedBox(height: 12),
                           InkWell(
                               onTap: () {
                                   final link = msg.metadata!['suggested_event']['reservation_link'] ?? msg.metadata!['suggested_event']['source_url'];
                                   if (link != null) launchUrl(Uri.parse(link));
                               },
                               child: Container(
                                   padding: const EdgeInsets.all(8),
                                   decoration: BoxDecoration(
                                       color: Colors.white,
                                       borderRadius: BorderRadius.circular(12),
                                       border: Border.all(color: AppTheme.primaryBrand.withOpacity(0.2)),
                                   ),
                                   child: Row(
                                       children: [
                                           ClipRRect(
                                               borderRadius: BorderRadius.circular(8),
                                               child: Image.network(
                                                   msg.metadata!['suggested_event']['image_url'] ?? 'https://images.unsplash.com/photo-1517048676732-d65bc937f952?w=200',
                                                   width: 50, height: 50, fit: BoxFit.cover,
                                                   errorBuilder: (_,__,___) => const Icon(Icons.auto_awesome, color: AppTheme.primaryBrand)
                                               )
                                           ),
                                           const SizedBox(width: 12),
                                           Expanded(
                                               child: Column(
                                                   crossAxisAlignment: CrossAxisAlignment.start,
                                                   children: [
                                                       Text(msg.metadata!['suggested_event']['title'] ?? 'Actividad Sugerida', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                                                       Text(msg.metadata!['suggested_event']['location'] ?? 'Haz clic para ver más', style: const TextStyle(fontSize: 11, color: AppTheme.primaryBrand, fontWeight: FontWeight.w500), maxLines: 1),
                                                   ],
                                               )
                                           ),
                                           const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                                       ],
                                   ),
                               ),
                           ),

                           // Quick action button (Votación)
                           const SizedBox(height: 8),
                           SizedBox(
                               width: double.infinity,
                               child: ElevatedButton(
                                   onPressed: () {
                                       HapticFeedback.lightImpact();
                                       final suggestedEvent = msg.metadata!['suggested_event'];
                                       _showCreatePollDialog(
                                           initialQuestion: "¿Agregamos el plan de ${suggestedEvent['title']}?",
                                       );
                                   },
                                   style: ElevatedButton.styleFrom(
                                       backgroundColor: AppTheme.primaryBrand, 
                                       foregroundColor: Colors.white, 
                                       elevation: 0,
                                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                                   ),
                                   child: const Text("Hacer Votación", style: TextStyle(fontSize: 12))
                               ),
                           ),
                       ],

                       const SizedBox(height: 4),
                       Text(
                         DateFormat('HH:mm').format(msg.createdAt),
                         style: TextStyle(
                           color: isSystem ? Colors.grey : (isMe ? Colors.white70 : Colors.black38),
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
                  icon: const Icon(Icons.casino_outlined, color: Colors.orange),
                  tooltip: "Ruleta de la Suerte",
                  onPressed: _openWheel,
              ),
              IconButton(
                  icon: const Icon(Icons.auto_awesome, color: Colors.purple),
                  tooltip: "Asistente IA",
                  onPressed: () {
                      _messageController.text = "@planmapp ${_messageController.text}";
                      _messageController.selection = TextSelection.fromPosition(TextPosition(offset: _messageController.text.length));
                  },
              ),
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLines: null,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
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
                      : Colors.grey[800], 
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
      // Game Mode Selection
      final mode = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: Colors.transparent, 
          builder: (context) => Container(
              decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 16),
                      const Text("Juegos de Azar 🎲", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      
                      _buildGameOption(
                          icon: Icons.attach_money, 
                          color: Colors.green, 
                          title: "¿Quién Paga?", 
                          subtitle: "Sorteo entre los participantes",
                          onTap: () => Navigator.pop(context, 'who_pays')
                      ),
                      _buildGameOption(
                          icon: Icons.fastfood, 
                          color: Colors.orange, 
                          title: "¿Qué Comemos?", 
                          subtitle: "Pizza, Sushi, Hamburguesa...",
                          onTap: () => Navigator.pop(context, 'food')
                      ),
                      _buildGameOption(
                          icon: Icons.casino, 
                          color: Colors.purple, 
                          title: "Decisión Abierta", 
                          subtitle: "Opciones personalizadas",
                          onTap: () => Navigator.pop(context, 'custom')
                      ),
                      const SizedBox(height: 20),
                  ],
              ),
          )
      );

      if (mode == null) return;

      List<String> options = [];
      
      if (mode == 'who_pays') {
           // Extract member names
           if (_membersMap.isNotEmpty) {
               options = _membersMap.values.map((m) => m['full_name'].toString().split(' ')[0]).toList();
           } else {
               // Fallback if empty (should fetch or use current user + mock)
               options = ["Yo", "Tú"];
           }
      } else if (mode == 'food') {
          options = ["Pizza 🍕", "Sushi 🍣", "Hamburguesa 🍔", "Tacos 🌮", "Pollo 🍗", "Chino 🥢"];
      }

      if (mounted) {
          await showDialog(
              context: context, 
              builder: (context) => WheelSpinDialog(
                  planId: widget.planId, 
                  initialOptions: options,
                  onSpinComplete: (result) {
                       // Handled internally by dialog
                  }
              )
          );
      }
  }

  Widget _buildGameOption({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
       return ListTile(
            leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: onTap,
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
