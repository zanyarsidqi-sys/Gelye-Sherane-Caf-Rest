import 'device_session_preference.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SectionPermission {
  final bool canView;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;

  const SectionPermission({
    required this.canView,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
  });
}

class EmployeePermissionService {
  EmployeePermissionService({
    SupabaseClient? client,
    Duration requestTimeout = const Duration(seconds: 12),
  }) : _client = client ?? Supabase.instance.client,
       _requestTimeout = requestTimeout;

  final SupabaseClient _client;
  final Duration _requestTimeout;

  Session _requireAuthenticatedAal2() {
    final user = _client.auth.currentUser;
    final session = _client.auth.currentSession;
    if (user == null || session == null || session.user.id != user.id) {
      throw StateError('No authenticated employee session.');
    }

    final assurance = _client.auth.mfa.getAuthenticatorAssuranceLevel();
    debugPrint(
      'AUTH DIAGNOSTIC: authenticated=true, '
      'currentAal=${assurance.currentLevel}, nextAal=${assurance.nextLevel}',
    );
    if (assurance.currentLevel != AuthenticatorAssuranceLevels.aal2) {
      throw StateError('MFA verification (AAL2) is required.');
    }
    return session;
  }

  void _requireSameSession(Session expected) {
    final current = _requireAuthenticatedAal2();
    // Reject stale results even if the same employee signs in again. A token
    // refresh during a lookup also requires a fresh lookup, never a stale grant.
    if (current.user.id != expected.user.id ||
        current.accessToken != expected.accessToken) {
      throw StateError('Employee session changed. Verify access again.');
    }
  }

  Future<Map<String, dynamic>?> getActiveEmployee() async {
    final session = _requireAuthenticatedAal2();
    if (!await DeviceSessionPreference.allows(
      session,
    ).timeout(_requestTimeout)) {
      throw StateError('Saved device session ended. Sign in again.');
    }
    final userId = session.user.id;
    try {
      final profile = await _client
          .from('employee_profiles')
          .select('user_id, full_name, role, is_active')
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(_requestTimeout);
      _requireSameSession(session);
      debugPrint(
        'PROFILE DIAGNOSTIC: found=${profile != null}, '
        'active=${profile?['is_active'] == true}',
      );
      if (profile == null ||
          profile['is_active'] != true ||
          profile['user_id'] != userId) {
        return null;
      }
      return profile;
    } on PostgrestException catch (e) {
      debugPrint('PROFILE QUERY ERROR: code=${e.code}, message=${e.message}');
      rethrow;
    }
  }

  Future<Map<String, SectionPermission>> getSectionPermissions() async {
    final session = _requireAuthenticatedAal2();
    final userId = session.user.id;
    final profile = await getActiveEmployee();
    _requireSameSession(session);
    if (profile == null) {
      throw StateError(
        'Active employee profile was not returned. '
        'Check profile ownership, activation, and RLS.',
      );
    }

    try {
      final rows = await _client
          .from('employee_section_permissions')
          .select('section_key, can_view, can_create, can_edit, can_delete')
          .eq('user_id', userId)
          .timeout(_requestTimeout);
      _requireSameSession(session);

      final permissions = <String, SectionPermission>{};
      for (final row in rows) {
        final rawKey = row['section_key'];
        if (rawKey is! String || rawKey.trim().isEmpty) continue;
        final key = rawKey.trim().toLowerCase();
        if (permissions.containsKey(key)) {
          throw StateError('Duplicate section permission key: $key');
        }
        permissions[key] = SectionPermission(
          canView: row['can_view'] == true,
          canCreate: row['can_create'] == true,
          canEdit: row['can_edit'] == true,
          canDelete: row['can_delete'] == true,
        );
      }

      debugPrint(
        'PERMISSIONS DIAGNOSTIC: rows=${rows.length}, '
        'dashboardRow=${permissions.containsKey('dashboard')}, '
        'dashboardCanView=${permissions['dashboard']?.canView}',
      );

      if (rows.isEmpty) {
        throw StateError(
          'No employee permission rows visible to this '
          'authenticated user. Verify user ID and Supabase RLS policies.',
        );
      }
      return permissions;
    } on PostgrestException catch (e) {
      debugPrint(
        'PERMISSIONS QUERY ERROR: code=${e.code}, '
        'message=${e.message}',
      );
      rethrow;
    }
  }

  Future<Set<String>> getAllowedSections() async {
    final permissions = await getSectionPermissions();
    final allowed = permissions.entries
        .where((entry) => entry.value.canView)
        .map((entry) => entry.key)
        .toSet();
    debugPrint(
      'PERMISSIONS DIAGNOSTIC: '
      'dashboardAllowed=${allowed.contains('dashboard')}, '
      'allowedCount=${allowed.length}',
    );
    return allowed;
  }
}
