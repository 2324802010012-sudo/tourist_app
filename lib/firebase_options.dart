import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => web,
      TargetPlatform.macOS => web,
      TargetPlatform.windows => web,
      TargetPlatform.linux => web,
      TargetPlatform.fuchsia => web,
    };
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB3JghH8A85fbhkNq55edhJUq-fEqXsPZc',
    appId: '1:964453834596:android:bba0295cce29be7f1d6471',
    messagingSenderId: '964453834596',
    projectId: 'vietlens-app',
    authDomain: 'vietlens-app.firebaseapp.com',
    storageBucket: 'vietlens-app.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB3JghH8A85fbhkNq55edhJUq-fEqXsPZc',
    appId: '1:964453834596:android:bba0295cce29be7f1d6471',
    messagingSenderId: '964453834596',
    projectId: 'vietlens-app',
    storageBucket: 'vietlens-app.firebasestorage.app',
  );
}
