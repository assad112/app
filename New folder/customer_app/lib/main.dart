import 'dart:ui';

import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:customer_app/app/app.dart';
import 'package:customer_app/core/services/firebase_messaging_service.dart';
import 'package:customer_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FlutterError.onError = (details) {
    if (_isExpectedMapTileImageError(details)) {
      FlutterError.presentError(details);
      return;
    }

    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    if (_isExpectedMapTilePlatformError(error)) {
      debugPrint('Ignored map tile image error: $error');
      return true;
    }

    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  final container = ProviderContainer();
  final messagingService = container.read(firebaseMessagingServiceProvider);
  try {
    await messagingService.requestPermission();
    await messagingService.initialize();
  } catch (error, stack) {
    debugPrint('Firebase messaging initialization failed: $error');
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
  }

  // تهيئة OneSignal
  OneSignal.initialize('72e630fa-b816-4860-ae62-9af58d9d65e2');
  OneSignal.Notifications.requestPermission(true);

  runApp(
    UncontrolledProviderScope(container: container, child: const CustomerApp()),
  );
}

bool _isExpectedMapTileImageError(FlutterErrorDetails details) {
  final message = details.toString();
  return message.contains('tile.openstreetmap.org') ||
      message.contains('NetworkTileImageProvider') ||
      message.contains('Error thrown resolving an image codec');
}

bool _isExpectedMapTilePlatformError(Object error) {
  final message = error.toString();
  return message.contains('tile.openstreetmap.org') ||
      message.contains('NetworkTileImageProvider');
}
