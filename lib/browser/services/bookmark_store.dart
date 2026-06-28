import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/bookmark.dart';

class BookmarkStore {
  BookmarkStore(this._preferences);

  static const _key = 'bookmarks';

  final SharedPreferences _preferences;

  List<Bookmark> load() {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) {
      return <Bookmark>[];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Bookmark.fromJson(Map<String, dynamic>.from(item)))
        .where((bookmark) => bookmark.url.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> save(List<Bookmark> bookmarks) async {
    await _preferences.setString(
      _key,
      jsonEncode(bookmarks.map((bookmark) => bookmark.toJson()).toList()),
    );
  }
}
