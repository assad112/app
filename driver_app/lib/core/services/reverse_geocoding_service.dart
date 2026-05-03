import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

final reverseGeocodingServiceProvider = Provider<ReverseGeocodingService>((
  ref,
) {
  return ReverseGeocodingService();
});

class ReverseGeocodingService {
  static const double _reuseDistanceMeters = 60;
  static const Duration _cacheDuration = Duration(minutes: 2);

  _ResolvedLocation? _cachedLocation;
  Future<String?>? _pendingLookup;

  Future<String?> resolveAddress({
    required double latitude,
    required double longitude,
    required Locale locale,
  }) {
    final cachedLocation = _cachedLocation;
    final now = DateTime.now();

    if (cachedLocation != null &&
        now.difference(cachedLocation.resolvedAt) <= _cacheDuration) {
      final distance = Geolocator.distanceBetween(
        cachedLocation.latitude,
        cachedLocation.longitude,
        latitude,
        longitude,
      );

      if (distance <= _reuseDistanceMeters) {
        return Future.value(cachedLocation.label);
      }
    }

    final pendingLookup = _pendingLookup;
    if (pendingLookup != null) {
      return pendingLookup;
    }

    final lookup = _resolveFromPlatform(
      latitude: latitude,
      longitude: longitude,
      locale: locale,
    );
    _pendingLookup = lookup;
    return lookup.whenComplete(() {
      if (identical(_pendingLookup, lookup)) {
        _pendingLookup = null;
      }
    });
  }

  Future<String?> _resolveFromPlatform({
    required double latitude,
    required double longitude,
    required Locale locale,
  }) async {
    try {
      await setLocaleIdentifier(_localeIdentifier(locale));
      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isEmpty) {
        return null;
      }

      final label = _formatPlacemark(placemarks.first);
      if (label == null) {
        return null;
      }

      _cachedLocation = _ResolvedLocation(
        latitude: latitude,
        longitude: longitude,
        label: label,
        resolvedAt: DateTime.now(),
      );
      return label;
    } catch (_) {
      return null;
    }
  }

  String _localeIdentifier(Locale locale) {
    final countryCode = locale.countryCode;
    if (countryCode != null && countryCode.isNotEmpty) {
      return '${locale.languageCode}_$countryCode';
    }

    return locale.languageCode;
  }

  String? _formatPlacemark(Placemark placemark) {
    final parts = <String>{
      placemark.street?.trim() ?? '',
      placemark.subLocality?.trim() ?? '',
      placemark.locality?.trim() ?? '',
      placemark.administrativeArea?.trim() ?? '',
      placemark.country?.trim() ?? '',
    }.where((part) => part.isNotEmpty).toList();

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(', ');
  }
}

class _ResolvedLocation {
  const _ResolvedLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.resolvedAt,
  });

  final double latitude;
  final double longitude;
  final String label;
  final DateTime resolvedAt;
}
