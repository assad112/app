import 'package:driver_app/core/storage/session_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale>((ref) {
      return LocaleController(ref.watch(sessionStorageProvider));
    });

class LocaleController extends StateNotifier<Locale> {
  LocaleController(this._storage) : super(const Locale('ar')) {
    _load();
  }

  final SessionStorage _storage;

  Future<void> _load() async {
    final savedCode = await _storage.readLocaleCode();

    if (savedCode == 'ar' || savedCode == 'en') {
      state = Locale(savedCode!);
    }
  }

  Future<void> setLocale(String languageCode) async {
    if (languageCode != 'ar' && languageCode != 'en') {
      return;
    }

    state = Locale(languageCode);
    await _storage.saveLocaleCode(languageCode);
  }

  Future<void> toggle() async {
    await setLocale(state.languageCode == 'ar' ? 'en' : 'ar');
  }
}
