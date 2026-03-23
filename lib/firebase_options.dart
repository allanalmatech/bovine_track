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
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBopBPxI121kslxpDrn-cObmkiZ7mdDQYI',
    appId: '1:321115442733:android:28ba5085b3317c1d0c72a4',
    messagingSenderId: '321115442733',
    projectId: 'bovinetrack-a10c9',
    databaseURL: 'https://bovinetrack-a10c9-default-rtdb.firebaseio.com',
    storageBucket: 'bovinetrack-a10c9.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FLUTTERFIRE_API_KEY',
    appId: 'REPLACE_WITH_FLUTTERFIRE_APP_ID',
    messagingSenderId: 'REPLACE_WITH_FLUTTERFIRE_SENDER_ID',
    projectId: 'bovinetrack-a10c9',
    authDomain: 'bovinetrack-a10c9.firebaseapp.com',
    databaseURL: 'https://bovinetrack-a10c9-default-rtdb.firebaseio.com',
    storageBucket: 'bovinetrack-a10c9.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FLUTTERFIRE_API_KEY',
    appId: 'REPLACE_WITH_FLUTTERFIRE_APP_ID',
    messagingSenderId: 'REPLACE_WITH_FLUTTERFIRE_SENDER_ID',
    projectId: 'bovinetrack-a10c9',
    databaseURL: 'https://bovinetrack-a10c9-default-rtdb.firebaseio.com',
    storageBucket: 'bovinetrack-a10c9.appspot.com',
    iosBundleId: 'com.bse.bovinetrack.bovineTrack',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FLUTTERFIRE_API_KEY',
    appId: 'REPLACE_WITH_FLUTTERFIRE_APP_ID',
    messagingSenderId: 'REPLACE_WITH_FLUTTERFIRE_SENDER_ID',
    projectId: 'bovinetrack-a10c9',
    databaseURL: 'https://bovinetrack-a10c9-default-rtdb.firebaseio.com',
    storageBucket: 'bovinetrack-a10c9.appspot.com',
    iosBundleId: 'com.bse.bovinetrack.bovineTrack',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FLUTTERFIRE_API_KEY',
    appId: 'REPLACE_WITH_FLUTTERFIRE_APP_ID',
    messagingSenderId: 'REPLACE_WITH_FLUTTERFIRE_SENDER_ID',
    projectId: 'bovinetrack-a10c9',
    databaseURL: 'https://bovinetrack-a10c9-default-rtdb.firebaseio.com',
    storageBucket: 'bovinetrack-a10c9.appspot.com',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FLUTTERFIRE_API_KEY',
    appId: 'REPLACE_WITH_FLUTTERFIRE_APP_ID',
    messagingSenderId: 'REPLACE_WITH_FLUTTERFIRE_SENDER_ID',
    projectId: 'bovinetrack-a10c9',
    databaseURL: 'https://bovinetrack-a10c9-default-rtdb.firebaseio.com',
    storageBucket: 'bovinetrack-a10c9.appspot.com',
  );
}
