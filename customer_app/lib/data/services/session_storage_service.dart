import 'dart:convert';

import 'package:customer_app/shared/localization/app_copy.dart';
import 'package:customer_app/shared/models/address_model.dart';
import 'package:customer_app/shared/models/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sessionStorageServiceProvider = Provider<SessionStorageService>((ref) {
  return SessionStorageService();
});

class SessionStorageService {
  static const _sessionKey = 'customer_session_active';
  static const _languageKey = 'customer_language';
  static const _userKey = 'customer_user_payload';
  static const _tokenKey = 'customer_auth_token';
  static const _lastIdentifierKey = 'customer_last_login_identifier';
  static const _currentAddressKey = 'customer_current_address_payload';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<bool> readSessionActive() async {
    final prefs = await _prefs;
    return prefs.getBool(_sessionKey) ?? false;
  }

  Future<AppLanguage> readLanguage() async {
    final prefs = await _prefs;
    return AppLanguage.fromCode(prefs.getString(_languageKey));
  }

  Future<UserProfile?> readUser() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_userKey);

    if (raw == null || raw.isEmpty) {
      return null;
    }

    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<String?> readAuthToken() async {
    final prefs = await _prefs;
    final token = prefs.getString(_tokenKey);

    if (token == null || token.isEmpty) {
      return null;
    }

    return token;
  }

  Future<String?> readLastIdentifier() async {
    final prefs = await _prefs;
    final identifier = prefs.getString(_lastIdentifierKey);

    if (identifier == null || identifier.isEmpty) {
      return null;
    }

    return identifier;
  }

  Future<AddressModel?> readCurrentAddress() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_currentAddressKey);

    if (raw == null || raw.isEmpty) {
      return null;
    }

    return AddressModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> persistLanguage(AppLanguage language) async {
    final prefs = await _prefs;
    await prefs.setString(_languageKey, language.code);
  }

  Future<void> persistSession(
    UserProfile user, {
    required String authToken,
  }) async {
    final prefs = await _prefs;
    await prefs.setBool(_sessionKey, true);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    await prefs.setString(_tokenKey, authToken);
  }

  Future<void> persistUserProfile(UserProfile user) async {
    final prefs = await _prefs;
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> persistCurrentAddress(AddressModel? address) async {
    final prefs = await _prefs;

    if (address == null) {
      await prefs.remove(_currentAddressKey);
      return;
    }

    await prefs.setString(_currentAddressKey, jsonEncode(address.toJson()));
  }

  Future<void> persistLastIdentifier(String identifier) async {
    final trimmedIdentifier = identifier.trim();
    if (trimmedIdentifier.isEmpty) {
      return;
    }

    final prefs = await _prefs;
    await prefs.setString(_lastIdentifierKey, trimmedIdentifier);
  }

  Future<void> clearSession() async {
    final prefs = await _prefs;
    await prefs.setBool(_sessionKey, false);
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_currentAddressKey);
  }
}
