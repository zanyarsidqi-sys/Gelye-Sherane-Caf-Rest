import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Staff onboarding queue. Pending requests are NOT proof of customer identity.
class CreditIdentityOnboardingPanel extends StatefulWidget {
  const CreditIdentityOnboardingPanel({super.key});
  @override
  State<CreditIdentityOnboardingPanel> createState() => _CreditIdentityOnboardingPanelState();
}

class _CreditIdentityOnboardingPanelState extends State<CreditIdentityOnboardingPanel> {
  final customerId = TextEditingController();
  final authUserId = TextEditingController();
  final reason = TextEditingController();
  String filter = 'pending';
  bool busy = false;
  String? message;
  List<Map<String, dynamic>> requests = [];

  @override
  void initState() { super.initState(); _refresh(); }
  @override
  void dispose() { customerId.dispose(); authUserId.dispose(); reason.dispose(); super.dispose(); }

  Future<void> _refresh() async {
    if (busy) return;
    setState(() { busy = true; message = null; });
    try {
      final data = await Supabase.instance.client.rpc('gs_staff_list_credit_identity_onboarding',
        params: {'p_status': filter});
      if (mounted) setState(() => requests = (data as List)
        .map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) { if (mounted) setState(() => message = 'Unable to load requests: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _showRequestHistoricalHold(String requestId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_credit_onboarding_request_hold_status',
        params: {'p_request_id': requestId});
      if (!mounted) return;
      final rows = (response as List)
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) throw StateError('No status returned; verification blocked');
      final status = rows.first;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text(status['blocked'] == true
          ? 'Historical Safety Hold — BLOCKED' : 'Historical Safety Hold Check'),
        content: Text('Hold count: ${status['hold_count']}\n'
          '${status['explanation']}\n\n'
          'This check does not verify customer identity or authorize payment.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => message =
        'Historical hold status unavailable; approval remains blocked: $e');
    }
  }

  Future<bool> _checkHistoricalHold(String customer, String user) async {
    try {
      final data = await Supabase.instance.client.rpc(
        'gs_staff_credit_onboarding_historical_hold_check',
        params: {'p_customer_id': customer, 'p_auth_user_id': user});
      final rows = (data as List)
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) {
        if (mounted) setState(() => message = 'Safety hold check returned no result; request blocked.');
        return false;
      }
      final result = rows.first;
      if (mounted) setState(() => message =
        'Historical safety hold: ${result['blocked'] == true ? 'BLOCKED' : 'none found'}. '
        '${result['explanation']}');
      return result['blocked'] == false;
    } catch (e) {
      if (mounted) setState(() => message = 'Historical safety hold check failed: $e');
      return false; // Fail closed, even if RPC is unavailable.
    }
  }

  Future<void> _create() async {
    if (busy) return;
    final customer = customerId.text.trim();
    final user = authUserId.text.trim();
    final note = reason.text.trim();
    final uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (!uuid.hasMatch(customer) || !uuid.hasMatch(user) || note.length < 10 || note.length > 1000) {
      setState(() => message = 'Enter valid customer/user UUIDs and a reason (10-1000 characters).');
      return;
    }
    setState(() { busy = true; message = null; });
    try {
      if (!await _checkHistoricalHold(customer, user)) return;
      final id = await Supabase.instance.client.rpc('gs_staff_request_credit_identity_onboarding',
        params: {'p_customer_id': customer, 'p_auth_user_id': user, 'p_reason': note});
      if (mounted) setState(() => message = 'Pending request $id created. Identity is NOT verified.');
    } catch (e) { if (mounted) setState(() => message = 'Onboarding request failed: $e'); }
    finally { if (mounted) setState(() => busy = false); }
    await _refresh();
  }

  Future<void> _cancel(String requestId) async {
    final controller = TextEditingController();
    try {
      final note = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Cancel pending onboarding'),
        content: TextField(controller: controller, maxLength: 1000, maxLines: 3,
          decoration: const InputDecoration(labelText: 'Cancellation reason (10+ characters)')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Cancel request'))]));
      if (note == null) return;
      if (note.length < 10 || note.length > 1000) { if (mounted) setState(() => message = 'Reason must be 10-1000 characters.'); return; }
      await Supabase.instance.client.rpc('gs_staff_cancel_credit_identity_onboarding',
        params: {'p_request_id': requestId, 'p_reason': note});
      if (mounted) setState(() => message = 'Onboarding request cancelled.');
      await _refresh();
    } catch (e) { if (mounted) setState(() => message = 'Cancellation failed: $e'); }
    finally { controller.dispose(); }
  }

  Future<void> _reviewEvidence(String requestId) async {
    // Preflight improves UX. The database independently enforces this guard
    // under a row lock when a review is submitted.
    try {
      final data = await Supabase.instance.client.rpc(
        'gs_staff_credit_identity_onboarding_dispute_status',
        params: {'p_request_id': requestId});
      final rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty || rows.first['review_allowed'] != true) {
        if (mounted) setState(() => message =
          'Evidence review blocked: ${rows.isEmpty ? 'No status returned' : rows.first['explanation']}');
        return;
      }
    } catch (e) {
      if (mounted) setState(() => message = 'Cannot verify dispute status: $e');
      return; // Fail closed.
    }
    if (!mounted) return;
    final evidence = TextEditingController();
    final note = TextEditingController();
    String outcome = 'needs_more_evidence';
    try {
      final submitted = await showDialog<Map<String, String>>(context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
          title: const Text('Independent Identity Evidence Review'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Evidence review is not identity verification or customer consent.'),
            TextField(controller: evidence, maxLength: 500,
              decoration: const InputDecoration(labelText: 'Evidence reference (8+ characters)')),
            TextField(controller: note, maxLength: 1000, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Review note (10+ characters)')),
            DropdownButton<String>(value: outcome, isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'needs_more_evidence', child: Text('Needs more evidence')),
                DropdownMenuItem(value: 'evidence_reviewed', child: Text('Evidence reviewed (not verified)')),
                DropdownMenuItem(value: 'rejected', child: Text('Evidence rejected')),
              ], onChanged: (v) { if (v != null) update(() => outcome = v); }),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            FilledButton(onPressed: () => Navigator.pop(ctx, {
              'reference': evidence.text.trim(), 'note': note.text.trim(), 'outcome': outcome,
            }), child: const Text('Submit Review'))],
        )));
      if (submitted == null) return;
      if (submitted['reference']!.length < 8 || submitted['note']!.length < 10) {
        if (mounted) setState(() => message = 'Evidence reference and review note are too short.');
        return;
      }
      await Supabase.instance.client.rpc('gs_staff_review_credit_identity_onboarding_evidence',
        params: {'p_request_id': requestId, 'p_evidence_reference': submitted['reference'],
          'p_review_note': submitted['note'], 'p_outcome': submitted['outcome']});
      if (mounted) setState(() => message = 'Evidence review recorded. Identity is NOT verified.');
    } catch (e) { if (mounted) setState(() => message = 'Evidence review failed: $e'); }
    finally { evidence.dispose(); note.dispose(); }
  }

  Future<void> _showEvidenceHistory(String requestId) async {
    try {
      final data = await Supabase.instance.client.rpc('gs_staff_list_credit_identity_onboarding_evidence',
        params: {'p_request_id': requestId});
      if (!mounted) return;
      final rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Evidence Review History'),
        content: SizedBox(width: 560, height: 350, child: rows.isEmpty
          ? const Center(child: Text('No evidence reviews yet.'))
          : ListView(children: rows.map((r) => ListTile(
              title: Text('${r['review_outcome']} · ${r['reviewed_at']}'),
              subtitle: Text('Reference: ${r['evidence_reference']}\n${r['review_note']}\nReviewer: ${r['reviewed_by']}'),
            )).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (e) { if (mounted) setState(() => message = 'Unable to load review history: $e'); }
  }

  Future<void> _showDisputeStatus(String requestId) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_credit_identity_onboarding_dispute_status',
        params: {'p_request_id': requestId});
      if (!mounted) return;
      final rows = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final row = rows.first;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Customer Dispute Safeguard'),
        content: Text('Request: ${row['request_status']}\n'
          'Customer response: ${row['customer_response'] ?? 'none'}\n'
          'Evidence review allowed: ${row['review_allowed']}\n\n'
          '${row['explanation']}'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => message = 'Dispute status unavailable: $e');
    }
  }

  Future<void> _finalIdentityAssessment(String requestId) async {
    final note = TextEditingController();
    String outcome = 'requires_external_verification';
    try {
      final result = await showDialog<Map<String, String>>(context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Independent Final Identity Assessment'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('This assessment does NOT verify identity or authorize credit. '
              'A separate external identity proof process is still required.'),
            DropdownButton<String>(value: outcome, isExpanded: true, items: const [
              DropdownMenuItem(value: 'requires_external_verification',
                child: Text('Requires external verification')),
              DropdownMenuItem(value: 'rejected', child: Text('Reject evidence')),
            ], onChanged: (v) { if (v != null) setDialogState(() => outcome = v); }),
            TextField(controller: note, maxLines: 3, maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Assessment note (15+ characters)')),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            FilledButton(onPressed: () => Navigator.pop(ctx,
              {'assessment': outcome, 'note': note.text.trim()}),
              child: const Text('Record Assessment'))],
        )));
      if (result == null) return;
      if ((result['note'] ?? '').length < 15) throw StateError('At least 15 characters required');
      await Supabase.instance.client.rpc('gs_staff_assess_credit_identity_onboarding',
        params: {'p_request_id': requestId, 'p_assessment': result['assessment'],
          'p_note': result['note']});
      if (mounted) setState(() => message = 'Assessment recorded; identity remains UNVERIFIED.');
    } catch (e) {
      if (mounted) setState(() => message = 'Final assessment unavailable: $e');
    } finally { note.dispose(); }
  }

  Future<void> _showExternalEvidence(String requestId) async {
    final provider = TextEditingController();
    final reference = TextEditingController();
    final note = TextEditingController();
    try {
      final rows = await Supabase.instance.client.rpc(
        'gs_staff_list_credit_identity_external_evidence',
        params: {'p_request_id': requestId});
      final reviewRows = await Supabase.instance.client.rpc(
        'gs_staff_list_credit_identity_external_evidence_reviews',
        params: {'p_request_id': requestId});
      if (!mounted) return;
      final reviewed = (reviewRows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('External Evidence — Unverified'),
        content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            const Text('Evidence submission does not verify identity or authorize credit.'),
            ...((rows as List).map((entry) => ListTile(
              title: Text('${entry['provider_name']} — ${entry['verification_status']}'),
              subtitle: Text('${entry['evidence_reference']} · ${entry['submitted_at']}'),
              trailing: reviewed.any((v) => '${v['evidence_id']}' == '${entry['evidence_id']}')
                ? const Text('Reviewed')
                : TextButton(onPressed: () async {
                    Navigator.pop(ctx);
                    await _reviewExternalEvidence('${entry['evidence_id']}');
                  }, child: const Text('Review')),
            ))),
            if (reviewed.isNotEmpty) const Divider(),
            ...reviewed.map((v) => ListTile(
              title: Text('Review: ${v['outcome']}'),
              subtitle: Text('${v['review_note']}\nBy ${v['reviewed_by']} · ${v['reviewed_at']}'),
            )),
            TextField(controller: provider, decoration: const InputDecoration(labelText: 'Verification provider')),
            TextField(controller: reference, decoration: const InputDecoration(labelText: 'Evidence reference')),
            TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Evidence details')),
          ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton(onPressed: () async {
            if (provider.text.trim().length < 3 || reference.text.trim().length < 8 || note.text.trim().length < 15) return;
            try {
              await Supabase.instance.client.rpc('gs_staff_submit_credit_identity_external_evidence', params: {
                'p_request_id': requestId, 'p_provider_name': provider.text.trim(),
                'p_evidence_reference': reference.text.trim(), 'p_note': note.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
            }
          }, child: const Text('Record Unverified Evidence')),
        ],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Evidence unavailable: $e')));
    } finally { provider.dispose(); reference.dispose(); note.dispose(); }
  }

  Future<void> _reviewExternalEvidence(String evidenceId) async {
    final note = TextEditingController();
    String outcome = 'needs_correction';
    try {
      final values = await showDialog<Map<String, String>>(context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
          title: const Text('Independent External Evidence Review'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Documentation review does not verify identity or approve credit.'),
            DropdownButton<String>(value: outcome, isExpanded: true, items: const [
              DropdownMenuItem(value: 'needs_correction', child: Text('Needs correction')),
              DropdownMenuItem(value: 'documentation_reviewed', child: Text('Documentation reviewed (not verified)')),
              DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
            ], onChanged: (v) { if (v != null) update(() => outcome = v); }),
            TextField(controller: note, maxLength: 1000, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Review note (15+ characters)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            FilledButton(onPressed: () => Navigator.pop(ctx,
              {'outcome': outcome, 'note': note.text.trim()}), child: const Text('Record Review')),
          ],
        )));
      if (values == null) return;
      if ((values['note'] ?? '').length < 15) throw StateError('Review note must be 15+ characters');
      await Supabase.instance.client.rpc('gs_staff_review_credit_identity_external_evidence',
        params: {'p_evidence_id': evidenceId, 'p_outcome': values['outcome'], 'p_note': values['note']});
      if (mounted) setState(() => message = 'External documentation review recorded. Identity remains unverified.');
    } catch (e) {
      if (mounted) setState(() => message = 'External evidence review failed: $e');
    } finally { note.dispose(); }
  }

  Future<void> _showFinalIdentityAssessment(String requestId) async {
    try {
      final data = await Supabase.instance.client.rpc(
        'gs_staff_list_credit_identity_final_assessments',
        params: {'p_request_id': requestId});
      if (!mounted) return;
      final rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Final Assessments — Not Identity Approval'),
        content: SizedBox(width: 480, height: 300, child: rows.isEmpty
          ? const Center(child: Text('No final assessment recorded.'))
          : ListView(children: rows.map((r) => ListTile(
            title: Text('${r['assessment']} · ${r['assessed_at']}'),
            subtitle: Text('${r['assessment_note']}\nAssessor: ${r['assessed_by']}'),
          )).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => message = 'Assessment history unavailable: $e');
    }
  }

  Future<void> _showExternalEvidenceSafety(String requestId) async {
    try {
      final data = await Supabase.instance.client.rpc(
        'gs_staff_credit_identity_evidence_safety',
        params: {'p_request_id': requestId});
      if (!mounted) return;
      final rows = (data as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('External Evidence Safety — Not Verified'),
        content: SizedBox(width: 560, height: 390,
          child: rows.isEmpty
            ? const Center(child: Text('No external evidence submitted. Identity verification remains blocked.'))
            : ListView(children: rows.map((r) => ListTile(
                leading: const Icon(Icons.gpp_bad_outlined),
                title: Text('Provider: ${r['provider_name']} · ${r['safety_status']}'),
                subtitle: Text('Review: ${r['review_outcome']}\nSubmitted: ${r['submitted_at']}\n${r['explanation']}'),
              )).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => message = 'Evidence safety check unavailable: $e');
    }
  }

  Future<void> _showCustomerSafetyHold(String requestId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_credit_identity_safety_hold_status',
        params: {'p_request_id': requestId});
      if (!mounted) return;
      final rows = (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();
      final hold = rows.isNotEmpty && rows.first['hold_active'] == true;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text(hold ? 'Customer Safety Hold — Active' : 'Customer Safety Hold'),
        content: Text(hold
          ? 'Customer has raised an identity dispute. Evidence review is blocked.\n'
            'Reason: ${rows.first['reason']}\nAt: ${rows.first['created_at']}'
          : 'No safety hold recorded. This does not prove identity or authorize payment.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => message = 'Safety hold status unavailable: $e');
    }
  }

  Future<void> _showLatestEvidenceGuard(String requestId) async {
    try {
      final data = await Supabase.instance.client.rpc(
        'gs_staff_credit_identity_latest_evidence_guard',
        params: {'p_request_id': requestId});
      if (!mounted) return;
      final checks = (data as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Latest Evidence — Identity Not Verified'),
        content: SizedBox(width: 560, height: 390,
          child: checks.isEmpty
            ? const Center(child: Text('No verification results. Identity remains blocked.'))
            : ListView(children: checks.map((c) => ListTile(
                leading: Icon(['blocked', 'missing', 'not_integrated', 'not_reviewed']
                    .contains(c['check_status'])
                  ? Icons.block_outlined : Icons.info_outline),
                title: Text('${c['check_name']}: ${c['check_status']}'),
                subtitle: Text('${c['explanation']}'),
              )).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => message = 'Latest evidence check unavailable: $e');
    }
  }

  Future<void> _showIdentityActivationStatus(String requestId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_credit_identity_activation_status',
        params: {'p_request_id': requestId});
      if (!mounted) return;
      final checks = (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Identity Activation — Blocked'),
        content: SizedBox(width: 570, height: 390,
          child: checks.isEmpty
            ? const Center(child: Text('No status available. Identity activation remains blocked.'))
            : ListView(children: checks.map((check) => ListTile(
                leading: Icon(check['check_status'] == 'blocked' ||
                    check['check_status'] == 'unavailable'
                    ? Icons.block_outlined : Icons.info_outline),
                title: Text('${check['check_name']}: ${check['check_status']}'),
                subtitle: Text('${check['details']}'),
              )).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => message =
        'Identity activation status unavailable: $e');
    }
  }

  Future<void> _showExternalVerificationReadiness(String requestId) async {
    try {
      final data = await Supabase.instance.client.rpc(
        'gs_staff_credit_external_identity_readiness',
        params: {'p_request_id': requestId});
      if (!mounted) return;
      final checks = (data as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('External Identity Readiness — Not Verified'),
        content: SizedBox(width: 570, height: 400,
          child: checks.isEmpty
            ? const Center(child: Text('No readiness results. Verification remains blocked.'))
            : ListView(children: checks.map((c) => ListTile(
                leading: Icon(c['check_status'] == 'blocked' || c['check_status'] == 'missing'
                    || c['check_status'] == 'not_integrated'
                  ? Icons.block_outlined : Icons.info_outline),
                title: Text('${c['check_name']}: ${c['check_status']}'),
                subtitle: Text('${c['explanation']}'),
              )).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => message =
        'External verification readiness unavailable: $e');
    }
  }

  Future<void> _showApprovalReadiness(String requestId) async {
    try {
      final data = await Supabase.instance.client.rpc(
        'gs_staff_credit_identity_approval_readiness',
        params: {'p_request_id': requestId});
      if (!mounted) return;
      final checks = (data as List)
        .map((item) => Map<String, dynamic>.from(item as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Identity Approval Readiness — Not Approved'),
        content: SizedBox(width: 570, height: 380,
          child: ListView(children: checks.map((c) => ListTile(
            title: Text('${c['check_name']}: ${c['check_status']}'),
            subtitle: Text('${c['explanation']}'),
          )).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => message = 'Readiness unavailable: $e');
    }
  }

  Future<void> _showCustomerResponse(String requestId) async {
    try {
      final data = await Supabase.instance.client.rpc(
        'gs_staff_list_credit_identity_onboarding_responses',
        params: {'p_request_id': requestId});
      if (!mounted) return;
      final rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Customer Acknowledgement'),
        content: Text(rows.isEmpty ? 'No response yet. Identity remains unverified.'
          : '${rows.first['response']} at ${rows.first['responded_at']}\n'
            'Authenticated user: ${rows.first['auth_user_id']}\n'
            'This response does not verify account ownership or authorize credit.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) setState(() => message = 'Unable to load customer response: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Customer Identity Onboarding', style: Theme.of(context).textTheme.titleMedium),
      const Text('Staff requests are pending only. No identity verification, consent or credit charge.'),
      TextField(controller: customerId, decoration: const InputDecoration(labelText: 'Existing credit customer UUID')),
      TextField(controller: authUserId, decoration: const InputDecoration(labelText: 'Authenticated customer user UUID')),
      TextField(controller: reason, maxLength: 1000, decoration: const InputDecoration(labelText: 'Onboarding reason')),
      OutlinedButton(onPressed: busy ? null : () async {
        final customer = customerId.text.trim();
        final user = authUserId.text.trim();
        final uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
        if (!uuid.hasMatch(customer) || !uuid.hasMatch(user)) {
          setState(() => message = 'Enter valid customer and authenticated user UUIDs.');
          return;
        }
        await _checkHistoricalHold(customer, user);
      }, child: const Text('Check Historical Safety Holds')),
      FilledButton(onPressed: busy ? null : _create, child: const Text('Request Pending Identity Onboarding')),
      const Divider(),
      Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        DropdownButton<String>(value: filter, items: const [
          DropdownMenuItem(value: 'pending', child: Text('Pending')),
          DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
          DropdownMenuItem(value: 'all', child: Text('All')),
        ], onChanged: busy ? null : (v) { if (v != null) { setState(() => filter = v); _refresh(); } }),
        OutlinedButton(onPressed: busy ? null : _refresh, child: const Text('Refresh')),
      ]),
      if (message != null) Text(message!),
      if (busy) const LinearProgressIndicator(),
      ...requests.map((r) => ListTile(
        title: Text('${r['customer_reference']} · ${r['status']}'),
        subtitle: Text('User: ${r['auth_user_id']}\nReason: ${r['reason']}\nRequested: ${r['requested_at']}'
          '${r['cancellation_reason'] == null ? '' : '\nCancelled: ${r['cancellation_reason']}'}'),
        isThreeLine: true,
        trailing: Wrap(spacing: 4, children: [
          TextButton(onPressed: busy ? null : () => _showCustomerResponse('${r['request_id']}'),
            child: const Text('Customer Response')),
          TextButton(onPressed: busy ? null : () => _finalIdentityAssessment('${r['request_id']}'),
            child: const Text('Final Assessment')),
          TextButton(onPressed: busy ? null : () => _showFinalIdentityAssessment('${r['request_id']}'),
            child: const Text('Assessment History')),
          TextButton(onPressed: busy ? null : () => _showExternalEvidence('${r['request_id']}'),
            child: const Text('External Evidence')),
          TextButton(onPressed: busy ? null : () => _showExternalEvidenceSafety('${r['request_id']}'),
            child: const Text('Evidence Safety')),
          TextButton(onPressed: busy ? null : () => _showLatestEvidenceGuard('${r['request_id']}'),
            child: const Text('Latest Evidence Check')),
          TextButton(onPressed: busy ? null : () => _showRequestHistoricalHold('${r['request_id']}'),
            child: const Text('Historical Hold Status')),
          TextButton(onPressed: () => _showCustomerSafetyHold('${r['request_id']}'),
            child: const Text('Customer Safety Hold')),
          TextButton(onPressed: busy ? null : () => _showExternalVerificationReadiness('${r['request_id']}'),
            child: const Text('External Verification Readiness')),
          TextButton(onPressed: busy ? null : () => _showIdentityActivationStatus('${r['request_id']}'),
            child: const Text('Activation Status')),
          TextButton(onPressed: busy ? null : () => _showApprovalReadiness('${r['request_id']}'),
            child: const Text('Approval Readiness')),
          TextButton(onPressed: busy ? null : () => _showDisputeStatus('${r['request_id']}'),
            child: const Text('Dispute Status')),
          TextButton(onPressed: busy ? null : () => _showEvidenceHistory('${r['request_id']}'),
            child: const Text('Review History')),
          if (r['status'] == 'pending')
            TextButton(onPressed: busy ? null : () => _reviewEvidence('${r['request_id']}'),
              child: const Text('Review Evidence')),
          if (r['status'] == 'pending')
            TextButton(onPressed: busy ? null : () => _cancel('${r['request_id']}'),
              child: const Text('Cancel')),
        ]),
      )),
    ]),
  ));
}
