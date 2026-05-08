import 'package:customer_app/shared/models/tracking_route_point.dart';

class DeliveryRoute {
  const DeliveryRoute({
    required this.points,
    this.distanceMeters,
    this.durationSeconds,
    this.etaMinutes,
    this.provider,
    this.isFallback = false,
  });

  final List<TrackingRoutePoint> points;
  final int? distanceMeters;
  final int? durationSeconds;
  final int? etaMinutes;
  final String? provider;
  final bool isFallback;

  bool get hasPath => points.length > 1;

  factory DeliveryRoute.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value == null || value == '') {
        return null;
      }

      if (value is int) {
        return value;
      }

      if (value is num) {
        return value.round();
      }

      return int.tryParse(value.toString());
    }

    double? parseDouble(dynamic value) {
      if (value == null || value == '') {
        return null;
      }

      if (value is num) {
        return value.toDouble();
      }

      return double.tryParse(value.toString());
    }

    Map<String, dynamic>? asMap(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value;
      }

      if (value is Map) {
        return value.map((key, item) => MapEntry(key.toString(), item));
      }

      return null;
    }

    final rawPoints =
        json['points'] ?? json['routePoints'] ?? json['route_points'];
    final points = <TrackingRoutePoint>[];

    if (rawPoints is List) {
      for (final item in rawPoints) {
        final map = asMap(item);
        if (map == null) {
          continue;
        }

        final latitude = parseDouble(map['latitude'] ?? map['lat'] ?? map['y']);
        final longitude = parseDouble(
          map['longitude'] ??
              map['lng'] ??
              map['lon'] ??
              map['long'] ??
              map['x'],
        );

        if (latitude == null || longitude == null) {
          continue;
        }

        points.add(
          TrackingRoutePoint(latitude: latitude, longitude: longitude),
        );
      }
    } else {
      final geometry = asMap(json['geometry']);
      final coordinates = geometry?['coordinates'];

      if (coordinates is List) {
        for (final coordinate in coordinates) {
          if (coordinate is! List || coordinate.length < 2) {
            continue;
          }

          final longitude = parseDouble(coordinate[0]);
          final latitude = parseDouble(coordinate[1]);

          if (latitude == null || longitude == null) {
            continue;
          }

          points.add(
            TrackingRoutePoint(latitude: latitude, longitude: longitude),
          );
        }
      }
    }

    return DeliveryRoute(
      points: List.unmodifiable(points),
      distanceMeters: parseInt(json['distanceMeters'] ?? json['distance']),
      durationSeconds: parseInt(json['durationSeconds'] ?? json['duration']),
      etaMinutes: parseInt(json['etaMinutes']),
      provider: json['provider']?.toString(),
      isFallback: json['isFallback'] == true,
    );
  }
}
