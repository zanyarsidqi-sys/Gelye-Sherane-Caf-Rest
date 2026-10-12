import 'package:supabase_flutter/supabase_flutter.dart';

/// Cloud-backed employee Dashboard settings. The server, not the client,
/// chooses the employee ID from the authenticated session.
class DashboardCloudPreferences {
  SupabaseClient get _client => Supabase.instance.client;

  Future<Map<String, dynamic>?> load() async {
    if (_client.auth.currentUser == null) return null;
    final value = await _client.rpc('gs_dashboard_preferences_get');
    if (value == null) return null;
    return Map<String, dynamic>.from(value as Map);
  }

  Future<void> save(Map<String, dynamic> preferences) async {
    if (_client.auth.currentUser == null) return;
    await _client.rpc('gs_dashboard_preferences_save',
        params: {'p_preferences': preferences});
  }
}
