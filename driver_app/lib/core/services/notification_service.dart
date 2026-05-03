import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return const NotificationService();
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

class NotificationService {
  const NotificationService();

  Future<void> initialize() async {
    // TODO(driver-app): Wire Firebase Cloud Messaging after native
    // configuration (google-services.json / GoogleService-Info.plist)
    // is available for the driver project.
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
