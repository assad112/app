import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'backend_endpoints.dart';

typedef SocketPayloadHandler = void Function(Map<String, dynamic> payload);

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(service.dispose);
  return service;
});

class SocketService {
  io.Socket? _socket;
  String? _customerId;
  String? _authToken;
  int _activeBaseUrlIndex = 0;
  List<String> _candidateBaseUrls = socketCandidateBaseUrls;
  SocketPayloadHandler? _onOrderStatusChanged;
  SocketPayloadHandler? _onDriverLocationUpdated;
  SocketPayloadHandler? _onProductUpdated;
  SocketPayloadHandler? _onZoneUpdated;
  SocketPayloadHandler? _onSettingsUpdated;
  SocketPayloadHandler? _onNotification;

  bool get isConnected => _socket?.connected ?? false;

  void connect({
    required String customerId,
    String? authToken,
    required SocketPayloadHandler onOrderStatusChanged,
    required SocketPayloadHandler onDriverLocationUpdated,
    SocketPayloadHandler? onProductUpdated,
    SocketPayloadHandler? onZoneUpdated,
    SocketPayloadHandler? onSettingsUpdated,
    SocketPayloadHandler? onNotification,
  }) {
    final shouldRecreate =
        _socket == null || _customerId != customerId || _authToken != authToken;

    _onOrderStatusChanged = onOrderStatusChanged;
    _onDriverLocationUpdated = onDriverLocationUpdated;
    _onProductUpdated = onProductUpdated;
    _onZoneUpdated = onZoneUpdated;
    _onSettingsUpdated = onSettingsUpdated;
    _onNotification = onNotification;

    if (shouldRecreate) {
      _disposeSocket();

      _customerId = customerId;
      _authToken = authToken;
      _candidateBaseUrls = socketCandidateBaseUrls;
      _activeBaseUrlIndex = 0;
      _createSocket();
    }

    _bindCurrentHandlers();

    if (!(_socket?.connected ?? false)) {
      _socket?.connect();
    } else {
      _announceSubscriptions();
    }
  }

  void _createSocket() {
    final customerId = _customerId;
    if (customerId == null || customerId.isEmpty) {
      return;
    }

    final authToken = _authToken;
    final socketBaseUrl = _candidateBaseUrls[_activeBaseUrlIndex];

    _socket = io.io(
      socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(12)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setTimeout(5000)
          .setQuery({'customerId': customerId})
          .setAuth({
            'customerId': customerId,
            if (authToken != null && authToken.isNotEmpty) 'token': authToken,
          })
          .setExtraHeaders({
            if (authToken != null && authToken.isNotEmpty)
              'Authorization': 'Bearer $authToken',
          })
          .build(),
    );

    _socket?.on('connect', (_) => _announceSubscriptions());
    _socket?.on('reconnect', (_) => _announceSubscriptions());
    _socket?.on('connect_error', _handleConnectionFailure);
  }

  void _bindCurrentHandlers() {
    final orderStatusChangedHandler = _onOrderStatusChanged;
    final driverLocationUpdatedHandler = _onDriverLocationUpdated;
    if (orderStatusChangedHandler == null ||
        driverLocationUpdatedHandler == null) {
      return;
    }

    _bindPayloadHandler('order_status_changed', orderStatusChangedHandler);
    _bindPayloadHandler(
      'driver_location_updated',
      driverLocationUpdatedHandler,
    );
    _bindPayloadHandler('order_tracking_updated', driverLocationUpdatedHandler);
    _bindPayloadHandler(
      'new_order',
      _onNotification ?? orderStatusChangedHandler,
    );
    _bindPayloadHandler(
      'order_updated',
      _onNotification ?? orderStatusChangedHandler,
    );

    if (_onProductUpdated != null) {
      _bindPayloadHandler('product_updated', _onProductUpdated!);
    } else {
      _socket?.off('product_updated');
    }

    if (_onZoneUpdated != null) {
      _bindPayloadHandler('zone_updated', _onZoneUpdated!);
    } else {
      _socket?.off('zone_updated');
    }

    if (_onSettingsUpdated != null) {
      _bindPayloadHandler('settings_updated', _onSettingsUpdated!);
    } else {
      _socket?.off('settings_updated');
    }

    if (_onNotification != null) {
      _bindPayloadHandler('new_notification', _onNotification!);
    } else {
      _socket?.off('new_notification');
    }
  }

  void disconnect() {
    _disposeSocket(resetSession: true);
  }

  void _disposeSocket({bool resetSession = false}) {
    _socket?.off('connect');
    _socket?.off('reconnect');
    _socket?.off('connect_error');
    _socket?.off('order_status_changed');
    _socket?.off('driver_location_updated');
    _socket?.off('order_tracking_updated');
    _socket?.off('new_order');
    _socket?.off('order_updated');
    _socket?.off('product_updated');
    _socket?.off('zone_updated');
    _socket?.off('settings_updated');
    _socket?.off('new_notification');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    if (!resetSession) {
      return;
    }

    _customerId = null;
    _authToken = null;
    _activeBaseUrlIndex = 0;
    _candidateBaseUrls = socketCandidateBaseUrls;
    _onOrderStatusChanged = null;
    _onDriverLocationUpdated = null;
    _onProductUpdated = null;
    _onZoneUpdated = null;
    _onSettingsUpdated = null;
    _onNotification = null;
  }

  void _handleConnectionFailure(dynamic _) {
    if (_socket?.connected ?? false) {
      return;
    }

    if (_activeBaseUrlIndex + 1 >= _candidateBaseUrls.length) {
      return;
    }

    _activeBaseUrlIndex += 1;
    _disposeSocket();
    _createSocket();
    _bindCurrentHandlers();
    _socket?.connect();
  }

  void _announceSubscriptions() {
    final customerId = _customerId;
    if (customerId == null || customerId.isEmpty) {
      return;
    }

    final payload = <String, dynamic>{
      'customerId': customerId,
      if (_authToken != null && _authToken!.isNotEmpty) 'token': _authToken,
    };

    _socket?.emit('join_customer_room', payload);
    _socket?.emit('subscribe_orders', payload);
  }

  void _bindPayloadHandler(String event, SocketPayloadHandler handler) {
    _socket?.off(event);
    _socket?.on(event, (dynamic data) {
      final payload = _asMap(data);
      if (payload == null) {
        return;
      }

      handler(payload);
    });
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }

    if (data is List && data.isNotEmpty) {
      return _asMap(data.first);
    }

    return null;
  }

  void dispose() {
    disconnect();
  }
}
