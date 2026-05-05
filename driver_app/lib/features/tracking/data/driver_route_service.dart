import 'package:dio/dio.dart';
import 'package:driver_app/core/network/api_client.dart';
import 'package:driver_app/shared/models/delivery_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef DriverRouteQuery = ({
  double? fromLat,
  double? fromLng,
  double? toLat,
  double? toLng,
});

final driverRouteServiceProvider = Provider<DriverRouteService>((ref) {
  return DriverRouteService(ref.watch(apiClientProvider));
});

final driverRouteProvider = FutureProvider.autoDispose
    .family<DeliveryRoute?, DriverRouteQuery>((ref, query) async {
      if (query.fromLat == null ||
          query.fromLng == null ||
          query.toLat == null ||
          query.toLng == null) {
        return null;
      }

      return ref
          .read(driverRouteServiceProvider)
          .fetchRoute(
            fromLat: query.fromLat!,
            fromLng: query.fromLng!,
            toLat: query.toLat!,
            toLng: query.toLng!,
          );
    });

class DriverRouteService {
  const DriverRouteService(this._dio);

  final Dio _dio;

  Future<DeliveryRoute?> fetchRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/routes',
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
