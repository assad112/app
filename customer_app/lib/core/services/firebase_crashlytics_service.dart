import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseCrashlyticsProvider = Provider<FirebaseCrashlyticsService>((ref) {
  return FirebaseCrashlyticsService();
});

class FirebaseCrashlyticsService {
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  Future<void> setUserId(String userId) async {
    await _crashlytics.setUserIdentifier(userId);
  }

  Future<void> clearUserId() async {
    await _crashlytics.setUserIdentifier('');
  }

  Future<void> log(String message) async {
    await _crashlytics.log(message);
  }

  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
    String? reason,
  }) async {
    await _crashlytics.recordError(
      error,
      stackTrace,
      fatal: fatal,
      reason: reason,
    );
  }

  Future<void> setCustomKey(String key, Object value) async {
    await _crashlytics.setCustomKey(key, value);
  }
}
