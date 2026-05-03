import 'package:customer_app/shared/models/delivery_route.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

typedef CustomerRouteQuery = ({
  double? fromLat,
  double? fromLng,
  double? toLat,
  double? toLng,
});

final customerRouteServiceProvider = Provider<CustomerRouteService>((ref) {
  return CustomerRouteService(ref.watch(apiClientProvider));
});

final customerRouteProvider = FutureProvider.autoDispose
    .family<DeliveryRoute?, CustomerRouteQuery>((ref, query) async {
      if (query.fromLat == null ||
          query.fromLng == null ||
          query.toLat == null ||
          query.toLng == null) {
        return null;
      }

      return ref
          .read(customerRouteServiceProvider)
          .fetchRoute(
            fromLat: query.fromLat!,
            fromLng: query.fromLng!,
            toLat: query.toLat!,
            toLng: query.toLng!,
          );
    });

class CustomerRouteService {
  const CustomerRouteService(this._dio);

  final Dio _dio;

  Future<DeliveryRoute?> fetchRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/routes',
        queryParameters: {
          'fromLat': fromLat,
          'fromLng': fromLng,
          'toLat': toLat,
          'toLng': toLng,
        },
      );

      final data = response.data;
      if (data == null) {
        return null;
      }

      return DeliveryRoute.fromJson(data);
    } on DioException {
      return null;
    }
  }
}
