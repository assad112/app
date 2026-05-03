import 'package:dio/dio.dart';
import 'package:driver_app/core/network/api_client.dart';
import 'package:driver_app/shared/models/driver_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

class ProfileRepository {
  const ProfileRepository(this._dio);

  final Dio _dio;

  Future<DriverProfile> fetchProfile() async {
    final response = await _dio.get<Map<String, dynamic>>('/driver/profile');
    final payload = Map<String, dynamic>.from(
      response.data?['driver'] as Map? ?? const {},
    );
    return DriverProfile.fromJson(payload);
  }

  Future<DriverProfile> updateAvailability({
    required String status,
    required String availability,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/driver/availability',
      data: {'status': status, 'availability': availability},
    );
    final payload = Map<String, dynamic>.from(
      response.data?['driver'] as Map? ?? const {},
    );
    return DriverProfile.fromJson(payload);
  }

  Future<DriverProfile> updateInventory({
    required List<String> availableCylinderSizes,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/driver/inventory',
      data: {'availableCylinderSizes': availableCylinderSizes},
    );
    final payload = Map<String, dynamic>.from(
      response.data?['driver'] as Map? ?? const {},
    );
    return DriverProfile.fromJson(payload);
  }
}
