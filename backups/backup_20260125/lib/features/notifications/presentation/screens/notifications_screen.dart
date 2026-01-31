
import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/notifications/data/models/notification_model.dart';
import 'package:planmapp/features/notifications/services/notification_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/presentation/widgets/dancing_empty_state.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _handleTap(BuildContext context, NotificationModel notification) async {
    // 1. Mark as read
    if (!notification.isRead) {
      await NotificationService().markAsRead(notification.id);
    }

    // 2. Navigate based on type
    if (context.mounted) {
      final planId = notification.data['plan_id'] as String?;
      
      if (planId != null) {
          // Go to plan
          context.push('/plan/$planId');
      } else {
         // Just show generic message if no deep link
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notificaciones", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          TextButton(
            onPressed: () async {
               await NotificationService().markAllAsRead();
               if(context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Todo marcado como leído")));
               }
            }, 
            child: const Text("Marcar todo leído")
          )
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: NotificationService().getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final list = snapshot.data ?? [];

          if (list.isEmpty) {
            return const Center(
               child: DancingEmptyState(
                 icon: Icons.notifications_off_outlined,
                 title: "Sin novedades",
                 message: "Todo está tranquilo por aquí.",
               ),
            );
          }

          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = list[index];
              return Dismissible(
                key: Key(item.id),
                background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                direction: DismissDirection.endToStart,
                onDismissed: (_) {
                   NotificationService().deleteNotification(item.id);
                },
                child: ListTile(
                  tileColor: item.isRead ? Colors.white : AppTheme.primaryBrand.withOpacity(0.05),
                  leading: CircleAvatar(
                    backgroundColor: _getColor(item.type).withOpacity(0.1),
                    child: Icon(_getIcon(item.type), color: _getColor(item.type)),
                  ),
                  title: Text(item.title, style: TextStyle(fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.body),
                      const SizedBox(height: 4),
                      Text(timeago.format(item.createdAt, locale: 'es'), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  onTap: () => _handleTap(context, item),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIcon(String type) {
    switch(type) {
      case 'invite': return Icons.mail_outline;
      case 'chat': return Icons.chat_bubble_outline;
      case 'poll': return Icons.poll_outlined;
      default: return Icons.notifications_none;
    }
  }

  Color _getColor(String type) {
    switch(type) {
      case 'invite': return Colors.blue;
      case 'chat': return Colors.green;
      case 'poll': return Colors.orange;
      default: return Colors.grey;
    }
  }
}
