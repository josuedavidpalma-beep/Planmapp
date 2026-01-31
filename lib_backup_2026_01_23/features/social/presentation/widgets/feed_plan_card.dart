
import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/plans/domain/models/plan_model.dart';
import 'package:intl/intl.dart';

class FeedPlanCard extends StatelessWidget {
  final Plan plan;
  final VoidCallback onTap;

  const FeedPlanCard({super.key, required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Creator Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // TODO: Fetch creator profile details if not in Plan model. 
                // For now, Plan doesn't have creator avatar/name embedded freely.
                // We might need to fetch it or assume it's passed?
                // The SocialFeedService fetched Plans, but Plan model is simple.
                // Let's use a placeholder or handle this better. 
                // Ideally SocialFeedService should join profiles.
                // Let's assume for MVP generic avatar.
                CircleAvatar(
                   backgroundColor: Colors.grey[200],
                   child: const Icon(Icons.person, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Amigo de Planmapp", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("Organizó un nuevo plan", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.more_horiz, color: Colors.grey),
              ],
            ),
          ),
          
          // Plan Content (Clickable)
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 180,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey[100],
                // TODO: Use plan cover image if available
                gradient: LinearGradient(
                   begin: Alignment.topLeft,
                   end: Alignment.bottomRight,
                   colors: [AppTheme.primaryBrand.withOpacity(0.8), AppTheme.secondaryBrand.withOpacity(0.8)]
                )
              ),
              child: Stack(
                 children: [
                    Positioned(
                      bottom: 16, left: 16, right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text(plan.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                           const SizedBox(height: 4),
                           Row(
                             children: [
                                const Icon(Icons.location_on, color: Colors.white70, size: 14),
                                const SizedBox(width: 4),
                                Text(plan.locationName, style: const TextStyle(color: Colors.white70)),
                             ],
                           )
                        ],
                      ),
                    )
                 ],
              ),
            ),
          ),
          
          // Actions
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                 _ActionChip(icon: Icons.calendar_today, label: DateFormat('MMM d').format(plan.eventDate)),
                 const SizedBox(width: 12),
                 const _ActionChip(icon: Icons.group_outlined, label: "Ver"),
                 const Spacer(),
                 ElevatedButton(
                   onPressed: onTap,
                   style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBrand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                   ),
                   child: const Text("Ver Plan"),
                 )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ActionChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: Colors.grey[800], fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
