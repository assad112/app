import 'package:customer_app/shared/models/user_profile.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(apiClientProvider));
});

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final UserProfile user;
}

class AuthRequestResult {
  const AuthRequestResult.success(this.data)
    : errorMessage = null,
      isSuccess = true;

  const AuthRequestResult.failure(this.errorMessage)
    : data = null,
      isSuccess = false;

  final AuthResult? data;
  final String? errorMessage;
  final bool isSuccess;
}

class AuthService {
  const AuthService(this._dio);

  final Dio _dio;

  Future<AuthRequestResult> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/register',
        data: {
          'fullName': fullName,
          'phone': phone,
          'email': email,
          'password': password,
        },
      );

      final result = _mapAuthResult(response.data);
      if (result == null) {
        return const AuthRequestResult.failure(
          'Unable to complete registration right now.',
        );
      }

      return AuthRequestResult.success(result);
    } on DioException catch (error) {
      return AuthRequestResult.failure(_extractErrorMessage(error));
    } catch (_) {
      return const AuthRequestResult.failure(
        'Unable to complete registration right now.',
      );
    }
  }

  Future<AuthRequestResult> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {'identifier': identifier, 'password': password},
      );

      final result = _mapAuthResult(response.data);
      if (result == null) {
        return const AuthRequestResult.failure('Invalid login credentials.');
      }

      return AuthRequestResult.success(result);
    } on DioException catch (error) {
      return AuthRequestResult.failure(_extractErrorMessage(error));
    } catch (_) {
      return const AuthRequestResult.failure('Unable to sign in right now.');
    }
  }

  Future<UserProfile?> me(String token) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final userJson = response.data?['user'] as Map<String, dynamic>?;
      if (userJson == null) {
        return null;
      }

      return UserProfile.fromJson(userJson);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout(String token) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/auth/logout',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {
      // Intentionally ignored. Local session will still be cleared.
    }
  }

  AuthResult? _mapAuthResult(Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }

    final token = data['token']?.toString();
    final userJson = data['user'] as Map<String, dynamic>?;

    if (token == null || token.isEmpty || userJson == null) {
      return null;
    }

    return AuthResult(token: token, user: UserProfile.fromJson(userJson));
  }

  String _extractErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'تعذّر الاتصال بالخادم. تحقق من اتصالك بالإنترنت وحاول مجدداً.';
      case DioExceptionType.connectionError:
        return 'تعذّر الوصول إلى الخادم. تحقق من اتصالك بالإنترنت.';
      default:
        break;
    }

    final responseData = error.response?.data;
    if (responseData is Map) {
      final message = responseData['message'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString().trim();
      }
    }

    return 'تعذّر إتمام الطلب في الوقت الحالي. حاول مجدداً.';
  }
}
