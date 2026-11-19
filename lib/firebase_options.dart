import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyA9r9jxySASRCwrKK4MTSWh6PkCFiEnbfk',
        appId: '1:732309253599:android:02c8bdebcc63612957686a',
        messagingSenderId: '732309253599',
        projectId: 'mrapache-23596',
        authDomain: 'mrapache-23596.firebaseapp.com',
        storageBucket: 'mrapache-23596.firebasestorage.app',
      );
    }
    return null;
  }
}
