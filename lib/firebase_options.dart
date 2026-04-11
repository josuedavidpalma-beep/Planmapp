// File generated manually for Planmapp Web Telemetry
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    // We only support Web for now as per the user's strategy
    throw UnsupportedError(
      'DefaultFirebaseOptions have not been configured for mobile. Only Web is supported.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDV_cJqok1orHMKC2GcmfjoEQIOA9CcLig',
    appId: '1:215284322468:web:adca5f29737c1db7761631',
    messagingSenderId: '215284322468',
    projectId: 'plan-mapp2-dgp8y5',
    authDomain: 'plan-mapp2-dgp8y5.firebaseapp.com',
    storageBucket: 'plan-mapp2-dgp8y5.firebasestorage.app',
  );
}
