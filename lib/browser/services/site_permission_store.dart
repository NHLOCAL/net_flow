import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/site_permission_decision.dart';

class SitePermissionStore {
  SitePermissionStore(this._preferences);

  static const _key = 'site_permission_decisions';

  final SharedPreferences _preferences;
  Map<String, SitePermissionDecision>? _cache;

  SitePermissionDecision? get({
    required String origin,
    required SitePermissionResource resource,
  }) {
    return _load()[_decisionKey(origin, resource)];
  }

  Future<void> save(SitePermissionDecision decision) async {
    if (!decision.persist) {
      return;
    }

    final decisions = Map<String, SitePermissionDecision>.from(_load());
    decisions[_decisionKey(decision.origin, decision.resource)] = decision;
    _cache = decisions;
    await _preferences.setString(
      _key,
      jsonEncode(decisions.map(
        (key, value) => MapEntry(key, value.toJson()),
      )),
    );
  }

  Future<void> clearForOrigin(String origin) async {
    final decisions = Map<String, SitePermissionDecision>.from(_load());
    decisions.removeWhere((key, value) => value.origin == origin);
    _cache = decisions;
    await _preferences.setString(
      _key,
      jsonEncode(decisions.map(
        (key, value) => MapEntry(key, value.toJson()),
      )),
    );
  }

  List<SitePermissionDecision> all() {
    return _load().values.toList(growable: false);
  }

  Map<String, SitePermissionDecision> _load() {
    if (_cache != null) {
      return _cache!;
    }

    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) {
      _cache = <String, SitePermissionDecision>{};
      return _cache!;
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _cache = decoded.map((key, value) {
      return MapEntry(
        key,
        SitePermissionDecision.fromJson(
          Map<String, dynamic>.from(value as Map),
        ),
      );
    });
    return _cache!;
  }

  String _decisionKey(String origin, SitePermissionResource resource) {
    return '$origin::${resource.name}';
  }
}
