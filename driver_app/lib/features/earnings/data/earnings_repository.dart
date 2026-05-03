import 'package:dio/dio.dart';
import 'package:driver_app/core/network/api_client.dart';
import 'package:driver_app/shared/models/earnings_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final earningsRepositoryProvider = Provider<EarningsRepository>((ref) {
  return EarningsRepository(ref.watch(apiClientProvider));
});

class EarningsRepository {
  const EarningsRepository(this._dio);

  final Dio _dio;

  Future<EarningsSummary> fetchSummary() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/driver/earnings/summary',
    );
    return EarningsSummary.fromJson(response.data ?? const {});
  }
}
