class AddressModel {
  static const currentLocationId = 'device-current-location';

  const AddressModel({
    required this.id,
    required this.label,
    required this.governorate,
    required this.wilayat,
    required this.area,
    required this.street,
    required this.houseNumber,
    required this.landmark,
    required this.latitude,
    required this.longitude,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String governorate;
  final String wilayat;
  final String area;
  final String street;
  final String houseNumber;
  final String landmark;
  final double latitude;
  final double longitude;
  final bool isDefault;

  String get fullAddress {
    return _joinAddressParts([
      governorate,
      wilayat,
      area,
      street,
      houseNumber,
      landmark,
    ]);
  }

  String get compactAddress => _joinAddressParts([wilayat, area, street]);

  bool get isCurrentLocation => id == currentLocationId;

  AddressModel copyWith({
    String? id,
    String? label,
    String? governorate,
    String? wilayat,
    String? area,
    String? street,
    String? houseNumber,
    String? landmark,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) {
    return AddressModel(
      id: id ?? this.id,
      label: label ?? this.label,
      governorate: governorate ?? this.governorate,
      wilayat: wilayat ?? this.wilayat,
      area: area ?? this.area,
      street: street ?? this.street,
      houseNumber: houseNumber ?? this.houseNumber,
      landmark: landmark ?? this.landmark,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'governorate': governorate,
      'wilayat': wilayat,
      'area': area,
      'street': street,
      'houseNumber': houseNumber,
      'landmark': landmark,
      'latitude': latitude,
      'longitude': longitude,
      'isDefault': isDefault,
    };
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id']?.toString() ?? currentLocationId,
      label: json['label']?.toString() ?? '',
      governorate: json['governorate']?.toString() ?? '',
      wilayat: json['wilayat']?.toString() ?? '',
      area: json['area']?.toString() ?? '',
      street: json['street']?.toString() ?? '',
      houseNumber: json['houseNumber']?.toString() ?? '',
      landmark: json['landmark']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  static bool _isUsablePart(String value) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty && trimmed != '-';
  }

  static String _joinAddressParts(Iterable<String> parts) {
    final values = <String>[];
    final seen = <String>{};

    for (final part in parts) {
      if (!_isUsablePart(part)) {
        continue;
      }

      final trimmed = part.trim();
      final normalized = _normalizeComparablePart(trimmed);
      if (normalized.isEmpty || !seen.add(normalized)) {
        continue;
      }

      values.add(trimmed);
    }

    return values.join(', ');
  }

  static String _normalizeComparablePart(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[\s,،._-]+'), '');
  }
}
