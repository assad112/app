import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAnalyticsProvider = Provider<FirebaseAnalyticsService>((ref) {
  return FirebaseAnalyticsService();
});

class FirebaseAnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> setUserId(String userId) async {
    await _analytics.setUserId(id: userId);
  }

  Future<void> clearUserId() async {
    await _analytics.setUserId(id: null);
  }

  Future<void> logLogin() async {
    await _analytics.logLogin(loginMethod: 'email_password');
  }

  Future<void> logSignUp() async {
    await _analytics.logSignUp(signUpMethod: 'email_password');
  }

  Future<void> logLogout() async {
    await _analytics.logEvent(name: 'customer_logout');
  }

  Future<void> logOrderCreated({
    required String orderId,
    required double value,
  }) async {
    await _analytics.logPurchase(
      transactionId: orderId,
      value: value,
      currency: 'OMR',
    );
  }

  Future<void> logOrderCancelled(String orderId) async {
    await _analytics.logEvent(
      name: 'order_cancelled',
      parameters: {'order_id': orderId},
    );
  }

  Future<void> logOrderTracked(String orderId) async {
    await _analytics.logEvent(
      name: 'order_tracking_viewed',
      parameters: {'order_id': orderId},
    );
  }

  Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }
}
