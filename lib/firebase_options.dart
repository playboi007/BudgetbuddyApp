import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static final FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyASCoJbEDOkE5bG-fG5m7E1D2YOhvhp9zo',
    appId: '1:32600895199:web:5bae922cf595142ccdc36a',
    messagingSenderId: '32600895199',
    projectId: 'budgetbuddy-6569f',
    authDomain: 'budgetbuddy-6569f.firebaseapp.com',
    storageBucket: 'budgetbuddy-6569f.firebasestorage.app',
    measurementId: 'G-PP4E49BK6Q',
  );

  static final FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAucm2ZlfZmlqpTJ-hCYiNtezLGwZuAyng',
    appId: '1:32600895199:android:f6b027c3c2e9b20fcdc36a',
    messagingSenderId: '32600895199',
    projectId: 'budgetbuddy-6569f',
    storageBucket: 'budgetbuddy-6569f.firebasestorage.app',
  );

  static final FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBX3EQ8jnqkac7rWHoQg8_axH5KQVIFZwI',
    appId: '1:32600895199:ios:18feb9194767e877cdc36a',
    messagingSenderId: '32600895199',
    projectId: 'budgetbuddy-6569f',
    storageBucket: 'budgetbuddy-6569f.firebasestorage.app',
    iosBundleId: 'com.example.budgetbuddyApp',
  );

  static FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBX3EQ8jnqkac7rWHoQg8_axH5KQVIFZwI',
    appId: '1:32600895199:ios:18feb9194767e877cdc36a',
    messagingSenderId: '32600895199',
    projectId: 'budgetbuddy-6569f',
    storageBucket: 'budgetbuddy-6569f.firebasestorage.app',
    iosBundleId: 'com.example.budgetbuddyApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyASCoJbEDOkE5bG-fG5m7E1D2YOhvhp9zo',
    appId: '1:32600895199:web:1ccacd6d3629a7e2cdc36a',
    messagingSenderId: '32600895199',
    projectId: 'budgetbuddy-6569f',
    authDomain: 'budgetbuddy-6569f.firebaseapp.com',
    storageBucket: 'budgetbuddy-6569f.firebasestorage.app',
    measurementId: 'G-S7E74M3KPG',
  );
}
