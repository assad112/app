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
const _channelDesc = 'Driver app updates and delivery alerts';

const _newOrderChannelId = 'ogas_driver_new_orders_v2';
const _newOrderChannelName = 'New Delivery Orders';
const _newOrderChannelDesc = 'Urgent notifications for newly assigned offers';

const _androidInitSettings = AndroidInitializationSettings(
  '@mipmap/ic_launcher',
);
const _iosInitSettings = DarwinInitializationSettings(
  requestAlertPermission: false,
  requestBadgePermission: false,
  requestSoundPermission: false,
);
const _localInitSettings = InitializationSettings(
  android: _androidInitSettings,
  iOS: _iosInitSettings,
);

class NotificationService {
  NotificationService(this._dio);

  final dynamic _dio;

  static bool _isInitialized = false;
  static bool _localNotificationsReady = false;

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
    if (_isInitialized) return;

    try {
      await _setupLocalNotifications().timeout(const Duration(seconds: 4));
      await _configureFCM().timeout(const Duration(seconds: 6));
      _isInitialized = true;
    } catch (error, stack) {
      debugPrint('[NotificationService] initialize skipped: $error');
      debugPrint('$stack');
    }
  }

  static Future<void> showBackgroundNotificationFromMessage(
    RemoteMessage message,
  ) async {
    // If the payload already contains a native notification, the OS can
    // display it in background by itself. We only synthesize notifications
    // for data-only payloads here to avoid duplicates.
    if (message.notification != null) {
      return;
    }

    final payload = Map<String, dynamic>.from(message.data);
    if (payload.isEmpty) {
      return;
    }

    await _ensureLocalNotificationsReady();

    final eventType =
        (payload['event'] ??
                payload['type'] ??
                payload['notification_type'] ??
                '')
            .toString()
            .trim();
    final isNewOrder =
        eventType == 'new_order' || eventType == 'driver_notified';
    final title = _buildBackgroundTitle(payload, isNewOrder);
    final body = _buildBackgroundBody(payload, isNewOrder);

    if (title.isEmpty && body.isEmpty) {
      return;
    }

    await _localNotifications.show(
      _notificationIdFromPayload(payload),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          isNewOrder ? _newOrderChannelId : _channelId,
          isNewOrder ? _newOrderChannelName : _channelName,
          channelDescription: isNewOrder ? _newOrderChannelDesc : _channelDesc,
          importance: isNewOrder ? Importance.max : Importance.high,
          priority: isNewOrder ? Priority.max : Priority.high,
          visibility: NotificationVisibility.public,
          category: isNewOrder
              ? AndroidNotificationCategory.call
              : AndroidNotificationCategory.message,
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
  }

  Future<void> _setupLocalNotifications() async {
    await _ensureLocalNotificationsReady();
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

    final initialMessage = await FirebaseMessaging.instance
        .getInitialMessage()
        .timeout(const Duration(seconds: 2), onTimeout: () => null);
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    final token = await FirebaseMessaging.instance.getToken().timeout(
      const Duration(seconds: 3),
      onTimeout: () => null,
    );
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
    debugPrint('[NotificationService] showNewOrderAlert: $title - $body');
    try {
      await _ensureLocalNotificationsReady();
      await _localNotifications.show(
        notificationId ??
            DateTime.now().millisecondsSinceEpoch.remainder(100000),
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
            largeIcon: const DrawableResourceAndroidBitmap(
              '@mipmap/ic_launcher',
            ),
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
    // Navigation can be added later based on message.data.
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

  static Future<void> _ensureLocalNotificationsReady() async {
    if (_localNotificationsReady) {
      return;
    }

    await _localNotifications.initialize(_localInitSettings);

    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(_androidChannel);
    await androidImpl?.createNotificationChannel(_newOrderChannel);
    _localNotificationsReady = true;
  }

  static String _buildBackgroundTitle(
    Map<String, dynamic> payload,
    bool isNewOrder,
  ) {
    final explicitTitle = (payload['title'] ?? payload['heading'] ?? '')
        .toString()
        .trim();
    if (explicitTitle.isNotEmpty) {
      return explicitTitle;
    }

    if (isNewOrder) {
      return 'طلب توصيل جديد!';
    }

    return 'تنبيه جديد';
  }

  static String _buildBackgroundBody(
    Map<String, dynamic> payload,
    bool isNewOrder,
  ) {
    final explicitBody = (payload['body'] ?? payload['message'] ?? '')
        .toString()
        .trim();
    if (explicitBody.isNotEmpty) {
      return explicitBody;
    }

    if (isNewOrder) {
      final gasType = (payload['gasType'] ?? payload['gas_type'] ?? '')
          .toString()
          .trim();
      final quantity = (payload['quantity'] ?? '1').toString().trim();
      final location =
          (payload['location'] ??
                  payload['addressFull'] ??
                  payload['address_full'] ??
                  '')
              .toString()
              .trim();
      final productText = gasType.isNotEmpty ? '$gasType x$quantity' : '';

      if (location.isNotEmpty && productText.isNotEmpty) {
        return '$productText - $location';
      }
      if (location.isNotEmpty) {
        return location;
      }
      if (productText.isNotEmpty) {
        return productText;
      }
    }

    return 'تم استلام تحديث جديد للسائق.';
  }

  static int _notificationIdFromPayload(Map<String, dynamic> payload) {
    final rawId = payload['id'] ?? payload['orderId'] ?? payload['order_id'];
    if (rawId != null) {
      return rawId.toString().hashCode;
    }

    return DateTime.now().millisecondsSinceEpoch.remainder(100000);
  }
}
