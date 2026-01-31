
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/notifications/data/models/notification_model.dart';
import 'package:rxdart/rxdart.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Stream of unread count
  Stream<int> getUnreadCountStream() {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', _supabase.auth.currentUser!.id) // Ensure RLS matches, but explicit safety
        .map((list) => list.where((n) => n['is_read'] == false).length);
  }

  // Stream of all notifications
  Stream<List<NotificationModel>> getNotificationsStream() {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', _supabase.auth.currentUser!.id)
        .order('created_at', ascending: false)
        .limit(50)
        .map((maps) => maps.map((e) => NotificationModel.fromJson(e)).toList());
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      print("Error marking notification as read: $e");
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      print("Error marking all as read: $e");
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      print("Error deleting notification: $e");
    }
  }
}
