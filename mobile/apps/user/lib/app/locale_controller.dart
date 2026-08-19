import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _localeStorageKey = 'app_locale';

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale>(
  (ref) => LocaleController(const FlutterSecureStorage())..restore(),
);

class LocaleController extends StateNotifier<Locale> {
  LocaleController(this._storage) : super(const Locale('ar'));

  final FlutterSecureStorage _storage;

  Future<void> restore() async {
    final saved = await _storage.read(key: _localeStorageKey);
    if (saved == 'en') state = const Locale('en');
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await _storage.write(key: _localeStorageKey, value: locale.languageCode);
  }
}
