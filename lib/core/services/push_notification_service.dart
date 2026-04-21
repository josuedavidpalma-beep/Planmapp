import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  
  static const String webVapidKey = "BKsSw5O52r-eT_M32Ga_izSm245TytUq_9bp6yFhWxGTSpUpCDpYHHuX8aKxI_JoIq6sTazhRGJqtLBrNa22eIM";

  // Singleton pattern
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  bool _initialized = false;

  Future<bool> requestPermissionAndSaveToken() async {
    if (_initialized) return true; // Pretend granted if already ran
    try {
      // 1. Request OS Permission
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
          
          _initialized = true;
          debugPrint('Push Notification Permission Granted or Provisional');
          
          final String? userId = _supabase.auth.currentUser?.id;
          if (userId == null) return true;

          // 2. Get FCM token
          String? token;
          if (kIsWeb) {
              try {
                  token = await _fcm.getToken(vapidKey: webVapidKey);
              } catch (e) {
                 debugPrint("FCM Web token failed (vapidKey needed or unsupported): $e");
                 return true; // Still granted permission, just no token
              }
          } else {
              token = await _fcm.getToken();
          }

          if (token != null) {
             debugPrint('Push Notification Token Retrieved Successfully: $token');
             await _registerToken(userId, token);
          }

          // 3. Listen to token refreshes
          _fcm.onTokenRefresh.listen((newToken) {
             final uid = _supabase.auth.currentUser?.id;
             if (uid != null) {
                 _registerToken(uid, newToken);
             }
          });
          
          return true;
      } else {
          debugPrint('Push Notification Permission Denied');
          return false;
      }
    } catch (e) {
      debugPrint('Push Notification Init Error: $e');
      return false;
    }
  }

  String _getDeviceType() {
      if (kIsWeb) return 'web';
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
      return 'unknown';
  }

  Future<void> _registerToken(String userId, String token) async {
      try {
          final existing = await _supabase.from('fcm_tokens')
              .select('id').eq('user_id', userId).eq('token', token).maybeSingle();
          if (existing != null) return;

          await _supabase.from('fcm_tokens').insert({
              'user_id': userId,
              'token': token,
              'device_type': _getDeviceType(),
              'updated_at': DateTime.now().toIso8601String(),
          });
          debugPrint('Push Notification Token Uploaded to Supabase fcm_tokens');
      } catch (e) {
          debugPrint('Error uploading FCM token: $e');
      }
  }

  Future<void> deleteToken() async {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      try {
          String? token;
          if (kIsWeb) {
              token = await _fcm.getToken(vapidKey: webVapidKey);
          } else {
              token = await _fcm.getToken();
          }

          if (token != null) {
              await _supabase.from('fcm_tokens').delete().match({
                  'user_id': user.id,
                  'token': token
              });
          }
          await _fcm.deleteToken();
      } catch (e) {
          debugPrint("Error deleting token: $e");
      }
  }
}
