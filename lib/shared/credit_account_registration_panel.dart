import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registration only. Accounts and barcode links remain pending verification.
class CreditAccountRegistrationPanel extends StatefulWidget {
  const CreditAccountRegistrationPanel({super.key});

  @override
  State<CreditAccountRegistrationPanel> createState() =>
      _CreditAccountRegistrationPanelState();
}

class _CreditAccountRegistrationPanelState
    extends State<CreditAccountRegistrationPanel> {
  final _customerReference = TextEditingController();
  final _displayName = TextEditingController();
  final _accountReference = TextEditingController();
  final _registryId = TextEditingController();
  final _accountId = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    for (final c in [
      _customerReference, _displayName, _accountReference, _registryId, _accountId
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (_busy) return;
    setState(() { _busy = true; _message = null; });
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_register_credit_account', params: {
          'p_customer_reference': _customerReference.text.trim(),
          'p_display_name': _displayName.text.trim(),
          'p_account_reference': _accountReference.text.trim(),
        });
      if (!mounted) return;
      _accountId.text = result.toString();
      setState(() => _message = 'Pending account created: $result. '
          'No credit limit or payment authorization has been granted.');
    } catch (e) {
      if (mounted) setState(() => _message = 'Registration failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _link() async {
    if (_busy) return;
    setState(() { _busy = true; _message = null; });
    try {
      await Supabase.instance.client.rpc(
        'gs_staff_link_credit_barcode_pending', params: {
          'p_registry_id': _registryId.text.trim(),
          'p_account_id': _accountId.text.trim(),
        });
      if (mounted) setState(() => _message =
          'Barcode linked as pending. Ownership is not verified.');
    } catch (e) {
      if (mounted) setState(() => _message = 'Link failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Credit Account Registration',
          style: Theme.of(context).textTheme.titleMedium),
        const Text('Pending registration only. No credit balances, limits, '
          'ownership verification, or payments are activated.'),
        TextField(controller: _customerReference,
          decoration: const InputDecoration(labelText: 'Customer reference')),
        TextField(controller: _displayName,
          decoration: const InputDecoration(labelText: 'Customer display name')),
        TextField(controller: _accountReference,
          decoration: const InputDecoration(labelText: 'Credit account reference')),
        const SizedBox(height: 8),
        FilledButton(onPressed: _busy ? null : _register,
          child: const Text('Register Pending Account')),
        const Divider(),
        TextField(controller: _registryId,
          decoration: const InputDecoration(labelText: 'Existing barcode registry UUID')),
        TextField(controller: _accountId,
          decoration: const InputDecoration(labelText: 'Pending credit account UUID')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _busy ? null : _link,
          child: const Text('Link Barcode as Pending')),
        if (_message != null) Padding(
          padding: const EdgeInsets.only(top: 8), child: Text(_message!)),
      ]),
    ),
  );
}
