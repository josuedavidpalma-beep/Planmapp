import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import 'package:planmapp/core/globals.dart'; // To show foreground snackbars

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

  bool _isInitialized = false;

  /// Returns true if permission was granted or provisional, false if denied.
  Future<bool> requestPermissionAndSaveToken() async {
    if (_isInitialized) return true;
    
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
            if (message.notification != null) {
                final title = message.notification?.title ?? "Planmapp";
                final body = message.notification?.body ?? "Nueva notificación";
                
                rootSnackbarKey.currentState?.showSnackBar(
                    SnackBar(
                        content: Row(
                            children: [
                                const Icon(Icons.notifications_active, color: Colors.white),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            Text(body, style: const TextStyle(fontSize: 13)),
                                        ]
                                    )
                                )
                            ]
                        ),
                        backgroundColor: Colors.indigoAccent,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 4),
                        margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                        elevation: 10,
                    )
                );
            }
        });
        
        _isInitialized = true;
        return true;

      } else {
        print('User declined or has not accepted permission');
        return false;
      }
    } catch (e) {
      print("PushNotificationService Error: $e");
      return false;
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
