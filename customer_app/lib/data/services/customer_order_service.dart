import 'package:customer_app/shared/models/address_model.dart';
import 'package:customer_app/shared/models/gas_product.dart';
import 'package:customer_app/shared/models/order_status.dart';
import 'package:customer_app/shared/models/payment_method.dart';
import 'package:customer_app/shared/models/user_profile.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/backend_endpoints.dart';
import 'session_storage_service.dart';

final customerOrderServiceProvider = Provider<CustomerOrderService>((ref) {
  return CustomerOrderService(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageServiceProvider),
  );
});

class RemoteOrderReceipt {
  const RemoteOrderReceipt({
    required this.orderId,
    required this.status,
    required this.createdAt,
  });

  final String orderId;
  final OrderStatus status;
  final DateTime createdAt;
}

class RemoteOrderSubmissionException implements Exception {
  const RemoteOrderSubmissionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BundledRemoteOrderItem {
  const BundledRemoteOrderItem({
    required this.productId,
    required this.quantity,
  });

  final String productId;
  final int quantity;
}

class CustomerOrderService {
  const CustomerOrderService(this._dio, this._storage);

  final Dio _dio;
  final SessionStorageService _storage;

  Future<List<Map<String, dynamic>>?> fetchMyOrders() async {
    try {
      final authToken = await _storage.readAuthToken();
      if (authToken == null || authToken.isEmpty) {
        return null;
      }
      final response = await _dio.get<List<dynamic>>(
        '/api/orders',
        queryParameters: const {'mine': 'true'},
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
      );

      final list = response.data;
      if (list == null) {
        return const <Map<String, dynamic>>[];
      }

      return list
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  Future<RemoteOrderReceipt> submitOrder({
    required UserProfile customer,
    required AddressModel address,
    required GasProduct product,
    required int quantity,
    required String notes,
    required PaymentMethod paymentMethod,
    String? preferredDeliveryWindow,
    double? totalAmount,
  }) async {
    final authToken = await _storage.readAuthToken();
    final compactAddress = address.compactAddress.isNotEmpty
        ? address.compactAddress
        : address.fullAddress;
    final requestData = <String, dynamic>{
      'customerId': customer.id,
      'productId': int.tryParse(product.id),
      'gasType': '${product.nameAr} - ${product.sizeLabel}',
      'quantity': quantity,
      'location': compactAddress,
      'addressText': compactAddress,
      'addressFull': address.fullAddress,
      'notes': notes.trim(),
      'paymentMethod': _mapPaymentMethod(paymentMethod),
      'latitude': address.latitude,
      'longitude': address.longitude,
      'customerLatitude': address.latitude,
      'customerLongitude': address.longitude,
      'customerLocation': {
        'latitude': address.latitude,
        'longitude': address.longitude,
        'addressText': compactAddress,
        'addressFull': address.fullAddress,
      },
    };
    final deliveryWindow = preferredDeliveryWindow?.trim();

    if (deliveryWindow != null && deliveryWindow.isNotEmpty) {
      requestData['preferredDeliveryWindow'] = deliveryWindow;
    }

    if (totalAmount != null) {
      requestData['totalAmount'] = totalAmount;
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/orders',
        data: requestData,
        options: Options(
          headers: {
            if (authToken != null) 'Authorization': 'Bearer $authToken',
          },
        ),
      );

      final data = response.data;
      final order = data?['order'] as Map<String, dynamic>?;

      if (data == null || order == null) {
        throw const RemoteOrderSubmissionException(
          'Unable to read order creation response.',
        );
      }

      return RemoteOrderReceipt(
        orderId:
            order['orderId']?.toString() ??
            order['order_id']?.toString() ??
            'ORD-${order['id']}',
        status: _mapStatus(
          (order['publicStatus'] ??
                  order['public_status'] ??
                  order['driverStage'] ??
                  order['driver_stage'] ??
                  order['status'])
              ?.toString(),
        ),
        createdAt:
            DateTime.tryParse(order['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
    } on DioException catch (error) {
      throw RemoteOrderSubmissionException(_extractErrorMessage(error));
    }
  }

  Future<RemoteOrderReceipt> submitBundledOrder({
    required UserProfile customer,
    required AddressModel address,
    required List<BundledRemoteOrderItem> items,
    required String gasType,
    required int quantity,
    required String notes,
    required PaymentMethod paymentMethod,
    String? preferredDeliveryWindow,
    double? totalAmount,
  }) async {
    final authToken = await _storage.readAuthToken();
    final compactAddress = address.compactAddress.isNotEmpty
        ? address.compactAddress
        : address.fullAddress;
    final requestData = <String, dynamic>{
      'customerId': customer.id,
      'items': items
          .map(
            (item) => {
              'productId': int.tryParse(item.productId),
              'quantity': item.quantity,
            },
          )
          .where((item) => item['productId'] != null)
          .toList(growable: false),
      'gasType': gasType.trim(),
      'quantity': quantity,
      'location': compactAddress,
      'addressText': compactAddress,
      'addressFull': address.fullAddress,
      'notes': notes.trim(),
      'paymentMethod': _mapPaymentMethod(paymentMethod),
      'latitude': address.latitude,
      'longitude': address.longitude,
      'customerLatitude': address.latitude,
      'customerLongitude': address.longitude,
      'customerLocation': {
        'latitude': address.latitude,
        'longitude': address.longitude,
        'addressText': compactAddress,
        'addressFull': address.fullAddress,
      },
    };
    final deliveryWindow = preferredDeliveryWindow?.trim();

    if (deliveryWindow != null && deliveryWindow.isNotEmpty) {
      requestData['preferredDeliveryWindow'] = deliveryWindow;
    }

    if (totalAmount != null) {
      requestData['totalAmount'] = totalAmount;
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/orders',
        data: requestData,
        options: Options(
          headers: {
            if (authToken != null) 'Authorization': 'Bearer $authToken',
          },
        ),
      );

      final data = response.data;
      final order = data?['order'] as Map<String, dynamic>?;

      if (data == null || order == null) {
        throw const RemoteOrderSubmissionException(
          'Unable to read order creation response.',
        );
      }

      return RemoteOrderReceipt(
        orderId:
            order['orderId']?.toString() ??
            order['order_id']?.toString() ??
            'ORD-${order['id']}',
        status: _mapStatus(
          (order['publicStatus'] ??
                  order['public_status'] ??
                  order['driverStage'] ??
                  order['driver_stage'] ??
                  order['status'])
              ?.toString(),
        ),
        createdAt:
            DateTime.tryParse(order['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
    } on DioException catch (error) {
      throw RemoteOrderSubmissionException(_extractErrorMessage(error));
    }
  }

  Future<Map<String, dynamic>> updateOrderDeliveryLocation({
    required String orderId,
    required AddressModel address,
  }) async {
    final authToken = await _storage.readAuthToken();

    if (authToken == null || authToken.isEmpty) {
      throw const RemoteOrderSubmissionException(
        'Authentication token is required.',
      );
    }

    final compactAddress = address.compactAddress.isNotEmpty
        ? address.compactAddress
        : address.fullAddress;

    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/api/orders/${_resolveRemoteOrderId(orderId)}',
        data: {
          'location': compactAddress,
          'addressText': compactAddress,
          'addressFull': address.fullAddress,
          'latitude': address.latitude,
          'longitude': address.longitude,
          'customerLatitude': address.latitude,
          'customerLongitude': address.longitude,
          'customerLocation': {
            'latitude': address.latitude,
            'longitude': address.longitude,
            'addressText': compactAddress,
            'addressFull': address.fullAddress,
          },
        },
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
      );

      final data = response.data;
      if (data == null) {
        throw const RemoteOrderSubmissionException(
          'Unable to read order update response.',
        );
      }

      return data;
    } on DioException catch (error) {
      throw RemoteOrderSubmissionException(_extractErrorMessage(error));
    }
  }

  OrderStatus _mapStatus(String? status) {
    switch (status) {
      case 'searching_driver':
        return OrderStatus.searchingDriver;
      case 'driver_notified':
        return OrderStatus.driverNotified;
      case 'no_driver_found':
        return OrderStatus.noDriverFound;
      case 'accepted':
        return OrderStatus.accepted;
      case 'delivered':
        return OrderStatus.delivered;
      case 'pending':
      default:
        return OrderStatus.pendingReview;
    }
  }

  String _mapPaymentMethod(PaymentMethod paymentMethod) {
    switch (paymentMethod) {
      case PaymentMethod.digitalWallet:
        return 'digital_wallet';
      case PaymentMethod.cashOnDelivery:
        return 'cash_on_delivery';
    }
  }

  String _extractErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return _buildNetworkFailureMessage(error);
      case DioExceptionType.connectionError:
        return _buildNetworkFailureMessage(error);
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

    final rawMessage = error.message?.toLowerCase() ?? '';
    if (rawMessage.contains('failed host lookup') ||
        rawMessage.contains('connection refused') ||
        rawMessage.contains('connection terminated') ||
        rawMessage.contains('connection error') ||
        rawMessage.contains('socketexception')) {
      return _buildNetworkFailureMessage(error);
    }

    return 'تعذر إرسال الطلب في الوقت الحالي. حاول مجددًا.';
  }

  String _buildNetworkFailureMessage(DioException error) {
    final attemptedTargets = _extractAttemptedTargets(error);
    final attemptedTargetsText = attemptedTargets.join(', ');
    final requestPath = error.requestOptions.path;

    if (attemptedTargetsText.isEmpty) {
      return 'تعذر الوصول إلى خادم إنشاء الطلبات على $requestPath. تحقق من عنوان الخادم أو مرر --dart-define=API_BASE_URL=http://YOUR_SERVER:PORT و --dart-define=SOCKET_BASE_URL=http://YOUR_SERVER:PORT.';
    }

    return 'تعذر الوصول إلى خادم إنشاء الطلبات على $requestPath. تمت محاولة الإرسال إلى: $attemptedTargetsText. تحقق من عنوان الخادم أو مرر --dart-define=API_BASE_URL=http://YOUR_SERVER:PORT و --dart-define=SOCKET_BASE_URL=http://YOUR_SERVER:PORT.';
  }

  List<String> _extractAttemptedTargets(DioException error) {
    final attemptedBaseUrls = <String>[];

    void addBaseUrl(String? value) {
      final normalized = normalizeBaseUrl(value);
      if (normalized.isEmpty || attemptedBaseUrls.contains(normalized)) {
        return;
      }

      attemptedBaseUrls.add(normalized);
    }

    addBaseUrl(error.requestOptions.baseUrl);

    final storedAttemptedBaseUrls =
        error.requestOptions.extra['attemptedBaseUrls'] as List<dynamic>?;
    if (storedAttemptedBaseUrls != null) {
      for (final value in storedAttemptedBaseUrls) {
        addBaseUrl(value.toString());
      }
    }

    final requestPath = error.requestOptions.path;
    return attemptedBaseUrls
        .map((baseUrl) => '$baseUrl$requestPath')
        .toList(growable: false);
  }

  String _resolveRemoteOrderId(String orderId) {
    final trimmed = orderId.trim();
    if (trimmed.toUpperCase().startsWith('ORD-')) {
      return trimmed.substring(4);
    }

    return trimmed;
  }
}
