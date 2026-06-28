import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/browser_settings.dart';

class SettingsStore {
  SettingsStore(this._preferences);

  static const _key = 'browser_settings';

  final SharedPreferences _preferences;

  BrowserSettings load() {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) {
      return const BrowserSettings.defaults();
    }

    return BrowserSettings.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  Future<void> save(BrowserSettings settings) async {
    await _preferences.setString(_key, jsonEncode(settings.toJson()));
  }
}
