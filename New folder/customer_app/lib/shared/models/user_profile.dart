class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.defaultAddressId,
    this.avatarUrl,
  });

  final String id;
  final String fullName;
  final String phone;
  final String email;
  final String defaultAddressId;
  final String? avatarUrl;

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? email,
    String? defaultAddressId,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      defaultAddressId: defaultAddressId ?? this.defaultAddressId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'defaultAddressId': defaultAddressId,
      'avatarUrl': avatarUrl,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'].toString(),
      fullName: json['fullName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      defaultAddressId: json['defaultAddressId']?.toString() ?? 'addr-001',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}
