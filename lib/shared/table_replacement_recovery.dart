import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local, user-scoped recovery pointer. It is not proof of a commit.
class TableReplacementRecovery {
  static String _key(String userId) => 'table_replacement_pending_v1_$userId';

  static Future<void> save(String userId, Map<String, dynamic> request) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(_key(userId), jsonEncode(request));
    if (!ok) throw StateError('Could not persist replacement recovery identity');
  }

  static Future<Map<String, dynamic>?> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null) return null;
    final parsed = jsonDecode(raw);
    if (parsed is! Map<String, dynamic> || parsed['request_id'] is! String) {
      throw StateError('Stored replacement recovery record is invalid');
    }
    return parsed;
  }

  static Future<void> clear(String userId, String requestId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(_key(userId));
    if (current == null) return;
    final parsed = jsonDecode(current);
    if (parsed is Map && parsed['request_id'] == requestId) {
      final ok = await prefs.remove(_key(userId));
      if (!ok) throw StateError('Could not clear replacement recovery identity');
    }
  }
}
