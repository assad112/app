import 'package:dio/dio.dart';
import 'package:driver_app/core/network/api_client.dart';
import 'package:driver_app/shared/models/delivery_order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.watch(apiClientProvider));
});

class OrdersRepository {
  const OrdersRepository(this._dio);

  final Dio _dio;

  Future<List<DeliveryOrder>> fetchAvailableOrders({String? search}) async {
    final response = await _dio.get<List<dynamic>>(
      '/driver/orders/available',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );

    return (response.data ?? const [])
        .map(
          (item) =>
              DeliveryOrder.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<List<DeliveryOrder>> fetchActiveOrders() async {
    final response = await _dio.get<List<dynamic>>(
      '/driver/orders/active',
      queryParameters: const {'includeTracking': false},
    );

    return (response.data ?? const [])
        .map(
          (item) =>
              DeliveryOrder.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<List<DeliveryOrder>> fetchHistory({String? search}) async {
    final response = await _dio.get<List<dynamic>>(
      '/driver/orders/history',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );

    return (response.data ?? const [])
        .map(
          (item) =>
              DeliveryOrder.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<DeliveryOrder> fetchOrderDetails(String orderId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/driver/orders/$orderId',
    );
    return DeliveryOrder.fromJson(response.data ?? const {});
  }

  Future<DeliveryOrder> acceptOrder(String orderId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/driver/orders/$orderId/accept',
    );
    return DeliveryOrder.fromJson(response.data ?? const {});
  }

  Future<void> rejectOrder(String orderId, {String? reason}) async {
    await _dio.post(
      '/driver/orders/$orderId/reject',
      data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  Future<DeliveryOrder> updateOrderStage({
    required String orderId,
    required String stage,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/driver/orders/$orderId/stage',
      data: {'stage': stage},
    );
    return DeliveryOrder.fromJson(response.data ?? const {});
  }

  Future<void> updateDriverLocation({
    required double latitude,
    required double longitude,
    String? orderId,
    String? currentLocation,
  }) async {
    await _dio.patch(
      '/driver/location',
      data: {
        'latitude': latitude,
        'longitude': longitude,
        if (orderId != null && orderId.isNotEmpty) ...{
          'orderId': orderId,
          'currentOrderId': orderId,
        },
        if (currentLocation != null && currentLocation.isNotEmpty)
          'currentLocation': currentLocation,
      },
    );
  }
}
