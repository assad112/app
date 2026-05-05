import 'dart:async';

import 'package:driver_app/core/services/driver_foreground_service.dart';
import 'package:driver_app/core/services/location_service.dart';
import 'package:driver_app/core/services/reverse_geocoding_service.dart';
import 'package:driver_app/features/auth/presentation/auth_controller.dart';
import 'package:driver_app/features/auth/presentation/auth_state.dart';
import 'package:driver_app/features/orders/data/orders_repository.dart';
import 'package:driver_app/shared/models/driver_profile.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final appDriverPresenceBindingsProvider = Provider<void>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  final reverseGeocodingService = ref.watch(reverseGeocodingServiceProvider);
  final ordersRepository = ref.watch(ordersRepositoryProvider);

  StreamSubscription<Position>? positionSubscription;
  Timer? heartbeatTimer;
  int sessionId = 0;
  bool syncInFlight = false;
  String? activeDriverId;

  Locale resolveLocale() {
    final context = WidgetsBinding.instance.platformDispatcher;
    final locales = context.locales;
    return locales.isNotEmpty ? locales.first : const Locale('ar');
  }

  Future<void> uploadPosition(Position position, int expectedSession) async {
    final currentLocation = await reverseGeocodingService.resolveAddress(
      latitude: position.latitude,
      longitude: position.longitude,
      locale: resolveLocale(),
    );

    if (expectedSession != sessionId) {
      return;
    }

    await ordersRepository.updateDriverLocation(
      latitude: position.latitude,
      longitude: position.longitude,
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

  bool shouldShareLocation(DriverProfile? driver) {
    return driver != null && driver.isOnline && !driver.isBusy;
  }

  Future<void> pushCurrentPosition(int expectedSession) async {
    if (syncInFlight || expectedSession != sessionId) {
      return;
    }

    syncInFlight = true;

    try {
      final currentPosition = await locationService.getCurrentPosition();

      if (currentPosition == null || expectedSession != sessionId) {
        return;
      }

      await uploadPosition(currentPosition, expectedSession);
    } catch (_) {
      // Keep live dispatch resilient even if one GPS read/upload fails.
    } finally {
      if (expectedSession == sessionId) {
        syncInFlight = false;
      }
    }
  }

  Future<void> pushStreamPosition(
    Position position,
    int expectedSession,
  ) async {
    if (syncInFlight || expectedSession != sessionId) {
      return;
    }

    syncInFlight = true;

    try {
      await uploadPosition(position, expectedSession);
    } catch (_) {
      // Ignore transient upload errors; the heartbeat will retry shortly.
    } finally {
      if (expectedSession == sessionId) {
        syncInFlight = false;
      }
    }
  }

  Future<void> stopPresence() async {
    sessionId += 1;
    activeDriverId = null;
    syncInFlight = false;
    heartbeatTimer?.cancel();
    heartbeatTimer = null;
    await positionSubscription?.cancel();
    positionSubscription = null;
    await DriverForegroundService.stop();
  }

  Future<void> startPresence(DriverProfile driver) async {
    await stopPresence();

    activeDriverId = driver.id;
    final currentSession = sessionId;
    final permissionResult = await locationService.ensurePermission();

    if (!permissionResult.isGranted || currentSession != sessionId) {
      return;
    }

    // تشغيل الخدمة بعد التحقق من الأذونات
    await DriverForegroundService.start();

    await pushCurrentPosition(currentSession);

    heartbeatTimer = Timer.periodic(const Duration(seconds: 90), (_) {
      unawaited(pushCurrentPosition(currentSession));
    });

    positionSubscription = locationService.watchPosition().listen((position) {
      unawaited(pushStreamPosition(position, currentSession));
    }, onError: (_) {});
  }

  Future<void> syncPresence(DriverProfile? driver) async {
    if (!shouldShareLocation(driver)) {
      await stopPresence();
      return;
    }

    if (activeDriverId == driver!.id && positionSubscription != null) {
      return;
    }

    await startPresence(driver);
  }

  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    final nextDriver = next.driver;
    unawaited(syncPresence(nextDriver));
  });

  final initialDriver = ref.read(authControllerProvider).driver;
  unawaited(syncPresence(initialDriver));

  ref.onDispose(() {
    unawaited(stopPresence());
  });
});
