import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/itinerary/domain/models/activity.dart';

class TimelineActivityItem extends StatelessWidget {
  final Activity activity;
  final bool isFirst;
  final bool isLast;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TimelineActivityItem({
    super.key,
    required this.activity,
    required this.isFirst,
    required this.isLast,
    this.canEdit = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeStr = DateFormat('LT', 'es_CO').format(activity.startTime); // 9:00 AM

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Time Column
          SizedBox(
            width: 70,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text(
                  timeStr,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.right,
                ),
                Text(
                  DateFormat('EEE', 'es_CO').format(activity.startTime).toUpperCase(),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  textAlign: TextAlign.right,
                )
              ],
            ),
          ),
          
          // 2. Timeline Line
          SizedBox(
            width: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Vertical Line
                if (!isLast)
                Positioned(
                  top: 24,
                  bottom: 0,
                  width: 2,
                  child: Container(color: Colors.grey[300]),
                ),
                if (!isFirst)
                Positioned(
                  top: 0,
                  bottom: 24, // Connect to center dot
                  width: 2,
                  child: Container(color: Colors.grey[300]),
                ),
                
                // Dot
                Positioned(
                  top: 16,
                  child: Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(activity.category),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0,2))]
                    ),
                  ),
                )
              ],
            ),
          ),

          // 3. Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0, right: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))
                  ],
                  border: Border.all(color: Colors.grey.withOpacity(0.1))
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: canEdit ? onEdit : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  activity.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              if (canEdit)
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                                  onSelected: (val) {
                                    if (val == 'edit') onEdit?.call();
                                    if (val == 'delete') onDelete?.call();
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Editar')])),
                                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
                                  ]
                                )
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (activity.locationName != null)
                            Row(children: [
                              Icon(Icons.location_on, size: 14, color: Colors.grey[600]), 
                              const SizedBox(width: 4), 
                              Expanded(child: Text(activity.locationName!, style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis))
                            ]),
                          if (activity.description != null && activity.description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                activity.description!,
                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          
                          // Chips/Tags
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildCategoryChip(activity.category),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate().slideX(begin: 0.1, duration: 300.ms).fade(),
            ),
          )
        ],
      ),
    );
  }

  Color _getCategoryColor(ActivityCategory cat) {
    switch (cat) {
        case ActivityCategory.food: return Colors.orange;
        case ActivityCategory.transport: return Colors.blue;
        case ActivityCategory.lodging: return Colors.indigo;
        case ActivityCategory.activity: return Colors.purple;
        default: return Colors.grey;
    }
  }

  Widget _buildCategoryChip(ActivityCategory cat) {
      Color c = _getCategoryColor(cat);
      IconData icon;
       switch (cat) {
        case ActivityCategory.food: icon = Icons.restaurant; break;
        case ActivityCategory.transport: icon = Icons.directions_bus; break;
        case ActivityCategory.lodging: icon = Icons.hotel; break;
        default: icon = Icons.local_activity;
       }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 4),
            Text(cat.name.toUpperCase(), style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold))
          ],
        ),
      );
  }
}
