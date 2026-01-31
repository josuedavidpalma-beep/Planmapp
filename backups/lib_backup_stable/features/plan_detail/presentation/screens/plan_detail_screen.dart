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
import 'package:planmapp/features/expenses/presentation/screens/add_expense_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/expenses/presentation/screens/budget_plan_tab.dart'; // Import Budget Tab
import 'package:planmapp/features/plans/services/plan_members_service.dart';

import 'package:planmapp/features/itinerary/presentation/screens/itinerary_plan_tab.dart';

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
    _tabController = TabController(length: 5, vsync: this); // 5 Tabs
    _chatStream = _chatService.getMessagesValues(widget.planId);
    _pollsStream = _pollService.getPollsStream(widget.planId);
    
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadAllData();
  }

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
    final fetchedPlan = await PlanService().getPlanById(widget.planId);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    
    String role = 'member';
    if (fetchedPlan != null && uid != null && fetchedPlan.creatorId == uid) {
        role = 'admin';
    } else {
        // role = await PlanMembersService().getMyRole(widget.planId);
        role = 'admin'; // FORCE ADMIN DEBUG
    }

    await _loadMembers(); // Fetch profiles for chat
    
    if (mounted) {
      setState(() {
        _plan = fetchedPlan;
        _myRole = role;
        _isLoading = false;
      });
    }
  }

  // ... (existing _loadMembers, dispose, build)

  Widget? _getFabForTab() {
      // 0: Chat (No FAB)
      // 1: Polls (Add Poll)
      // 2: Budget (No Global FAB, handled inside tab)
      // 3: Expenses (Add Expense)
      // 4: Itinerary (Handled internally by ItineraryPlanTab's Scaffold OR null here)
      switch (_tabController.index) {
          case 1:
              return FloatingActionButton.extended(
                  onPressed: _showCreatePollDialog,
                  label: const Text("Nueva Encuesta"),
                  icon: const Icon(Icons.add),
              );
          case 3:
              // Only Admin or Treasurer can Add Expenses
              if (_myRole == 'admin' || _myRole == 'treasurer') {
                  return FloatingActionButton(
                    onPressed: () {
                      Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => AddExpenseScreen(planId: widget.planId),
                          ),
                      );
                    },
                    child: const Icon(Icons.add),
                  );
              }
              return null;
          default:
              return null; // Itinerary handles its own FAB via internal Scaffold
      }
  }

  Future<void> _loadMembers() async {
     try {
       // Fetch members to get names/avatars
       final supabase = Supabase.instance.client;
       final response = await supabase
           .from('plan_members')
           .select('user_id, profiles(id, full_name, avatar_url)')
           .eq('plan_id', widget.planId);
           
       final newMap = <String, Map<String, dynamic>>{};
       for (var row in response) {
           final profile = row['profiles'] as Map<String, dynamic>?;
           if (profile != null) {
               newMap[row['user_id']] = profile;
           }
       }
       // Also add the plan creator manually to the map if not already there
       if (_plan != null) {
          final creatorProf = await supabase.from('profiles').select().eq('id', _plan!.creatorId).single();
          newMap[_plan!.creatorId] = creatorProf;
       }

       setState(() {
           _membersMap = newMap;
       });
     } catch (e) {
         print("Error loading members for chat: $e");
     }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: const Center(child: Text("No pudimos encontrar este plan.\nQuizás fue eliminado.")),
      );
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200.0,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _plan!.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
                      ),
                    ),
                    if (_plan!.eventDate != null)
                      Text(
                        "${DateFormat('dd MMM').format(_plan!.eventDate!)} • ${DateFormat('HH:mm').format(_plan!.eventDate!)}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                  ],
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryBrand, AppTheme.secondaryBrand],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -20,
                      top: 40,
                      child: Icon(Icons.celebration, color: Colors.white.withOpacity(0.15), size: 150),
                    ),
                  ],
                ),
              ),
              actions: [
                PopupMenuButton<String>(
                   icon: const Icon(Icons.more_vert, color: Colors.white),
                   onSelected: (value) async {
                       if (value == 'share') {
                            final String inviteLink = "https://planmapp.app/join/${widget.planId}";
                            Clipboard.setData(ClipboardData(text: inviteLink));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("¡Enlace de invitación copiado! 🔗"),
                                backgroundColor: AppTheme.primaryBrand,
                              ),
                            );
                       } else if (value == 'delete') {
                            final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                                title: const Text("¿Eliminar Plan?"),
                                content: const Text("Esta acción no se puede deshacer. Se borrarán todos los datos, gastos y chats."),
                                actions: [
                                    TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Cancelar")),
                                    ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                        onPressed: ()=>Navigator.pop(c, true), 
                                        child: const Text("Eliminar")
                                    ),
                                ]
                            ));

                            if (confirm == true) {
                                try {
                                    await PlanService().deletePlan(widget.planId);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Plan eliminado.")));
                                      context.go('/home'); 
                                    }
                                } catch (e) {
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                                }
                            }
                       }
                   },
                   itemBuilder: (context) => [
                       const PopupMenuItem(
                           value: 'share',
                           child: Row(children: [Icon(Icons.share, size: 20), SizedBox(width: 8), Text("Compartir Plan")]),
                       ),
                       if (_myRole == 'admin') // Using checks from _loadAllData
                           const PopupMenuItem(
                               value: 'delete',
                               child: Row(children: [Icon(Icons.delete_forever, size: 20, color: Colors.red), SizedBox(width: 8), Text("Eliminar Plan", style: TextStyle(color: Colors.red))]),
                           ),
                   ],
                ),
              ],
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true, // Allow scrolling if names are long
                  labelColor: AppTheme.primaryBrand,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppTheme.primaryBrand,
                  tabs: const [
                    Tab(icon: Icon(Icons.chat_bubble_outline), text: "Chat"),
                    Tab(icon: Icon(Icons.poll_outlined), text: "Votos"),
                    Tab(icon: Icon(Icons.monetization_on_outlined), text: "Presupuesto"),
                    Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: "Gastos"),
                    Tab(icon: Icon(Icons.map_outlined), text: "Itinerario"),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
             _buildChatTab(),
             _buildPollsTab(),
             BudgetPlanTab(planId: widget.planId), // New Budget Tab
             ExpensesPlanTab(planId: widget.planId, userRole: _myRole),
             ItineraryPlanTab(planId: widget.planId, userRole: _myRole),
          ],
        ),
      ),
      floatingActionButton: _getFabForTab(),
    );
  }
  






  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;
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

  Future<void> _showCreatePollDialog({String? initialQuestion, String? draftId}) async {
    final titleController = TextEditingController(text: initialQuestion);
    final optionControllers = [TextEditingController(), TextEditingController()];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(draftId != null ? "Configurar Encuesta" : "Nueva Encuesta"),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: "¿Qué quieres preguntar?"),
                ),
                const SizedBox(height: 16),
                ...optionControllers.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TextField(
                    controller: entry.value,
                    decoration: InputDecoration(
                       labelText: "Opción ${entry.key + 1}",
                       suffixIcon: entry.key > 1 
                        ? IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => setDialogState(() => optionControllers.removeAt(entry.key)),
                          ) 
                        : null,
                    ),
                  ),
                )),
                TextButton.icon(
                  onPressed: () => setDialogState(() => optionControllers.add(TextEditingController())),
                  icon: const Icon(Icons.add),
                  label: const Text("Agregar opción"),
                ),
              ],
            ),
          ),
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
              if (options.length < 2) return;

              // If promoting draft, delete old one first
              if (draftId != null) {
                  try {
                      await _pollService.deletePoll(draftId);
                  } catch (_) {}
              }

              await _pollService.createPoll(widget.planId, titleController.text, options);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Crear"),
          ),
        ],
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
                 return const Center(child: Text("¡Hola! 👋 Escribe el primer mensaje."));
              }
              return ListView.builder(
                controller: _chatScrollController,
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) => _buildMessageBubble(messages[index]),
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.poll, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text("No hay votaciones activas", style: TextStyle(color: Colors.grey)),
                ],
              ),
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

                  ...activePolls.map((poll) => _buildPollCard(poll)),
              ],
          );
        },
      );
  }

  Widget _buildPollCard(Poll poll) {
    // Creator Check
    final isCreator = _plan?.creatorId == _chatService.currentUserId;
    final int totalVotes = poll.options.fold(0, (sum, opt) => sum + opt.voteCount);
    
    // CLOSED STATE
    if (poll.isClosed) {
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
               leading: const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.check, color: Colors.white)),
               title: Text(poll.question, style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.lineThrough, color: Colors.grey)),
               subtitle: Text(
                   max > 0 ? (isTie ? "Empate ($max votos)" : "Ganador: ${winner?.text} ($max votos)") : "Sin votos",
                   style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)
               ),
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
                      Expanded(child: Text("Encuesta", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
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
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          /* IconButton(
            icon: const Icon(Icons.poll_outlined, color: AppTheme.primaryBrand),
            onPressed: _showCreatePollDialog,
          ),*/
          Expanded(
            child: TextField(
              controller: _messageController,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: "Escribe algo...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
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
