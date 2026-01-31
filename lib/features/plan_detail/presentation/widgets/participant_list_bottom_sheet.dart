import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/plans/services/plan_members_service.dart';

class ParticipantListBottomSheet extends StatelessWidget {
  final List<PlanMember> members;
  final String creatorId;

  const ParticipantListBottomSheet({
    super.key, 
    required this.members,
    required this.creatorId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Text(
            "Invitados (${members.length})",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: members.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final member = members[index];
                final bool isAdmin = member.id == creatorId || member.role == 'admin';
                
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: _getColorForName(member.name),
                    child: Text(
                      member.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (isAdmin) ...[
                         const SizedBox(width: 8),
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                           decoration: BoxDecoration(
                             color: AppTheme.primaryBrand.withOpacity(0.1),
                             borderRadius: BorderRadius.circular(4),
                             border: Border.all(color: AppTheme.primaryBrand.withOpacity(0.3))
                           ),
                           child: const Text("Admin", style: TextStyle(fontSize: 10, color: AppTheme.primaryBrand, fontWeight: FontWeight.bold)),
                         )
                      ]
                    ],
                  ),
                  subtitle: Text(
                    member.isGuest ? "Invitado (Sin cuenta)" : "Miembro",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  trailing: _getStatusIcon(member.role),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForName(String name) {
    final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal];
    return colors[name.length % colors.length];
  }

  Widget _getStatusIcon(String status) {
    // Ideally this comes from a real 'status' field (accepted, pending, declined)
    // For now we assume existing members are accepted.
    return const Icon(Icons.check_circle, color: Colors.green, size: 20);
  }
}
