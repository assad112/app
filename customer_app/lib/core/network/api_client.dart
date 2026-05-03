import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend_endpoints.dart';

final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: defaultApiBaseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 12),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(_ConnectionFailoverInterceptor(dio));
  return dio;
});

class _ConnectionFailoverInterceptor extends Interceptor {
  _ConnectionFailoverInterceptor(this._dio);

  final Dio _dio;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final attemptedBaseUrls = _extractAttemptedBaseUrls(options);

    options.extra['attemptedBaseUrls'] = attemptedBaseUrls;
    options.extra['candidateBaseUrls'] = apiCandidateBaseUrls;

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldRetry(error)) {
      handler.next(error);
      return;
    }

    final attemptedBaseUrls = _extractAttemptedBaseUrls(error.requestOptions);

    DioException latestError = error;

    for (final candidateBaseUrl in apiCandidateBaseUrls) {
      if (attemptedBaseUrls.contains(candidateBaseUrl)) {
        continue;
      }

      try {
        final response = await _dio.fetch<dynamic>(
          error.requestOptions.copyWith(
            baseUrl: candidateBaseUrl,
            extra: {
              ...error.requestOptions.extra,
              'didConnectionFailover': true,
              'attemptedBaseUrls': [
                ...attemptedBaseUrls,
                if (!attemptedBaseUrls.contains(candidateBaseUrl))
                  candidateBaseUrl,
              ],
            },
          ),
        );

        handler.resolve(response);
        return;
      } on DioException catch (nextError) {
        latestError = nextError;
      }
    }

    handler.next(latestError);
  }

  bool _shouldRetry(DioException error) {
    if (error.requestOptions.extra['didConnectionFailover'] == true) {
      return false;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return true;
      default:
        final message = error.message?.toLowerCase() ?? '';
        return message.contains('failed host lookup') ||
            message.contains('connection refused') ||
            message.contains('socketexception');
    }
  }

  List<String> _extractAttemptedBaseUrls(RequestOptions options) {
    final attemptedBaseUrls = <String>[];

    void addBaseUrl(String? value) {
      final normalized = normalizeBaseUrl(value);
      if (normalized.isEmpty || attemptedBaseUrls.contains(normalized)) {
        return;
      }

      attemptedBaseUrls.add(normalized);
    }

    addBaseUrl(options.baseUrl);

    final storedAttemptedBaseUrls =
        options.extra['attemptedBaseUrls'] as List<dynamic>?;
    if (storedAttemptedBaseUrls != null) {
      for (final value in storedAttemptedBaseUrls) {
        addBaseUrl(value.toString());
      }
    }

    return attemptedBaseUrls;
  }
}
