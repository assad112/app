import 'package:dio/dio.dart';
import 'package:driver_app/core/network/api_client.dart';
import 'package:driver_app/shared/models/driver_dashboard_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(apiClientProvider));
});

class HomeRepository {
  const HomeRepository(this._dio);

  final Dio _dio;

  Future<DriverDashboardData> fetchDashboard() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/driver/dashboard',
      queryParameters: const {'includeTracking': false},
    );
    return DriverDashboardData.fromJson(response.data ?? const {});
  }
}
