import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

final deviceLocationServiceProvider = Provider<DeviceLocationService>((ref) {
  return DeviceLocationService();
});

enum DeviceLocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
  outOfCoverage,
}

class DeviceLocationException implements Exception {
  const DeviceLocationException(this.failure);

  final DeviceLocationFailure failure;
}

class DeviceLocationSnapshot {
  const DeviceLocationSnapshot({
    required this.latitude,
    required this.longitude,
    this.placemark,
    this.accuracyMeters,
    this.capturedAt,
    this.isFromLastKnown = false,
  });

  final double latitude;
  final double longitude;
  final Placemark? placemark;
  final double? accuracyMeters;
  final DateTime? capturedAt;
  final bool isFromLastKnown;
}

class DeviceLocationService {
  static const double _muscatLatitude = 23.5880;
  static const double _muscatLongitude = 58.3829;
  static const double _omanLatitudeMin = 15.0;
  static const double _omanLatitudeMax = 28.8;
  static const double _omanLongitudeMin = 51.0;
  static const double _omanLongitudeMax = 60.9;

  Future<bool>? _isEmulatorFuture;

  Future<DeviceLocationSnapshot> getPreciseLocation({
    required String localeIdentifier,
  }) async {
    final isEmulator = await _isEmulator();

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (isEmulator) {
        return _buildEmulatorFallbackSnapshot(
          localeIdentifier: localeIdentifier,
        );
      }

      throw const DeviceLocationException(
        DeviceLocationFailure.serviceDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (isEmulator) {
        return _buildEmulatorFallbackSnapshot(
          localeIdentifier: localeIdentifier,
        );
      }

      throw const DeviceLocationException(
        DeviceLocationFailure.permissionDenied,
      );
    }

    if (permission == LocationPermission.deniedForever) {
      if (isEmulator) {
        return _buildEmulatorFallbackSnapshot(
          localeIdentifier: localeIdentifier,
        );
      }

      throw const DeviceLocationException(
        DeviceLocationFailure.permissionDeniedForever,
      );
    }

    final fallback = await Geolocator.getLastKnownPosition();
    final resolvedPosition = await _resolveBestPosition(fallback: fallback);

    if (resolvedPosition == null) {
      if (isEmulator) {
        return _buildEmulatorFallbackSnapshot(
          localeIdentifier: localeIdentifier,
        );
      }

      throw const DeviceLocationException(DeviceLocationFailure.unavailable);
    }

    if (isEmulator &&
        !_isCoordinateWithinOman(
          resolvedPosition.position.latitude,
          resolvedPosition.position.longitude,
        )) {
      return _buildEmulatorFallbackSnapshot(localeIdentifier: localeIdentifier);
    }

    final latitude = resolvedPosition.position.latitude;
    final longitude = resolvedPosition.position.longitude;
    final placemark = await _resolvePlacemark(
      latitude: latitude,
      longitude: longitude,
      localeIdentifier: localeIdentifier,
    );

    return DeviceLocationSnapshot(
      latitude: latitude,
      longitude: longitude,
      placemark: placemark,
      accuracyMeters: _safeAccuracy(resolvedPosition.position.accuracy),
      capturedAt: resolvedPosition.position.timestamp,
      isFromLastKnown: resolvedPosition.isFromLastKnown,
    );
  }

  Future<DeviceLocationSnapshot> _buildEmulatorFallbackSnapshot({
    required String localeIdentifier,
  }) async {
    final placemark = await _resolvePlacemark(
      latitude: _muscatLatitude,
      longitude: _muscatLongitude,
      localeIdentifier: localeIdentifier,
    );

    return DeviceLocationSnapshot(
      latitude: _muscatLatitude,
      longitude: _muscatLongitude,
      placemark: placemark,
    );
  }

  Future<Placemark?> _resolvePlacemark({
    required double latitude,
    required double longitude,
    required String localeIdentifier,
  }) async {
    try {
      final geocoderPresent = await isPresent().timeout(
        const Duration(seconds: 1),
        onTimeout: () => false,
      );

      if (!geocoderPresent) {
        return null;
      }

      await setLocaleIdentifier(
        localeIdentifier,
      ).timeout(const Duration(seconds: 1));

      final placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      ).timeout(const Duration(seconds: 2));

      if (placemarks.isNotEmpty) {
        return placemarks.first;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  bool _isCoordinateWithinOman(double latitude, double longitude) {
    return latitude >= _omanLatitudeMin &&
        latitude <= _omanLatitudeMax &&
        longitude >= _omanLongitudeMin &&
        longitude <= _omanLongitudeMax;
  }

  Future<_ResolvedPosition?> _resolveBestPosition({
    required Position? fallback,
  }) async {
    final candidates = <_ResolvedPosition>[
      if (fallback != null)
        _ResolvedPosition(position: fallback, isFromLastKnown: true),
    ];

    final firstFix = await _tryCurrentPosition(
      timeout: const Duration(seconds: 8),
    );
    if (firstFix != null) {
      candidates.add(
        _ResolvedPosition(position: firstFix, isFromLastKnown: false),
      );
    }

    final initialBest = _pickBestPosition(candidates);

    if (_needsAccuracyRefinement(initialBest)) {
      await Future<void>.delayed(const Duration(milliseconds: 650));
      final secondFix = await _tryCurrentPosition(
        timeout: const Duration(seconds: 6),
      );
      if (secondFix != null) {
        candidates.add(
          _ResolvedPosition(position: secondFix, isFromLastKnown: false),
        );
      }
    }

    return _pickBestPosition(candidates);
  }

  Future<Position?> _tryCurrentPosition({required Duration timeout}) async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: timeout,
        ),
      );
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  _ResolvedPosition? _pickBestPosition(Iterable<_ResolvedPosition> candidates) {
    _ResolvedPosition? best;

    for (final candidate in candidates) {
      if (best == null || _isBetterPositionCandidate(candidate, best)) {
        best = candidate;
      }
    }

    return best;
  }

  bool _isBetterPositionCandidate(
    _ResolvedPosition candidate,
    _ResolvedPosition best,
  ) {
    final candidateAge = _positionAge(candidate.position);
    final bestAge = _positionAge(best.position);
    final candidateAccuracy =
        _safeAccuracy(candidate.position.accuracy) ?? 9999;
    final bestAccuracy = _safeAccuracy(best.position.accuracy) ?? 9999;

    final candidateIsFresh = candidateAge <= const Duration(minutes: 2);
    final bestIsFresh = bestAge <= const Duration(minutes: 2);

    if (candidateIsFresh != bestIsFresh) {
      return candidateIsFresh;
    }

    if ((candidateAccuracy - bestAccuracy).abs() >= 12) {
      return candidateAccuracy < bestAccuracy;
    }

    final ageGap = candidateAge.inSeconds - bestAge.inSeconds;
    if (ageGap.abs() >= 10) {
      return candidateAge < bestAge;
    }

    if (candidate.isFromLastKnown != best.isFromLastKnown) {
      return !candidate.isFromLastKnown;
    }

    return candidateAccuracy < bestAccuracy;
  }

  bool _needsAccuracyRefinement(_ResolvedPosition? candidate) {
    if (candidate == null) {
      return true;
    }

    if (candidate.isFromLastKnown) {
      return true;
    }

    final accuracy = _safeAccuracy(candidate.position.accuracy);
    final age = _positionAge(candidate.position);

    return accuracy == null ||
        accuracy > 40 ||
        age > const Duration(minutes: 1);
  }

  Duration _positionAge(Position position) {
    final timestamp = position.timestamp;
    final age = DateTime.now().difference(timestamp);
    return age.isNegative ? Duration.zero : age;
  }

  double? _safeAccuracy(double? value) {
    if (value == null || value.isNaN || value.isInfinite || value <= 0) {
      return null;
    }

    return value;
  }

  Future<bool> _isEmulator() {
    return _isEmulatorFuture ??= _readIsEmulator();
  }

  Future<bool> _readIsEmulator() async {
    if (kIsWeb) {
      return false;
    }

    final deviceInfo = DeviceInfoPlugin();

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final info = await deviceInfo.androidInfo;
        return !info.isPhysicalDevice;
      case TargetPlatform.iOS:
        final info = await deviceInfo.iosInfo;
        return !info.isPhysicalDevice;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return false;
    }
  }
}

class _ResolvedPosition {
  const _ResolvedPosition({
    required this.position,
    required this.isFromLastKnown,
  });

  final Position position;
  final bool isFromLastKnown;
}
