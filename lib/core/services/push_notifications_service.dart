import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class PushNotificationsService {
  static final _firebaseMessaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    try {
      // Request permission (shows popup on iOS/Web)
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted push permission');
        await _saveToken();
        
        // Listen for token updates
        _firebaseMessaging.onTokenRefresh.listen((token) {
           _saveToken(forcedToken: token);
        });
      } else {
        debugPrint('User declined push permission');
      }
    } catch (e) {
      debugPrint('Error initializing Push Notifications: $e');
    }
  }

  static Future<void> _saveToken({String? forcedToken}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      final token = forcedToken ?? await _firebaseMessaging.getToken();
      if (token != null) {
        
        String deviceType = 'web';
        if (!kIsWeb) {
            deviceType = Platform.isIOS ? 'ios' : 'android';
        }

        // Save to Supabase fcm_tokens table
        await Supabase.instance.client.from('fcm_tokens').upsert({
            'user_id': user.id,
            'token': token,
            'device_type': deviceType,
            'updated_at': DateTime.now().toIso8601String()
        }, onConflict: 'user_id, token');
        
        debugPrint('FCM Token saved to DB: $token');
      }
    } catch (e) {
      debugPrint('Error saving FCM token to DB: $e');
    }
  }
}
