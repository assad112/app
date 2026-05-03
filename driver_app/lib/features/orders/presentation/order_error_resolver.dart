import 'package:dio/dio.dart';
import 'package:driver_app/core/localization/app_strings.dart';

String resolveDriverOrderErrorMessage(Object error, AppStrings strings) {
  if (isOrderNotAvailableForDriverError(error)) {
    return strings.orderNoLongerAssignedMessage;
  }

  final backendMessage = _extractBackendMessage(error);
  if (backendMessage != null && backendMessage.isNotEmpty) {
    return backendMessage;
  }

  return error.toString();
}

bool isOrderNotAvailableForDriverError(Object error) {
  if (error is! DioException) {
    return false;
  }

  final statusCode = error.response?.statusCode;
  final backendMessage = _extractBackendMessage(error)?.toLowerCase();

  return statusCode == 404 &&
      backendMessage != null &&
      backendMessage.contains('order not found for this driver');
}

String? _extractBackendMessage(Object error) {
  if (error is! DioException) {
    return null;
  }

  final responseData = error.response?.data;
  if (responseData is Map) {
    final message = responseData['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
  }

  final message = error.message;
  if (message == null || message.trim().isEmpty) {
    return null;
  }

  return message.trim();
}
