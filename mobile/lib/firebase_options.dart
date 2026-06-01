import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web tidak didukung');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
            'Platform ${defaultTargetPlatform.name} tidak didukung');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyBT2C6P54bfOMQxTpQovmnZGkEE5TRSKoE',
    appId:             '1:831646074653:android:11d547468ed68e515c03f4',
    messagingSenderId: '831646074653',
    projectId:         'hydroserv-83a25',
    storageBucket:     'hydroserv-83a25.firebasestorage.app',
  );
}
