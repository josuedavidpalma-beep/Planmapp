import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  // The VAPID Key used ONLY for Web. 
  // Nota de seguridad: Esta llave es pública por diseño (es la mitad pública de un par de llaves asimétricas) 
  // para verificar la procedencia de la app. Es 100% segura exponerla.
  static const String webVapidKey = "BKsSw5O52r-eT_M32Ga_izSm245TytUq_9bp6yFhWxGTSpUpCDpYHHuX8aKxI_JoIq6sTazhRGJqtLBrNa22eIM";

  static final PushNotificationService _instance = PushNotificationService._internal();

  factory PushNotificationService() {
    return _instance;
  }

  PushNotificationService._internal();

  /// Requests permission and saves the FCM token to the database.
  /// Should be explicitly triggered post-registration to get the popup.
  Future<void> requestPermissionAndSaveToken() async {
    try {
      // 1. Request OS Permission
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        print('User granted permission: ${settings.authorizationStatus}');
        
        // 2. Fetch the unique FCM Token
        String? token;
        
        if (kIsWeb) {
            token = await _fcm.getToken(vapidKey: webVapidKey);
        } else {
            token = await _fcm.getToken();
        }

        if (token != null) {
          print('FCM Token generated successfully.');
          await _saveTokenToDatabase(token);
        }

        // 3. Listen to foreground messages (Optional, to show local snackbars when app is open)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
            print('Got a message whilst in the foreground!');
            print('Message data: ${message.data}');
            if (message.notification != null) {
                print('Message also contained a notification: ${message.notification}');
                // You could trigger a local NotificationService here or a Snackbar alert
            }
        });

      } else {
        print('User declined or has not accepted permission');
      }
    } catch (e) {
      print("PushNotificationService Error: $e");
    }
  }

  Future<void> _saveTokenToDatabase(String token) async {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      try {
         String deviceType = 'web';
         if (!kIsWeb) {
             deviceType = Platform.isIOS ? 'ios' : 'android';
         }

         await _supabase.from('fcm_tokens').upsert(
            {
                'user_id': user.id,
                'token': token,
                'device_type': deviceType,
                'updated_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'user_id, token'
         );
      } catch (e) {
         print("Error saving FCM Token to Supabase: $e");
      }
  }

  /// Remove token on logout
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
          print("Error deleting token: $e");
      }
  }
}
