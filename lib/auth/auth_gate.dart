import '../services/device_session_preference.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/employee_permission_service.dart';
import 'employee_login_screen.dart';
import 'mfa_screen.dart';
import 'staff_entrance_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.onAuthorized,
  });
  final void Function(Set<String> allowedSections) onAuthorized;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

enum _AuthStep {
  entrance,
  login,
  mfa,
  checking,
  completed,
}

class _AuthGateState extends State<AuthGate> {
  final EmployeePermissionService _permissionService =
      EmployeePermissionService();
  _AuthStep _step = _AuthStep.checking;

  @override
  void initState() {
    super.initState();
    _restoreRememberedDevice();
  }

  Future<void> _restoreRememberedDevice() async {
    try {
      final auth = Supabase.instance.client.auth;
      final session = auth.currentSession;
      if (session == null || !await DeviceSessionPreference.allows(session)) {
        if (mounted) setState(() => _step = _AuthStep.entrance);
        return;
      }
      // A remembered device is convenience only: MFA and RLS are still required.
      final user = (await auth.getUser()).user;
      if (user == null || user.id != session.user.id) {
        if (mounted) setState(() => _step = _AuthStep.entrance);
        return;
      }
      if (!mounted) return;
      if (auth.mfa.getAuthenticatorAssuranceLevel().currentLevel ==
          AuthenticatorAssuranceLevels.aal2) {
        setState(() => _step = _AuthStep.mfa);
        await _handleMfaVerified();
      } else {
        setState(() => _step = _AuthStep.mfa);
      }
    } catch (_) {
      if (mounted) setState(() => _step = _AuthStep.entrance);
    }
  }

  bool _finishing = false;
  String _verificationStage = 'not started';
  void _openEmployeeLogin() {
    if (!mounted || _step != _AuthStep.entrance) {
      return;
    }
    setState(() {
      _step = _AuthStep.login;
    });
  }

  Future<void> _handleLoginSuccess() async {
    if (!mounted || _step != _AuthStep.login) {
      return;
    }
    setState(() {
      _step = _AuthStep.checking;
    });

    try {
      final client = Supabase.instance.client;

      final userResponse = await client.auth.getUser();
      final user = userResponse.user;

      if (user == null || client.auth.currentSession == null) {
        throw StateError('Employee session not found.');
      }

      // Do not read employee_profiles here.
      // Supabase RLS requires MFA before profile access.

      if (!mounted) return;

      setState(() {
        _step = _AuthStep.mfa;
      });
    } catch (error) {
      debugPrint('AUTH GATE LOGIN ERROR: $error');

      await _denyAccess(
        'Employee login verification failed.',
      );
    }
  }

  Future<void> _handleMfaVerified() async {
    if (!mounted || _finishing || _step != _AuthStep.mfa) {
      return;
    }
    _finishing = true;

    setState(() {
      _step = _AuthStep.checking;
    });

    try {
      final client = Supabase.instance.client;

      _verificationStage = 'MFA assurance level';
      // Require completed MFA.
      final assurance = client.auth.mfa.getAuthenticatorAssuranceLevel();

      if (assurance.currentLevel != AuthenticatorAssuranceLevels.aal2) {
        throw StateError('MFA verification is required.');
      }

      _verificationStage = 'authenticated employee session';
      final userResponse = await client.auth.getUser();
      final user = userResponse.user;

      if (user == null || client.auth.currentSession == null) {
        throw StateError('Employee session expired.');
      }

      // Read employee profile only after MFA succeeds.
      _verificationStage = 'active employee profile (RLS)';
      final profile = await _permissionService.getActiveEmployee();

      if (profile == null ||
          profile['user_id'] != user.id ||
          profile['is_active'] != true) {
        throw StateError(
          'Employee account is not authorized.',
        );
      }

      // Diagnostic only: do not print JWTs, passwords, MFA codes, or user IDs.
      final permissionAssurance =
          client.auth.mfa.getAuthenticatorAssuranceLevel();
      debugPrint(
        'AUTH CHECK: current=${permissionAssurance.currentLevel}, '
        'next=${permissionAssurance.nextLevel}, '
        'userPresent=${client.auth.currentUser != null}',
      );

      _verificationStage = 'section permissions (RLS)';
      final allowedSections = await _permissionService.getAllowedSections();

      _verificationStage = 'dashboard permission';
      if (!allowedSections.contains('dashboard')) {
        throw StateError('Dashboard view permission was not returned.');
      }

      if (allowedSections.isEmpty) {
        throw StateError(
          'No management sections assigned.',
        );
      }

      if (!mounted) return;

      setState(() {
        _step = _AuthStep.completed;
      });

      widget.onAuthorized(allowedSections);
    } catch (error) {
      debugPrint('AUTH GATE MFA ERROR at $_verificationStage: $error');

      await _denyAccess(
        'Security verification failed at $_verificationStage. '
        'Management access remains locked.',
      );
    } finally {
      _finishing = false;
    }
  }

  Future<void> _denyAccess(String message) async {
    try {
      try { await DeviceSessionPreference.clear(); } catch (_) {}
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (error) {
      debugPrint('AUTH GATE SIGN OUT ERROR: $error');
    }
    if (!mounted) return;

    setState(() {
      _step = _AuthStep.login;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _backToEntrance() {
    if (!mounted || _step != _AuthStep.login) {
      return;
    }
    setState(() {
      _step = _AuthStep.entrance;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _AuthStep.entrance:
        return StaffEntranceScreen(
          onContinue: _openEmployeeLogin,
        );
      case _AuthStep.login:
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              _backToEntrance();
            }
          },
          child: EmployeeLoginScreen(
            onLoginSuccess: _handleLoginSuccess,
          ),
        );

      case _AuthStep.mfa:
        return PopScope(
          canPop: false,
          child: MfaScreen(
            onVerified: _handleMfaVerified,
          ),
        );

      case _AuthStep.checking:
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Checking employee security...'),
              ],
            ),
          ),
        );

      case _AuthStep.completed:
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user,
                  color: Colors.green,
                  size: 64,
                ),
                SizedBox(height: 16),
                Text(
                  'Authentication completed.',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Management dashboard integration '
                  'is pending.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
    }
  }
}
