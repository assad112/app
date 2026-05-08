import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return const LocationService();
});

enum LocationPermissionStatus {
  granted,
  serviceDisabled,
  denied,
  deniedForever,
}

class LocationPermissionResult {
  const LocationPermissionResult({
    required this.status,
    required this.permission,
  });

  final LocationPermissionStatus status;
  final LocationPermission permission;

  bool get isGranted => status == LocationPermissionStatus.granted;
}

class LocationService {
  const LocationService();

  static const int liveTrackingDistanceFilterMeters = 8;
  static const Duration liveTrackingInterval = Duration(seconds: 4);

  Future<LocationPermissionResult> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return const LocationPermissionResult(
        status: LocationPermissionStatus.serviceDisabled,
        permission: LocationPermission.denied,
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return LocationPermissionResult(
        status: LocationPermissionStatus.granted,
        permission: permission,
      );
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationPermissionResult(
        status: LocationPermissionStatus.deniedForever,
        permission: LocationPermission.deniedForever,
      );
    }

    return LocationPermissionResult(
      status: LocationPermissionStatus.denied,
      permission: permission,
    );
  }

  Future<Position?> getCurrentPosition() async {
    final permissionResult = await ensurePermission();

    if (!permissionResult.isGranted) {
      return null;
    }

    return Geolocator.getCurrentPosition(locationSettings: _locationSettings);
  }

  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  Stream<Position> watchPosition() {
    return Geolocator.getPositionStream(locationSettings: _locationSettings);
  }

  LocationSettings get _locationSettings {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: liveTrackingDistanceFilterMeters,
        intervalDuration: liveTrackingInterval,
        forceLocationManager: false,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: liveTrackingDistanceFilterMeters,
    );
  }
}
