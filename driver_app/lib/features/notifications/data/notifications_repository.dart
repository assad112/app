import 'package:dio/dio.dart';
import 'package:driver_app/core/network/api_client.dart';
import 'package:driver_app/shared/models/driver_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(ref.watch(apiClientProvider));
});

class NotificationsRepository {
  const NotificationsRepository(this._dio);

  final Dio _dio;

  Future<List<DriverNotificationItem>> fetchNotifications() async {
    final response = await _dio.get<List<dynamic>>('/driver/notifications');
    return (response.data ?? const [])
        .map(
          (item) => DriverNotificationItem.fromBackend(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }
}
