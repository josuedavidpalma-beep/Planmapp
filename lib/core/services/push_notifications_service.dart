import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io' show Platform;
import 'package:planmapp/core/router/app_router.dart';
import 'package:planmapp/core/globals.dart'; // for rootSnackbarKey

class PushNotificationsService {
  static final _firebaseMessaging = FirebaseMessaging.instance;
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
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

        // Handle foreground notifications
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Foreground message received: ${message.notification?.title}');
          final context = rootNavigatorKey.currentContext;
          if (context != null && message.notification != null) {
             rootSnackbarKey.currentState?.showSnackBar(
                SnackBar(
                   content: Text('${message.notification?.title ?? ''}\n${message.notification?.body ?? ''}'),
                   behavior: SnackBarBehavior.floating,
                   action: message.data.containsKey('route') ? SnackBarAction(
                     label: 'Ver', 
                     textColor: Colors.blueAccent,
                     onPressed: () => context.push(message.data['route'])
                   ) : null,
                   duration: const Duration(seconds: 4),
                )
             );
          }
        });

        // Handle background tap (app was in background)
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

        // Handle terminated state tap (app was completely closed)
        _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
           if (message != null) {
              // Wait a bit for the GoRouter to initialize before pushing
              Future.delayed(const Duration(milliseconds: 500), () {
                 _handleMessage(message);
              });
           }
        });

      } else {
        debugPrint('User declined push permission');
      }
    } catch (e) {
      debugPrint('Error initializing Push Notifications: $e');
    }
  }

  static void _handleMessage(RemoteMessage message) {
    if (message.data.containsKey('route')) {
      final route = message.data['route'];
      final context = rootNavigatorKey.currentContext;
      if (context != null) {
        context.push(route);
      }
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
