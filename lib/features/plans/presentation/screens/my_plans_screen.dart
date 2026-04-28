import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/plans/domain/models/plan_model.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/services/plan_service.dart';
import 'package:planmapp/features/plans/services/plan_members_service.dart';
import 'package:planmapp/core/presentation/widgets/skeleton_helper.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/core/presentation/widgets/premium_empty_state.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MyPlansScreen extends ConsumerStatefulWidget {
  const MyPlansScreen({super.key});

  @override
  ConsumerState<MyPlansScreen> createState() => _MyPlansScreenState();
}

class _MyPlansScreenState extends ConsumerState<MyPlansScreen> {
  List<Plan> _plans = [];
  List<Plan> _chats = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    PlanService.listUpdateNotifier.addListener(_loadPlans);
    _loadPlans();
  }
  
  @override
  void dispose() {
    PlanService.listUpdateNotifier.removeListener(_loadPlans);
    super.dispose();
  }

  Future<void> _confirmDeleteAll() async {
      final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
          title: const Text("⚠️ ¿ELIMINAR TODO?"),
          content: const Text("Se borrarán TODOS tus planes (creados y membresías). Útil para iniciar de cero."),
          actions: [
              TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Cancelar")),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: ()=>Navigator.pop(c, true), 
                  child: const Text("ELIMINAR TODO")
              ),
          ],
      ));

      if (confirm == true) {
          setState(() { 
              _isLoading = true;
              _plans = []; // OPTIMISTIC CLEAR
              _chats = [];
          }); 
          
          try {
              await PlanService().deleteAllPlans();
              if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Limpieza completada ✨")));
          } catch (e) {
              if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Nota: $e")));
          } finally {
             _loadPlans();
          }
      }
  }

  Future<void> _loadPlans() async {
    if (!mounted) return;
    setState(() {
       _isLoading = true;
       _errorMessage = null; 
    });
    
    try {
      final plans = await PlanService().getPlans(isDirectChat: false);
      final chats = await PlanService().getPlans(isDirectChat: true);
      if (mounted) {
        setState(() {
          _plans = plans;
          _chats = chats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
           _isLoading = false;
           _errorMessage = "Problema al cargar: ${e.toString()}";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Mis Espacios", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 24)),
          backgroundColor: AppTheme.darkBackground,
          elevation: 0,
          centerTitle: false,
          actions: [
             IconButton(
               icon: const Icon(Icons.person_add_alt_1, color: Colors.white), 
               onPressed: () => _showNewChatDialog(context),
               tooltip: "Nuevo Chat",
             ),
             IconButton(
               icon: const Icon(Icons.refresh, color: Colors.white), 
               onPressed: _loadPlans,
               tooltip: "Recargar",
             ),
             IconButton(
               icon: const Icon(Icons.delete_sweep, color: Colors.white54),
               onPressed: _confirmDeleteAll,
               tooltip: "Eliminar Todo (Debug)",
             )
          ],
          bottom: const TabBar(
            indicatorColor: AppTheme.primaryBrand,
            tabs: [
              Tab(icon: Icon(Icons.celebration, size: 20), text: "Planes Grupos"),
              Tab(icon: Icon(Icons.chat_bubble_outline, size: 20), text: "Chats"),
            ],
          ),
        ),
        body: Container(
          color: AppTheme.darkBackground,
          child: SafeArea(
            child: Column(
              children: [
                 Expanded(
                   child: Container(
                     width: double.infinity,
                     decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]
                     ),
                     child: ClipRRect(
                       borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                       child: _isLoading 
                          ? _buildLoadingState() 
                          : _errorMessage != null 
                              ? _buildErrorState()
                              : TabBarView(
                                  children: [
                                    _plans.isEmpty ? _buildEmptyState(false) : _buildPlanList(context, _plans),
                                    _chats.isEmpty ? _buildEmptyState(true) : _buildPlanList(context, _chats),
                                  ],
                                ),
                     ),
                   ),
                 ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
      return Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                  Icon(Icons.cloud_off, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(_errorMessage ?? "Error desconocido", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[800], fontSize: 16)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                      onPressed: _loadPlans,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Intentar de nuevo"),
                  )
               ],
            ),
          )
      );
  }

  Widget _buildLoadingState() {
     return ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: 4,
        separatorBuilder: (_,__) => const SizedBox(height: 16),
        itemBuilder: (_,__) => SkeletonHelper.planCardSkeleton(),
     );
  }

  Widget _buildEmptyState(bool isChat) {
     return Center(
        child: Column(
           children: [
              Expanded(
                child: PremiumEmptyState(
                  icon: isChat ? Icons.chat_bubble_outline : Icons.rocket_launch_rounded,
                  title: isChat ? "Aún no tienes chats" : "Aún no hay expediciones",
                  subtitle: isChat ? "Tus mensajes y vacas 1 a 1 aparecerán aquí." : "Tus futuros planes, vacas y deudas organizadas aparecerán aquí mágicamente.",
                )
              ),
              _buildArchiveAndTrashSection(context),
              const SizedBox(height: 16),
           ],
        )
     );
  }

  Widget _buildPlanList(BuildContext context, List<Plan> plans) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100), // Extra bottom padding for FAB
      itemCount: plans.length + 1,
      separatorBuilder: (_,__) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index == plans.length) {
            return _buildArchiveAndTrashSection(context);
        }
        
        final plan = plans[index];
        return _PlanCard(
            plan: plan, 
            onRefresh: _loadPlans
        )
            .animate(delay: (50 * index).ms) 
            .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuad)
            .fade(duration: 400.ms);
      },
    );
  }

  Widget _buildArchiveAndTrashSection(BuildContext context) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                   TextButton.icon(
                       onPressed: () => _showSpecialPlans(context, isArchive: true),
                       icon: const Icon(Icons.archive_outlined, color: Colors.grey),
                       label: const Text("Archivo", style: TextStyle(color: Colors.grey)),
                   ),
                   TextButton.icon(
                       onPressed: () => _showSpecialPlans(context, isArchive: false),
                       icon: const Icon(Icons.delete_outline, color: Colors.grey),
                       label: const Text("Papelera", style: TextStyle(color: Colors.grey)),
                   ),
              ]
          )
      );
  }

  void _showSpecialPlans(BuildContext context, {required bool isArchive}) {
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (c) => Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
              child: Column(
                  children: [
                      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 24),
                      Row(
                          children: [
                              Icon(isArchive ? Icons.archive : Icons.delete, color: isArchive ? Colors.blue : Colors.red),
                              const SizedBox(width: 12),
                              Text(isArchive ? "Archivo de Planes" : "Papelera", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ]
                      ),
                      const SizedBox(height: 8),
                      Text(
                          isArchive ? "Se eliminan definitivamente a los 7 días." : "Se eliminan definitivamente a las 24 horas.", 
                          style: TextStyle(color: Colors.grey[600], fontSize: 13)
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                          child: FutureBuilder<List<Plan>>(
                              future: PlanService().getPlans(archived: isArchive, deleted: !isArchive),
                              builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No hay elementos aquí."));
                                  return ListView.separated(
                                      itemCount: snapshot.data!.length,
                                      separatorBuilder: (_,__) => const SizedBox(height: 12),
                                      itemBuilder: (context, idx) {
                                           final p = snapshot.data![idx];
                                           return ListTile(
                                                title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                subtitle: Text(p.locationName),
                                                trailing: IconButton(
                                                    icon: const Icon(Icons.restore),
                                                    tooltip: "Restaurar",
                                                    onPressed: () async {
                                                        await PlanService().restorePlan(p.id);
                                                        if (context.mounted) Navigator.pop(context);
                                                        _loadPlans();
                                                    }
                                                )
                                           );
                                      }
                                  );
                              }
                          )
                      )
                  ]
              )
          )
      );
  }
}

class _PlanCard extends StatelessWidget {
  final Plan plan;
  final VoidCallback onRefresh;

  const _PlanCard({required this.plan, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (plan.isDirectChat) {
         return _buildDirectChatCard(context);
    }

    final uid = Supabase.instance.client.auth.currentUser?.id;
    final isCreator = uid == plan.creatorId;
    final theme = Theme.of(context);

    return Hero(
      tag: 'plan_bg_${plan.id}',
      child: Container(
      decoration: BoxDecoration(
        color: Colors.black, // fallback
        image: DecorationImage(
          image: CachedNetworkImageProvider(plan.imageUrl ?? plan.displayImageUrl),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.55), BlendMode.darken),
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: AppTheme.primaryBrand.withOpacity(0.05),
            blurRadius: 0,
            offset: const Offset(0, 0),
            spreadRadius: 1, // Subtle border effect
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
             HapticFeedback.lightImpact(); // Tactile feedback
             context.push('/plan/${plan.id}');
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     // Status Badge
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                       decoration: BoxDecoration(
                          color: AppTheme.primaryBrand.withOpacity(0.08), 
                          borderRadius: BorderRadius.circular(20),
                       ),
                       child: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                            const Icon(Icons.circle, size: 8, color: AppTheme.primaryBrand),
                            const SizedBox(width: 6),
                            Text(
                              plan.status.name.toUpperCase(),
                              style: const TextStyle(
                                color: AppTheme.primaryBrand,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.5
                              ),
                            ),
                         ],
                       ),
                     ),
                     // 3-Dots Menu (FIXED)
                     PopupMenuButton<String>(
                        icon: Icon(Icons.more_horiz, color: Colors.grey[400]),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        onSelected: (value) async {
                             if (value == 'delete') {
                                 final confirm = await _showSimpleConfirm(context, "Mover a Papelera", "El plan se eliminará permanentemente en 24 horas y puedes restaurarlo.");
                                 if (confirm) {
                                     await PlanService().softDeletePlan(plan.id);
                                     onRefresh();
                                 }
                             } else if (value == 'archive') {
                                 final confirm = await _showSimpleConfirm(context, "Archivar Plan", "Se guardará en el Archivo y se borrará definitivamente en 7 días.");
                                 if (confirm) {
                                     await PlanService().archivePlan(plan.id);
                                     onRefresh();
                                 }
                             } else if (value == 'leave') {
                                  _handleAction(context, false);
                             } else if (value == 'hard_delete') {
                                  _handleAction(context, true);
                             }
                        },
                        itemBuilder: (context) => [
                           if (isCreator) ...[
                               PopupMenuItem(value: 'archive', child: Row(children: const [Icon(Icons.archive_outlined, size: 20), SizedBox(width: 12), Text("Archivar")])),
                               PopupMenuItem(value: 'delete', child: Row(children: const [Icon(Icons.delete_outline, color: Colors.orange, size: 20), SizedBox(width: 12), Text("A Papelera", style: const TextStyle(color: Colors.orange))])),
                               const PopupMenuDivider(),
                               PopupMenuItem(value: 'hard_delete', child: Row(children: const [Icon(Icons.delete_forever, color: Colors.red, size: 20), SizedBox(width: 12), Text("Eliminar Definitivo", style: const TextStyle(color: Colors.red))])),
                           ] else
                               PopupMenuItem(value: 'leave', child: Row(children: const [Icon(Icons.exit_to_app, color: Colors.red, size: 20), SizedBox(width: 12), Text("Salir del Plan", style: const TextStyle(color: Colors.red))])),
                        ],
                     )
                  ],
                ),
                const SizedBox(height: 12),
                
                // Title
                Text(
                  plan.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                if (!plan.isDirectChat) ...[
                  Row(
                    children: [
                        Container(
                         padding: const EdgeInsets.all(8),
                         decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                         child: const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.white),
                       ),
                       const SizedBox(width: 12),
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                            Text(plan.eventDate != null ? DateFormat('MMM d, y').format(plan.eventDate!) : "Por definir", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                            Text(plan.eventDate != null ? DateFormat('h:mm a').format(plan.eventDate!) : "--:--", style: TextStyle(color: Colors.white70, fontSize: 13)),
                         ],
                       )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                       Container(
                         padding: const EdgeInsets.all(8),
                         decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                         child: const Icon(Icons.location_on_outlined, size: 16, color: Colors.white),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: Text(
                           plan.locationName.isEmpty ? "Ubicación por definir" : plan.locationName,
                           maxLines: 1,
                           overflow: TextOverflow.ellipsis,
                           style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                         ),
                       ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  // Direct Chat visual filler
                  Row(
                     children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppTheme.primaryBrand.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.lock, size: 16, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        const Text("Chat cifrado de amigo", style: TextStyle(color: Colors.white70)),
                     ]
                  ),
                  const SizedBox(height: 20),
                ],
                const Divider(height: 1),
                const SizedBox(height: 16),
                
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     _buildAvatarStack(context, plan.participantCount),
                     Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black, 
                          borderRadius: BorderRadius.circular(30)
                        ),
                        child: const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                     )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildDirectChatCard(BuildContext context) {
      return FutureBuilder<List<PlanMember>>(
          future: PlanMembersService().getMembers(plan.id),
          builder: (context, snapshot) {
              final myId = Supabase.instance.client.auth.currentUser?.id;
              final otherUser = snapshot.data?.where((m) => m.id != myId).firstOrNull;
              final titleText = (otherUser?.name != null && otherUser!.name.isNotEmpty) ? otherUser.name : "Chat Privado";
              final String? avatarUrl = otherUser?.avatarUrl;

              return Card(
                  color: Theme.of(context).cardColor,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.withOpacity(0.1))
                  ),
                  child: ListTile(
                      onTap: () {
                          HapticFeedback.lightImpact();
                          context.push('/plan/${plan.id}');
                      },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.primaryBrand.withOpacity(0.1),
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null ? const Icon(Icons.person, color: AppTheme.primaryBrand) : null,
                      ),
                      title: Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: const Text("Toca para chatear", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        onSelected: (value) async {
                             if (value == 'delete') {
                                 final confirm = await _showSimpleConfirm(context, "Eliminar Chat", "¿Estás seguro que quieres eliminar la conversación en tu dispositivo?");
                                 if (confirm) {
                                     await PlanService().softDeletePlan(plan.id);
                                     onRefresh();
                                 }
                             }
                        },
                        itemBuilder: (context) => [
                               PopupMenuItem(value: 'delete', child: Row(children: const [Icon(Icons.delete_outline, color: Colors.red, size: 20), SizedBox(width: 12), Text("Eliminar Chat", style: TextStyle(color: Colors.red))])),
                        ],
                     )
                  )
              );
          }
      );
  }

  Future<bool> _showSimpleConfirm(BuildContext context, String title, String msg) async {
      return await showDialog<bool>(context: context, builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(msg),
          actions: [
              TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Cancelar")),
              TextButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("Confirmar", style: TextStyle(fontWeight: FontWeight.bold))),
          ],
      )) ?? false;
  }

  Future<void> _handleAction(BuildContext context, bool isCreatorIgnored) async {
       // Check real role from DB to be safe
       final realRole = await PlanMembersService().getMyRole(plan.id);
       final isRealAdmin = realRole == 'admin';

       if (!context.mounted) return;

       final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
          title: Text(isRealAdmin ? "¿Eliminar este plan?" : "¿Salir del plan?"),
          content: Text(isRealAdmin 
            ? "Esta acción NO se puede deshacer. Se borrarán todos los datos, chats y gastos." 
            : "Ya no tendrás acceso al chat ni a los gastos compartidos."),
          actions: [
              TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Cancelar")),
              TextButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("Confirmar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
          ],
      ));

      if (confirm == true) {
          try {
              if (isRealAdmin) {
                  await PlanService().deletePlan(plan.id);
                  if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Plan eliminado definitivamente")));
              } else {
                  await PlanMembersService().leavePlan(plan.id);
                  if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saliste del plan")));
              }
              onRefresh(); 
          } catch (e) {
              if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
          }
      }
  }

  Widget _buildAvatarStack(BuildContext context, int count) {
    return Row(
      children: [
        for (int i = 0; i < (count > 3 ? 3 : count); i++)
          Align(
            widthFactor: 0.7,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).cardColor, width: 2),
              ),
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, size: 14, color: Colors.white),
              ),
            ),
          ),
        if (count > 3)
          Container(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              "+${count - 3}",
              style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}

  Future<void> _showNewChatDialog(BuildContext context) async {
       String searchText = "";
       bool isSearchingUser = false;
       String? searchError;
       List<dynamic> foundUsers = [];

       await showModalBottomSheet(
           context: context, 
           isScrollControlled: true,
           backgroundColor: Colors.transparent,
           builder: (c) => StatefulBuilder(
               builder: (context, setState) {
                   return Container(
                       padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom, 
                          left: 24, right: 24, top: 32
                       ),
                       constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
                       decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
                       child: Column(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                               const Text("Nuevo Chat Directo", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                               const SizedBox(height: 8),
                               const Text("Busca a un usuario por su nombre, apodo o correo exacto.", style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center,),
                               const SizedBox(height: 24),
                               TextField(
                                   decoration: const InputDecoration(
                                       hintText: "Escribe un nombre o apodo",
                                       prefixIcon: Icon(Icons.search),
                                       border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)))
                                   ),
                                   onChanged: (v) => searchText = v.trim(),
                                   onSubmitted: (_) {
                                      // Optional trigger search
                                   },
                               ),
                               const SizedBox(height: 16),
                               if (searchError != null) Text(searchError!, style: const TextStyle(color: Colors.red)),
                               if (isSearchingUser) const CircularProgressIndicator(),
                               if (foundUsers.isNotEmpty)
                                   Flexible(
                                       child: ListView.builder(
                                           shrinkWrap: true,
                                           itemCount: foundUsers.length,
                                           itemBuilder: (ctx, index) {
                                               final user = foundUsers[index];
                                               return Card(
                                                   color: AppTheme.darkBackground,
                                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                   margin: const EdgeInsets.only(bottom: 8),
                                                   child: ListTile(
                                                       leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.person, color: Colors.white)),
                                                       title: Text(user['nickname'] ?? user['full_name'] ?? 'Usuario', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                       subtitle: Text("ID: ${user['id'].substring(0,6)}...", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                                       trailing: IconButton(
                                                            icon: const Icon(Icons.chat, color: AppTheme.primaryBrand),
                                                          onPressed: () async {
                                                                 Navigator.pop(context);
                                                                 try {
                                                                     final chatId = await PlanService().getOrCreateDirectChat(user['id']);
                                                                     if (context.mounted) context.push('/plan/$chatId');
                                                                 } catch (e) {
                                                                     if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                                                                 }
                                                            }
                                                       )
                                                   )
                                               );
                                           }
                                       )
                                   ),
                               const SizedBox(height: 24),
                               SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
                                   style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand),
                                   onPressed: isSearchingUser ? null : () async {
                                       if(searchText.isEmpty) return;
                                       setState(() { isSearchingUser = true; searchError = null; foundUsers = []; });
                                       try {
                                            final currentId = Supabase.instance.client.auth.currentUser?.id;
                                            // Realizamos la búsqueda
                                            final res = await Supabase.instance.client
                                                .from('profiles')
                                                .select('id, full_name, nickname, email')
                                                .or('email.ilike.%$searchText%,nickname.ilike.%$searchText%,full_name.ilike.%$searchText%')
                                                .limit(10);
                                                
                                            final filtered = (res as List).where((u) => u['id'] != currentId).toList();
                                            
                                            if (filtered.isNotEmpty) {
                                                setState(() { foundUsers = filtered; });
                                            } else {
                                                setState(() { searchError = "Usuario no encontrado."; });
                                            }
                                       } catch (e) {
                                            setState(() { searchError = "Fallo la búsqueda: $e"; });
                                       } finally {
                                            setState(() { isSearchingUser = false; });
                                       }
                                   },
                                   child: const Text("Buscar")
                               )),
                               const SizedBox(height: 32),
                           ]
                       )
                   );
               }
           )
       );
  }
