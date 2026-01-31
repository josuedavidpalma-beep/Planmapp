
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/notification_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider definition
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(Supabase.instance.client);
});

// Stream provider for easy UI consumption
final notificationsStreamProvider = StreamProvider<List<NotificationModel>>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.getNotificationsStream();
});

// Unread count provider
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.getNotificationsStream().map((list) => list.where((n) => !n.isRead).length);
});

class NotificationService {
  final SupabaseClient _supabase;

  NotificationService(this._supabase);

  /// Listens to real-time changes in the 'notifications' table for the current user.
  Stream<List<NotificationModel>> getNotificationsStream() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value([]);

    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => NotificationModel.fromJson(json)).toList());
  }

  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false); // Only update unread ones for efficiency
  }

  Future<void> deleteNotification(String notificationId) async {
    await _supabase
        .from('notifications')
        .delete()
        .eq('id', notificationId);
  }
}
