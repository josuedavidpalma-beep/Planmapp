import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/plans/services/plan_members_service.dart';
import 'package:planmapp/core/services/plan_service.dart'; // Core plan service
import 'package:go_router/go_router.dart';

class ParticipantsListBottomSheet extends StatefulWidget {
  final String planId;
  final bool isAdmin;
  final bool isCancelled;

  const ParticipantsListBottomSheet({
      super.key, 
      required this.planId, 
      required this.isAdmin,
      this.isCancelled = false
  });

  @override
  State<ParticipantsListBottomSheet> createState() => _ParticipantsListBottomSheetState();
}

class _ParticipantsListBottomSheetState extends State<ParticipantsListBottomSheet> with SingleTickerProviderStateMixin {
  final PlanMembersService _membersService = PlanMembersService();
  final PlanService _planService = PlanService();
  late TabController _tabController;
  bool _isLoading = true;
  List<PlanMember> _members = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMembers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
      try {
          final members = await _membersService.getMembers(widget.planId);
          if (mounted) setState(() { _members = members; _isLoading = false; });
      } catch (e) {
          if (mounted) setState(() => _isLoading = false);
      }
  }

  Future<void> _cancelPlan() async {
      final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
          title: const Text("⚠️ ¿Cancelar Plan?"),
          content: const Text("Esta acción notificará a todos los invitados. El plan quedará en estado 'Cancelado' y no se podrá editar."),
          actions: [
              TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Volver")),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: ()=>Navigator.pop(c, true), 
                  child: const Text("Sí, Cancelar Plan")
              )
          ],
      ));

      if (confirm == true) {
          try {
               Navigator.pop(context); // Close sheet
               await _planService.cancelPlan(widget.planId);
               // The parent screen should listen to status change or we pop
               // For now, we rely on the parent to refresh or stream.
          } catch (e) {
               // Show error
          }
      }
  }

  Future<void> _openInternalInviteSearch() async {
      await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _InternalUserSearchSheet(
              planId: widget.planId, 
              currentMembers: _members,
              onUserInvited: _loadMembers,
          )
      );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                       const Text("Participantes", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                       Row(
                           children: [
                               if (widget.isAdmin && !widget.isCancelled)
                                  IconButton(
                                      icon: const Icon(Icons.person_add_alt_1, color: AppTheme.primaryBrand), 
                                      tooltip: "Buscar amigos en Planmapp",
                                      onPressed: () {
                                          _openInternalInviteSearch();
                                      }
                                  ),
                               IconButton(icon: const Icon(Icons.close), onPressed: ()=>Navigator.pop(context))
                           ]
                       )
                   ],
                ),
                const SizedBox(height: 16),
                
                TabBar(
                    controller: _tabController,
                    isScrollable: false,
                    labelColor: AppTheme.primaryBrand,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppTheme.primaryBrand,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: [
                        Tab(text: "Van (${_members.where((m) => m.status == 'accepted').length})"),
                        Tab(text: "Pnd (${_members.where((m) => m.status == 'pending').length})"),
                        Tab(text: "No (${_members.where((m) => m.status == 'declined').length})"),
                    ],
                ),
                const SizedBox(height: 16),

                Expanded(
                    child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                            _buildMembersList('accepted'),
                            _buildMembersList('pending'),
                            _buildMembersList('declined'),
                        ],
                    )
                ),

                if (widget.isAdmin && !widget.isCancelled) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                        onPressed: _cancelPlan, 
                        icon: const Icon(Icons.cancel_presentation, color: Colors.red),
                        label: const Text("Cancelar Plan"),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red)
                        ),
                    )
                ] else if (widget.isCancelled) ...[
                    Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.red[50], 
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.block, color: Colors.red), SizedBox(width: 8), Text("Este plan ha sido cancelado", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))])
                    )
                ]
            ],
        ),
    );
  }

  Widget _buildMembersList(String status) {
      final filtered = _members.where((m) => m.status == status).toList();
      if (filtered.isEmpty) {
          return Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      Icon(Icons.people_outline, size: 48, color: Colors.grey.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Text("Aún no hay nadie en esta lista", style: TextStyle(color: Colors.grey.withOpacity(0.8))),
                  ],
              ),
          );
      }
      return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
              final member = filtered[index];
              return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                      backgroundImage: member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
                      child: member.avatarUrl == null ? Text(member.name[0].toUpperCase()) : null,
                  ),
                  title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(member.role == 'admin' ? "Organizador" : "Invitado", style: const TextStyle(fontSize: 12)),
                  trailing: _buildStatusChip(member.status),
              );
          },
      );
  }

  Widget _buildStatusChip(String status) {
      Color color;
      String text;
      IconData icon;

      switch(status) {
          case 'accepted': color = Colors.green; text = "Confirmado"; icon = Icons.check; break;
          case 'declined': color = Colors.red; text = "No va"; icon = Icons.close; break;
          default: color = Colors.orange; text = "Pendiente"; icon = Icons.access_time;
      }

      return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
          child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))
              ],
          ),
      );
  }
}

class _InternalUserSearchSheet extends StatefulWidget {
  final String planId;
  final List<PlanMember> currentMembers;
  final VoidCallback onUserInvited;

  const _InternalUserSearchSheet({
      required this.planId, 
      required this.currentMembers, 
      required this.onUserInvited
  });

  @override
  State<_InternalUserSearchSheet> createState() => _InternalUserSearchSheetState();
}

class _InternalUserSearchSheetState extends State<_InternalUserSearchSheet> {
    final TextEditingController _searchController = TextEditingController();
    bool _isSearching = false;
    List<Map<String, dynamic>> _results = [];

    Future<void> _performSearch(String query) async {
        if (query.length < 3) {
            setState(() { _results = []; _isSearching = false; });
            return;
        }

        setState(() => _isSearching = true);
        try {
            final data = await Supabase.instance.client
                .from('profiles')
                .select('id, nickname, full_name')
                .or('nickname.ilike.%$query%,full_name.ilike.%$query%')
                .limit(10);
            
            // Filter out existing members
            final currentIds = widget.currentMembers.map((m) => m.id).toSet();
            final filtered = (data as List<dynamic>)
                .where((user) => !currentIds.contains(user['id']))
                .cast<Map<String,dynamic>>()
                .toList();

            setState(() { _results = filtered; _isSearching = false; });
        } catch (e) {
            setState(() => _isSearching = false);
        }
    }

    Future<void> _inviteUser(String userId, String userName) async {
        try {
            await PlanMembersService().addMember(widget.planId, userId, role: 'member', status: 'pending');
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invitación enviada a $userName", style: const TextStyle(color: Colors.white)), backgroundColor: Colors.green));
            widget.onUserInvited();
            Navigator.pop(context);
        } catch (e) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al invitar: $e")));
        }
    }

    @override
    Widget build(BuildContext context) {
        return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: EdgeInsets.only(left: 20, right: 20, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    const Text("Buscar Usuario", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                        controller: _searchController,
                        onChanged: _performSearch,
                        decoration: InputDecoration(
                            hintText: "Nombre o Apodo...",
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                        ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                        child: _isSearching 
                        ? const Center(child: CircularProgressIndicator())
                        : _results.isEmpty 
                            ? Center(child: Text(_searchController.text.length < 3 ? "Ingresa 3 letras para buscar" : "No se encontraron usuarios libres", style: const TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                itemCount: _results.length,
                                itemBuilder: (c, i) {
                                    final u = _results[i];
                                    final name = u['nickname']?.isNotEmpty == true ? u['nickname'] : u['full_name'];
                                    return ListTile(
                                        leading: CircleAvatar(backgroundColor: AppTheme.primaryBrand.withOpacity(0.1), child: const Icon(Icons.person, color: AppTheme.primaryBrand)),
                                        title: Text(name ?? "Usuario", style: const TextStyle(fontWeight: FontWeight.bold)),
                                        trailing: ElevatedButton(
                                            onPressed: () => _inviteUser(u['id'], name),
                                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.white),
                                            child: const Text("Invitar")
                                        ),
                                    );
                                }
                            )
                    )
                ]
            )
        );
    }
}
