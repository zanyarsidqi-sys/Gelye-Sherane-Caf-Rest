import 'browser_push.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Device convenience preference, never a substitute for server authorization.
/// Contains no passwords or tokens. Supabase owns credential persistence.
class DeviceSessionPreference {
  static const _key = 'cafe_rest_device_session_v1';
  static Map<String, dynamic>? _memory;
  static Timer? _expiryTimer;
  static int? get expiresAtMilliseconds => _memory?['expires'] as int?;

  static String? sessionId(Session? session) {
    try {
      if (session == null) return null;
      final parts = session.accessToken.split('.');
      if (parts.length != 3) return null;
      final claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final id = claims['session_id'];
      return id is String && id.isNotEmpty ? id : null;
    } catch (_) { return null; }
  }

  static bool accepts(Map<String, dynamic>? record, String userId,
      String? sessionId, DateTime now) {
    if (record == null || sessionId == null || record['user'] != userId ||
        record['session'] != sessionId) return false;
    final mode = record['mode'];
    if (mode != 'runtime' && mode != 'timed' && mode != 'logout') return false;
    final expiry = record['expires'];
    if (mode == 'timed') {
      return expiry is int && now.toUtc().millisecondsSinceEpoch < expiry;
    }
    return expiry == null;
  }

  static Future<void> save(Session session, int hours) async {
    // 0 = this running app only; -1 = until logout; positive = fixed hours.
    if (hours < -1 || hours > 8760) throw ArgumentError('Invalid duration');
    final id = sessionId(session);
    if (id == null) throw StateError('Session identity unavailable');
    final record = <String, dynamic>{
      'user': session.user.id, 'session': id,
      'mode': hours == 0 ? 'runtime' : hours == -1 ? 'logout' : 'timed',
      'expires': hours > 0 ? DateTime.now().toUtc().add(Duration(hours: hours)).millisecondsSinceEpoch : null,
    };
    final prefs = await SharedPreferences.getInstance();
    // Remove a previous login preference before accepting a new login.
    if (!await prefs.remove(_key)) throw StateError('Unable to clear saved device');
    _memory = null;
    _expiryTimer?.cancel();
    if (hours != 0 && !await prefs.setString(_key, jsonEncode(record))) {
      throw StateError('Unable to remember this device');
    }
    // A sign-out or account switch during the asynchronous preference write
    // must never leave the previous employee remembered on this device.
    final current = Supabase.instance.client.auth.currentSession;
    if (current?.user.id != session.user.id || sessionId(current) != id) {
      if (hours != 0) await prefs.remove(_key);
      _memory = null;
      throw StateError('Session changed while saving device preference');
    }
    _memory = record;
    _scheduleExpiry(record);
  }

  static Future<bool> allows(Session? session) async {
    if (session == null) return false;
    try {
      // Reload on each access check so another tab's logout is respected.
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString(_key);
      final record = _memory?['mode'] == 'runtime' ? _memory :
          raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final allowed = accepts(record, session.user.id, sessionId(session), DateTime.now());
      if (allowed && record != null) {
        _memory = record;
        _scheduleExpiry(record);
      }
      return allowed;
    } catch (_) { return false; }
  }

  static void _scheduleExpiry(Map<String, dynamic> record) {
    _expiryTimer?.cancel();
    final expires = record['expires'];
    if (expires is! int) return;
    final delay = DateTime.fromMillisecondsSinceEpoch(expires, isUtc: true).difference(DateTime.now().toUtc());
    _expiryTimer = Timer(delay.isNegative ? Duration.zero : delay, () async {
      final auth = Supabase.instance.client.auth;
      if (auth.currentUser?.id != record['user'] || sessionId(auth.currentSession) != record['session']) return;
      try {
        try { await disableBrowserPush(); } catch (_) {}
        await clear();
        await auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        // Access guards also reject the expired preference if offline.
      }
    });
  }

  static Future<void> clear() async {
    _expiryTimer?.cancel();
    _memory = null;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(_key)) throw StateError('Unable to clear saved device');
  }
}
