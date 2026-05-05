import 'package:customer_app/core/network/api_client.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseMessagingServiceProvider =
    Provider<FirebaseMessagingService>((ref) {
      return FirebaseMessagingService(ref.watch(apiClientProvider));
    });

const _channelId = 'ogas_customer_channel';
const _channelName = 'OGas Customer Notifications';
const _channelDesc = 'تحديثات الطلبات والتوصيل';

class FirebaseMessagingService {
  FirebaseMessagingService(this._dio);

  final dynamic _dio;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color(0xFFFF7A1A),
      );

  Future<void> initialize() async {
    await _setupLocalNotifications();
    await _configureFCM();
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
  }

  Future<void> _configureFCM() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _registerTokenWithBackend(token);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen(_registerTokenWithBackend);
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final android = notification.android;
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.message,
          enableVibration: true,
          enableLights: true,
          ledColor: const Color(0xFFFF7A1A),
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          styleInformation: BigTextStyleInformation(
            notification.body ?? '',
            contentTitle: notification.title,
            htmlFormatContent: false,
            htmlFormatContentTitle: false,
          ),
          icon: android?.smallIcon ?? '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    // الإشعار يُعرض — يمكن لاحقاً إضافة navigation هنا حسب message.data
  }

  Future<void> _registerTokenWithBackend(String token) async {
    try {
      await _dio.post<void>(
        '/api/customer/push-token',
        data: {'token': token, 'platform': defaultTargetPlatform.name},
      );
    } catch (_) {
      // Token registration is best-effort; failures are non-fatal.
    }
  }

  Future<void> requestPermission() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }
}
