import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase web is not configured for this app.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBaXHVWXLx8UfnERxx-W3bm_xKZGVt7SdU',
    appId: '1:888043366370:android:4f865c630de7f0b4e0bbbb',
    messagingSenderId: '888043366370',
    projectId: 'ogas-941c4',
    storageBucket: 'ogas-941c4.firebasestorage.app',
  );

  // أضف GoogleService-Info.plist في ios/Runner/ ثم عدّل القيم أدناه
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_IOS_API_KEY',
    appId: 'REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: '888043366370',
    projectId: 'ogas-941c4',
    storageBucket: 'ogas-941c4.firebasestorage.app',
    iosBundleId: 'com.omangas.driverApp',
  );
}
