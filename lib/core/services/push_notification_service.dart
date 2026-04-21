import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final SupabaseClient _supabase = Supabase.instance.client;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      // 1. Request permissions (shows popup on iOS / Android 13+)
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
          if (userId == null) return;

          // 2. Get FCM token
          String? token;
          if (kIsWeb) {
              try {
                  // For web you normally pass a vapidKey
                  // token = await _fcm.getToken(vapidKey: '...');
                  token = await _fcm.getToken();
              } catch (e) {
                 debugPrint("FCM Web token failed (vapidKey needed or unsupported): $e");
                 return;
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
      } else {
          debugPrint('Push Notification Permission Denied');
      }
    } catch (e) {
      debugPrint('Push Notification Init Error: $e');
    }
  }

  static String _getDeviceType() {
      if (kIsWeb) return 'web';
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
      return 'unknown';
  }

  static Future<void> _registerToken(String userId, String token) async {
      try {
          // Check if it exists first
          final existing = await _supabase.from('fcm_tokens').select('id').eq('user_id', userId).eq('token', token).maybeSingle();
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
}
