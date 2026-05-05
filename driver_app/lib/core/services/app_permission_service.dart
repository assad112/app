import 'package:driver_app/core/services/location_service.dart';
import 'package:driver_app/core/services/notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appPermissionServiceProvider = Provider<AppPermissionService>((ref) {
  return AppPermissionService(ref);
});

class AppPermissionService {
  const AppPermissionService(this._ref);

  final Ref _ref;

  Future<void> requestImportantPermissions() async {
    final locationService = _ref.read(locationServiceProvider);
    final notificationService = _ref.read(notificationServiceProvider);

    try {
      await locationService.ensurePermission();
    } catch (_) {
      // Permission prompts should never crash app startup.
    }

    try {
      await notificationService.requestPermissionIfNeeded();
    } catch (_) {
      // Keep app startup resilient even if notification permissions fail.
    }
  }
}
