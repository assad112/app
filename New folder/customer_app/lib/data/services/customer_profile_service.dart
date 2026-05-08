import 'package:customer_app/shared/models/address_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'session_storage_service.dart';

final customerProfileServiceProvider = Provider<CustomerProfileService>((ref) {
  return CustomerProfileService(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageServiceProvider),
  );
});

class CustomerProfileService {
  const CustomerProfileService(this._dio, this._storage);

  final Dio _dio;
  final SessionStorageService _storage;

  Future<bool> saveDefaultAddress(AddressModel address) async {
    final authToken = await _storage.readAuthToken();
    if (authToken == null || authToken.isEmpty) {
      return false;
    }

    final payload = _addressPayload(address);
    final options = Options(headers: {'Authorization': 'Bearer $authToken'});

    for (final request in [
      () => _dio.post<Map<String, dynamic>>(
        '/api/customer/addresses',
        data: payload,
        options: options,
      ),
      () => _dio.put<Map<String, dynamic>>(
        '/api/customer/addresses/${address.id}',
        data: payload,
        options: options,
      ),
      () => _dio.put<Map<String, dynamic>>(
        '/api/customer/profile',
        data: {
          'defaultAddressId': address.id,
          'defaultAddress': payload,
          'address': payload,
          'location': payload['location'],
          'latitude': address.latitude,
          'longitude': address.longitude,
        },
        options: options,
      ),
    ]) {
      try {
        await request();
        return true;
      } on DioException catch (error) {
        final statusCode = error.response?.statusCode ?? 0;
        if (statusCode != 404 && statusCode != 405 && statusCode != 409) {
          return false;
        }
      } catch (_) {
        return false;
      }
    }

    return false;
  }

  Map<String, dynamic> _addressPayload(AddressModel address) {
    final compactAddress = address.compactAddress.isNotEmpty
        ? address.compactAddress
        : address.fullAddress;

    return {
      'id': address.id,
      'label': address.label,
      'governorate': address.governorate,
      'wilayat': address.wilayat,
      'area': address.area,
      'street': address.street,
      'houseNumber': address.houseNumber,
      'landmark': address.landmark,
      'latitude': address.latitude,
      'longitude': address.longitude,
      'isDefault': true,
      'location': compactAddress,
      'addressText': compactAddress,
      'addressFull': address.fullAddress,
      'customerLocation': {
        'latitude': address.latitude,
        'longitude': address.longitude,
        'addressText': compactAddress,
        'addressFull': address.fullAddress,
      },
    };
  }
}
