import 'dart:async';

import 'package:driver_app/core/realtime/socket_service.dart';
import 'package:driver_app/features/auth/presentation/auth_controller.dart';
import 'package:driver_app/features/home/presentation/home_controller.dart';
import 'package:driver_app/features/notifications/presentation/notifications_controller.dart';
import 'package:driver_app/features/orders/presentation/orders_controller.dart';
import 'package:driver_app/features/profile/presentation/profile_controller.dart';
import 'package:driver_app/shared/models/delivery_order.dart';
import 'package:driver_app/shared/models/driver_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appRealtimeBindingsProvider = Provider<void>((ref) {
  final socketService = ref.watch(socketServiceProvider);
  Timer? driverRefreshDebounce;
  Timer? dashboardRefreshDebounce;

  bool isPendingOffer(DeliveryOrder order) {
    return order.status == 'pending' && order.driverStage == 'driver_notified';
  }

  void scheduleDriverRefresh() {
    driverRefreshDebounce?.cancel();
    driverRefreshDebounce = Timer(const Duration(milliseconds: 500), () async {
      await ref.read(authControllerProvider.notifier).refreshDriver();
      ref.invalidate(profileControllerProvider);
    });
  }

  void scheduleDashboardRefresh() {
    dashboardRefreshDebounce?.cancel();
    dashboardRefreshDebounce = Timer(
      const Duration(milliseconds: 700),
      () async {
        await ref.read(homeControllerProvider.notifier).refreshSilently();
      },
    );
  }

  final subscription = socketService.events.listen((event) {
    if (event.payload is! Map) {
      return;
    }

    final payload = Map<String, dynamic>.from(event.payload as Map);

    switch (event.name) {
      case 'new_order':
      case 'order_updated':
      case 'order_status_changed':
        final order = DeliveryOrder.fromJson(payload);
        ref.read(ordersControllerProvider.notifier).handleRealtime(order);
        scheduleDashboardRefresh();
        if (event.name == 'order_status_changed' && !isPendingOffer(order)) {
          ref
              .read(notificationsControllerProvider.notifier)
              .prepend(
                DriverNotificationItem.fromBackend({
                  ...payload,
                  'notification_type':
                      payload['driver_stage'] ?? payload['status'],
                }),
              );
        }
        break;
      case 'order_tracking_updated':
        final order = DeliveryOrder.fromJson(payload);
        ref.read(ordersControllerProvider.notifier).handleRealtime(order);
        scheduleDashboardRefresh();
        break;
      case 'driver_notification':
        ref
            .read(notificationsControllerProvider.notifier)
            .prepend(DriverNotificationItem.fromRealtime(payload));
        break;
      case 'driver_updated':
        scheduleDriverRefresh();
        scheduleDashboardRefresh();
        break;
      case 'driver_location_updated':
        // The tracking screen already owns the current position locally.
        // Avoid triggering extra profile/dashboard fetches for every location echo.
        break;
    }
  });

  ref.onDispose(() {
    driverRefreshDebounce?.cancel();
    dashboardRefreshDebounce?.cancel();
    subscription.cancel();
  });
});
