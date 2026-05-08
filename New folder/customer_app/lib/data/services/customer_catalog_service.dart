import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'session_storage_service.dart';

final customerCatalogServiceProvider = Provider<CustomerCatalogService>((ref) {
  return CustomerCatalogService(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageServiceProvider),
  );
});

class RemoteCatalogSnapshot {
  const RemoteCatalogSnapshot({
    required this.products,
    required this.zones,
    required this.settings,
  });

  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> zones;
  final Map<String, dynamic>? settings;
}

class CustomerCatalogService {
  const CustomerCatalogService(this._dio, this._storage);

  final Dio _dio;
  final SessionStorageService _storage;

  Future<RemoteCatalogSnapshot?> fetchCatalogSnapshot() async {
    final authToken = await _storage.readAuthToken();
    final headers = authToken == null || authToken.isEmpty
        ? const <String, String>{}
        : <String, String>{'Authorization': 'Bearer $authToken'};

    try {
      final responses = await Future.wait([
        _dio.get<List<dynamic>>(
          '/api/products',
          options: Options(headers: headers),
        ),
        _dio.get<List<dynamic>>(
          '/api/zones',
          options: Options(headers: headers),
        ),
        _dio.get<Map<String, dynamic>>(
          '/api/settings',
          options: Options(headers: headers),
        ),
      ]);

      return RemoteCatalogSnapshot(
        products: _toMapList(responses[0].data),
        zones: _toMapList(responses[1].data),
        settings: _toMap(responses[2].data),
      );
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _toMapList(dynamic input) {
    if (input is! List) {
      return const [];
    }

    return input
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);
  }

  Map<String, dynamic>? _toMap(dynamic input) {
    if (input is Map<String, dynamic>) {
      return input;
    }

    if (input is Map) {
      return input.map((key, value) => MapEntry('$key', value));
    }

    return null;
  }
}
