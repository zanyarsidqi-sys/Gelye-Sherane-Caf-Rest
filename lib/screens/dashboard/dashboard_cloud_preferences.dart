import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardPreferenceSnapshot {
  const DashboardPreferenceSnapshot({
    required this.preferences,
    required this.revision,
  });

  final Map<String, dynamic> preferences;
  final int revision;

  factory DashboardPreferenceSnapshot.fromJson(Object? value) {
    if (value is! Map ||
        value['preferences'] is! Map ||
        value['revision'] is! int ||
        (value['revision'] as int) < 0) {
      throw const FormatException('Invalid Dashboard preference snapshot');
    }
    return DashboardPreferenceSnapshot(
      preferences: Map<String, dynamic>.from(value['preferences'] as Map),
      revision: value['revision'] as int,
    );
  }
}

class DashboardPreferencesConflict implements Exception {
  const DashboardPreferencesConflict();
}

/// Cloud-backed employee Dashboard settings. The server, not the client,
/// chooses the employee ID from the authenticated session.
class DashboardCloudPreferences {
  SupabaseClient get _client => Supabase.instance.client;

  Future<DashboardPreferenceSnapshot> load() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Dashboard sign-in required');
    final value = await _client
        .rpc('gs_dashboard_preferences_get')
        .timeout(const Duration(seconds: 20));
    if (_client.auth.currentUser?.id != userId) {
      throw StateError('Dashboard account changed during preference sync');
    }
    return DashboardPreferenceSnapshot.fromJson(value);
  }

  Future<DashboardPreferenceSnapshot> save({
    required Map<String, dynamic> preferences,
    required int expectedRevision,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Dashboard sign-in required');
    if (expectedRevision < 0) {
      throw ArgumentError.value(expectedRevision, 'expectedRevision');
    }
    try {
      final value = await _client
          .rpc(
            'gs_dashboard_preferences_save',
            params: {
              'p_preferences': preferences,
              'p_expected_revision': expectedRevision,
            },
          )
          .timeout(const Duration(seconds: 20));
      if (_client.auth.currentUser?.id != userId) {
        throw StateError('Dashboard account changed during preference sync');
      }
      return DashboardPreferenceSnapshot.fromJson(value);
    } on PostgrestException catch (error) {
      if (error.code == '40001') {
        throw const DashboardPreferencesConflict();
      }
      rethrow;
    }
  }
}
