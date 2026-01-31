
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/notifications/services/notification_service.dart';
import 'package:planmapp/features/notifications/data/models/notification_model.dart';
import 'package:planmapp/features/home/presentation/widgets/skeleton_card.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Marcar todo como leído',
            onPressed: () {
               ref.read(notificationServiceProvider).markAllAsRead();
            },
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes notificaciones',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ).animate().fade(duration: 400.ms).scale(),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Dismissible(
                key: Key(notification.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  ref.read(notificationServiceProvider).deleteNotification(notification.id);
                },
                child: _NotificationTile(notification: notification),
              ).animate(delay: (index * 50).ms).fade().slideX();
            },
          );
        },
        loading: () => ListView.builder(
          itemCount: 6,
          itemBuilder: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(height: 80, child: Card(child: Center(child: CircularProgressIndicator()))) // Placeholder if SkeletonCard isn't easily imported strictly
          ),
        ),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final NotificationModel notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = notification.isRead;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isRead ? Colors.grey.withOpacity(0.2) : AppTheme.primaryBrand.withOpacity(0.1),
        child: Icon(
          _getIconForType(notification.type),
          color: isRead ? Colors.grey : AppTheme.primaryBrand,
        ),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(notification.body),
          const SizedBox(height: 4),
          Text(
            DateFormat.yMMMd().add_jm().format(notification.createdAt.toLocal()),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
      onTap: () {
        if (!isRead) {
          ref.read(notificationServiceProvider).markAsRead(notification.id);
        }
        _handleNavigation(context, notification);
      },
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'invite': return Icons.mail_outline;
      case 'chat': return Icons.chat_bubble_outline;
      case 'poll': return Icons.poll_outlined;
      case 'expense': return Icons.receipt_long;
      default: return Icons.notifications_none;
    }
  }

  void _handleNavigation(BuildContext context, NotificationModel n) {
    if (n.data.containsKey('plan_id')) {
      final planId = n.data['plan_id'];
      // Example navigation logic
      // context.push('/plans/$planId');
      // For now, assuming standard plan detail route
       context.push('/plan/$planId'); 
    }
  }
}
