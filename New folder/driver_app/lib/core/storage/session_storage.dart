import 'dart:convert';

import 'package:driver_app/shared/models/driver_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  return const SessionStorage(FlutterSecureStorage());
});

class SessionStorage {
  const SessionStorage(this._storage);

  static const _tokenKey = 'driver_auth_token';
  static const _driverKey = 'driver_profile_cache';
  static const _localeKey = 'driver_app_locale';

  final FlutterSecureStorage _storage;

  Future<void> saveSession({
    required String token,
    required DriverProfile driver,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _driverKey, value: jsonEncode(driver.toJson()));
  }

  Future<String?> readToken() {
    return _storage.read(key: _tokenKey);
  }

  Future<DriverProfile?> readDriver() async {
    final rawValue = await _storage.read(key: _driverKey);

    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    final json = jsonDecode(rawValue) as Map<String, dynamic>;
    return DriverProfile.fromJson(json);
  }

  Future<void> saveLocaleCode(String localeCode) {
    return _storage.write(key: _localeKey, value: localeCode);
  }

  Future<String?> readLocaleCode() {
    return _storage.read(key: _localeKey);
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _driverKey);
  }
}
