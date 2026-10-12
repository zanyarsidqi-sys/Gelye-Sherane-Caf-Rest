import '../services/device_session_preference.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeLoginScreen extends StatefulWidget {
  const EmployeeLoginScreen({
    super.key,
    required this.onLoginSuccess,
  });

  final Future<void> Function() onLoginSuccess;

  @override
  State<EmployeeLoginScreen> createState() => _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends State<EmployeeLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  int _rememberHours = 0;
  final _customHours = TextEditingController(text: '48');
  bool _loading = false;
  bool _hidePassword = true;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void dispose() {
    _customHours.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
  }

  Future<void> _safeSignOut() async {
    try {
      try { await DeviceSessionPreference.clear(); } catch (_) {}
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // Cleanup errors must not replace the original login error.
    }
  }

  Future<void> _signIn() async {
    if (!mounted || _loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final response = await _client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user == null || response.session == null) {
        throw StateError('Authentication was not completed.');
      }

      final hours = _rememberHours == -2 ? int.parse(_customHours.text.trim()) : _rememberHours;
      await DeviceSessionPreference.save(response.session!, hours);
      if (!mounted) return;
      // The caller can verify employee access and navigate after success.
      // If that verification throws, the failure handler clears the session.
      await widget.onLoginSuccess();
    } on AuthException catch (_) {
      await _safeSignOut();
      _showError(
        'Sign in failed. Check your credentials or contact an administrator.',
      );
    } catch (_) {
      await _safeSignOut();
      _showError(
        'Employee login failed or access could not be verified. '
        'Please try again or contact an administrator.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Employee Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_person_outlined, size: 70),
                    const SizedBox(height: 20),
                    const Text(
                      'Gelye Sherane Cafe & Restaurant',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_loading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Employee Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Enter your email';
                        if (!_emailPattern.hasMatch(email)) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_loading,
                      obscureText: _hidePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip:
                              _hidePassword ? 'Show password' : 'Hide password',
                          onPressed: _loading
                              ? null
                              : () => setState(
                                    () => _hidePassword = !_hidePassword,
                                  ),
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter your password';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _signIn(),
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<int>(
                      initialValue: _rememberHours,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Remember this device',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Only while this app stays open')),
                        DropdownMenuItem(value: 1, child: Text('1 hour')),
                        DropdownMenuItem(value: 8, child: Text('8 hours')),
                        DropdownMenuItem(value: 24, child: Text('24 hours')),
                        DropdownMenuItem(value: 168, child: Text('7 days')),
                        DropdownMenuItem(value: 720, child: Text('30 days')),
                        DropdownMenuItem(value: -2, child: Text('Custom duration')),
                        DropdownMenuItem(value: -1, child: Text('Until I log out')),
                      ],
                      onChanged: _loading ? null : (value) => setState(() => _rememberHours = value ?? 0),
                    ),
                    if (_rememberHours == -2) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _customHours,
                        enabled: !_loading,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Hours (1–8760)'),
                        validator: (value) {
                          final hours = int.tryParse(value?.trim() ?? '');
                          return hours == null || hours < 1 || hours > 8760
                              ? 'Enter 1–8760 hours' : null;
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text('Use remembered login on your own device. Section access is checked automatically. Server session limits still apply.'),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _signIn,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Sign In'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Management dashboard access remains disabled until '
                      'MFA and server-side authorization checks are complete.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
