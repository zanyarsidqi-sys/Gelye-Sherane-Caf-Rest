import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// For authenticated customer screens only. Acknowledgement is not identity verification.
class CreditIdentityCustomerAcknowledgementPanel extends StatefulWidget {
  const CreditIdentityCustomerAcknowledgementPanel({super.key});
  @override
  State<CreditIdentityCustomerAcknowledgementPanel> createState() =>
      _CreditIdentityCustomerAcknowledgementPanelState();
}

class _CreditIdentityCustomerAcknowledgementPanelState
    extends State<CreditIdentityCustomerAcknowledgementPanel> {
  bool loading = false;
  String? error;
  List<Map<String, dynamic>> requests = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (loading) return;
    setState(() { loading = true; error = null; });
    try {
      final data = await Supabase.instance.client.rpc(
        'gs_credit_my_identity_onboarding_responses_v2');
      if (mounted) setState(() => requests = (data as List)
        .map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) {
      if (mounted) setState(() => error = 'Unable to load identity requests: $e');
    } finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> _respond(String requestId, String response) async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: Text(response == 'disputed' ? 'Dispute identity request?' : 'Acknowledge identity request?'),
        content: const Text('This records your response only. It does NOT verify your identity, '
          'approve a credit account, authorize an invoice, or allow a payment. '
          'Disputing automatically places a safety hold on this request.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ));
    if (confirmed != true || !mounted) return;
    setState(() { loading = true; error = null; });
    try {
      await Supabase.instance.client.rpc('gs_credit_respond_to_identity_onboarding',
        params: {'p_request_id': requestId, 'p_response': response});
    } catch (e) {
      if (mounted) setState(() => error = 'Response not recorded: $e');
    } finally { if (mounted) setState(() => loading = false); }
    await _load();
  }

  Future<void> _raiseSafetyHold(String requestId) async {
    final reason = TextEditingController();
    try {
      final explanation = await showDialog<String>(context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Report identity safety concern'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Use this if the identity request is incorrect, suspicious, or no longer authorized. This blocks further identity review. It does not cancel an invoice or a payment.'),
            TextField(controller: reason, maxLength: 1000, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason (at least 10 characters)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Back')),
            FilledButton(onPressed: () => Navigator.pop(ctx, reason.text.trim()),
              child: const Text('Place Safety Hold')),
          ],
        ));
      if (explanation == null) return;
      if (explanation.length < 10) {
        if (mounted) setState(() => error = 'Please provide at least 10 characters.');
        return;
      }
      if (mounted) setState(() { loading = true; error = null; });
      await Supabase.instance.client.rpc('gs_credit_raise_identity_safety_hold',
        params: {'p_request_id': requestId, 'p_reason': explanation});
      if (mounted) setState(() => error = 'Safety hold submitted. Further identity review is blocked.');
    } catch (e) {
      if (mounted) setState(() => error = 'Unable to place safety hold: $e');
    } finally {
      reason.dispose();
      if (mounted) setState(() => loading = false);
      await _load();
    }
  }

  Future<void> _showRequestSafetyHoldStatus(String requestId) async {
    try {
      final data = await Supabase.instance.client.rpc(
        'gs_credit_my_identity_request_hold_status',
        params: {'p_request_id': requestId});
      if (!mounted) return;
      final records = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (records.isEmpty) throw StateError('No safety status returned');
      final hold = records.first;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Identity Request Safety Status'),
        content: Text(hold['hold_active'] == true
            ? 'Safety hold active. Identity review is blocked.\n'
              'Reason: ${hold['reason']}\nRecorded: ${hold['created_at']}'
            : 'No safety hold recorded for this request. '
              'This does not verify identity or authorize credit.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => error = 'Unable to verify safety hold: $e');
    }
  }

  Future<void> _showMySafetyHolds() async {
    try {
      final data = await Supabase.instance.client.rpc('gs_credit_my_identity_safety_holds');
      if (!mounted) return;
      final holds = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('My Identity Safety Holds'),
        content: SizedBox(width: 480, height: 300,
          child: holds.isEmpty ? const Text('No safety holds found.') : ListView(
            children: holds.map((h) => ListTile(
              title: Text('Request ${h['request_id']}'),
              subtitle: Text('${h['reason']}\n${h['created_at']}'),
            )).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => error = 'Unable to load safety holds: $e');
    }
  }

  Future<void> _showIdentitySafetyOverview() async {
    try {
      final data = await Supabase.instance.client.rpc(
        'gs_credit_my_identity_safety_overview');
      if (!mounted) return;
      final items = (data as List)
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('My Identity Safety Overview'),
        content: SizedBox(width: 520, height: 360,
          child: items.isEmpty ? const Text('No identity onboarding requests found.')
            : ListView(children: items.map((r) => ListTile(
              title: Text('Customer: ${r['customer_reference']}'),
              subtitle: Text('Onboarding: ${r['request_status']}\n'
                'Response: ${r['response_status']}\n'
                'Safety hold: ${r['hold_active'] == true ? 'Active' : 'None'}\n'
                'Identity: Unverified · Credit authorization: Disabled'
                '${r['hold_reason'] == null ? '' : '\nReason: ${r['hold_reason']}'}'),
            )).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => error = 'Unable to load safety overview: $e');
    }
  }


  Future<void> _reportAuthorizationConcern(String invoiceReference) async {
    final controller = TextEditingController();
    try {
      final reason = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Report an unrecognized authorization'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Invoice: $invoiceReference'),
          const Text('This reports a concern for review. It does not cancel the invoice, authorize payment, or deduct credit.'),
          TextField(controller: controller, maxLength: 1000, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Explain the concern (minimum 10 characters)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Submit concern')),
        ],
      ));
      if (reason == null) return;
      if (reason.length < 10) throw StateError('Please enter at least 10 characters.');
      await Supabase.instance.client.rpc('gs_credit_report_authorization_concern',
        params: {'p_invoice_reference': invoiceReference, 'p_reason': reason});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Concern recorded for staff review. No payment was authorized.')));
    } catch (e) {
      if (mounted) setState(() => error = 'Concern could not be recorded: $e');
    } finally { controller.dispose(); }
  }

  Future<void> _showMyAuthorizationRequests() async {
    try {
      final binding = await Supabase.instance.client.rpc(
        'gs_credit_my_identity_binding_status');
      if (!mounted) return;
      final verified = binding is List && binding.any((row) =>
          row is Map && row['binding_status'] == 'verified');
      if (!verified) {
        await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('Identity verification required'),
          content: const Text('Invoice authorization requests are private and cannot be shown until your identity is independently verified. No payment consent or credit deduction is available.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ));
        return;
      }
      final data = await Supabase.instance.client.rpc(
        'gs_credit_my_authorization_requests');
      if (!mounted) return;
      final items = (data as List)
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('My Credit Authorization Requests (Read Only)'),
        content: SizedBox(width: 520, height: 340,
          child: items.isEmpty
            ? const Text('No eligible requests are visible. An unresolved safety hold may block access. No consent or payment can be submitted here.')
            : ListView(children: items.map((r) => ListTile(
                title: Text('Invoice: ${r['invoice_reference']}'),
                subtitle: Text('Amount: ${r['amount_iqd']} IQD\n'
                  'Status: ${r['request_status']}\n'
                  'Requested: ${r['requested_at']}\n'
                  'Expires: ${r['expires_at'] ?? 'Not specified'}\n'
                  'Read only — no consent or debit'),
                trailing: TextButton(onPressed: () => _reportAuthorizationConcern(
                  '${r['invoice_reference']}'), child: const Text('Report Concern')),
              )).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => error = 'Unable to load authorization requests: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('My Credit Identity Requests', style: Theme.of(context).textTheme.titleMedium),
      const Text('Respond only if this request relates to you. This is NOT payment consent.'),
      OutlinedButton(onPressed: loading ? null : _load, child: const Text('Refresh')),
      OutlinedButton(onPressed: loading ? null : _showIdentitySafetyOverview,
        child: const Text('Identity Safety Overview')),
      OutlinedButton(onPressed: loading ? null : _showMyAuthorizationRequests,
        child: const Text('My Authorization Requests (Read Only)')),
      OutlinedButton(onPressed: loading ? null : _showMySafetyHolds,
        child: const Text('My Safety Holds')),
      if (loading) const LinearProgressIndicator(),
      if (error != null) Text(error!),
      ...requests.map((r) => ListTile(
        title: Text('Customer: ${r['customer_reference']}'),
        subtitle: Text('Request: ${r['request_status']} · Response: ${r['response'] ?? 'Not answered'}'
          '${r['hold_active'] == true ? ' · SAFETY HOLD ACTIVE' : ''}'),
        trailing: Wrap(children: [
          TextButton(onPressed: loading ? null : () => _showRequestSafetyHoldStatus('${r['request_id']}'),
            child: const Text('Hold Status')),
          TextButton(onPressed: loading ? null : () => _raiseSafetyHold('${r['request_id']}'),
            child: const Text('Safety Hold')),
          if (r['request_status'] == 'pending' && r['response'] == null && r['hold_active'] != true) ...[
              TextButton(onPressed: loading ? null : () => _respond('${r['request_id']}', 'disputed'),
                child: const Text('Dispute')),
              TextButton(onPressed: loading ? null : () => _respond('${r['request_id']}', 'acknowledged'),
                child: const Text('Acknowledge')),
            ],
        ]),
      )),
    ]),
  ));
}
