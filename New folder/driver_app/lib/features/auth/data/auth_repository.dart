import 'package:dio/dio.dart';
import 'package:driver_app/shared/models/driver_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driver_app/core/network/api_client.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

class AuthResult {
  const AuthResult({required this.token, required this.driver});

  final String token;
  final DriverProfile driver;
}

class AuthRepository {
  const AuthRepository(this._dio);

  final Dio _dio;

  Future<AuthResult> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/driver-auth/login',
      data: {'identifier': identifier, 'password': password},
    );

    return _mapAuthResult(response.data ?? const {});
  }

  Future<DriverProfile> fetchCurrentDriver() async {
    final response = await _dio.get<Map<String, dynamic>>('/driver-auth/me');
    final driver = Map<String, dynamic>.from(
      response.data?['driver'] as Map? ?? const {},
    );
    return DriverProfile.fromJson(driver);
  }

  Future<void> logout() async {
    await _dio.post('/driver-auth/logout');
  }

  AuthResult _mapAuthResult(Map<String, dynamic> json) {
    return AuthResult(
      token: (json['token'] ?? '').toString(),
      driver: DriverProfile.fromJson(
        Map<String, dynamic>.from(json['driver'] as Map? ?? const {}),
      ),
    );
  }
}
