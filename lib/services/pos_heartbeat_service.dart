import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Foreground-only heartbeat for a specifically selected, manager-bound POS.
/// This identifies a selected registration, NOT cryptographically attested hardware.
class PosHeartbeatService {
  final SupabaseClient _client = Supabase.instance.client;

  String? get _prefix {
    final user = _client.auth.currentUser;
    return user == null ? null : 'gelye_cafe_rest_pos_device_v3_${user.id}';
  }

  Future<int?> selectedDeviceId() async {
    final prefix = _prefix;
    if (prefix == null || kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    return (await SharedPreferences.getInstance()).getInt('${prefix}_id');
  }

  Future<void> selectDevice(int id) async {
    final prefix = _prefix;
    if (prefix == null || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw StateError('Device selection requires an authenticated Android app.');
    }
    final rows = await _client.rpc('gs_my_bound_cafe_pos_devices');
    if (!(rows as List).any((row) => row['id'] == id)) {
      throw StateError('This device is not assigned to your account.');
    }
    // A network request may finish after sign-out or account switching.
    if (_prefix != prefix) {
      throw StateError('Employee changed during POS device selection.');
    }
    final prefs = await SharedPreferences.getInstance();
    if (_prefix != prefix) {
      throw StateError('Employee changed before saving POS device selection.');
    }
    await prefs.setInt('${prefix}_id', id);
    await prefs.setBool('${prefix}_enabled', true);
  }

  Future<bool> isEnabledForCurrentUser() async {
    final prefix = _prefix;
    if (prefix == null || kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${prefix}_enabled') == true && prefs.getInt('${prefix}_id') != null;
  }

  Future<void> setEnabledForCurrentUser(bool enabled) async {
    final prefix = _prefix;
    if (prefix == null || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw StateError('Automatic POS heartbeat requires an authenticated Android app.');
    }
    final prefs = await SharedPreferences.getInstance();
    if (enabled && prefs.getInt('${prefix}_id') == null) {
      throw StateError('Select an assigned POS device before enabling heartbeats.');
    }
    await prefs.setBool('${prefix}_enabled', enabled);
  }

  Future<void> sendIfOptedIn() async {
    final originalPrefix = _prefix;
    if (originalPrefix == null || !await isEnabledForCurrentUser()) return;
    final id = await selectedDeviceId();
    if (id == null || _prefix != originalPrefix) return;
    try {
      await _client.rpc('gs_cafe_pos_heartbeat_for_device', params: {'p_device_id': id});
    } catch (error) {
      debugPrint('Selected POS heartbeat failed: $error');
    }
  }
}
