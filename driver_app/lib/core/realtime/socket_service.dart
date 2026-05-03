import 'dart:async';

import 'package:driver_app/config/environment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(service.dispose);
  return service;
});

class RealtimeEvent {
  const RealtimeEvent({required this.name, required this.payload});

  final String name;
  final dynamic payload;
}

class SocketService {
  final StreamController<RealtimeEvent> _eventsController =
      StreamController<RealtimeEvent>.broadcast();

  io.Socket? _socket;

  Stream<RealtimeEvent> get events => _eventsController.stream;

  void connect(String token) {
    disconnect();

    _socket = io.io(
      Environment.socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setReconnectionAttempts(20)
          .setReconnectionDelay(1500)
          .setAuth({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    for (final eventName in const [
      'new_order',
      'order_updated',
      'order_status_changed',
      'order_tracking_updated',
      'driver_notification',
      'driver_updated',
      'driver_location_updated',
    ]) {
      _socket?.on(eventName, (payload) {
        _eventsController.add(RealtimeEvent(name: eventName, payload: payload));
      });
    }

    _socket?.onConnect((_) {
      _socket?.emit('join_driver_room', {'token': token});
    });

    _socket?.connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _eventsController.close();
  }
}
