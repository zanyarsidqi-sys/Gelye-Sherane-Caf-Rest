import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_release.dart';

class AppReleaseService {
  final SupabaseClient _client = Supabase.instance.client;
  static const timeout = Duration(seconds: 15);
  String newRequestId() {
    final random = Random.secure();
    return List.generate(24, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
  String _sessionToken() {
    final auth = _client.auth;
    final session = auth.currentSession;
    if (session == null || auth.currentUser?.id != session.user.id ||
        auth.mfa.getAuthenticatorAssuranceLevel().currentLevel != AuthenticatorAssuranceLevels.aal2) {
      throw StateError('A verified MFA session is required.');
    }
    return session.accessToken;
  }
  Future<List<AppRelease>> list() async {
    final token = _sessionToken();
    final rows = await _client.from('gs_app_releases').select()
        .order('created_at', ascending: false).limit(100).timeout(timeout);
    if (_sessionToken() != token) throw StateError('Session changed. Refresh.');
    return rows.map((r) => AppRelease(Map<String, dynamic>.from(r))).toList();
  }
  Future<List<Map<String, dynamic>>> history(String id) async {
    final token = _sessionToken();
    final rows = await _client.from('gs_app_release_events').select()
        .eq('release_id', id).order('created_at', ascending: false).limit(100).timeout(timeout);
    if (_sessionToken() != token) throw StateError('Session changed. Refresh.');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }
  Future<void> create(Map<String, dynamic> draft, String requestId) async {
    final token = _sessionToken();
    await _client.rpc('gs_app_release_create', params: {
      'p_draft': draft, 'p_request_id': requestId,
    }).timeout(timeout);
    if (_sessionToken() != token) throw StateError('Session changed. Refresh release records.');
  }
  Future<void> transition(AppRelease release, String action, String reason,
      Map<String, bool> checks, String requestId) async {
    final token = _sessionToken();
    await _client.rpc('gs_app_release_transition', params: {
      'p_id': int.parse(release.id), 'p_revision': release.revision,
      'p_action': action, 'p_reason': reason, 'p_checks': checks,
      'p_request_id': requestId,
    }).timeout(timeout);
    if (_sessionToken() != token) throw StateError('Session changed. Refresh release records.');
  }
}
