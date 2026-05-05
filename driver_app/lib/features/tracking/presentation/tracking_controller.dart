import 'dart:async';

import 'package:driver_app/core/services/location_service.dart';
import 'package:driver_app/core/services/reverse_geocoding_service.dart';
import 'package:driver_app/features/auth/presentation/auth_controller.dart';
import 'package:driver_app/features/orders/data/orders_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final trackingControllerProvider =
    NotifierProvider<TrackingController, TrackingState>(TrackingController.new);

class TrackingState {
  const TrackingState({
    required this.isSharing,
    required this.activeOrderId,
    required this.currentPosition,
    required this.errorMessage,
  });

  const TrackingState.initial()
    : isSharing = false,
      activeOrderId = null,
      currentPosition = null,
      errorMessage = null;

  final bool isSharing;
  final String? activeOrderId;
  final Position? currentPosition;
  final String? errorMessage;

  TrackingState copyWith({
    bool? isSharing,
    String? activeOrderId,
    Position? currentPosition,
    String? errorMessage,
    bool clearError = false,
    bool clearOrder = false,
  }) {
    return TrackingState(
      isSharing: isSharing ?? this.isSharing,
      activeOrderId: clearOrder ? null : (activeOrderId ?? this.activeOrderId),
      currentPosition: currentPosition ?? this.currentPosition,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class TrackingController extends Notifier<TrackingState> {
  static const locationPermissionRequiredCode = 'location_permission_required';
  static const locationServiceDisabledCode = 'location_service_disabled';
  static const locationPermissionDeniedForeverCode =
      'location_permission_denied_forever';
  static const double _minMovementMetersForPush = 8;
  static const int _maxSecondsBetweenPushes = 5;
  static const double _maxAcceptedAccuracyMeters = 120;

  StreamSubscription<Position>? _positionSubscription;
  Position? _lastSentPosition;
  DateTime? _lastSentAt;
  bool _isSendingLocation = false;
  Position? _queuedPosition;
  bool _isDisposed = false;
  int _sharingSessionId = 0;

  @override
  TrackingState build() {
    ref.onDispose(() {
      _isDisposed = true;
      _sharingSessionId += 1;
      _positionSubscription?.cancel();
      _positionSubscription = null;
    });
    return const TrackingState.initial();
  }

  Future<void> startSharing(String orderId) async {
    final sessionId = ++_sharingSessionId;
    final locationService = ref.read(locationServiceProvider);
    final permissionResult = await locationService.ensurePermission();

    if (!_isSessionActive(sessionId)) {
      return;
    }

    if (!permissionResult.isGranted) {
      state = state.copyWith(
        errorMessage: switch (permissionResult.status) {
          LocationPermissionStatus.serviceDisabled =>
            locationServiceDisabledCode,
          LocationPermissionStatus.deniedForever =>
            locationPermissionDeniedForeverCode,
          _ => locationPermissionRequiredCode,
        },
      );
      return;
    }

    final currentPosition = await locationService.getCurrentPosition();

    if (!_isSessionActive(sessionId)) {
      return;
    }

    if (currentPosition == null) {
      state = state.copyWith(errorMessage: locationPermissionRequiredCode);
      return;
    }

    await _positionSubscription?.cancel();

    state = state.copyWith(
      isSharing: true,
      activeOrderId: orderId,
      currentPosition: currentPosition,
      clearError: true,
    );

    await _sendOrQueuePosition(
      currentPosition,
      force: true,
      sessionId: sessionId,
    );

    _positionSubscription = locationService.watchPosition().listen(
      (position) async {
        if (!_isSessionActive(sessionId)) {
          return;
        }
        state = state.copyWith(currentPosition: position);
        await _sendOrQueuePosition(position, sessionId: sessionId);
      },
      onError: (Object error) {
        if (!_isSessionActive(sessionId)) {
          return;
        }
        state = state.copyWith(errorMessage: error.toString());
      },
    );
  }

  Future<void> stopSharing() async {
    _sharingSessionId += 1;
    final currentSubscription = _positionSubscription;
    _positionSubscription = null;
    await currentSubscription?.cancel();
    _positionSubscription = null;
    _lastSentPosition = null;
    _lastSentAt = null;
    _queuedPosition = null;
    _isSendingLocation = false;

    if (_isDisposed) {
      return;
    }

    state = state.copyWith(
      isSharing: false,
      clearOrder: true,
      clearError: true,
    );
  }

  Future<void> _sendOrQueuePosition(
    Position position, {
    bool force = false,
    required int sessionId,
  }) async {
    if (!_isSessionActive(sessionId)) {
      return;
    }

    if (!force && !_shouldSendPosition(position)) {
      return;
    }

    if (_isSendingLocation) {
      _queuedPosition = position;
      return;
    }

    _isSendingLocation = true;
    try {
      await _pushPosition(position);
      if (!_isSessionActive(sessionId)) {
        return;
      }
      _lastSentPosition = position;
      _lastSentAt = DateTime.now();
    } catch (error) {
      if (!_isSessionActive(sessionId)) {
        return;
      }
      state = state.copyWith(errorMessage: error.toString());
    } finally {
      _isSendingLocation = false;
    }

    final queuedPosition = _queuedPosition;
    if (!_isSessionActive(sessionId)) {
      _queuedPosition = null;
      return;
    }

    if (queuedPosition != null && !identical(queuedPosition, position)) {
      _queuedPosition = null;
      await _sendOrQueuePosition(
        queuedPosition,
        force: true,
        sessionId: sessionId,
      );
    } else {
      _queuedPosition = null;
    }
  }

  bool _isSessionActive(int sessionId) {
    return !_isDisposed && sessionId == _sharingSessionId;
  }

  Locale _resolveLocale() {
    final locales = WidgetsBinding.instance.platformDispatcher.locales;
    return locales.isNotEmpty ? locales.first : const Locale('ar');
  }

  bool _shouldSendPosition(Position position) {
    if (!_isReliablePosition(position)) {
      return false;
    }

    final lastSentPosition = _lastSentPosition;
    final lastSentAt = _lastSentAt;

    if (lastSentPosition == null || lastSentAt == null) {
      return true;
    }

    final distanceMeters = Geolocator.distanceBetween(
      lastSentPosition.latitude,
      lastSentPosition.longitude,
      position.latitude,
      position.longitude,
    );

    final secondsSinceLastPush = DateTime.now()
        .difference(lastSentAt)
        .inSeconds;

    return distanceMeters >= _minMovementMetersForPush ||
        secondsSinceLastPush >= _maxSecondsBetweenPushes;
  }

  bool _isReliablePosition(Position position) {
    final accuracy = position.accuracy;
    return !accuracy.isNaN &&
        accuracy > 0 &&
        accuracy <= _maxAcceptedAccuracyMeters;
  }

  Future<void> _pushPosition(Position position) async {
    final currentLocation = await ref
        .read(reverseGeocodingServiceProvider)
        .resolveAddress(
          latitude: position.latitude,
          longitude: position.longitude,
          locale: _resolveLocale(),
        );

    await ref
        .read(ordersRepositoryProvider)
        .updateDriverLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          orderId: state.activeOrderId,
          currentLocation: currentLocation,
        );

    await ref
        .read(authControllerProvider.notifier)
        .updateDriverLocationLocally(
          latitude: position.latitude,
          longitude: position.longitude,
          currentLocation: currentLocation,
        );
  }
}
