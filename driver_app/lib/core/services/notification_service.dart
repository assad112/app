import 'package:driver_app/core/network/api_client.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(apiClientProvider));
});

enum NotificationPermissionStatus {
  granted,
  denied,
  deniedForever,
  unsupported,
}

class NotificationPermissionResult {
  const NotificationPermissionResult(this.status);

  final NotificationPermissionStatus status;

  bool get isGranted =>
      status == NotificationPermissionStatus.granted ||
      status == NotificationPermissionStatus.unsupported;
}

const _channelId = 'ogas_driver_channel';
const _channelName = 'OGas Driver Notifications';
const _channelDesc = 'طلبات التوصيل وتحديثات السائق';

const _newOrderChannelId = 'ogas_driver_new_orders_v2';
const _newOrderChannelName = 'طلبات توصيل جديدة';
const _newOrderChannelDesc = 'تنبيهات عاجلة عند وصول طلب توصيل جديد';

class NotificationService {
  NotificationService(this._dio);

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

  static const AndroidNotificationChannel _newOrderChannel =
      AndroidNotificationChannel(
        _newOrderChannelId,
        _newOrderChannelName,
        description: _newOrderChannelDesc,
        importance: Importance.max,
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

    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(_androidChannel);
    await androidImpl?.createNotificationChannel(_newOrderChannel);
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
          category: AndroidNotificationCategory.call,
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

  Future<void> showNewOrderAlert({
    required String title,
    required String body,
    int? notificationId,
  }) async {
    debugPrint('[NotificationService] showNewOrderAlert: $title — $body');
    try {
      await _localNotifications.show(
      notificationId ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _newOrderChannelId,
          _newOrderChannelName,
          channelDescription: _newOrderChannelDesc,
          importance: Importance.max,
          priority: Priority.max,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.call,
          enableVibration: true,
          enableLights: true,
          ledColor: const Color(0xFFFF7A1A),
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            htmlFormatContent: false,
            htmlFormatContentTitle: false,
          ),
          icon: '@mipmap/ic_launcher',
          ticker: title,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
      debugPrint('[NotificationService] showNewOrderAlert: dispatched OK');
    } catch (error, stack) {
      debugPrint('[NotificationService] showNewOrderAlert FAILED: $error');
      debugPrint('$stack');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    // الإشعار يُعرض — يمكن لاحقاً إضافة navigation هنا حسب message.data
  }

  Future<void> _registerTokenWithBackend(String token) async {
    try {
      await _dio.post<void>(
        '/api/driver/push-token',
        data: {'token': token, 'platform': defaultTargetPlatform.name},
      );
    } catch (_) {
      // Token registration is best-effort; failures are non-fatal.
    }
  }

  Future<NotificationPermissionResult> requestPermissionIfNeeded() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return const NotificationPermissionResult(
        NotificationPermissionStatus.unsupported,
      );
    }

    var status = await Permission.notification.status;

    if (status.isGranted || status.isLimited || status.isProvisional) {
      return const NotificationPermissionResult(
        NotificationPermissionStatus.granted,
      );
    }

    if (status.isPermanentlyDenied) {
      return const NotificationPermissionResult(
        NotificationPermissionStatus.deniedForever,
      );
    }

    status = await Permission.notification.request();

    if (status.isGranted || status.isLimited || status.isProvisional) {
      await FirebaseMessaging.instance.requestPermission();
      return const NotificationPermissionResult(
        NotificationPermissionStatus.granted,
      );
    }

    if (status.isPermanentlyDenied) {
      return const NotificationPermissionResult(
        NotificationPermissionStatus.deniedForever,
      );
    }

    return const NotificationPermissionResult(
      NotificationPermissionStatus.denied,
    );
  }

  Future<bool> openAppSettings() {
    return permission_handler.openAppSettings();
  }
}
