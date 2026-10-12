import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  Future<Map<String, dynamic>?> getEmployeeProfile() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return null;
    }

    final profile = await _client
        .from('employee_profiles')
        .select('user_id, full_name, role, is_active')
        .eq('user_id', user.id)
        .maybeSingle();

    if (profile == null || profile['is_active'] != true) {
      return null;
    }

    return profile;
  }

  AuthService(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
