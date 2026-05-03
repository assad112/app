class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.status,
    required this.availability,
    required this.currentLocation,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.vehicleLabel,
    required this.licenseNumber,
    required this.availableCylinderSizes,
    required this.lastSeenAt,
    required this.lastLocationAt,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String status;
  final String availability;
  final String currentLocation;
  final double? currentLatitude;
  final double? currentLongitude;
  final String vehicleLabel;
  final String licenseNumber;
  final List<String> availableCylinderSizes;
  final DateTime? lastSeenAt;
  final DateTime? lastLocationAt;

  bool get isOnline => status == "online";
  bool get isBusy => availability == "busy";

  DriverProfile copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? status,
    String? availability,
    String? currentLocation,
    double? currentLatitude,
    double? currentLongitude,
    String? vehicleLabel,
    String? licenseNumber,
    List<String>? availableCylinderSizes,
    DateTime? lastSeenAt,
    DateTime? lastLocationAt,
    bool clearLastSeenAt = false,
    bool clearLastLocationAt = false,
  }) {
    return DriverProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      status: status ?? this.status,
      availability: availability ?? this.availability,
      currentLocation: currentLocation ?? this.currentLocation,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      vehicleLabel: vehicleLabel ?? this.vehicleLabel,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      availableCylinderSizes:
          availableCylinderSizes ?? this.availableCylinderSizes,
      lastSeenAt: clearLastSeenAt ? null : (lastSeenAt ?? this.lastSeenAt),
      lastLocationAt: clearLastLocationAt
          ? null
          : (lastLocationAt ?? this.lastLocationAt),
    );
  }

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    double? parseCoordinate(dynamic value) {
      if (value == null || value == "") {
        return null;
      }

      return double.tryParse(value.toString());
    }

    DateTime? parseDate(dynamic value) {
      if (value == null || value == "") {
        return null;
      }

      return DateTime.tryParse(value.toString());
    }

    List<String> parseCylinderSizes(dynamic value) {
      if (value is List) {
        return value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }

      if (value is String && value.isNotEmpty) {
        return value
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }

      return const [];
    }

    return DriverProfile(
      id: (json["id"] ?? "").toString(),
      name: (json["name"] ?? "").toString(),
      phone: (json["phone"] ?? "").toString(),
      email: (json["email"] ?? "").toString(),
      status: (json["status"] ?? "offline").toString(),
      availability: (json["availability"] ?? "available").toString(),
      currentLocation:
          (json["currentLocation"] ?? json["current_location"] ?? "")
              .toString(),
      currentLatitude: parseCoordinate(
        json["currentLatitude"] ?? json["current_latitude"],
      ),
      currentLongitude: parseCoordinate(
        json["currentLongitude"] ?? json["current_longitude"],
      ),
      vehicleLabel: (json["vehicleLabel"] ?? json["vehicle_label"] ?? "")
          .toString(),
      licenseNumber: (json["licenseNumber"] ?? json["license_number"] ?? "")
          .toString(),
      availableCylinderSizes: parseCylinderSizes(
        json["availableCylinderSizes"] ?? json["available_cylinder_sizes"],
      ),
      lastSeenAt: parseDate(json["lastSeenAt"] ?? json["last_seen_at"]),
      lastLocationAt: parseDate(
        json["lastLocationAt"] ?? json["last_location_at"],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "phone": phone,
      "email": email,
      "status": status,
      "availability": availability,
      "currentLocation": currentLocation,
      "currentLatitude": currentLatitude,
      "currentLongitude": currentLongitude,
      "vehicleLabel": vehicleLabel,
      "licenseNumber": licenseNumber,
      "availableCylinderSizes": availableCylinderSizes,
      "lastSeenAt": lastSeenAt?.toIso8601String(),
      "lastLocationAt": lastLocationAt?.toIso8601String(),
    };
  }
}
