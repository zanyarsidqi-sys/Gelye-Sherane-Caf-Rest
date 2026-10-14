import 'dart:async';
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
  final Future<void> Function(Set<String> allowedSections) onAuthorized;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

enum _AuthStep {
  entrance,
  login,
  mfa,
  checking,
  verificationRetry,
  completed,
}

class _AuthGateState extends State<AuthGate> {
  static const _securityTimeout = Duration(seconds: 12);
  static const _cleanupTimeout = Duration(seconds: 3);
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
      if (session == null ||
          !await DeviceSessionPreference.allows(
            session,
          ).timeout(_securityTimeout)) {
        if (mounted) setState(() => _step = _AuthStep.entrance);
        return;
      }
      // A remembered device is convenience only: MFA and RLS are still required.
      final user = (await auth.getUser().timeout(_securityTimeout)).user;
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
      if (mounted) {
        unawaited(_clearUnverifiedDevicePreference());
        setState(() => _step = _AuthStep.entrance);
        _showSavedSessionFallback();
      }
    }
  }

  Future<void> _clearUnverifiedDevicePreference() async {
    try {
      await DeviceSessionPreference.clear().timeout(_cleanupTimeout);
    } catch (_) {
      // The employee sign-in flow remains available if local cleanup stalls.
    }
  }

  void _showSavedSessionFallback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not verify the saved employee session. Please sign in again.',
          ),
        ),
      );
    });
  }

  bool _finishing = false;
  String _verificationStage = 'not started';
  String? _verificationRetryMessage;
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

      final userResponse = await client.auth
          .getUser()
          .timeout(_securityTimeout);
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
        error is TimeoutException
            ? 'Employee login verification timed out. Please try again.'
            : 'Employee login verification failed.',
      );
    }
  }

  Future<void> _handleMfaVerified() async {
    if (!mounted ||
        _finishing ||
        !{_AuthStep.mfa, _AuthStep.verificationRetry}.contains(_step)) {
      return;
    }
    _finishing = true;

    setState(() {
      _step = _AuthStep.checking;
      _verificationRetryMessage = null;
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
      final userResponse = await client.auth
          .getUser()
          .timeout(_securityTimeout);
      final user = userResponse.user;

      if (user == null || client.auth.currentSession == null) {
        throw StateError('Employee session expired.');
      }

      // Read employee profile only after MFA succeeds.
      _verificationStage = 'active employee profile (RLS)';
      final profile = await _permissionService.getActiveEmployee()
          .timeout(_securityTimeout);

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
      final allowedSections = await _permissionService.getAllowedSections()
          .timeout(_securityTimeout);

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

      _verificationStage = 'management dashboard access';
      await widget.onAuthorized(allowedSections);
    } catch (error) {
      debugPrint('AUTH GATE MFA ERROR at $_verificationStage: $error');

      if (error is TimeoutException) {
        if (mounted) {
          setState(() {
            _step = _AuthStep.verificationRetry;
            _verificationRetryMessage =
                'The employee security check took too long. '
                'Your verified session is still protected. Retry the check '
                'when your connection is ready.';
          });
        }
        return;
      }

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
      try {
        await DeviceSessionPreference.clear().timeout(_cleanupTimeout);
      } catch (_) {}
      await Supabase.instance.client.auth
          .signOut(scope: SignOutScope.local)
          .timeout(_cleanupTimeout);
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

      case _AuthStep.verificationRetry:
        return Scaffold(
          appBar: AppBar(title: const Text('Employee security check')),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_tethering_error_rounded,
                      color: Colors.orange,
                      size: 56,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _verificationRetryMessage ??
                          'The employee security check needs another try.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            _finishing ? null : _handleMfaVerified,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry security check'),
                      ),
                    ),
                    TextButton(
                      onPressed: _finishing
                          ? null
                          : () => _denyAccess(
                              'You signed out of the employee session.',
                            ),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
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
