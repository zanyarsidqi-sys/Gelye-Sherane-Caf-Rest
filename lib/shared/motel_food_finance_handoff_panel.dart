import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only financial handoff. These entries are not unified invoices or payments.
class MotelFoodFinanceHandoffPanel extends StatefulWidget {
  const MotelFoodFinanceHandoffPanel({super.key});

  @override
  State<MotelFoodFinanceHandoffPanel> createState() => _MotelFoodFinanceHandoffPanelState();
}

class _MotelFoodFinanceHandoffPanelState extends State<MotelFoodFinanceHandoffPanel> {
  bool loading = false;
  String? error;
  List<Map<String, dynamic>> entries = [];
  List<Map<String, dynamic>> postedInvoices = [];
  String invoicePeriod = 'All dates';
  String invoiceMethod = 'All methods';
  // Choices are derived only from authorized posted invoice rows.
  List<String> get recordedInvoiceMethods => postedInvoices
      .map((row) => (row['payment_method'] ?? '').toString().trim())
      .where((value) => value.isNotEmpty).toSet().toList()..sort();
  String invoiceEmployee = '';
  // Employee choices reflect IDs present in authorized invoice results.
  List<String> get recordedInvoiceEmployees => postedInvoices
      .map((row) => (row['employee_id'] ?? row['created_by'] ?? '').toString().trim())
      .where((value) => value.isNotEmpty).toSet().toList()..sort();
  String invoiceSubtype = 'All recorded subtypes';
  // Only expose subtypes actually present in authorized invoice rows.
  List<String> get recordedInvoiceSubtypes => postedInvoices
      .map((row) => (row['payment_subtype'] ?? '').toString().trim())
      .where((value) => value.isNotEmpty).toSet().toList()..sort();
  DateTime? invoiceFrom;
  DateTime? invoiceTo;

  // Only filter against fields returned by the authorized finance RPC.
  // Missing metadata never gets fabricated or silently treated as matching.
  List<Map<String, dynamic>> get visiblePostedInvoices {
    final now = DateTime.now();
    DateTime? since;
    if (invoicePeriod == 'Yesterday') {
      since = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    } else if (invoicePeriod == 'Last week') {
      since = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
    } else if (invoicePeriod == 'Last month') {
      since = DateTime(now.year, now.month - 1, now.day);
    } else if (invoicePeriod == 'Last year') {
      since = DateTime(now.year - 1, now.month, now.day);
    }
    final yesterdayEnd = DateTime(now.year, now.month, now.day);
    return postedInvoices.where((row) {
      if (invoicePeriod != 'All dates') {
        final date = DateTime.tryParse((row['created_at'] ?? '').toString())?.toLocal();
        if (date == null) return false;
        if (invoicePeriod == 'Custom range') {
          if (invoiceFrom == null || invoiceTo == null ||
              invoiceFrom!.isAfter(invoiceTo!)) return false;
          final from = DateTime(invoiceFrom!.year, invoiceFrom!.month, invoiceFrom!.day);
          final until = DateTime(invoiceTo!.year, invoiceTo!.month, invoiceTo!.day).add(const Duration(days: 1));
          if (date.isBefore(from) || !date.isBefore(until)) return false;
        } else {
          if (since == null || date.isBefore(since)) return false;
          if (invoicePeriod == 'Yesterday' && !date.isBefore(yesterdayEnd)) return false;
        }
      }
      if (invoiceMethod != 'All methods' &&
          (row['payment_method'] ?? '').toString().toLowerCase() != invoiceMethod.toLowerCase()) return false;
      if (invoiceEmployee.trim().isNotEmpty &&
          (row['employee_id'] ?? row['created_by'] ?? '').toString().toLowerCase() != invoiceEmployee.trim().toLowerCase()) return false;
      if (invoiceSubtype != 'All recorded subtypes' &&
          (row['payment_subtype'] ?? '').toString().trim() != invoiceSubtype) return false;
      return true;
    }).toList();
  }

  Widget _invoiceFilters() => Column(children: [
    DropdownButtonFormField<String>(
      value: invoicePeriod,
      decoration: const InputDecoration(labelText: 'Invoice date filter'),
      items: ['All dates', 'Yesterday', 'Last week', 'Last month', 'Last year', 'Custom range']
        .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: (v) => setState(() => invoicePeriod = v ?? 'All dates'),
    ),
    if (invoicePeriod == 'Custom range') Wrap(spacing: 8, children: [
      TextButton(onPressed: () async {
        final d = await showDatePicker(context: context, initialDate: invoiceFrom ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (d != null) setState(() => invoiceFrom = d);
      }, child: Text('From: ${invoiceFrom?.toIso8601String().substring(0, 10) ?? "Select"}')),
      TextButton(onPressed: () async {
        final d = await showDatePicker(context: context, initialDate: invoiceTo ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (d != null) setState(() => invoiceTo = d);
      }, child: Text('To: ${invoiceTo?.toIso8601String().substring(0, 10) ?? "Select"}')),
    ]),
    if (invoicePeriod == 'Custom range' && invoiceFrom != null &&
        invoiceTo != null && invoiceFrom!.isAfter(invoiceTo!))
      const Text('Invalid date range: From must not be after To.',
          style: TextStyle(color: Colors.red)),
    DropdownButtonFormField<String>(
      value: recordedInvoiceMethods.any(
          (v) => v.toLowerCase() == invoiceMethod.toLowerCase())
          ? recordedInvoiceMethods.firstWhere(
              (v) => v.toLowerCase() == invoiceMethod.toLowerCase())
          : 'All methods',
      decoration: const InputDecoration(labelText: 'Payment method (recorded only)'),
      items: ['All methods', ...recordedInvoiceMethods]
        .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: (v) => setState(() => invoiceMethod = v ?? 'All methods'),
    ),
    DropdownButtonFormField<String>(
      value: recordedInvoiceEmployees.contains(invoiceEmployee)
          ? invoiceEmployee : '',
      decoration: const InputDecoration(labelText: 'Employee (recorded ID only)'),
      items: ['', ...recordedInvoiceEmployees]
          .map((v) => DropdownMenuItem(
              value: v, child: Text(v.isEmpty ? 'All employees' : v))).toList(),
      onChanged: (v) => setState(() => invoiceEmployee = v ?? ''),
    ),
    DropdownButtonFormField<String>(
      value: recordedInvoiceSubtypes.contains(invoiceSubtype)
          ? invoiceSubtype : 'All recorded subtypes',
      decoration: const InputDecoration(labelText: 'Invoice payment subtype (recorded only)'),
      items: ['All recorded subtypes', ...recordedInvoiceSubtypes]
          .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: (v) => setState(() => invoiceSubtype = v ?? 'All recorded subtypes'),
    ),
    const Text('Filters use only available finance fields; unrecorded fields do not match.'),
  ]);

  // Payment preparation drafts are NOT received cash or completed credit payments.
  // Apply only metadata actually returned by the authorized draft RPC.
  String draftMethodFilter = 'All methods';
  String draftStatusFilter = 'All statuses';
  String draftEmployeeFilter = '';
  String draftSubtypeFilter = 'All recorded subtypes';
  String draftPeriodFilter = 'All dates';
  DateTime? draftFrom;
  DateTime? draftTo;

  // A missing/invalid timestamp never qualifies for a requested date filter.
  // Only the fields supplied by the authorized draft RPC are inspected.
  List<Map<String, dynamic>> get visiblePaymentDrafts => paymentDrafts.where((draft) {
    final method = (draft['method'] ?? '').toString().toLowerCase();
    final status = (draft['status'] ?? '').toString().toLowerCase();
    if (draftMethodFilter != 'All methods' && method != draftMethodFilter.toLowerCase()) return false;
    if (draftStatusFilter != 'All statuses' && status != draftStatusFilter.toLowerCase()) return false;
    // Filter only source metadata returned by the authorized backend.
    // Missing employee/subtype fields cannot match an explicit filter.
    if (draftEmployeeFilter.trim().isNotEmpty &&
        (draft['created_by'] ?? '').toString().toLowerCase() !=
          draftEmployeeFilter.trim().toLowerCase()) return false;
    if (draftSubtypeFilter != 'All recorded subtypes' &&
        (draft['payment_subtype'] ?? '').toString() != draftSubtypeFilter) return false;
    if (draftPeriodFilter == 'All dates') return true;
    final date = DateTime.tryParse((draft['created_at'] ?? '').toString())?.toLocal();
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (draftPeriodFilter == 'Custom range') {
      if (draftFrom == null || draftTo == null) return false;
      final from = DateTime(draftFrom!.year, draftFrom!.month, draftFrom!.day);
      final end = DateTime(draftTo!.year, draftTo!.month, draftTo!.day).add(const Duration(days: 1));
      return !date.isBefore(from) && date.isBefore(end);
    }
    DateTime? start;
    if (draftPeriodFilter == 'Yesterday') start = today.subtract(const Duration(days: 1));
    if (draftPeriodFilter == 'Last week') start = today.subtract(const Duration(days: 7));
    if (draftPeriodFilter == 'Last month') start = DateTime(today.year, today.month - 1, today.day);
    if (draftPeriodFilter == 'Last year') start = DateTime(today.year - 1, today.month, today.day);
    if (start == null || date.isBefore(start) || date.isAfter(now)) return false;
    return draftPeriodFilter != 'Yesterday' || date.isBefore(today);
  }).toList();

  // Only offer subtype values actually present in authorized draft results.
  List<String> get recordedDraftSubtypes => paymentDrafts
      .map((row) => (row['payment_subtype'] ?? '').toString().trim())
      .where((value) => value.isNotEmpty).toSet().toList()..sort();

  Future<void> _showDraftDetails(Map<String, dynamic> draft) async {
    if (!mounted) return;
    const allowed = ['intent_id', 'finance_invoice_id', 'amount_iqd',
      'method', 'status', 'created_at', 'created_by', 'payment_subtype'];
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Payment draft details — read only'),
      content: SizedBox(width: 480, child: ListView(shrinkWrap: true,
        children: [
          for (final key in allowed)
            ListTile(dense: true, title: Text(key.replaceAll('_', ' ')),
              subtitle: Text(draft[key]?.toString() ?? 'Not recorded')),
          const Text('Drafts are not proof of collected funds. Official invoice printing is not enabled.'),
        ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx),
        child: const Text('Close'))],
    ));
  }

  Widget _draftFilters() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Wrap(spacing: 12, runSpacing: 8, children: [
      DropdownButton<String>(
        value: draftPeriodFilter,
        items: ['All dates', 'Yesterday', 'Last week', 'Last month', 'Last year', 'Custom range']
            .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => draftPeriodFilter = v ?? 'All dates'),
      ),
      if (draftPeriodFilter == 'Custom range') TextButton(
        onPressed: () async {
          final picked = await showDatePicker(context: context,
            initialDate: draftFrom ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (picked != null && mounted) setState(() => draftFrom = picked);
        }, child: Text('From: ${draftFrom?.toIso8601String().substring(0, 10) ?? "Select"}'),
      ),
      if (draftPeriodFilter == 'Custom range') TextButton(
        onPressed: () async {
          final picked = await showDatePicker(context: context,
            initialDate: draftTo ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (picked != null && mounted) setState(() => draftTo = picked);
        }, child: Text('To: ${draftTo?.toIso8601String().substring(0, 10) ?? "Select"}'),
      ),
      DropdownButton<String>(
        value: draftMethodFilter,
        items: ['All methods', 'cash', 'credit', 'electronic']
            .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => draftMethodFilter = v ?? 'All methods'),
      ),
      SizedBox(width: 210, child: TextFormField(
        decoration: const InputDecoration(labelText: 'Creator employee ID (recorded)'),
        onChanged: (value) => setState(() => draftEmployeeFilter = value),
      )),
      DropdownButton<String>(
        value: recordedDraftSubtypes.contains(draftSubtypeFilter)
          ? draftSubtypeFilter : 'All recorded subtypes',
        items: ['All recorded subtypes', ...recordedDraftSubtypes]
          .map((value) => DropdownMenuItem(value: value, child: Text(value)))
          .toList(),
        onChanged: (value) => setState(() =>
          draftSubtypeFilter = value ?? 'All recorded subtypes'),
      ),
      DropdownButton<String>(
        value: draftStatusFilter,
        items: ['All statuses', 'draft', 'cancelled', 'settled']
            .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => draftStatusFilter = v ?? 'All statuses'),
      ),
    ]),
  );

  Widget _draftListTotal() {
    final amounts = visiblePaymentDrafts.map((draft) {
      final value = draft['amount_iqd'];
      if (value is int) return value >= 0 ? value : null;
      if (value is num && value.isFinite && value >= 0 && value == value.roundToDouble()) {
        return value.toInt();
      }
      final parsed = int.tryParse(value?.toString() ?? '');
      return parsed != null && parsed >= 0 ? parsed : null;
    }).toList();
    final invalid = amounts.any((v) => v == null);
    final sum = amounts.whereType<int>().fold<int>(0, (a, b) => a + b);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Total of listed payment preparation drafts: '
          '${invalid ? "Unavailable — check amounts" : "$sum IQD"} '
          '(${visiblePaymentDrafts.length} records)',
          style: const TextStyle(fontWeight: FontWeight.bold)),
        const Text('Preparation amounts only; NOT confirmed payments or collected revenue.'),
      ]),
    );
  }

  List<Map<String, dynamic>> paymentDrafts = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (loading) return;
    setState(() { loading = true; error = null; });
    try {
      final result = await Supabase.instance.client.rpc('gs_staff_motel_food_finance_handoff');
      final posted = await Supabase.instance.client.rpc('gs_staff_list_motel_food_finance_invoices');
      final drafts = await Supabase.instance.client.rpc('gs_staff_list_motel_food_payment_drafts');
      if (!mounted) return;
      setState(() {
        postedInvoices = (posted as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        paymentDrafts = (drafts as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
      if (!mounted) return;
      setState(() => entries = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _showLineAudit(String invoiceId) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_motel_food_finance_line_audit',
        params: {'p_invoice_id': invoiceId},
      );
      if (!mounted) return;
      final lines = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Food Invoice Source Audit'),
          content: SizedBox(
            width: 650,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text('Read-only verification. No payment or unified invoice is created.'),
                if (lines.isEmpty) const Text('No registered source lines found.'),
                ...lines.map((line) => ListTile(
                  leading: Icon(line['line_status'] == 'matched'
                      ? Icons.check_circle_outline : Icons.warning_amber_outlined),
                  title: Text('${line['registered_iqd']} IQD — ${line['line_status']}'),
                  subtitle: Text('Order: ${line['source_order_id']}\n'
                      'Ledger: ${line['source_ledger_id']}\n'
                      'Reservation: ${line['reservation_id']}\n'
                      'Ledger amount: ${line['ledger_iqd']} IQD; '
                      'Order amount: ${line['order_iqd']} IQD'),
                  isThreeLine: true,
                )),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Source audit unavailable: $e')),
      );
    }
  }

  Future<void> _showReadiness(String invoiceId) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_motel_food_invoice_readiness',
        params: {'p_invoice_id': invoiceId},
      );
      if (!mounted) return;
      final records = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (records.isEmpty) throw StateError('Readiness report unavailable');
      final report = records.first;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Food Invoice Readiness'),
          content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Status: ${report['readiness_status']}'),
              Text('Source lines: ${report['actual_lines']} / ${report['expected_lines']}'),
              Text('Matched lines: ${report['matched_lines']}'),
              Text('Blocked lines: ${report['blocked_lines']}'),
              Text('Amount: ${report['actual_iqd']} / ${report['expected_iqd']} IQD'),
              const SizedBox(height: 12),
              const Text('Source verification only. Unified invoice and payment posting are not enabled.'),
            ]),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Readiness check failed: $e')),
      );
    }
  }

  Future<void> _showAttestationStatus(String invoiceId) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_motel_food_attestation_status',
        params: {'p_invoice_id': invoiceId},
      );
      if (!mounted) return;
      final rows = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) throw StateError('Attestation status unavailable');
      final status = rows.first;
      final state = status['attestation_status']?.toString() ?? 'unknown';
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Finance Handoff Status'),
        content: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Status: ${state == 'valid' ? 'Valid Attestation' : state == 'stale' ? 'Stale — Reconciliation Required' : 'Not Attested'}'),
          Text('Current amount: ${status['current_total_iqd']} IQD'),
          Text('Current source orders: ${status['current_source_count']}'),
          if (status['attested_at'] != null) ...[
            Text('Attested at: ${status['attested_at']}'),
            Text('Attested amount: ${status['attested_total_iqd']} IQD'),
            Text('Attested orders: ${status['attested_source_count']}'),
          ],
          const SizedBox(height: 12),
          const Text('This status does not indicate payment or a unified invoice.'),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attestation status unavailable: $e')));
    }
  }

  Future<void> _attestHandoff(String invoiceId) async {
    final controller = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Finance Handoff Attestation'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Confirm source reconciliation only. This does not create a unified invoice or payment.'),
            TextField(controller: controller, maxLength: 500,
              decoration: const InputDecoration(labelText: 'Review note (required)',
                hintText: 'Explain what was verified')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Attest Handoff')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final note = controller.text.trim();
      if (note.length < 5) throw StateError('Enter at least five characters for the review note');
      final result = await Supabase.instance.client.rpc(
        'gs_staff_attest_motel_food_finance_handoff',
        params: {'p_invoice_id': invoiceId, 'p_note': note},
      );
      if (!mounted) return;
      final rows = (result as List).cast<Map>();
      final existing = rows.isNotEmpty && rows.first['already_attested'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(existing
        ? 'Previously attested; source fingerprint still matches.'
        : 'Finance source handoff attested. No payment posted.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Handoff attestation failed: $e')));
    } finally {
      controller.dispose();
    }
  }

  Future<void> _checkIntakeIntegrity(String invoiceId) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_motel_food_intake_integrity',
        params: {'p_food_invoice_id': invoiceId},
      );
      if (!mounted) return;
      final rows = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) throw StateError('No intake integrity result');
      final item = rows.first;
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Finance Intake Integrity'),
        content: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Status: ${item['intake_status']}'),
          Text('Issues: ${item['issue_count']}'),
          Text('Details: ${item['details']}'),
          Text('Intake amount: ${item['intake_total_iqd'] ?? '—'} IQD'),
          Text('Current amount: ${item['current_total_iqd']} IQD'),
          const SizedBox(height: 12),
          const Text('Verification only — no unified invoice or payment is posted.'),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Intake integrity check failed: $e')));
    }
  }

  Future<void> _createIntakeDraft(String invoiceId) async {
    final confirm = await showDialog<bool>(context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Finance Intake Draft'),
        content: const Text('Create a verified food-only finance intake draft? This does not issue an official invoice or collect payment.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Create Draft')),
        ],
      ));
    if (confirm != true || !mounted) return;
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_create_motel_food_invoice_intake',
        params: {'p_food_invoice_id': invoiceId},
      );
      if (!mounted) return;
      final rows = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) throw StateError('Intake response missing');
      final record = rows.first;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        record['already_created'] == true
          ? 'Existing intake draft verified. No duplicate created.'
          : 'Finance intake draft created for ${record['total_iqd']} IQD. No payment posted.',
      )));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot create intake draft: $e')));
    }
  }

  Future<void> _postFinanceInvoice(String invoiceId) async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Post Motel Food Finance Invoice'),
        content: const Text('Post verified food charges to the dedicated finance invoice register? '
          'This does NOT collect payment or update the shared accounting invoice system.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Post Invoice')),
        ],
      ));
    if (confirmed != true || !mounted) return;
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_post_motel_food_finance_invoice',
        params: {'p_food_invoice_id': invoiceId},
      );
      if (!mounted) return;
      final rows = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) throw StateError('No finance posting result');
      final row = rows.first;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        row['already_posted'] == true
          ? 'Existing finance invoice verified — no duplicate posted.'
          : 'Food finance invoice posted: ${row['total_iqd']} IQD. Payment remains unpaid.',
      )));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Finance invoice posting blocked: $e')));
    }
  }

  Future<void> _checkPostedFinanceInvoice(String financeId) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_check_motel_food_finance_invoice',
        params: {'p_finance_invoice_id': financeId});
      if (!mounted) return;
      final rows = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) throw StateError('No reconciliation result');
      final r = rows.first;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Posted Invoice Reconciliation'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Status: ${r['check_status']}'),
          Text('Issues: ${r['issue_count']}'),
          Text('Orders: ${r['actual_count']} / ${r['expected_count']}'),
          Text('Amount: ${r['actual_iqd']} / ${r['expected_iqd']} IQD'),
          Text('${r['details']}'),
          const SizedBox(height: 12),
          const Text('Read-only audit. No payment is collected.'),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Finance reconciliation failed: $e')));
    }
  }

  Future<void> _checkPaymentEligibility(String financeId) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_motel_food_payment_eligibility',
        params: {'p_finance_invoice_id': financeId},
      );
      if (!mounted) return;
      final rows = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) throw StateError('Payment eligibility result unavailable');
      final r = rows.first;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Payment Eligibility — Read Only'),
        content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Eligibility: ${r['eligibility_status']}'),
            Text('Amount: ${r['amount_due_iqd']} IQD'),
            Text('Invoice payment status: ${r['payment_status']}'),
            Text('Source reconciliation: ${r['source_status']}'),
            Text('Issues: ${r['issue_count']}'),
            Text('${r['details']}'),
            const SizedBox(height: 12),
            const Text('This does not collect cash, process electronic payments, '
                'debit customer credit, or mark the invoice paid.'),
          ],
        )),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment eligibility unavailable: $e')));
    }
  }

  String _newPaymentAttemptId() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> _preparePaymentDraft(String financeId) async {
    String selectedMethod = 'cash';
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: const Text('Prepare Payment Draft'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Preparation only. No cash is collected, credit debited, or electronic transaction processed.'),
          DropdownButton<String>(value: selectedMethod, isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'credit', child: Text('Credit — no debit')),
              DropdownMenuItem(value: 'electronic', child: Text('Electronic — no transfer')),
            ], onChanged: (v) { if (v != null) update(() => selectedMethod = v); }),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Prepare Only')),
        ],
      )),
    );
    if (confirmed != true || !mounted) return;
    try {
      final key = Supabase.instance.client.auth.currentUser?.id;
      if (key == null) throw StateError('Employee session required');
      // A fresh UUID identifies each preparation attempt; the backend prevents duplicates.
      final result = await Supabase.instance.client.rpc('gs_staff_prepare_motel_food_payment',
        params: {'p_finance_invoice_id': financeId, 'p_method': selectedMethod,
          'p_idempotency_key': _newPaymentAttemptId()});
      if (!mounted) return;
      final rows = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) throw StateError('Payment draft not returned');
      final r = rows.first;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        'Payment draft ${r['already_prepared'] == true ? 'verified' : 'prepared'}: '
        '${r['amount_iqd']} IQD (${r['method']}). No payment processed.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment preparation blocked: $e')));
    }
  }

  Future<void> _checkPaymentDraft(String intentId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_check_motel_food_payment_draft',
        params: {'p_intent_id': intentId},
      );
      final rows = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) throw StateError('Draft integrity report unavailable');
      if (!mounted) return;
      final r = rows.first;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Payment Draft Integrity'),
          content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Status: ${r['check_status']}'),
              Text('Method: ${r['method']}'),
              Text('Draft amount: ${r['amount_iqd']} IQD'),
              Text('Invoice amount: ${r['invoice_amount_iqd']} IQD'),
              Text('Invoice status: ${r['invoice_payment_status']}'),
              Text('${r['details']}'),
              const SizedBox(height: 8),
              const Text('Read-only check. No funds have been moved.'),
            ]),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Draft check unavailable: $e')));
    }
  }

  Future<void> _showLedgerCompatibility(String intentId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_motel_payment_ledger_compatibility',
        params: {'p_intent_id': intentId},
      );
      if (!mounted) return;
      final rows = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) throw StateError('No compatibility report returned');
      final r = rows.first;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Shared Ledger Compatibility'),
        content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${r['compatibility_status']}'),
            Text('Method: ${r['payment_method']}'),
            Text('Amount: ${r['amount_iqd']} IQD'),
            Text('Motel source: ${r['source_order_model']}'),
            Text('Shared ledger: ${r['destination_order_model']}'),
            const SizedBox(height: 12),
            Text('${r['reason']}'),
            const SizedBox(height: 12),
            const Text('Diagnostic only — no money collected or posted.'),
          ],
        ))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ledger compatibility unavailable: $e')));
    }
  }

  Future<void> _showPaymentDraftHistory(String financeId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_motel_food_payment_draft_history',
        params: {'p_finance_invoice_id': financeId});
      if (!mounted) return;
      final history = (response as List)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Payment Draft History'),
        content: SizedBox(width: 520, child: history.isEmpty
          ? const Text('No payment drafts for this invoice.')
          : ListView.builder(shrinkWrap: true, itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                return ListTile(
                  title: Text('${item['amount_iqd']} IQD • ${item['method']} • ${item['status']}'),
                  subtitle: Text('Created: ${item['created_at']}\n'
                    'Created by: ${item['created_by']}\n'
                    'Cancelled: ${item['cancelled_at'] ?? '—'}\n'
                    'Cancelled by: ${item['cancelled_by'] ?? '—'}\n'
                    'Reason: ${item['cancellation_reason'] ?? '—'}'),
                  isThreeLine: true,
                );
              })),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Unable to load payment draft history: $e')));
    }
  }

  Future<void> _cancelPaymentDraft(String intentId) async {
    final reason = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancel Payment Draft'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('This cancels preparation only. No payment has been processed.'),
            TextField(controller: reason, maxLength: 500,
              decoration: const InputDecoration(labelText: 'Cancellation reason (required)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Draft')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel Draft')),
          ],
        ));
      if (confirmed != true || !mounted) return;
      if (reason.text.trim().length < 5) throw StateError('Enter a reason of at least 5 characters');
      await Supabase.instance.client.rpc('gs_staff_cancel_motel_food_payment_draft',
        params: {'p_intent_id': intentId, 'p_reason': reason.text.trim()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment draft cancelled. No funds moved.')));
      await _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cancellation blocked: $e')));
    } finally {
      reason.dispose();
    }
  }

  Future<void> _registerFinanceSource(String financeId) async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register Finance Source'),
        content: const Text('Register the verified motel-food invoice source? '
          'This does not create a legacy order, collect payment, or mark an invoice paid.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Register')),
        ],
      ));
    if (confirmed != true || !mounted) return;
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_register_motel_finance_source',
        params: {'p_invoice_id': financeId});
      if (!mounted) return;
      final rows = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) throw StateError('No source registration returned');
      final record = rows.first;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        record['already_registered'] == true
          ? 'Existing finance source verified; no duplicate registered.'
          : 'Finance source registered for ${record['amount_iqd']} IQD. No payment posted.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Source registration blocked: $e')));
    }
  }

  Future<void> _prepareAllocationPlan(String intentId) async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Prepare Allocation Review Plan'),
        content: const Text('Create an auditable UUID-based review plan? '
          'This does NOT collect cash, deduct credit, post to the ledger, or mark an invoice paid.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Prepare Plan')),
        ],
      ));
    if (confirmed != true || !mounted) return;
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_prepare_motel_allocation_plan',
        params: {'p_intent_id': intentId});
      if (!mounted) return;
      final rows = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) throw StateError('No allocation plan returned');
      final plan = rows.first;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Allocation Review Plan'),
        content: Text('Plan: ${plan['plan_id']}\n'
          'Status: ${plan['plan_status']}\n'
          'Amount: ${plan['amount_iqd']} IQD\n'
          'Existing plan: ${plan['already_prepared']}\n\n'
          'Review only — no payment has been processed.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Allocation plan blocked: $e')));
    }
  }

  Future<void> _prepareCashConfirmationReview(String intentId) async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cashier Confirmation Review'),
        content: const Text('Prepare a cash confirmation review for the cashier? '
          'This is NOT a receipt, cash collection, payment posting, or paid invoice.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Prepare Review')),
        ],
      ));
    if (confirmed != true || !mounted) return;
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_prepare_motel_cash_confirmation',
        params: {'p_intent_id': intentId});
      if (!mounted) return;
      final rows = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) throw StateError('No cashier review returned');
      final record = rows.first;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Cashier Review Prepared'),
        content: Text('Review: ${record['review_id']}\n'
          'Status: ${record['review_status']}\n'
          'Amount: ${record['amount_iqd']} IQD\n'
          'Existing: ${record['already_prepared']}\n\n'
          'No money collected or invoice marked paid.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cashier review blocked: $e')));
    }
  }

  Future<void> _acknowledgeCashReceived(String intentId) async {
    final receipt = TextEditingController();
    final note = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(context: context, builder: (ctx) =>
        AlertDialog(
          title: const Text('Acknowledge Physical Cash Receipt'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Only continue after physically receiving the full cash amount. '
              'This records a cashier attestation, NOT a settled ledger payment or paid invoice.'),
            TextField(controller: receipt, maxLength: 100,
              decoration: const InputDecoration(labelText: 'Unique receipt reference (required)')),
            TextField(controller: note, maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Cashier note (optional)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm Cash Received')),
          ],
        ));
      if (confirmed != true || !mounted) return;
      if (receipt.text.trim().isEmpty) throw StateError('Receipt reference is required');
      final response = await Supabase.instance.client.rpc(
        'gs_staff_acknowledge_motel_cash_received', params: {
          'p_intent_id': intentId,
          'p_receipt_reference': receipt.text.trim(),
          'p_note': note.text.trim(),
        });
      if (!mounted) return;
      final rows = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) throw StateError('No cashier acknowledgement returned');
      final record = rows.first;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Cash Receipt Recorded'),
        content: Text('Review: ${record['review_id']}\n'
          'Status: ${record['review_status']}\n'
          'Received at: ${record['received_at']}\n'
          'Already recorded: ${record['already_acknowledged']}\n\n'
          'Settlement is still pending. The invoice remains unpaid in the ledger.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cash receipt blocked: $e')));
    } finally {
      receipt.dispose();
      note.dispose();
    }
  }

  Future<void> _showCashSettlementReport() async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_motel_cash_settlement_report', params: {'p_limit': 100});
      if (!mounted) return;
      final rows = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final matched = rows.where((e) => e['reconciliation_status'] == 'matched').length;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Motel Cash Settlement Report'),
        content: SizedBox(width: 650, height: 440,
          child: Column(children: [
            Text('Latest ${rows.length} settlements • $matched matched • '
              '${rows.length - matched} require investigation'),
            const Divider(),
            Expanded(child: rows.isEmpty
              ? const Center(child: Text('No cash settlements recorded.'))
              : ListView.builder(itemCount: rows.length, itemBuilder: (_, index) {
                  final r = rows[index];
                  return ListTile(
                    leading: Icon(r['reconciliation_status'] == 'matched'
                      ? Icons.verified_outlined : Icons.warning_amber_outlined),
                    title: Text('${r['amount_iqd']} IQD • ${r['receipt_reference']}'),
                    subtitle: Text('Status: ${r['reconciliation_status']}\\n'
                      'Invoice: ${r['finance_invoice_id']}\\n'
                      'Invoice amount: ${r['invoice_total_iqd']} IQD • '
                      '${r['payment_status']}\\n'
                      'Settled by: ${r['settled_by']} • ${r['settled_at']}'),
                    isThreeLine: true,
                  );
                })),
          ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Settlement report unavailable: $e')));
    }
  }

  Future<void> _showCreditSchemaInventory() async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_motel_credit_schema_inventory');
      if (!mounted) return;
      final rows = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Credit Account Schema Inventory'),
        content: SizedBox(width: 690, height: 440,
          child: Column(children: [
            const Text('Administrator diagnostic: table definitions only. '
              'No balances or account ownership have been verified. '
              'Credit payment remains blocked.'),
            const Divider(),
            Expanded(child: rows.isEmpty
              ? const Center(child: Text('No matching account tables found.'))
              : ListView.builder(itemCount: rows.length, itemBuilder: (_, i) {
                  final item = rows[i];
                  return ExpansionTile(
                    title: Text('${item['object_name']} (${item['object_kind']})'),
                    subtitle: Text('Row security: ${item['row_security_enabled']}'),
                    children: [Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText('${item['column_names']}\\n\\n'
                        '${item['integration_note']}'),
                    )],
                  );
                })),
          ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Credit schema inventory unavailable: $e')));
    }
  }

  Future<void> _showCreditBackendReadiness(String intentId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_motel_credit_backend_readiness',
        params: {'p_intent_id': intentId});
      if (!mounted) return;
      final checks = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Credit Backend Integration Checks'),
        content: SizedBox(width: 620, height: 440,
          child: ListView(children: [
            const Text('Diagnostic only. Credit payments are BLOCKED until '
              'account ownership, balance, limits and atomic debit are verified.'),
            const Divider(),
            for (final c in checks) ListTile(
              leading: Icon(c['check_status'] == 'pass' || c['check_status'] == 'present'
                ? Icons.info_outline : Icons.block_outlined),
              title: Text('${c['check_name']}: ${c['check_status']}'),
              subtitle: Text('${c['detail']}'),
            ),
          ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Credit integration check unavailable: $e')));
    }
  }

  Future<void> _reviewCreditEvidence(String requestId) async {
    final note = TextEditingController();
    String kind = 'review_note';
    try {
      final selected = await showDialog<Map<String, String>>(context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) =>
          AlertDialog(
            title: const Text('Credit Verification Evidence'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('This records review notes only. It does not verify '
                'customer ownership, credit balance, consent or authorize payment.'),
              DropdownButtonFormField<String>(
                value: kind,
                items: const [
                  DropdownMenuItem(value: 'review_note', child: Text('Review note')),
                  DropdownMenuItem(value: 'ownership_evidence_requested', child: Text('Ownership evidence requested')),
                  DropdownMenuItem(value: 'ownership_evidence_received', child: Text('Ownership evidence received')),
                  DropdownMenuItem(value: 'balance_provider_required', child: Text('Balance provider required')),
                  DropdownMenuItem(value: 'customer_consent_required', child: Text('Customer consent required')),
                ],
                onChanged: (v) => setDialogState(() => kind = v ?? 'review_note')),
              TextField(controller: note, maxLength: 1000, maxLines: 3,
                decoration: const InputDecoration(labelText: 'Review note (10+ characters)')),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx,
                {'type': kind, 'note': note.text.trim()}),
                child: const Text('Save Review')),
            ],
          )));
      if (selected == null || !mounted) return;
      if ((selected['note'] ?? '').length < 10) {
        throw StateError('Review note must contain at least 10 characters');
      }
      await Supabase.instance.client.rpc(
        'gs_staff_note_motel_credit_verification',
        params: {'p_request_id': requestId,
          'p_review_type': selected['type'], 'p_note': selected['note']});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credit review recorded; payment remains blocked.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Credit review failed: $e')));
    } finally {
      note.dispose();
    }
  }

  Future<void> _showCreditVerificationGate(String requestId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_motel_credit_verification_gate',
        params: {'p_request_id': requestId});
      if (!mounted) return;
      final checks = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Credit Verification Gate'),
        content: SizedBox(width: 590, height: 420,
          child: ListView.separated(
            itemCount: checks.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, index) {
              final c = checks[index];
              final ok = c['check_status'] == 'pass';
              return ListTile(
                leading: Icon(ok ? Icons.check_circle_outline : Icons.block_outlined),
                title: Text('${c['check_name']}: ${c['check_status']}'),
                subtitle: Text('${c['explanation']}'),
              );
            },
          )),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Credit verification gate unavailable: $e')));
    }
  }

  Future<void> _showCreditEvidenceHistory(String requestId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_list_motel_credit_review_events',
        params: {'p_request_id': requestId});
      if (!mounted) return;
      final rows = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Credit Evidence Review History'),
        content: SizedBox(
          width: 580,
          height: 390,
          child: rows.isEmpty
            ? const Center(child: Text('No review events recorded.'))
            : ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, index) {
                  final event = rows[index];
                  final kind = event['review_type']?.toString()
                    .replaceAll('_', ' ') ?? 'Review';
                  return ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(kind),
                    subtitle: Text(
                      '${event['note']}\\n'
                      'Employee: ${event['reviewed_by']}\\n'
                      'Date: ${event['reviewed_at']}'),
                    isThreeLine: true,
                  );
                },
              ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Close')),
        ],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Credit evidence history unavailable: $e')));
    }
  }

  Future<void> _showCreditVerificationReview(String intentId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_list_motel_credit_verifications',
        params: {'p_intent_id': intentId});
      if (!mounted) return;
      final rows = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Credit Verification Requests'),
        content: SizedBox(width: 600, height: 380,
          child: rows.isEmpty
            ? const Center(child: Text('No credit verification requests.'))
            : ListView.builder(itemCount: rows.length, itemBuilder: (_, index) {
                final q = rows[index];
                return ListTile(
                  title: Text('${q['account_label']} • ${q['amount_iqd']} IQD'),
                  subtitle: Text('Status: ${q['request_status']}\\n'
                    'Requested: ${q['requested_at']} by ${q['requested_by']}'
                    '${q['cancellation_reason'] == null ? '' : '\\nCancellation: ${q['cancellation_reason']}'}'),
                  isThreeLine: true,
                  trailing: Wrap(children: [
                    TextButton(onPressed: () async {
                      Navigator.pop(ctx);
                      await _showCreditVerificationGate(q['request_id'].toString());
                      if (mounted) await _showCreditVerificationReview(intentId);
                    }, child: const Text('Verification Gate')),
                    TextButton(onPressed: () async {
                      Navigator.pop(ctx);
                      await _showCreditEvidenceHistory(q['request_id'].toString());
                      if (mounted) await _showCreditVerificationReview(intentId);
                    }, child: const Text('Review History')),
                    if (q['request_status'] == 'pending') ...[
                      TextButton(onPressed: () async {
                        Navigator.pop(ctx);
                        await _reviewCreditEvidence(q['request_id'].toString());
                        if (mounted) await _showCreditVerificationReview(intentId);
                      }, child: const Text('Review Evidence')),
                      TextButton(onPressed: () async {
                        Navigator.pop(ctx);
                        await _cancelCreditVerification(q['request_id'].toString());
                        if (mounted) await _showCreditVerificationReview(intentId);
                      }, child: const Text('Cancel Request')),
                    ],
                  ]),
                );
              })),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Credit request history unavailable: $e')));
    }
  }

  Future<void> _cancelCreditVerification(String requestId) async {
    final controller = TextEditingController();
    try {
      final reason = await showDialog<String>(context: context, builder: (ctx) =>
        AlertDialog(
          title: const Text('Cancel Credit Verification'),
          content: TextField(controller: controller, maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Reason (required, at least 5 characters)')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Back')),
            FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Cancel Request')),
          ],
        ));
      if (reason == null || reason.length < 5 || !mounted) return;
      await Supabase.instance.client.rpc(
        'gs_staff_cancel_motel_credit_verification',
        params: {'p_request_id': requestId, 'p_reason': reason});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credit verification request cancelled. No debit performed.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cancellation failed: $e')));
    } finally {
      controller.dispose();
    }
  }

  Future<void> _requestCreditVerification(String intentId) async {
    final barcodeController = TextEditingController();
    try {
      final barcode = await showDialog<String>(context: context, builder: (ctx) =>
        AlertDialog(
          title: const Text('Request Credit Verification'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Enter the customer barcode to create a pending '
              'credit verification request. This does not confirm ownership, '
              'available balance, or debit any account.'),
            TextField(controller: barcodeController, obscureText: true,
              decoration: const InputDecoration(labelText: 'Customer barcode')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, barcodeController.text.trim()),
              child: const Text('Request Verification')),
          ],
        ));
      if (barcode == null || barcode.isEmpty || !mounted) return;
      final result = await Supabase.instance.client.rpc(
        'gs_staff_request_motel_credit_verification',
        params: {'p_intent_id': intentId, 'p_barcode': barcode});
      if (!mounted) return;
      final rows = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) throw StateError('No verification request returned');
      final request = rows.first;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Credit verification ${request['request_status']}: '
          '${request['account_label']} • ${request['amount_iqd']} IQD. '
          'No credit deducted.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Credit verification request blocked: $e')));
    } finally {
      barcodeController.dispose();
    }
  }

  Future<void> _lookupCreditBarcode(String intentId) async {
    final controller = TextEditingController();
    try {
      final barcode = await showDialog<String>(context: context, builder: (ctx) =>
        AlertDialog(
          title: const Text('Identify Credit Account'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Scan the customer barcode into the field or enter it manually. '
              'Identity lookup does not verify the balance or charge the account.'),
            TextField(controller: controller, autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Customer barcode')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Look Up')),
          ],
        ));
      if (barcode == null || barcode.isEmpty || !mounted) return;
      final response = await Supabase.instance.client.rpc(
        'gs_staff_lookup_motel_credit_barcode',
        params: {'p_intent_id': intentId, 'p_barcode': barcode});
      if (!mounted) return;
      final rows = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) throw StateError('No lookup result returned');
      final result = rows.first;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Credit Identity Lookup'),
        content: Text('Status: ${result['identity_status']}\\n'
          'Account: ${result['account_label'] ?? 'Not found'}\\n'
          'Reference: ${result['account_reference'] ?? '—'}\\n'
          'Invoice amount: ${result['draft_amount_iqd']} IQD\\n\\n'
          '${result['verification_note']}'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Credit identity lookup failed: $e')));
    } finally {
      controller.dispose();
    }
  }

  Future<void> _checkCreditReadiness(String intentId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_check_motel_credit_readiness',
        params: {'p_intent_id': intentId});
      if (!mounted) return;
      final rows = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) throw StateError('Credit readiness response missing');
      final result = rows.first;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Credit Payment Readiness'),
        content: Text('Status: ${result['readiness_status']}\n'
          'Amount: ${result['amount_iqd']} IQD\n'
          'Invoice: ${result['invoice_id']}\n\n'
          '${result['details']}'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Credit readiness check failed: $e')));
    }
  }

  Future<void> _settleCash(String intentId) async {
    try {
      final confirmed = await showDialog<bool>(context: context, builder: (ctx) =>
        AlertDialog(
          title: const Text('Finalize Cash Settlement'),
          content: const Text('This action records a real cash settlement in the '
            'Motel Food finance ledger and marks its invoice paid. '
            'Confirm only after checking the cashier receipt. '
            'It does not post to the legacy shared numeric-order ledger.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Settle Cash')),
          ],
        ));
      if (confirmed != true || !mounted) return;
      final response = await Supabase.instance.client.rpc(
        'gs_staff_settle_motel_food_cash',
        params: {'p_intent_id': intentId});
      if (!mounted) return;
      final rows = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) throw StateError('No settlement returned');
      final result = rows.first;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Motel Cash Settled'),
        content: Text('Settlement: ${result['settlement_id']}\\n'
          'Receipt: ${result['receipt_reference']}\\n'
          'Time: ${result['settled_at']}\\n'
          'Previously settled: ${result['already_settled']}\\n\\n'
          'Recorded in the motel-food cash settlement ledger only.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
      await _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cash settlement blocked: $e')));
    }
  }

  Future<void> _checkPaymentSource(String intentId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_check_motel_payment_source',
        params: {'p_intent_id': intentId});
      if (!mounted) return;
      final rows = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) throw StateError('No source check returned');
      final result = rows.first;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Payment Source Readiness'),
        content: SizedBox(width: 540, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${result['source_status']}'),
            Text('Amount: ${result['amount_iqd']} IQD'),
            Text('Invoice: ${result['finance_invoice_id']}'),
            Text('Bridge: ${result['bridge_id'] ?? 'Not registered'}'),
            const SizedBox(height: 8),
            Text('${result['details']}'),
            const SizedBox(height: 8),
            const Text('Read-only. Payment posting is disabled.'),
          ],
        ))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment source check blocked: $e')));
    }
  }

  Future<void> _showFinanceSource(String financeId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_get_motel_finance_source',
        params: {'p_invoice_id': financeId});
      if (!mounted) return;
      final rows = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Finance Source Mapping'),
        content: SizedBox(width: 550, child: SingleChildScrollView(child:
          rows.isEmpty ? const Text('No registered source mapping yet.') :
          Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Bridge ID: ${rows.first['bridge_id']}'),
              Text('Guest stay: ${rows.first['guest_session_id']}'),
              Text('Room: ${rows.first['room_id']}'),
              Text('Amount: ${rows.first['amount_iqd']} IQD'),
              Text('Mapping: ${rows.first['mapping_status']}'),
              Text('Legacy order: ${rows.first['legacy_order_id'] ?? 'Not linked'}'),
              Text('Created: ${rows.first['created_at']}'),
              const SizedBox(height: 12),
              const Text('Read-only mapping. No payment or legacy ledger posting.'),
            ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Source mapping unavailable: $e')));
    }
  }

  // Read-only finance source inspection. Never attempts settlement.
  Future<void> _showFinanceSourceOrderProducts(Object? rawOrderId) async {
    final orderId = int.tryParse(rawOrderId?.toString() ?? '');
    if (orderId == null || orderId <= 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A valid linked order ID is unavailable.')));
      return;
    }
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_finance_itemized_order_detail', params: {'p_order_id': orderId});
      if (!mounted) return;
      if (response is! Map) throw const FormatException('Unexpected detail response');
      final detail = Map<String, dynamic>.from(response);
      final items = (detail['items'] as List? ?? const [])
          .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      String display(Object? value) => value == null || value.toString().isEmpty
          ? 'Not recorded' : value.toString();
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text('Source Order #$orderId — Products'),
        content: SizedBox(width: 650, child: ListView(shrinkWrap: true, children: [
          const Text('Read-only source data. Payment and delivery actions are not available.'),
          Text('Order status: ${display(detail['status'])}'),
          Text('Order created: ${display(detail['created_at'])}'),
          Text('Delivery address: ${display(detail['delivery_address'])}'),
          Text('Customer phone: ${display(detail['customer_phone'])}'),
          Text('Requested delivery: ${display(detail['requested_delivery_at'])}'),
          Text('Motel room: ${display(detail['room_number'])}'),
          Text('Delivery employee: ${display(detail['delivery_employee_id'])}'),
          Text('Delivery status: ${display(detail['delivery_status'])}'),
          if (items.isEmpty) const Text('No itemized products returned.'),
          ...items.map((item) => ListTile(
            title: Text(display(item['product_name'])),
            subtitle: Text('Quantity: ${display(item['quantity'])} • Unit: ${display(item['unit_price_iqd'])} IQD\n'
                'Ordered: ${display(item['ordered_at'])} • Customer: ${display(item['individual_customer'])}'),
            trailing: Text('${display(item['line_total_iqd'])} IQD'),
          )),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Source order details unavailable: $e')));
    }
  }

  Future<void> _showPostedInvoiceLines(String financeId) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_motel_food_finance_invoice_line_details',
        params: {'p_finance_invoice_id': financeId},
      );
      if (!mounted) return;
      final lines = (result as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Posted Food Invoice — Source Lines'),
        content: SizedBox(width: 650, child: ListView(shrinkWrap: true, children: [
          const Text('Read-only source details; no payment or accounting entry is created.'),
          if (lines.isEmpty) const Text('No source lines. Reconciliation required.'),
          ...lines.map((line) => ListTile(
            leading: Icon(line['line_status'] == 'matched'
                ? Icons.check_circle_outline : Icons.warning_amber_outlined),
            title: Text('${line['amount_iqd']} IQD — ${line['line_status']}'),
            subtitle: Text('Order: ${line['source_order_id']}\n'
                'Source line: ${line['source_register_line_id']}\n'
                'Order total: ${line['order_amount_iqd']} IQD\n'
                'Status: ${line['order_status']}'),
            isThreeLine: true,
            onTap: () => _showFinanceSourceOrderProducts(line['source_order_id']),
            trailing: const Icon(Icons.chevron_right),
          )),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'))],
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice source details unavailable: $e')));
    }
  }

  // Totals always use the same records rendered immediately above them.
  // A missing or malformed amount is not silently counted as zero.
  int? _invoiceAmount(Map<String, dynamic> row) {
    final value = row['total_iqd'];
    if (value is int) return value >= 0 ? value : null;
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value >= 0 ? value.toInt() : null;
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed >= 0 ? parsed : null;
  }

  Widget _postedInvoiceListTotal() {
    final amounts = visiblePostedInvoices.map(_invoiceAmount).toList();
    final incomplete = amounts.any((amount) => amount == null);
    final total = amounts.whereType<int>().fold<int>(0, (sum, value) => sum + value);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        const Expanded(child: Text('Total of listed finance invoices',
          style: TextStyle(fontWeight: FontWeight.bold))),
        Text(incomplete ? 'Unavailable — check amounts' : '$total IQD',
          style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('  (${visiblePostedInvoices.length} records)'),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ListTile(
        title: const Text('Motel Food Register Handoff'),
        subtitle: const Text('Read-only food-only register. Not unified invoices or payments.'),
        trailing: IconButton(onPressed: loading ? null : _refresh,
          icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
      ),
      if (loading) const LinearProgressIndicator(),
      if (error != null) Padding(padding: const EdgeInsets.all(12),
        child: Text('Unable to load handoff: $error')),
      Align(alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: loading ? null : _showCashSettlementReport,
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Cash Settlement Report'),
        )),
      const Divider(),
      const ListTile(title: Text('Payment Preparation Drafts'),
        subtitle: Text('Cash drafts may be settled in the motel-food ledger; credit and electronic remain unprocessed.')),
      if (!loading && paymentDrafts.isEmpty)
        const Padding(padding: EdgeInsets.all(12), child: Text('No payment drafts.')),
      _draftFilters(),
      ...visiblePaymentDrafts.map((draft) => ListTile(
        onTap: () => _showDraftDetails(draft),
        leading: Icon(draft['status'] == 'draft' ? Icons.pending_actions : Icons.cancel_outlined),
        title: Text('${draft['amount_iqd']} IQD • ${draft['method']} • ${draft['status']}'),
        subtitle: Text('Invoice: ${draft['finance_invoice_id']}\nCreated: ${draft['created_at']}'),
        isThreeLine: true,
        trailing: Wrap(children: [
          IconButton(tooltip: 'Check payment draft integrity (read-only)',
            icon: const Icon(Icons.verified_outlined),
            onPressed: () => _checkPaymentDraft(draft['intent_id'].toString())),
          if (draft['status'] == 'draft')
            TextButton(child: const Text('Allocation Plan'),
              onPressed: () => _prepareAllocationPlan(draft['intent_id'].toString())),
          if (draft['status'] == 'draft' && draft['method'] == 'cash')
            TextButton(child: const Text('Cashier Review'),
              onPressed: () => _prepareCashConfirmationReview(draft['intent_id'].toString())),
          if (draft['status'] == 'draft' && draft['method'] == 'cash')
            TextButton(child: const Text('Cash Received'),
              onPressed: () => _acknowledgeCashReceived(draft['intent_id'].toString())),
          if (draft['status'] == 'draft' && draft['method'] == 'credit')
            TextButton(child: const Text('Account Schema'),
              onPressed: _showCreditSchemaInventory),
          if (draft['status'] == 'draft' && draft['method'] == 'credit')
            TextButton(child: const Text('Credit Backend Checks'),
              onPressed: () => _showCreditBackendReadiness(draft['intent_id'].toString())),
          if (draft['method'] == 'credit')
            TextButton(child: const Text('Credit Requests'),
              onPressed: () => _showCreditVerificationReview(draft['intent_id'].toString())),
          if (draft['status'] == 'draft' && draft['method'] == 'credit')
            TextButton(child: const Text('Request Credit Verification'),
              onPressed: () => _requestCreditVerification(draft['intent_id'].toString())),
          if (draft['status'] == 'draft' && draft['method'] == 'credit')
            TextButton(child: const Text('Credit Barcode'),
              onPressed: () => _lookupCreditBarcode(draft['intent_id'].toString())),
          if (draft['status'] == 'draft' && draft['method'] == 'credit')
            TextButton(child: const Text('Credit Readiness'),
              onPressed: () => _checkCreditReadiness(draft['intent_id'].toString())),
          if (draft['status'] == 'draft' && draft['method'] == 'cash')
            TextButton(child: const Text('Settle Cash'),
              onPressed: () => _settleCash(draft['intent_id'].toString())),
          TextButton(child: const Text('Source Readiness'),
            onPressed: () => _checkPaymentSource(draft['intent_id'].toString())),
          TextButton(child: const Text('Ledger Mapping'),
            onPressed: () => _showLedgerCompatibility(draft['intent_id'].toString())),
          if (draft['status'] == 'draft')
            TextButton(onPressed: () => _cancelPaymentDraft(draft['intent_id'].toString()),
              child: const Text('Cancel Draft')),
        ]),
      )),
      if (!loading) _draftListTotal(),
      const Divider(),
      const ListTile(title: Text('Posted Motel Food Finance Invoices'),
        subtitle: Text('Food-only register with motel cash settlement status; not the shared numeric-order ledger.')),
      if (!loading && postedInvoices.isEmpty)
        const Padding(padding: EdgeInsets.all(12), child: Text('No posted finance invoices.')),
      _invoiceFilters(),
      ...visiblePostedInvoices.map((f) => ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text('${f['total_iqd']} IQD • ${f['source_count']} orders'),
        subtitle: Text('Finance ID: ${f['finance_invoice_id']}\nGuest stay: ${f['guest_session_id']}\nPayment: ${f['payment_status']}'),
        isThreeLine: true,
        onTap: () => _showPostedInvoiceLines(f['finance_invoice_id'].toString()),
        trailing: Wrap(children: [
          IconButton(tooltip: 'Register verified finance source (no payment)',
            icon: const Icon(Icons.add_link_outlined),
            onPressed: () => _registerFinanceSource(f['finance_invoice_id'].toString())),
          IconButton(tooltip: 'View finance source mapping (read-only)',
            icon: const Icon(Icons.link_outlined),
            onPressed: () => _showFinanceSource(f['finance_invoice_id'].toString())),
          IconButton(tooltip: 'Prepare payment draft — no charge',
            icon: const Icon(Icons.edit_note_outlined),
            onPressed: () => _preparePaymentDraft(f['finance_invoice_id'].toString())),
          IconButton(tooltip: 'View payment draft history (read-only)',
            icon: const Icon(Icons.history),
            onPressed: () => _showPaymentDraftHistory(f['finance_invoice_id'].toString())),
          IconButton(tooltip: 'Check payment eligibility (read-only)',
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () => _checkPaymentEligibility(f['finance_invoice_id'].toString())),
          IconButton(tooltip: 'View posted invoice source lines',
            icon: const Icon(Icons.list_alt_outlined),
            onPressed: () => _showPostedInvoiceLines(f['finance_invoice_id'].toString())),
          IconButton(tooltip: 'Reconcile posted invoice',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () => _checkPostedFinanceInvoice(f['finance_invoice_id'].toString())),
        ]),
      )),
      // Keep the aggregate AFTER the invoice rows, not above the list.
      if (!loading) _postedInvoiceListTotal(),
      const Divider(),
      if (!loading && error == null && entries.isEmpty)
        const Padding(padding: EdgeInsets.all(12), child: Text('No posted food registers.')),
      ...entries.map((e) {
        final matched = e['integrity_status'] == 'matched';
        return ListTile(
          leading: Icon(matched ? Icons.verified_outlined : Icons.warning_amber_outlined,
            color: matched ? Colors.green : Colors.orange),
          title: Text('${e['total_iqd']} IQD • ${e['source_count']} food orders'),
          subtitle: Text('Guest stay: ${e['guest_session_id']}\n'
            'Register: ${e['invoice_id']}\n'
            'Line total: ${e['registered_line_total_iqd']} IQD • '
            '${e['registered_line_count']} lines\n'
            'Status: ${matched ? 'Matched — not a paid invoice' : 'Requires reconciliation'}'),
          isThreeLine: true,
          trailing: Wrap(children: [
            IconButton(
              tooltip: 'Post verified food-only finance invoice (no payment)',
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: matched ? () => _postFinanceInvoice(e['invoice_id'].toString()) : null,
            ),
            IconButton(
              tooltip: 'Verify finance intake draft integrity (read-only)',
              icon: const Icon(Icons.fact_check),
              onPressed: () => _checkIntakeIntegrity(e['invoice_id'].toString()),
            ),
            IconButton(
              tooltip: 'Create verified finance intake draft (no invoice or payment)',
              icon: const Icon(Icons.note_add_outlined),
              onPressed: matched ? () => _createIntakeDraft(e['invoice_id'].toString()) : null,
            ),
            IconButton(
              tooltip: 'View finance attestation status',
              icon: const Icon(Icons.verified_user_outlined),
              onPressed: () => _showAttestationStatus(e['invoice_id'].toString()),
            ),
            IconButton(
              tooltip: 'Attest verified finance handoff (no payment)',
              icon: const Icon(Icons.assignment_turned_in_outlined),
              onPressed: matched ? () => _attestHandoff(e['invoice_id'].toString()) : null,
            ),
            IconButton(
              tooltip: 'Check invoice readiness',
              icon: const Icon(Icons.rule_outlined),
              onPressed: () => _showReadiness(e['invoice_id'].toString()),
            ),
            IconButton(
              tooltip: 'Audit source lines',
              icon: const Icon(Icons.fact_check_outlined),
              onPressed: () => _showLineAudit(e['invoice_id'].toString()),
            ),
          ]),
        );
      }),
    ],
  );
}
