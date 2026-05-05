import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

final mapLauncherServiceProvider = Provider<MapLauncherService>((ref) {
  return const MapLauncherService();
});

enum MapLaunchFailureReason { destinationMissing, launchFailed }

class MapLaunchResult {
  const MapLaunchResult._({required this.isSuccess, this.reason});

  const MapLaunchResult.success() : this._(isSuccess: true);

  const MapLaunchResult.failure(MapLaunchFailureReason reason)
    : this._(isSuccess: false, reason: reason);

  final bool isSuccess;
  final MapLaunchFailureReason? reason;
}

class MapLauncherService {
  const MapLauncherService();

  Future<MapLaunchResult> openDrivingNavigation({
    required String address,
    String? label,
    double? destinationLatitude,
    double? destinationLongitude,
    double? originLatitude,
    double? originLongitude,
  }) async {
    final normalizedAddress = address.trim();
    final destination = _normalizeCoordinates(
      destinationLatitude,
      destinationLongitude,
    );
    final origin = _normalizeCoordinates(originLatitude, originLongitude);
    final destinationLabel = _normalizeLabel(label);

    if (destination == null && normalizedAddress.isEmpty) {
      return const MapLaunchResult.failure(
        MapLaunchFailureReason.destinationMissing,
      );
    }

    final candidates = _buildCandidates(
      address: normalizedAddress,
      destination: destination,
      origin: origin,
      label: destinationLabel,
    );

    for (final candidate in candidates) {
      if (await _tryLaunch(candidate)) {
        return const MapLaunchResult.success();
      }
    }

    return const MapLaunchResult.failure(MapLaunchFailureReason.launchFailed);
  }

  List<Uri> _buildCandidates({
    required String address,
    required _Coordinates? destination,
    required _Coordinates? origin,
    required String label,
  }) {
    final candidates = <Uri>[];

    if (destination != null) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        candidates.add(
          Uri.parse(
            'geo:0,0?q=${Uri.encodeComponent('${destination.latitude},${destination.longitude}($label)')}',
          ),
        );
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        candidates.add(
          Uri.parse(
            'http://maps.apple.com/?daddr=${destination.latitude},${destination.longitude}&dirflg=d',
          ),
        );
      }

      if (origin != null) {
        candidates.add(
          Uri.parse(
            'https://www.openstreetmap.org/directions?engine=fossgis_osrm_car&route=${origin.latitude},${origin.longitude};${destination.latitude},${destination.longitude}',
          ),
        );
      }

      candidates.add(
        Uri.parse(
          'https://www.openstreetmap.org/?mlat=${destination.latitude}&mlon=${destination.longitude}#map=16/${destination.latitude}/${destination.longitude}',
        ),
      );
    }

    if (address.isNotEmpty) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        candidates.add(Uri.parse('geo:0,0?q=${Uri.encodeComponent(address)}'));
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        candidates.add(
          Uri.parse('http://maps.apple.com/?q=${Uri.encodeComponent(address)}'),
        );
      }

      candidates.add(
        Uri.parse(
          'https://www.openstreetmap.org/search?query=${Uri.encodeComponent(address)}',
        ),
      );
    }

    final seen = <String>{};
    return candidates
        .where((candidate) => seen.add(candidate.toString()))
        .toList();
  }

  Future<bool> _tryLaunch(Uri uri) async {
    try {
      final canLaunch = await canLaunchUrl(uri);
      if (!canLaunch) {
        return false;
      }

      return launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  _Coordinates? _normalizeCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return null;
    }

    if (latitude.isNaN || longitude.isNaN) {
      return null;
    }

    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    if (latitude.abs() < 0.000001 && longitude.abs() < 0.000001) {
      return null;
    }

    return _Coordinates(latitude: latitude, longitude: longitude);
  }

  String _normalizeLabel(String? label) {
    final trimmed = label?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'Destination';
    }

    return trimmed;
  }
}

class _Coordinates {
  const _Coordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}
