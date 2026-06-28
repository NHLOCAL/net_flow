import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryStore {
  SearchHistoryStore(this._preferences);

  static const key = 'search_history';
  static const maxItems = 8;

  final SharedPreferences _preferences;

  List<String> load() {
    final raw = _preferences.getString(key);
    if (raw == null || raw.isEmpty) {
      return <String>[];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .take(maxItems)
        .toList(growable: false);
  }

  Future<List<String>> remember(String input) async {
    final query = input.trim();
    if (query.isEmpty) {
      return load();
    }

    final next = <String>[
      query,
      ...load().where((item) => item != query),
    ].take(maxItems).toList(growable: false);

    await _preferences.setString(key, jsonEncode(next));
    return next;
  }
}
