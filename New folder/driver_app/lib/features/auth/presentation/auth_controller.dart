import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:driver_app/core/realtime/socket_service.dart';
import 'package:driver_app/core/services/notification_service.dart';
import 'package:driver_app/core/storage/session_storage.dart';
import 'package:driver_app/features/auth/data/auth_repository.dart';
import 'package:driver_app/features/auth/presentation/auth_state.dart';
import 'package:driver_app/features/earnings/presentation/earnings_controller.dart';
import 'package:driver_app/features/home/presentation/home_controller.dart';
import 'package:driver_app/features/notifications/presentation/notifications_controller.dart';
import 'package:driver_app/features/orders/presentation/orders_controller.dart';
import 'package:driver_app/features/profile/presentation/profile_controller.dart';
import 'package:driver_app/features/tracking/presentation/tracking_controller.dart';
import 'package:driver_app/shared/models/driver_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  void _resetDriverScopedState() {
    ref.invalidate(homeControllerProvider);
    ref.invalidate(ordersControllerProvider);
    ref.invalidate(notificationsControllerProvider);
    ref.invalidate(earningsControllerProvider);
    ref.invalidate(profileControllerProvider);
    ref.invalidate(trackingControllerProvider);
  }

  @override
  AuthState build() {
    return const AuthState.initial();
  }

  Future<void> bootstrap() async {
    if (state.hasBootstrapped || state.isLoading) {
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    final sessionStorage = ref.read(sessionStorageProvider);
    final authRepository = ref.read(authRepositoryProvider);
    try {
      final token = await sessionStorage.readToken();
      final cachedDriver = await sessionStorage.readDriver();

      if (token == null || token.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          hasBootstrapped: true,
          clearToken: true,
          clearDriver: true,
        );
        return;
      }

      await ref.read(notificationServiceProvider).initialize();

      if (cachedDriver != null) {
        state = state.copyWith(
          token: token,
          driver: cachedDriver,
          hasBootstrapped: true,
        );
      }

      final currentDriver = await authRepository.fetchCurrentDriver();
      await sessionStorage.saveSession(token: token, driver: currentDriver);
      ref.read(socketServiceProvider).connect(token);
      // ربط السائق بـ OneSignal عند استعادة الجلسة
      await OneSignal.login(currentDriver.id);
      OneSignal.User.addTagWithKey('userType', 'driver');

      state = state.copyWith(
        isLoading: false,
        hasBootstrapped: true,
        token: token,
        driver: currentDriver,
        clearError: true,
      );
    } catch (error) {
      await sessionStorage.clear();
      ref.read(socketServiceProvider).disconnect();

      state = state.copyWith(
        isLoading: false,
        hasBootstrapped: true,
        clearToken: true,
        clearDriver: true,
        errorMessage: error.toString(),
      );
    }
  }

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await ref
          .read(authRepositoryProvider)
          .login(identifier: identifier, password: password);

      await ref
          .read(sessionStorageProvider)
          .saveSession(token: result.token, driver: result.driver);
      ref.read(socketServiceProvider).connect(result.token);
      await OneSignal.login(result.driver.id);
      OneSignal.User.addTagWithKey('userType', 'driver');
      _resetDriverScopedState();

      state = state.copyWith(
        isLoading: false,
        hasBootstrapped: true,
        token: result.token,
        driver: result.driver,
      );
      return true;
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {
      // Clearing the local session remains the priority.
    }

    await ref.read(sessionStorageProvider).clear();
    ref.read(socketServiceProvider).disconnect();
    OneSignal.logout();
    _resetDriverScopedState();

    state = const AuthState.initial().copyWith(hasBootstrapped: true);
  }

  Future<void> refreshDriver() async {
    try {
      final driver = await ref
          .read(authRepositoryProvider)
          .fetchCurrentDriver();
      final token = state.token;

      if (token != null) {
        await ref
            .read(sessionStorageProvider)
            .saveSession(token: token, driver: driver);
      }

      state = state.copyWith(driver: driver, clearError: true);
    } catch (_) {
      // Keep the current UI responsive even if a silent refresh fails.
    }
  }

  Future<void> updateDriverLocally(DriverProfile driver) async {
    final token = state.token;

    if (token != null) {
      await ref
          .read(sessionStorageProvider)
          .saveSession(token: token, driver: driver);
    }

    state = state.copyWith(driver: driver);
  }

  Future<void> updateDriverLocationLocally({
    required double latitude,
    required double longitude,
    String? currentLocation,
  }) async {
    final currentDriver = state.driver;
    if (currentDriver == null) {
      return;
    }

    final nextDriver = currentDriver.copyWith(
      currentLatitude: latitude,
      currentLongitude: longitude,
      currentLocation: currentLocation ?? currentDriver.currentLocation,
      lastLocationAt: DateTime.now(),
      lastSeenAt: DateTime.now(),
    );

    await updateDriverLocally(nextDriver);
  }
}
