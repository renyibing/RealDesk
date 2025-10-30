import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'settings_model.dart';

class SettingsStore {
  static const _kKey = 'realdesk_settings_v1';

  static Future<RealDeskSettings> load() async {
    final pref = await SharedPreferences.getInstance();
    final s = pref.getString(_kKey);
    if (s == null || s.isEmpty) return RealDeskSettings();
    try {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return RealDeskSettings.fromMap(map);
    } catch (_) {
      return RealDeskSettings();
    }
  }

  static Future<void> save(RealDeskSettings settings) async {
    final pref = await SharedPreferences.getInstance();
    await pref.setString(_kKey, jsonEncode(settings.toMap()));
  }
}
