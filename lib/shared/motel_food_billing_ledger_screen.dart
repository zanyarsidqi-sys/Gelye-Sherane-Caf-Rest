import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MotelFoodBillingLedgerScreen extends StatefulWidget {
  const MotelFoodBillingLedgerScreen({super.key});
  @override
  State<MotelFoodBillingLedgerScreen> createState() => _MotelFoodBillingLedgerScreenState();
}

class _MotelFoodBillingLedgerScreenState extends State<MotelFoodBillingLedgerScreen> {
  bool loading = false;
  String? error;
  List<Map<String, dynamic>> entries = [];
  Map<String, dynamic>? reconciliation;
  List<Map<String, dynamic>> preflight = [];
  List<Map<String, dynamic>> invoiceDrafts = [];
  List<Map<String, dynamic>> draftReviews = [];
  List<Map<String, dynamic>> architectureChecks = [];
  List<Map<String, dynamic>> postedFoodInvoices = [];
  @override
  void initState() { super.initState(); refresh(); }
  Future<void> refresh() async {
    if (loading) return;
    setState(() { loading = true; error = null; });
    try {
      final result = await Supabase.instance.client.rpc('gs_staff_motel_food_billing_ledger');
      final check = await Supabase.instance.client.rpc('gs_staff_motel_food_ledger_reconciliation');
      final readiness = await Supabase.instance.client.rpc('gs_staff_motel_food_invoice_preflight');
      final drafts = await Supabase.instance.client.rpc('gs_staff_motel_food_invoice_drafts');
      final reviews = await Supabase.instance.client.rpc('gs_staff_motel_food_draft_review_status');
      final architecture = await Supabase.instance.client.rpc('gs_staff_motel_food_invoice_architecture_check');
      final posted = await Supabase.instance.client.rpc('gs_staff_list_motel_food_invoice_register');
      if (!mounted) return;
      setState(() {
        postedFoodInvoices = (posted as List).map((e) => Map<String,dynamic>.from(e as Map)).toList();
        architectureChecks = (architecture as List).map((e) => Map<String,dynamic>.from(e as Map)).toList();
        draftReviews = (reviews as List).map((e) => Map<String,dynamic>.from(e as Map)).toList();
        invoiceDrafts = (drafts as List).map((e) => Map<String,dynamic>.from(e as Map)).toList();
        preflight = (readiness as List).map((e) => Map<String,dynamic>.from(e as Map)).toList();
        entries = (result as List).map((e) => Map<String,dynamic>.from(e as Map)).toList();
        reconciliation = (check as List).isEmpty ? null : Map<String,dynamic>.from(check.first as Map);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  Future<void> reviewDraft(Map<String, dynamic> draft) async {
    final guestSession = draft['guest_session_id']?.toString();
    if (guestSession == null) return;
    final approved = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Sign off food draft?'),
      content: Text('Room ${draft['room_label']}: ${draft['food_subtotal_iqd']} IQD. '
        'This records an employee review only. It does not issue an invoice or take payment.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx,false),child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx,true),child: const Text('Review'))],
    ));
    if (approved != true || !mounted) return;
    try {
      await Supabase.instance.client.rpc('gs_staff_review_motel_food_draft',
        params: {'p_guest_session_id': guestSession, 'p_note': ''});
      await refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Review failed: $e')));
    }
  }
  Future<void> rereviewDraft(Map<String, dynamic> draft) async {
    final guestSession = draft['guest_session_id']?.toString();
    if (guestSession == null) return;
    final reasonController = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Re-review changed food draft'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Room ${draft['room_label']} — ${draft['food_subtotal_iqd']} IQD. All charges will be validated again.'),
          TextField(controller: reasonController, maxLength: 500,
            decoration: const InputDecoration(labelText: 'Reason for re-review (required)')),
          const Text('No invoice or payment will be created.'),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Re-review'))],
      ));
      if (confirmed != true || !mounted) return;
      await Supabase.instance.client.rpc('gs_staff_rereview_motel_food_draft', params: {
        'p_guest_session_id': guestSession, 'p_reason': reasonController.text.trim(),
      });
      await refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Re-review failed: $e')));
    } finally { reasonController.dispose(); }
  }
  Future<void> showDraftDetails(Map<String, dynamic> draft) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_motel_food_invoice_draft_details',
        params: {'p_guest_session_id': draft['guest_session_id']});
      if (!mounted) return;
      final lines = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text('Room ${draft['room_label']} — Food Draft'),
        content: SizedBox(width: 540, child: ListView(shrinkWrap: true, children: [
          const Text('Read-only. No invoice or payment has been created.'),
          if (lines.isEmpty) const Text('No itemized lines available.'),
          ...lines.map((line) => ListTile(
            title: Text('${line['product_name']} × ${line['quantity']}'),
            subtitle: Text('Order ${line['request_id']} • ${line['eligible'] == true ? 'Eligible' : 'Review required'}'),
            trailing: Text('${line['line_total_iqd']} IQD'),
          )),
          const Divider(),
          Text('Staged total: ${draft['food_subtotal_iqd']} IQD'),
          if ((num.tryParse('${draft['blocked_order_count']}') ?? 0) > 0)
            const Text('Some orders are blocked. Review before invoicing.',
              style: TextStyle(color: Colors.red)),
        ])),
        actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close'))],
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to load draft: $e')));
    }
  }
  Future<void> showInvoiceCrosswalk(Map<String, dynamic> draft) async {
    final guestSession = draft['guest_session_id']?.toString();
    if (guestSession == null) return;
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_motel_food_invoice_crosswalk_preview',
        params: {'p_guest_session_id': guestSession});
      if (!mounted) return;
      final rows = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final total = rows.fold<int>(0, (sum, row) => sum +
        (num.tryParse('${row['amount_iqd']}')?.toInt() ?? 0));
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Verified invoice source mapping'),
        content: SizedBox(width: 560, child: ListView(shrinkWrap: true, children: [
          const Text('Preview only. No invoice, payment, or credit transaction is created.'),
          Text('Guest stay: $guestSession'),
          Text('Verified orders: ${rows.length} • Total: $total IQD'),
          ...rows.map((r) => ListTile(
            title: Text('${r['amount_iqd']} IQD'),
            subtitle: SelectableText('${r['source_key']}\nLedger: ${r['source_ledger_id']}'),
          )),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Invoice mapping blocked: $e')));
    }
  }
  Future<void> reserveInvoiceSources(Map<String, dynamic> draft) async {
    final stay = draft['guest_session_id']?.toString();
    if (stay == null) return;
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Reserve verified food sources?'),
      content: Text('Room ${draft['room_label']} — ${draft['food_subtotal_iqd']} IQD. '
        'This locks source references for future invoicing. It does NOT issue an invoice or collect payment.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reserve Sources'))],
    ));
    if (confirm != true || !mounted) return;
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_reserve_motel_food_invoice_sources',
        params: {'p_guest_session_id': stay});
      if (!mounted) return;
      final rows = (response as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final total = rows.fold<int>(0, (sum, r) => sum + (num.tryParse('${r['amount_iqd']}')?.toInt() ?? 0));
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Food sources reserved'),
        content: Text('${rows.length} source orders • $total IQD. No invoice or payment posted.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
      await refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Reservation blocked: $e')));
    }
  }
  Future<void> showReservationReconciliation(Map<String, dynamic> draft) async {
    final stay = draft['guest_session_id']?.toString();
    if (stay == null) return;
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_motel_invoice_reservation_reconciliation',
        params: {'p_guest_session_id': stay});
      if (!mounted) return;
      final rows = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final problems = rows.where((r) => r['issue'] != 'matched').toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Invoice reservation reconciliation'),
        content: SizedBox(width: 560, child: ListView(shrinkWrap: true, children: [
          const Text('Read-only verification. No invoice or payment is posted.'),
          Text('Matched: ${rows.length - problems.length} / ${rows.length}'),
          Text(problems.isEmpty && rows.isNotEmpty
              ? 'All verified source reservations match.'
              : 'Invoice handoff is NOT ready. Resolve discrepancies first.',
            style: TextStyle(color: problems.isEmpty && rows.isNotEmpty ? Colors.green : Colors.red)),
          ...rows.map((r) => ListTile(
            dense: true,
            leading: Icon(r['issue'] == 'matched' ? Icons.check_circle_outline : Icons.warning_amber,
              color: r['issue'] == 'matched' ? Colors.green : Colors.orange),
            title: Text('${r['issue']}'),
            subtitle: SelectableText('Order: ${r['source_order_id']}'),
            trailing: Text('${r['reserved_amount_iqd'] ?? '—'} IQD'),
          )),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Reconciliation blocked: $e')));
    }
  }
  Future<void> postFoodInvoiceRegister(Map<String, dynamic> draft) async {
    final stay = draft['guest_session_id']?.toString();
    if (stay == null || loading) return;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Post food-only invoice register?'),
      content: Text('Room ${draft['room_label']} — ${draft['food_subtotal_iqd']} IQD. '
        'This creates an auditable food-only invoice register entry. '
        'It does NOT issue a unified invoice, collect payment, or deduct credit. '
        'Posting cannot be undone from this screen.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Post Food Register'))],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => loading = true);
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_post_motel_food_invoice_register',
        params: {'p_guest_session_id': stay});
      if (!mounted) return;
      final rows = (response as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) throw StateError('No invoice register confirmation returned');
      final row = rows.first;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text(row['already_posted'] == true ? 'Already registered' : 'Food register posted'),
        content: SelectableText('Register ID: ${row['invoice_id']}\n'
          'Sources: ${row['source_count']}\nTotal: ${row['total_iqd']} IQD\n'
          'No payment or unified invoice was created.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Register posting blocked: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
    await refresh();
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    ListTile(title: const Text('Delivered Food Billing Ledger'),
      subtitle: const Text('Staging only — not an invoice or confirmed payment'),
      trailing: IconButton(onPressed: loading ? null : refresh, icon: const Icon(Icons.refresh))),
    if (loading) const LinearProgressIndicator(),
    if (reconciliation != null) Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ledger Reconciliation', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('Delivered orders: ${reconciliation!['delivered_orders']} • Ledger entries: ${reconciliation!['ledger_entries']}'),
        Text('Missing: ${reconciliation!['missing_entries']} • Amount mismatches: ${reconciliation!['amount_mismatches']} • Invalid ledger entries: ${reconciliation!['orphan_or_non_delivered_entries']}'),
        Text('Delivered: ${reconciliation!['delivered_total_iqd']} IQD • Staged: ${reconciliation!['staged_total_iqd']} IQD'),
        if (['missing_entries', 'amount_mismatches', 'orphan_or_non_delivered_entries'].any(
          (key) => (num.tryParse('${reconciliation![key]}') ?? 0) > 0))
          const Text('Review discrepancies before invoicing.', style: TextStyle(color: Colors.red)),
      ]),
    )),
    if (architectureChecks.isNotEmpty) Card(child: Padding(
      padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Official Invoice Integration — Safety Checks',
            style: TextStyle(fontWeight: FontWeight.bold)),
          const Text('Not yet connected. Review these blockers before posting invoices.'),
          ...architectureChecks.map((item) => ListTile(
            dense: true,
            leading: const Icon(Icons.shield_outlined, color: Colors.orange),
            title: Text('${item['check_name']}: ${item['check_status']}'),
            subtitle: Text('${item['details']}'),
          )),
        ],
      ),
    )),
    if (preflight.isNotEmpty) Card(child: Padding(
      padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Invoice Integration Preflight', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Ready for future integration: ${preflight.where((e) => e['eligible_for_future_invoice'] == true).length} / ${preflight.length} staged orders'),
          const Text('Read-only check. No invoice or payment is created.'),
          ...preflight.where((e) => e['eligible_for_future_invoice'] != true).take(5).map((e) =>
            Text('Room ${e['room_label']}: ${(e['blockers'] as List?)?.join(', ') ?? 'Review required'}',
              style: const TextStyle(color: Colors.red))),
        ],
      ),
    )),
    if (postedFoodInvoices.isNotEmpty) Card(child: Padding(
      padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Posted Food-Only Register', style: TextStyle(fontWeight: FontWeight.bold)),
          const Text('Separate from unified invoices and payments.'),
          ...postedFoodInvoices.take(10).map((entry) => ListTile(
            dense: true,
            title: Text('${entry['total_iqd']} IQD • ${entry['source_count']} orders'),
            subtitle: SelectableText('Register ${entry['invoice_id']}\n${entry['posted_at']}'),
          )),
        ],
      ),
    )),
    if (invoiceDrafts.isNotEmpty) Card(child: Padding(
      padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Room Food Invoice Drafts', style: TextStyle(fontWeight: FontWeight.bold)),
          const Text('Grouped by guest stay. Preview only; excludes accommodation, payments and discounts.'),
          const Text('Tap a draft for item details. Mapping is read-only; Reserve requires both editing permissions and a current approval.'),
          ...invoiceDrafts.take(20).map((d) => ListTile(
            dense: true,
            onTap: () => showDraftDetails(d),
            title: Text('Room ${d['room_label']} — ${d['food_subtotal_iqd']} IQD'),
            subtitle: Text('${d['delivered_order_count']} delivered food orders • ${d['blocked_order_count']} blocked'),
            leading: PopupMenuButton<String>(
              tooltip: 'Invoice source actions',
              icon: const Icon(Icons.account_tree_outlined),
              onSelected: (action) {
                if (action == 'mapping') showInvoiceCrosswalk(d);
                if (action == 'reserve') reserveInvoiceSources(d);
                if (action == 'reconcile') showReservationReconciliation(d);
                if (action == 'post') postFoodInvoiceRegister(d);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'mapping', child: Text('Verify source mapping')),
                const PopupMenuItem(value: 'reconcile', child: Text('Check reserved sources')),
                if ((num.tryParse('${d['blocked_order_count']}') ?? 0) == 0 &&
                    draftReviews.any((r) => r['guest_session_id'] == d['guest_session_id'] &&
                      r['changed_since_review'] != true))
                  const PopupMenuItem(value: 'post', child: Text('Post food-only register')),
                if ((num.tryParse('${d['blocked_order_count']}') ?? 0) == 0 &&
                    draftReviews.any((r) => r['guest_session_id'] == d['guest_session_id'] &&
                      r['changed_since_review'] != true))
                  const PopupMenuItem(value: 'reserve', child: Text('Reserve verified sources')),
              ],
            ),
            trailing: Builder(builder: (context) {
              final review = draftReviews.where((r) => r['guest_session_id'] == d['guest_session_id']).toList();
              if (review.isNotEmpty) {
                final stale = review.first['changed_since_review'] == true;
                return stale ? TextButton.icon(
                  onPressed: (num.tryParse('${d['blocked_order_count']}') ?? 0) > 0
                    ? null : () => rereviewDraft(d),
                  icon: const Icon(Icons.warning_amber, color: Colors.orange),
                  label: const Text('Re-review'))
                  : const Tooltip(message: 'Reviewed; not yet invoiced',
                      child: Icon(Icons.verified_outlined, color: Colors.green));
              }
              return TextButton(onPressed: (num.tryParse('${d['blocked_order_count']}') ?? 0) > 0
                ? null : () => reviewDraft(d), child: const Text('Review'));
            }),
          )),
        ],
      ),
    )),
    if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
    Expanded(child: entries.isEmpty
      ? const Center(child: Text('No delivered food charges recorded'))
      : ListView.builder(itemCount: entries.length, itemBuilder: (context, index) {
        final e = entries[index];
        return ListTile(
          title: Text('Room ${e['room_label'] ?? ''} — ${e['amount_iqd'] ?? 0} IQD'),
          subtitle: Text('${e['room_name'] ?? ''} • ${e['payment_status'] ?? 'unpaid'} • ${e['posted_at'] ?? ''}'),
          trailing: const Icon(Icons.receipt_long_outlined));
      })),
  ]);
}
