import 'package:driver_app/core/storage/session_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localeControllerProvider =
    NotifierProvider<LocaleController, Locale>(LocaleController.new);

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    _load();
    return const Locale('ar');
  }

  Future<void> _load() async {
    final savedCode = await ref.read(sessionStorageProvider).readLocaleCode();

    if (savedCode == 'ar' || savedCode == 'en') {
      state = Locale(savedCode!);
    }
  }

  Future<void> setLocale(String languageCode) async {
    if (languageCode != 'ar' && languageCode != 'en') {
      return;
    }

    state = Locale(languageCode);
    await ref.read(sessionStorageProvider).saveLocaleCode(languageCode);
  }

  Future<void> toggle() async {
    await setLocale(state.languageCode == 'ar' ? 'en' : 'ar');
  }
}
