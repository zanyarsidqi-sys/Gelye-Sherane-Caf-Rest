import 'device_session_preference.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'employee_permission_service.dart';

class SavedSessionResult {
  const SavedSessionResult({
    required this.authorized,
    this.allowedSections = const <String>{},
  });
  final bool authorized;
  final Set<String> allowedSections;
}

class SavedSessionService {
  SavedSessionService({
    SupabaseClient? client,
    Duration requestTimeout = const Duration(seconds: 12),
  }) : _client = client ?? Supabase.instance.client,
       _permissions = EmployeePermissionService(
         client: client,
         requestTimeout: requestTimeout,
       ),
       _requestTimeout = requestTimeout;

  final SupabaseClient _client;
  final EmployeePermissionService _permissions;
  final Duration _requestTimeout;
  Future<SavedSessionResult> restoreSession() async {
    try {
      // Step 1: Check the saved Supabase session.
      final session = _client.auth.currentSession;
      final originalSessionId = DeviceSessionPreference.sessionId(session);
      if (session == null || !await DeviceSessionPreference.allows(session)) {
        debugPrint('Saved Session: No session found.');
        return const SavedSessionResult(authorized: false);
      }

      // Step 2: Verify the authenticated user.
      final response = await _client.auth.getUser().timeout(_requestTimeout);
      final user = response.user;

      if (user == null ||
          user.id != session.user.id ||
          DeviceSessionPreference.sessionId(_client.auth.currentSession) != originalSessionId) {
        debugPrint('Saved Session: No authenticated user.');
        return const SavedSessionResult(authorized: false);
      }

      // Step 3: Verify MFA.
      final assurance = _client.auth.mfa.getAuthenticatorAssuranceLevel();

      if (assurance.currentLevel != AuthenticatorAssuranceLevels.aal2) {
        debugPrint('Saved Session: MFA verification required.');
        return const SavedSessionResult(authorized: false);
      }

      // Step 4: Verify employee profile.
      final profile = await _permissions.getActiveEmployee();

      if (profile == null ||
          profile['user_id'] != user.id ||
          profile['is_active'] != true) {
        debugPrint('Saved Session: Employee not authorized.');
        return const SavedSessionResult(authorized: false);
      }

      // Step 5: Confirm the same authenticated identity survived the async checks.
      if (_client.auth.currentUser?.id != user.id ||
          _client.auth.currentSession == null ||
          _client.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel !=
              AuthenticatorAssuranceLevels.aal2) {
        return const SavedSessionResult(authorized: false);
      }

      // Step 6: Reload current permissions.
      final sections = await _permissions.getAllowedSections();

      if (sections.isEmpty ||
          !sections.contains('dashboard') ||
          _client.auth.currentUser?.id != user.id ||
          _client.auth.currentSession == null ||
          DeviceSessionPreference.sessionId(_client.auth.currentSession) != originalSessionId ||
          _client.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel !=
              AuthenticatorAssuranceLevels.aal2) {
        debugPrint('Saved Session: No authorized sections.');
        return const SavedSessionResult(authorized: false);
      }

      debugPrint('Saved Session: Authorized with ${sections.length} sections.');

      return SavedSessionResult(authorized: true, allowedSections: sections);
    } catch (error) {
      debugPrint('Saved Session: Verification failed: ${error.runtimeType}');

      return const SavedSessionResult(authorized: false);
    }
  }
}
