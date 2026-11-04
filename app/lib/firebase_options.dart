import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions not configured for this platform.',
        );
    }
  }

  // ── Web ──────────────────────────────────────────────────────────────────
  // Get appId from: Firebase Console → Project Settings → Your apps → Web app
  // Format: "1:274739580013:web:XXXXXXXXXXXXXXXX"
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCqo_wEoOmK2ZivEnZ5GnoHpn81SD_HdnU',
    appId: '1:274739580013:web:01cc02d7f89ef1fc8d8364',
    messagingSenderId: '274739580013',
    projectId: 'parche-6c44d',
    authDomain: 'parche-6c44d.firebaseapp.com',
    storageBucket: 'parche-6c44d.firebasestorage.app',
    measurementId: 'G-0ZSPZ47SBP',
  );

  // ── Android ───────────────────────────────────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBkMR47MmMs4M5wbDJFw2adLR-I5SVKsZ8',
    appId: '1:274739580013:android:97ba5ca836fc8a9e8d8364',
    messagingSenderId: '274739580013',
    projectId: 'parche-6c44d',
    authDomain: 'parche-6c44d.firebaseapp.com',
    storageBucket: 'parche-6c44d.firebasestorage.app',
  );
}
