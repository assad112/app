import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'driver_foreground_task.dart';

class DriverForegroundService {
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'ogas_driver_location',
        channelName: 'OGas Driver Location',
        channelDescription: 'يبقي تطبيق السائق نشطاً أثناء العمل',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );
  }

  static Future<void> start() async {
    try {
      final isRunning = await FlutterForegroundTask.isRunningService;
      if (isRunning) return;

      await FlutterForegroundTask.startService(
        serviceId: 300,
        notificationTitle: 'أنت متاح للاستلام',
        notificationText: 'يمكنك استلام الطلبات الآن',
        callback: driverLocationTaskCallback,
      );
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      final isRunning = await FlutterForegroundTask.isRunningService;
      if (!isRunning) return;
      await FlutterForegroundTask.stopService();
    } catch (_) {}
  }
}
