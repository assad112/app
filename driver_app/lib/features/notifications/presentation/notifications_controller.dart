import 'package:driver_app/features/notifications/data/notifications_repository.dart';
import 'package:driver_app/shared/models/driver_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationsControllerProvider =
    AsyncNotifierProvider<
      NotificationsController,
      List<DriverNotificationItem>
    >(NotificationsController.new);

class NotificationsController
    extends AsyncNotifier<List<DriverNotificationItem>> {
  @override
  Future<List<DriverNotificationItem>> build() async {
    final notifications = await ref
        .read(notificationsRepositoryProvider)
        .fetchNotifications();
    return _normalize(notifications);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final notifications = await ref
          .read(notificationsRepositoryProvider)
          .fetchNotifications();
      return _normalize(notifications);
    });
  }

  Future<void> refreshSilently() async {
    try {
      final notifications = await ref
          .read(notificationsRepositoryProvider)
          .fetchNotifications();
      state = AsyncData(_normalize(notifications));
    } catch (_) {
      // Preserve the current list on silent failures.
    }
  }

  void prepend(DriverNotificationItem item) {
    final current = state.valueOrNull ?? const <DriverNotificationItem>[];
    state = AsyncData(_normalize([item, ...current]));
  }

  List<DriverNotificationItem> _normalize(
    List<DriverNotificationItem> notifications,
  ) {
    final byKey = <String, DriverNotificationItem>{};

    for (final item in notifications) {
      final existing = byKey[item.dedupeKey];
      if (existing == null || item.timestamp.isAfter(existing.timestamp)) {
        byKey[item.dedupeKey] = item;
      }
    }

    final result = byKey.values.toList();
    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }
}
