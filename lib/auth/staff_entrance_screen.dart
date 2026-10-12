import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffEntranceScreen extends StatefulWidget {
  const StaffEntranceScreen({
    super.key,
    required this.onContinue,
  });
  final VoidCallback onContinue;
  @override
  State<StaffEntranceScreen> createState() => _StaffEntranceScreenState();
}

class _StaffEntranceScreenState extends State<StaffEntranceScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  bool _obscureCode = true;
  bool _isLoading = false;
  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _continue() async {
    if (_isLoading) return;
    final form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final code = _codeController.text.trim();

      final response = await Supabase.instance.client.functions.invoke(
        'verify-staff-entrance',
        body: <String, dynamic>{
          'code': code,
        },
      );

      if (!mounted) return;

      final dynamic data = response.data;

      final bool verified =
          response.status == 200 && data is Map && data['verified'] == true;

      if (!verified) {
        _showMessage(
          'Invalid staff entrance code.',
          isError: true,
        );
        return;
      }

      _codeController.clear();

      _showMessage(
        'Staff entrance verified successfully.',
      );

      widget.onContinue();
    } on FunctionException catch (error) {
      if (!mounted) return;

      final status = error.status;

      if (status == 401 || status == 403) {
        _showMessage(
          'Invalid or unauthorized entrance code.',
          isError: true,
        );
      } else if (status == 429) {
        _showMessage(
          'Too many attempts. Please try again later.',
          isError: true,
        );
      } else {
        _showMessage(
          'Server verification failed. Please try again.',
          isError: true,
        );
      }
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Unable to verify staff entrance. '
        'Check your connection and try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Private Staff Entrance',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 76,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Gelye Sherane Cafe & Restaurant',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Authorized Employees Only',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _codeController,
                      enabled: !_isLoading,
                      obscureText: _obscureCode,
                      obscuringCharacter: '•',
                      maxLength: 128,
                      // The following line sets the action button on the keyboard to "done".
                      textInputAction: TextInputAction.done,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: const [
                        AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Staff Entrance Code',
                        hintText: 'Enter your entrance code',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(
                          Icons.password_outlined,
                        ),
                        suffixIcon: IconButton(
                          tooltip: _obscureCode ? 'Show code' : 'Hide code',
                          onPressed: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _obscureCode = !_obscureCode;
                                  });
                                },
                          icon: Icon(
                            _obscureCode
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter the staff entrance code';
                        }

                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (!_isLoading) {
                          _continue();
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _continue,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.login,
                              ),
                        label: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _isLoading ? 'Verifying...' : 'Continue',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Your entrance code will be '
                      'verified by the server before '
                      'employee login.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
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
