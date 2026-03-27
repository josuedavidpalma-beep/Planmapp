import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> initialize() async {
    // Note: Firebase.initializeApp() must be called in main.dart before this.
    try {
      // 1. Request Permission (Crucial for iOS/Web)
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('Usuario aceptó las notificaciones push.');
        await _registerToken();

        // Listen to token refresh
        _fcm.onTokenRefresh.listen((newToken) {
          _saveTokenToSupabase(newToken);
        });

      } else {
        debugPrint('El usuario denegó las notificaciones.');
      }
    } catch (e) {
      debugPrint("Error inicializando FCM: $e");
    }
  }

  Future<void> _registerToken() async {
    try {
      String? token;
      
      if (kIsWeb) {
        // En Web necesitamos una VAPID Key generada en Firebase Console
        // token = await _fcm.getToken(vapidKey: 'YOUR_VAPID_KEY');
        token = await _fcm.getToken();
      } else {
        token = await _fcm.getToken();
      }

      if (token != null) {
        await _saveTokenToSupabase(token);
      }
    } catch (e) {
      debugPrint("Error obteniendo token FCM: $e");
    }
  }

  Future<void> _saveTokenToSupabase(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      String deviceType = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');

      await _supabase.from('fcm_tokens').upsert({
        'user_id': userId,
        'token': token,
        'device_type': deviceType,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id, token');
      
      debugPrint("FCM Token guardado en DB de Supabase.");
    } catch (e) {
      debugPrint("Error guardando token en DB: $e");
    }
  }
}
