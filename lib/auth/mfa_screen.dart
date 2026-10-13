import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MfaScreen extends StatefulWidget {
  const MfaScreen({
    super.key,
    required this.onVerified,
  });
  final Future<void> Function() onVerified;
  @override
  State<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen> {
  static const _mfaRequestTimeout = Duration(seconds: 15);
  final _client = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  bool _setupMode = false;
  String? _factorId;
  String? _secret;
  String? _error;
  @override
  void initState() {
    super.initState();
    _initializeMfa();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _initializeMfa() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _factorId = null;
      _secret = null;
      _setupMode = false;
    });
    try {
      if (_client.auth.currentSession == null) {
        throw StateError('Please sign in again.');
      }
      final assurance = _client.auth.mfa.getAuthenticatorAssuranceLevel();

      if (assurance.currentLevel == AuthenticatorAssuranceLevels.aal2) {
        if (!mounted) return;
        await widget.onVerified();
        return;
      }

      final factors = await _client.auth.mfa
          .listFactors()
          .timeout(_mfaRequestTimeout);

      if (factors.totp.isNotEmpty) {
        if (!mounted) return;

        setState(() {
          _factorId = factors.totp.first.id;
          _setupMode = false;
        });
      } else {
        final enrollment = await _client.auth.mfa
            .enroll(
              factorType: FactorType.totp,
              friendlyName: 'Gelye Sherane Employee',
            )
            .timeout(_mfaRequestTimeout);

        final totp = enrollment.totp;

        if (totp == null) {
          throw StateError(
            'Supabase did not return MFA setup details.',
          );
        }

        if (!mounted) return;

        setState(() {
          _factorId = enrollment.id;
          _secret = totp.secret;
          _setupMode = true;
        });
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = 'The MFA check timed out. Check your connection and retry.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to initialize MFA. '
            'Please check your connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    if (_submitting || _loading) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final factorId = _factorId;

    if (factorId == null) {
      setState(() {
        _error = 'MFA is not ready.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _client.auth.mfa
          .challengeAndVerify(
            factorId: factorId,
            code: _codeController.text.trim(),
          )
          .timeout(_mfaRequestTimeout);

      final assurance = _client.auth.mfa.getAuthenticatorAssuranceLevel();

      if (assurance.currentLevel != AuthenticatorAssuranceLevels.aal2) {
        throw StateError('MFA assurance not confirmed.');
      }

      if (!mounted) return;

      _codeController.clear();

      await widget.onVerified();
    } on TimeoutException {
      if (!mounted) return;
      final assurance = _client.auth.mfa.getAuthenticatorAssuranceLevel();
      if (assurance.currentLevel == AuthenticatorAssuranceLevels.aal2) {
        _codeController.clear();
        await widget.onVerified();
      } else {
        setState(() {
          _error =
              'MFA verification timed out. Check your connection, then retry.';
        });
      }
    } on AuthException catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Invalid or expired verification code. '
            'Please try again.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Verification failed. '
            'Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee MFA Security'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 430,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 72,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _setupMode
                        ? 'Set Up Two-Factor Authentication'
                        : 'Verify Your Identity',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _setupMode
                        ? 'Add this account to your '
                            'authenticator app using '
                            'the setup key below.'
                        : 'Enter the six-digit code '
                            'from your authenticator app.',
                    textAlign: TextAlign.center,
                  ),
                  if (_setupMode && _secret != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Authenticator Setup Key',
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _secret!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: _secret!),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Setup Key'),
                    ),
                    const Text(
                      'Keep this key private. '
                      'Do not share it with anyone.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _codeController,
                    enabled: !_submitting,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: '6-Digit MFA Code',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pin_outlined),
                      counterText: '',
                    ),
                    validator: (value) {
                      final code = value?.trim() ?? '';

                      if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                        return 'Enter a valid 6-digit code';
                      }

                      return null;
                    },
                    onFieldSubmitted: (_) {
                      _verifyCode();
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: _submitting ? null : _initializeMfa,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry MFA check'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _verifyCode,
                      icon: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.security,
                            ),
                      label: Text(
                        _submitting
                            ? 'Verifying...'
                            : _setupMode
                                ? 'Activate MFA'
                                : 'Verify & Continue',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'MFA is mandatory for every employee.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
