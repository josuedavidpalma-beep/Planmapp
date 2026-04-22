import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/plans/domain/models/plan_model.dart';
import 'package:planmapp/features/social/domain/models/friendship_model.dart';
import 'package:planmapp/features/social/services/friendship_service.dart';
import 'package:planmapp/core/services/invitation_service.dart';

class InAppInviteSheet extends StatefulWidget {
  final Plan plan;
  final Map<String, dynamic> existingMembers;

  const InAppInviteSheet({
    super.key,
    required this.plan,
    required this.existingMembers,
  });

  @override
  State<InAppInviteSheet> createState() => _InAppInviteSheetState();
}

class _InAppInviteSheetState extends State<InAppInviteSheet> {
  final FriendshipService _friendshipService = FriendshipService();
  List<Friendship> _friends = [];
  bool _isLoading = true;
  String _error = '';
  final Set<String> _sentInvites = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final friendships = await _friendshipService.getFriendships();
      setState(() {
        _friends = friendships.where((f) => f.status == FriendshipStatus.accepted).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Error cargando amigos: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _sendInternalInvite(Friendship friend) async {
    final friendId = friend.friendId;
    if (friendId == null) return;
    if (_sentInvites.contains(friendId)) return;

    setState(() => _sentInvites.add(friendId));

    try {
      await _friendshipService.sendPlanInvite(friendId, widget.plan);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error interno: $e", style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      }
      setState(() => _sentInvites.remove(friendId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 30,
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Invitar Amigos",
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.plan.title,
            style: const TextStyle(color: AppTheme.primaryBrand, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error.isNotEmpty)
            Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
          else if (_friends.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  "Aún no tienes amigos agregados en la app. Busca usuarios y agrégalos para invitarlos fácilmente.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else ...[
            const Text("Amigos de Planmapp", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _friends.length,
                separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                itemBuilder: (context, index) {
                  final friend = _friends[index];
                  final friendIdStr = friend.friendId ?? '';
                  final friendAvatar = friend.friendAvatarUrl ?? '';
                  final friendNameStr = friend.friendName ?? 'Amigo';
                  
                  final isAlreadyMember = widget.existingMembers.containsKey(friendIdStr);
                  final hasSentInvite = _sentInvites.contains(friendIdStr);

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundImage: friendAvatar.isNotEmpty ? NetworkImage(friendAvatar) : null,
                      backgroundColor: Colors.grey[800],
                      child: friendAvatar.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                    title: Text(friendNameStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    trailing: isAlreadyMember 
                        ? const Text("Ya es miembro", style: TextStyle(color: Colors.white38, fontSize: 13))
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasSentInvite ? Colors.green.withOpacity(0.2) : AppTheme.primaryBrand,
                              foregroundColor: hasSentInvite ? Colors.green : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            onPressed: hasSentInvite ? null : () => _sendInternalInvite(friend),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasSentInvite) ...[
                                  const Icon(Icons.check, size: 16),
                                  const SizedBox(width: 4),
                                ],
                                Text(hasSentInvite ? "Enviada" : "Invitar"),
                              ],
                            ),
                        ),
                  );
                },
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.link, color: Colors.white),
            label: const Text("Compartir Enlace / WhatsApp", style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white38),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              InvitationService.inviteToPlan(widget.plan);
            },
          )
        ],
      ),
    );
  }
}
