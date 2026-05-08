import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAnalyticsProvider = Provider<FirebaseAnalyticsService>((ref) {
  return FirebaseAnalyticsService();
});

class FirebaseAnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsService();

  Future<void> setUserId(String driverId) async {
    await _analytics.setUserId(id: driverId);
  }

  Future<void> clearUserId() async {
    await _analytics.setUserId(id: null);
  }

  Future<void> logLogin() async {
    await _analytics.logLogin(loginMethod: 'identifier_password');
  }

  Future<void> logLogout() async {
    await _analytics.logEvent(name: 'driver_logout');
  }

  Future<void> logOrderAccepted(String orderId) async {
    await _analytics.logEvent(
      name: 'order_accepted',
      parameters: {'order_id': orderId},
    );
  }

  Future<void> logOrderRejected(String orderId) async {
    await _analytics.logEvent(
      name: 'order_rejected',
      parameters: {'order_id': orderId},
    );
  }

  Future<void> logDeliveryStarted(String orderId) async {
    await _analytics.logEvent(
      name: 'delivery_started',
      parameters: {'order_id': orderId},
    );
  }

  Future<void> logDeliveryCompleted(String orderId) async {
    await _analytics.logEvent(
      name: 'delivery_completed',
      parameters: {'order_id': orderId},
    );
  }

  Future<void> logAvailabilityToggled({required bool online}) async {
    await _analytics.logEvent(
      name: 'availability_toggled',
      parameters: {'status': online ? 'online' : 'offline'},
    );
  }

  Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }
}
