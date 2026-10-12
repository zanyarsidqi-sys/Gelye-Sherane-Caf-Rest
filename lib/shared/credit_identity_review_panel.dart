import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Human evidence review only. Never marks an account verified or permits debit.
class CreditIdentityReviewPanel extends StatefulWidget {
  const CreditIdentityReviewPanel({super.key});
  @override
  State<CreditIdentityReviewPanel> createState() => _CreditIdentityReviewPanelState();
}

class _CreditIdentityReviewPanelState extends State<CreditIdentityReviewPanel> {
  final registry = TextEditingController();
  final evidence = TextEditingController();
  final note = TextEditingController();
  bool busy = false;
  String? message;
  List<Map<String, dynamic>> reviews = [];

  @override
  void dispose() {
    registry.dispose(); evidence.dispose(); note.dispose(); super.dispose();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final result = await Supabase.instance.client.rpc('gs_staff_list_credit_identity_reviews');
      if (mounted) setState(() {
        reviews = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        message = null;
      });
    } catch (e) {
      if (mounted) setState(() => message = 'Review list unavailable: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    setState(() => busy = true);
    try {
      await Supabase.instance.client.rpc('gs_staff_request_credit_identity_review', params: {
        'p_registry_id': registry.text.trim(),
        'p_evidence_reference': evidence.text.trim(),
        'p_note': note.text.trim(),
      });
      if (mounted) setState(() => message = 'Evidence review requested. Account remains unverified.');
    } catch (e) {
      if (mounted) setState(() => message = 'Request failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (mounted) await load();
  }

  Future<void> showInvoiceRequestConflicts(String invoiceReference) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_credit_invoice_request_conflicts',
        params: {'p_invoice_reference': invoiceReference});
      if (!mounted) return;
      final records = (response as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Invoice Authorization Requests'),
        content: SizedBox(width: 540, height: 300,
          child: records.isEmpty
            ? const Center(child: Text('No outstanding unexpired requests.'))
            : ListView.builder(itemCount: records.length, itemBuilder: (_, i) {
                final r = records[i];
                return ListTile(title: Text('Request ${r['request_id']}'),
                  subtitle: Text('Review ${r['review_id']}\nExpires: ${r['expires_at']}'));
              })),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => message = 'Invoice request check failed: $e');
    }
  }

  Future<void> showAuthorizationSafetyHold(String requestId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_credit_authorization_request_hold_check',
        params: {'p_request_id': requestId});
      if (!mounted) return;
      final records = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Customer Identity Safety Hold'),
        content: SizedBox(width: 500, child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            ...records.map((r) => ListTile(
              leading: Icon(r['blocked'] == true
                  ? Icons.block : Icons.info_outline),
              title: Text(r['blocked'] == true
                  ? 'Authorization blocked' : 'No historical hold found'),
              subtitle: Text('Historical holds: ${r['hold_count']}\n'
                  '${r['explanation']}'),
            )),
            const Text('No hold does not mean customer identity or consent is verified.'),
          ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => message =
          'Safety hold check unavailable; authorization remains unverified: $e');
    }
  }

  Future<void> showAuthorizationExpiry(String requestId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_credit_authorization_expiry_checks',
        params: {'p_request_id': requestId});
      if (!mounted) return;
      final checks = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Authorization Request Expiry'),
        content: SizedBox(width: 520, height: 300,
          child: ListView.builder(itemCount: checks.length, itemBuilder: (_, i) {
            final c = checks[i];
            return ListTile(
              title: Text('${c['check_name']}: ${c['check_status']}'),
              subtitle: Text('${c['explanation']}'),
            );
          })),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => message = 'Expiry check unavailable: $e');
    }
  }

  Future<void> showAuthorizationPreflight(String requestId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_credit_authorization_preflight',
        params: {'p_request_id': requestId});
      if (!mounted) return;
      final checks = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Credit Authorization Readiness'),
        content: SizedBox(width: 580, height: 400,
          child: ListView(children: [
            const Text('Read-only checks. No customer consent or debit is authorized.'),
            ...checks.map((c) => ListTile(
              title: Text('${c['check_name']}: ${c['check_status']}'),
              subtitle: Text('${c['explanation']}'),
            )),
          ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => message = 'Readiness check failed: $e');
    }
  }

  Future<void> showAuthorizationInvoiceChecks(String requestId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_credit_authorization_invoice_checks',
        params: {'p_request_id': requestId});
      if (!mounted) return;
      final checks = (response as List)
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Authorization Invoice Checks'),
        content: SizedBox(width: 580, height: 390,
          child: ListView.builder(itemCount: checks.length, itemBuilder: (_, i) {
            final c = checks[i];
            return ListTile(
              leading: Icon(c['check_status'] == 'matched'
                ? Icons.check_circle_outline : Icons.info_outline),
              title: Text('${c['check_name']}: ${c['check_status']}'),
              subtitle: Text('${c['explanation']}'),
            );
          })),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => message = 'Invoice checks unavailable: $e');
    }
  }

  Future<void> cancelAuthorizationRequest(String requestId) async {
    final reason = TextEditingController();
    try {
      final text = await showDialog<String>(context: context, builder: (ctx) =>
        AlertDialog(
          title: const Text('Cancel Authorization Request'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Cancellation cannot be undone. No credit payment will be processed.'),
            TextField(controller: reason, maxLength: 1000, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason (10+ characters)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Request')),
            FilledButton(onPressed: () => Navigator.pop(ctx, reason.text.trim()),
              child: const Text('Cancel Request')),
          ],
        ));
      if (text == null) return;
      if (text.length < 10) throw StateError('Reason must contain at least 10 characters');
      await Supabase.instance.client.rpc('gs_staff_cancel_credit_customer_authorization',
        params: {'p_request_id': requestId, 'p_reason': text});
      if (mounted) setState(() => message =
        'Authorization request cancelled. No consent or credit charge was recorded.');
    } catch (e) {
      if (mounted) setState(() => message = 'Authorization cancellation failed: $e');
    } finally {
      reason.dispose();
    }
  }

  Future<void> showAuthorizationReadiness(String reviewId) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_credit_authorization_readiness',
        params: {'p_review_id': reviewId});
      if (!mounted) return;
      final rows = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Authorization Security Readiness'),
        content: SizedBox(width: 540, height: 340, child: rows.isEmpty
          ? const Text('No authorization requests for this review.')
          : ListView(children: rows.map((r) => ListTile(
              title: Text('${r['invoice_reference']} · ${r['amount_iqd']} IQD'),
              subtitle: Text('Status: ${r['request_status']}\n'
                'Identity verified: ${r['identity_verified'] == true ? 'Yes' : 'No'}\n'
                'Historical safety hold: ${r['historical_safety_hold'] == true ? 'Yes' : 'No'}\n'
                'Consent enabled: No\n${r['reason']}'),
            )).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => message = 'Authorization readiness unavailable: $e');
    }
  }

  Future<void> showCustomerAuthorizationConcerns(String reviewId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_credit_authorization_concerns',
        params: {'p_review_id': reviewId});
      if (!mounted) return;
      final concerns = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Customer Authorization Concerns'),
        content: SizedBox(width: 540, height: 320,
          child: concerns.isEmpty
            ? const Text('No customer concerns recorded for this review.')
            : ListView(children: concerns.map((c) => ListTile(
                title: Text('Invoice: ${c['invoice_reference']}'),
                subtitle: Text('Reported: ${c['reported_at']}\n${c['concern_reason']}'),
              )).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => message = 'Customer concerns unavailable: $e');
    }
  }

  Future<void> showAuthorizationRequests(String reviewId) async {
    final invoice = TextEditingController();
    final amount = TextEditingController();
    final noteController = TextEditingController();
    String channel = 'in_person';
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_list_credit_customer_authorizations_v3',
        params: {'p_review_id': reviewId});
      if (!mounted) return;
      final history = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final data = await showDialog<Map<String, String>>(context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
          title: const Text('Request Customer Authorization'),
          content: SizedBox(width: 550, child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('This logs a request only, not customer consent. '
                'Credit charging and account activation remain disabled.'),
              OutlinedButton(onPressed: () async {
                Navigator.pop(ctx);
                await showAuthorizationReadiness(reviewId);
              }, child: const Text('Check Authorization Readiness')),
              OutlinedButton(onPressed: () async {
                Navigator.pop(ctx);
                await showCustomerAuthorizationConcerns(reviewId);
              }, child: const Text('Review Customer Concerns')),
              ...history.map((item) => ListTile(
                title: Text('${item['invoice_reference']} · ${item['amount_iqd']} IQD'),
                subtitle: Text('${item['effective_status']} · ${item['channel']} · ${item['requested_at']}'
                  ' · Expires: ${item['expires_at']}'
                  '${item['cancellation_reason'] == null ? '' : '\\nCancelled: ${item['cancellation_reason']}'}'),
                trailing: Wrap(children: [
                  TextButton(onPressed: () async {
                    Navigator.pop(ctx);
                    await showAuthorizationExpiry(item['request_id'].toString());
                    if (mounted) await showAuthorizationRequests(reviewId);
                  }, child: const Text('Expiry Check')),
                  TextButton(onPressed: () async {
                    Navigator.pop(ctx);
                    await showInvoiceRequestConflicts(item['invoice_reference'].toString());
                    if (mounted) await showAuthorizationRequests(reviewId);
                  }, child: const Text('Invoice Requests')),
                  TextButton(onPressed: () async {
                    Navigator.pop(ctx);
                    await showAuthorizationSafetyHold(item['request_id'].toString());
                    if (mounted) await showAuthorizationRequests(reviewId);
                  }, child: const Text('Safety Hold')),
                  TextButton(onPressed: () async {
                    Navigator.pop(ctx);
                    await showAuthorizationPreflight(item['request_id'].toString());
                    if (mounted) await showAuthorizationRequests(reviewId);
                  }, child: const Text('Readiness')),
                  TextButton(onPressed: () async {
                    Navigator.pop(ctx);
                    await showAuthorizationInvoiceChecks(item['request_id'].toString());
                    if (mounted) await showAuthorizationRequests(reviewId);
                  }, child: const Text('Invoice Checks')),
                  if (item['effective_status'] == 'awaiting_customer_consent')
                    TextButton(onPressed: () async {
                      Navigator.pop(ctx);
                      await cancelAuthorizationRequest(item['request_id'].toString());
                      if (mounted) await showAuthorizationRequests(reviewId);
                    }, child: const Text('Cancel')),
                ]),
              )),
              TextField(controller: invoice, maxLength: 120,
                decoration: const InputDecoration(labelText: 'Motel Food invoice UUID')),
              TextField(controller: amount, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Exact amount (IQD)')),
              DropdownButtonFormField<String>(value: channel,
                items: const [
                  DropdownMenuItem(value: 'in_person', child: Text('In person')),
                  DropdownMenuItem(value: 'phone', child: Text('Phone')),
                  DropdownMenuItem(value: 'sms', child: Text('SMS')),
                  DropdownMenuItem(value: 'email', child: Text('Email')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ], onChanged: (v) => update(() => channel = v ?? 'in_person')),
              TextField(controller: noteController, maxLength: 1000, maxLines: 2,
                decoration: const InputDecoration(labelText: 'Reason (10+ characters)')),
            ]))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            FilledButton(onPressed: () => Navigator.pop(ctx, {
              'invoice': invoice.text.trim(), 'amount': amount.text.trim(),
              'channel': channel, 'note': noteController.text.trim(),
            }), child: const Text('Request Authorization')),
          ],
        )));
      if (data == null) return;
      final value = int.tryParse(data['amount'] ?? '');
      if (!RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(data['invoice'] ?? '') || value == null || value <= 0 ||
          (data['note'] ?? '').length < 10) {
        throw StateError('Valid invoice UUID, positive IQD amount and note required');
      }
      await Supabase.instance.client.rpc('gs_staff_request_credit_customer_authorization',
        params: {'p_review_id': reviewId, 'p_invoice_reference': data['invoice'],
          'p_amount_iqd': value, 'p_channel': data['channel'], 'p_note': data['note']});
      if (mounted) setState(() => message =
        'Customer authorization requested; consent is NOT verified and payment remains blocked.');
    } catch (e) {
      if (mounted) setState(() => message = 'Authorization request unavailable: $e');
    } finally {
      invoice.dispose(); amount.dispose(); noteController.dispose();
    }
  }

  Future<void> showConsentOutreach(String reviewId) async {
    final noteController = TextEditingController();
    String channel = 'in_person';
    try {
      final existing = await Supabase.instance.client.rpc(
        'gs_staff_list_credit_consent_outreach',
        params: {'p_review_id': reviewId});
      if (!mounted) return;
      final events = (existing as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final result = await showDialog<Map<String, String>>(context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
          title: const Text('Customer Consent Outreach'),
          content: SizedBox(width: 570, child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Outreach is NOT customer consent or authorization. '
                'No credit account will be activated or charged.'),
              ...events.map((e) => ListTile(
                title: Text('${e['channel']} · ${e['status']}'),
                subtitle: Text('${e['note']}\n${e['requested_at']}'),
              )),
              DropdownButtonFormField<String>(value: channel,
                items: const [
                  DropdownMenuItem(value: 'in_person', child: Text('In person')),
                  DropdownMenuItem(value: 'phone', child: Text('Phone')),
                  DropdownMenuItem(value: 'sms', child: Text('SMS')),
                  DropdownMenuItem(value: 'email', child: Text('Email')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => update(() => channel = v ?? 'in_person')),
              TextField(controller: noteController, maxLength: 1000, maxLines: 3,
                decoration: const InputDecoration(labelText: 'Outreach note (10+ characters)')),
            ]))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            FilledButton(onPressed: () => Navigator.pop(ctx,
              {'channel': channel, 'note': noteController.text.trim()}),
              child: const Text('Record Request')),
          ],
        )));
      if (result == null) return;
      if ((result['note'] ?? '').length < 10) {
        throw StateError('At least 10 characters required');
      }
      await Supabase.instance.client.rpc('gs_staff_request_credit_consent_outreach',
        params: {'p_review_id': reviewId, 'p_channel': result['channel'],
          'p_note': result['note']});
      if (mounted) setState(() => message =
        'Consent outreach recorded; actual consent remains unverified.');
    } catch (e) {
      if (mounted) setState(() => message = 'Consent outreach unavailable: $e');
    } finally {
      noteController.dispose();
    }
  }

  Future<void> showReviewEligibility(String reviewId) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_credit_identity_review_eligibility',
        params: {'p_review_id': reviewId});
      if (!mounted) return;
      final checks = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Identity Approval Eligibility'),
        content: SizedBox(width: 620, height: 430,
          child: ListView.separated(
            itemCount: checks.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, i) {
              final item = checks[i];
              final passed = item['check_status'] == 'pass';
              return ListTile(
                leading: Icon(passed ? Icons.check_circle_outline : Icons.block_outlined),
                title: Text('${item['check_name']}: ${item['check_status']}'),
                subtitle: Text('${item['explanation']}'),
              );
            },
          )),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => message = 'Approval eligibility unavailable: $e');
    }
  }

  Future<void> showApprovalReadiness(String registryId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_credit_link_approval_readiness',
        params: {'p_registry_id': registryId});
      if (!mounted) return;
      final checks = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Credit Link Approval Readiness'),
        content: SizedBox(width: 600, height: 400,
          child: ListView.separated(
            itemCount: checks.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, i) {
              final c = checks[i];
              return ListTile(
                leading: Icon(c['check_status'] == 'pass'
                    ? Icons.check_circle_outline : Icons.info_outline),
                title: Text('${c['check_name']}: ${c['check_status']}'),
                subtitle: Text('${c['explanation']}'),
              );
            },
          )),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => message = 'Readiness check unavailable: $e');
    }
  }

  Future<void> showRevocationHistory(String registryId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_list_credit_link_revocations',
        params: {'p_registry_id': registryId});
      if (!mounted) return;
      final entries = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Credit Link Revocation History'),
        content: SizedBox(width: 600, height: 380,
          child: entries.isEmpty
              ? const Center(child: Text('No revocation recorded for this link.'))
              : ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, i) {
                    final event = entries[i];
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text('Previous status: ${event['previous_status']}'),
                      subtitle: Text('Reason: ${event['reason']}\n'
                        'Employee: ${event['revoked_by']}\n'
                        'Date: ${event['revoked_at']}'),
                      isThreeLine: true,
                    );
                  },
                )),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => message = 'Revocation history unavailable: $e');
    }
  }

  Future<void> revokePendingLink(String registryId) async {
    final controller = TextEditingController();
    try {
      final reason = await showDialog<String>(context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Revoke Pending Credit Link'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('This revokes an unverified barcode-account link. '
              'It does not close the account or change any credit balance.'),
            TextField(controller: controller, maxLength: 1000, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason (10+ characters)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Revoke Link')),
          ],
        ));
      if (reason == null) return;
      if (reason.length < 10) throw StateError('Reason must contain 10+ characters');
      if (mounted) setState(() => busy = true);
      await Supabase.instance.client.rpc('gs_staff_revoke_pending_credit_link',
        params: {'p_registry_id': registryId, 'p_reason': reason});
      if (mounted) setState(() => message = 'Pending link revoked and audited.');
      if (mounted) await load();
    } catch (e) {
      if (mounted) setState(() => message = 'Revocation failed: $e');
    } finally {
      controller.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> decide(String id, bool accept) async {
    final controller = TextEditingController();
    try {
      final reviewNote = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        title: Text(accept ? 'Accept evidence for review' : 'Reject evidence'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('A second employee must decide. Accepting evidence does NOT verify ownership or enable credit.'),
          TextField(controller: controller, maxLength: 1000, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Decision note (at least 10 characters)')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Record decision'))],
      ));
      if (reviewNote == null) return;
      if (reviewNote.length < 10) throw StateError('At least 10 characters required');
      await Supabase.instance.client.rpc('gs_staff_decide_credit_identity_review', params: {
        'p_review_id': id, 'p_accept_evidence': accept, 'p_note': reviewNote,
      });
      if (mounted) setState(() => message = 'Decision recorded; credit account remains unverified.');
      if (mounted) await load();
    } catch (e) {
      if (mounted) setState(() => message = 'Decision failed: $e');
    } finally { controller.dispose(); }
  }

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Credit Identity Evidence Review', style: Theme.of(context).textTheme.titleMedium),
      const Text('Two-person evidence review only. No identity approval, credit limit or payment authorization.'),
      TextField(controller: registry, decoration: const InputDecoration(labelText: 'Linked barcode registry UUID')),
      TextField(controller: evidence, decoration: const InputDecoration(labelText: 'Evidence reference (not document contents)')),
      TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Reason for review (10+ characters)')),
      Wrap(spacing: 8, children: [
        FilledButton(onPressed: busy ? null : submit, child: const Text('Request Evidence Review')),
        OutlinedButton(onPressed: busy ? null : load, child: const Text('Refresh Reviews')),
      ]),
      if (message != null) Text(message!),
      ...reviews.map((r) => ListTile(
        title: Text('${r['status']} · ${r['evidence_reference']}'),
        subtitle: Text('Requested by ${r['requested_by']} · ${r['requested_at']}\n'
          'Reviewer: ${r['reviewed_by'] ?? 'pending'} · ${r['review_note'] ?? ''}'),
        isThreeLine: true,
        trailing: Wrap(children: [
          TextButton(onPressed: busy ? null : () =>
            showRevocationHistory(r['registry_id'].toString()),
            child: const Text('Revocation History')),
          TextButton(onPressed: busy ? null : () =>
            showConsentOutreach(r['review_id'].toString()),
            child: const Text('Consent Outreach')),
          TextButton(onPressed: busy ? null : () =>
            showAuthorizationRequests(r['review_id'].toString()),
            child: const Text('Authorization Request')),
          TextButton(onPressed: busy ? null : () =>
            showReviewEligibility(r['review_id'].toString()),
            child: const Text('Approval Eligibility')),
          TextButton(onPressed: busy ? null : () =>
            showApprovalReadiness(r['registry_id'].toString()),
            child: const Text('Link Readiness')),
          if (r['status'] == 'pending')
            TextButton(onPressed: busy ? null : () =>
              revokePendingLink(r['registry_id'].toString()),
              child: const Text('Revoke Pending Link')),
          if (r['status'] == 'pending') ...[
          TextButton(onPressed: busy ? null : () => decide(r['review_id'].toString(), true),
            child: const Text('Evidence Reviewed')),
          TextButton(onPressed: busy ? null : () => decide(r['review_id'].toString(), false),
            child: const Text('Reject')),
          ],
        ]),
      )),
    ]),
  ));
}
