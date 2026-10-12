import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authorized, read-only reconciliation of cash actually recorded in the ledger.
/// Outstanding amounts do not account for external payment providers.
class PaymentsManagementPanel extends StatefulWidget {
  const PaymentsManagementPanel({super.key, this.initialFocus});
  /// Dashboard deep link: 'standing' or 'pending'.
  final String? initialFocus;
  @override
  State<PaymentsManagementPanel> createState() => _PaymentsManagementPanelState();
}

class _PaymentsManagementPanelState extends State<PaymentsManagementPanel> {
  late Future<List<Map<String, dynamic>>> _rows = _load();
  String _paymentFilter = 'all';
  String _activePaymentCard = 'standing';
  String _cardSearch = '';
  // Sort only the authorized, returned source sample; never imply global ranking.
  String _sourceSort = 'original';
  String _cardStatus = 'all';
  // Amount filtering uses only server-returned, integer IQD source amounts.
  // It is not a filter on all-method outstanding balances.
  int? _minimumSourceIqd;
  int? _maximumSourceIqd;
  final _minimumSourceController = TextEditingController();
  final _maximumSourceController = TextEditingController();
  final TextEditingController _cardSearchController = TextEditingController();
  @override
  void initState() {
    super.initState();
    // Respect the Dashboard deep link without replacing the application shell.
    // Invalid or missing values safely fall back to Standing Cash.
    _activePaymentCard = widget.initialFocus == 'pending' ? 'pending' : 'standing';
  }
  @override
  void dispose() {
    _cardSearchController.dispose();
    _minimumSourceController.dispose();
    _maximumSourceController.dispose();
    super.dispose();
  }
  bool _cardMatches(Map<String, dynamic> row, String id, String status) {
    // Search only source-verified identifiers. Avoid guessing customer names,
    // room numbers, employee names or payment methods absent from this RPC.
    final q = _cardSearch.trim().toLowerCase();
    if (q.isNotEmpty && !id.toLowerCase().contains(q)) return false;
    if (_cardStatus != 'all' && status != _cardStatus) return false;
    // No date filter without a validated source timestamp; never invent dates.
    return true;
  }
  // Fail closed on invalid ranges. A malformed filter must never silently
  // show a broader financial result set than the employee requested.
  bool get _validSourceAmountRange {
    final minText = _minimumSourceController.text.trim();
    final maxText = _maximumSourceController.text.trim();
    if (minText.isNotEmpty && _minimumSourceIqd == null) return false;
    if (maxText.isNotEmpty && _maximumSourceIqd == null) return false;
    if (_minimumSourceIqd != null && _maximumSourceIqd != null &&
        _minimumSourceIqd! > _maximumSourceIqd!) return false;
    return true;
  }

  bool _sourceAmountMatches(Object? sourceValue) {
    if (!_validSourceAmountRange) return false;
    final value = _wholeIqd(sourceValue);
    if (value == null || value < 0) return false;
    if (_minimumSourceIqd != null && value < _minimumSourceIqd!) return false;
    if (_maximumSourceIqd != null && value > _maximumSourceIqd!) return false;
    return true;
  }

  int? _parseNonnegativeIqd(String text) {
    final value = text.trim();
    if (value.isEmpty) return null;
    if (!RegExp(r'^\d{1,15}$').hasMatch(value)) return null;
    return int.tryParse(value);
  }

  void _updateSourceAmountFilter(String _, {required bool minimum}) {
    final text = minimum ? _minimumSourceController.text : _maximumSourceController.text;
    setState(() {
      if (minimum) { _minimumSourceIqd = _parseNonnegativeIqd(text); }
      else { _maximumSourceIqd = _parseNonnegativeIqd(text); }
    });
  }

  bool _listFiltersExpanded = false;
  Widget _cardFilters() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    OutlinedButton.icon(
      onPressed: () => setState(() => _listFiltersExpanded = !_listFiltersExpanded),
      icon: Icon(_listFiltersExpanded ? Icons.filter_alt_off : Icons.filter_list),
      label: Text(_listFiltersExpanded ? 'Hide payment list filters' : 'Show payment list filters'),
    ),
    const SizedBox(height: 4),
    const Text('Search, IQD amount, source status / cash eligibility and sorting apply only to authorized returned records.',
      style: TextStyle(fontSize: 12)),
    if (_listFiltersExpanded) ...[
    TextField(controller: _cardSearchController,
      decoration: const InputDecoration(labelText: 'Search order / invoice ID',
        prefixIcon: Icon(Icons.search)),
      onChanged: (value) => setState(() => _cardSearch = value)),
    const SizedBox(height: 8),
    const Text('Source amount range (IQD) · cash-only remaining for Standing Cash; posted invoice total for Pending Payment.'),
    Row(children: [
      Expanded(child: TextField(controller: _minimumSourceController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Minimum IQD'),
        onChanged: (value) => _updateSourceAmountFilter(value, minimum: true))),
      const SizedBox(width: 8),
      Expanded(child: TextField(controller: _maximumSourceController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Maximum IQD'),
        onChanged: (value) => _updateSourceAmountFilter(value, minimum: false))),
    ]),
    if ((_minimumSourceController.text.trim().isNotEmpty && _minimumSourceIqd == null) ||
        (_maximumSourceController.text.trim().isNotEmpty && _maximumSourceIqd == null) ||
        (_minimumSourceIqd != null && _maximumSourceIqd != null && _minimumSourceIqd! > _maximumSourceIqd!))
      const Text('Invalid IQD range: enter whole nonnegative values (up to 15 digits), minimum not above maximum. No financial records or totals are shown until the range is corrected.',
        style: TextStyle(color: Colors.deepOrange, fontSize: 12)),
    if (_activePaymentCard == 'pending')
      DropdownButtonFormField<String>(value: _cardStatus,
        decoration: const InputDecoration(labelText: 'Source invoice status'),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All source statuses')),
          DropdownMenuItem(value: 'unpaid', child: Text('Unpaid source status')),
        ], onChanged: (value) => setState(() => _cardStatus = value ?? 'all')),
    if (_activePaymentCard == 'standing') ...[
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Server-approved cash collection only'),
        subtitle: const Text('Filter by cash_collection_eligible from the authorized Standing Cash RPC.'),
        value: _standingEligibleOnly,
        onChanged: (value) => setState(() => _standingEligibleOnly = value),
      ),
      const Text('Payment-status filtering is unavailable: the cash-only source does not verify whether an order is unpaid or partially paid.',
        style: TextStyle(fontSize: 12)),
    ],
    DropdownButtonFormField<String>(
      value: _sourceSort,
      decoration: const InputDecoration(labelText: 'Sort returned source records'),
      items: const [
        DropdownMenuItem(value: 'original', child: Text('Backend order')),
        DropdownMenuItem(value: 'amount_low', child: Text('Source amount: low to high')),
        DropdownMenuItem(value: 'amount_high', child: Text('Source amount: high to low')),
      ],
      onChanged: (value) => setState(() => _sourceSort = value ?? 'original'),
    ),
    const Text('Date range, employee and cash/credit subtype filters are unavailable '
      'until authorized backend fields are verified. No misleading filtering is applied.',
      style: TextStyle(fontSize: 12)),
    TextButton.icon(
      onPressed: () => setState(() {
        _cardSearch = '';
        _cardStatus = 'all';
        _sourceSort = 'original';
        _standingEligibleOnly = false;
        _cardSearchController.clear();
        _minimumSourceIqd = null;
        _maximumSourceIqd = null;
        _minimumSourceController.clear();
        _maximumSourceController.clear();
      }),
      icon: const Icon(Icons.filter_alt_off_outlined),
      label: const Text('Clear list filters')),
    ],
  ]);

  // Card-specific, source-grounded filter: only the Standing Cash RPC exposes
  // cash_collection_eligible. This must never be inferred from a cash balance.
  bool _standingEligibleOnly = false;
  bool _showLedgerWarningsOnly = false;

  // Read-only, permission-scoped detail. Never infer missing customer or delivery data.
  Future<void> _inspectItemizedOrder(Map<String, dynamic> order) async {
    final orderId = _wholeIqd(order['order_id']);
    if (orderId == null || orderId <= 0) return;
    try {
      final raw = await Supabase.instance.client.rpc(
        'gs_finance_itemized_order_detail',
        params: {'p_order_id': orderId},
      ).timeout(const Duration(seconds: 20));
      if (raw is! Map || raw['order_id'] != orderId || raw['items'] is! List) {
        throw const FormatException('Unexpected itemized order response');
      }
      final rows = raw['items'] as List;
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text('Order #$orderId · Products'),
        content: SizedBox(width: 460, child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order #$orderId · Table ${order['table_id'] ?? 'Unavailable'}'),
              Text('Cash-only remaining: ${_iqd(order['cash_only_remaining_iqd'])}'),
              Text(order['cash_collection_eligible'] == true
                ? 'Cash collection eligibility: server approved (rechecked on Pay)'
                : 'Cash collection eligibility: not approved'),
              const Text('Read-only itemized details. All-method settlement and payment history are not verified.'),
              const SizedBox(height: 12),
              if (rows.isEmpty) const Text('No products recorded.'),
              for (final value in rows) if (value is Map)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${value['product_name'] ?? 'Unknown product'}'),
                  subtitle: Text('Qty: ${value['quantity'] ?? '—'} · Unit: ${value['unit_price_iqd'] ?? '—'} IQD\n'
                    'Recorded order time: ${value['ordered_at'] ?? 'Unavailable'}\n'
                    'Individual customer: ${value['individual_customer'] ?? 'Not recorded'}'),
                  trailing: Text('${value['line_total_iqd'] ?? '—'} IQD'),
                ),
            ],
          ),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton(
            onPressed: order['cash_collection_eligible'] == true
              ? () { Navigator.pop(ctx); _receiveStandingCash(order); }
              : null,
            child: const Text('Pay'),
          ),
        ],
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Item details unavailable. Check permissions, connectivity and deployed migration.'),
      ));
    }
  }


  // Read-only posted motel invoice line audit; never implies payment eligibility.
  Future<void> _inspectMotelInvoice(Map<String, dynamic> invoice) async {
    final id = invoice['finance_invoice_id'];
    if (id is! String || id.isEmpty) return;
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_motel_food_finance_line_audit',
        params: {'p_invoice_id': id},
      ).timeout(const Duration(seconds: 20));
      if (result is! List || result.length > 300 ||
          result.any((row) => row is! Map)) {
        throw const FormatException('Unexpected motel invoice line audit');
      }
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Motel invoice · Source details'),
        content: SizedBox(width: 520, child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Invoice: $id'),
            Text('Posted invoice total: ${_iqd(invoice['invoice_total_iqd'])}'),
            Text('Source payment status: ${invoice['payment_status'] ?? 'Unavailable'}'),
            const Text('Read-only source audit. Payment collection is blocked. '
              'Room, delivery employee and requested time must be verified '
              'against the linked motel request.'),
            const SizedBox(height: 12),
            // Same authorized read-only settlement diagnostics as the Pending
            // Payment panel. Never infer the all-method amount due from cash.
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _pendingAllocations,
              builder: (context, evidenceSnapshot) {
                if (evidenceSnapshot.hasError) return const Text(
                  'Settlement evidence unavailable; payment remains blocked.');
                if (!evidenceSnapshot.hasData) return const Text(
                  'Loading authorized settlement evidence…');
                final matches = evidenceSnapshot.data!
                    .where((row) => row['finance_invoice_id'] == id).toList();
                if (matches.length != 1) return const Text(
                  'Unique invoice settlement evidence not established; payment blocked.');
                final evidence = matches.single;
                // Cross-check the two independently authorized RPC responses.
                // Neither matching evidence nor cash settlement proves an
                // all-method outstanding amount or authorizes collection.
                final samePostedTotal = _wholeIqd(evidence['invoice_total_iqd']) ==
                    _wholeIqd(invoice['invoice_total_iqd']);
                final sameStatus = evidence['invoice_status'] == invoice['payment_status'];
                final needsReview = !samePostedTotal || !sameStatus ||
                    evidence['requires_manual_review'] == true ||
                    evidence['bridge_identity_consistent'] != true ||
                    evidence['source_fingerprint_collision'] == true ||
                    evidence['bridge_amount_mismatch'] == true ||
                    evidence['cash_evidence_exceeds_invoice'] == true ||
                    evidence['invalid_cash_settlement_amount'] == true ||
                    evidence['invalid_invoice_total'] == true ||
                    evidence['invoice_cash_status_inconsistent'] == true;
                return Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Confirmed cash evidence: ${_iqd(evidence['confirmed_cash_settlement_iqd'])}'),
                    Text('Confirmed cash settlements: ${evidence['confirmed_cash_settlement_count']}'),
                    Text('Source bridge consistent: ${evidence['bridge_identity_consistent'] == true ? 'Yes' : 'No / unavailable'}'),
                    Text('Manual review from diagnostic RPC: ${evidence['requires_manual_review'] == true ? 'Required' : 'Not flagged'}'),
                    Text('Cross-source invoice total matches: ${samePostedTotal ? 'Yes' : 'No / unavailable'}'),
                    Text('Combined source review: ${needsReview ? 'Required — source discrepancy or risk' : 'No flagged discrepancy in returned evidence'}'),
                    Text('Diagnostic invoice status: ${evidence['invoice_status'] ?? 'Unavailable'}'),
                    Text('Status matches source: ${sameStatus ? 'Yes' : 'No / unavailable'}'),
                    Text('Source fingerprint collision: ${evidence['source_fingerprint_collision'] == true ? 'Flagged' : 'Not flagged'}'),
                    Text('Bridge amount mismatch: ${evidence['bridge_amount_mismatch'] == true ? 'Flagged' : 'Not flagged'}'),
                    Text('Cash evidence exceeds invoice: ${evidence['cash_evidence_exceeds_invoice'] == true ? 'Flagged' : 'Not flagged'}'),
                    Text('Cash-status inconsistency: ${evidence['invoice_cash_status_inconsistent'] == true ? 'Flagged' : 'Not flagged'}'),
                    const Text('Other payment methods, prepaid coverage and final unpaid amount are unverified. Pay disabled.'),
                  ]);
              }),
            const SizedBox(height: 12),
            if (result.isEmpty) const Text('No source lines returned.'),
            for (final value in result) if (value is Map)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${value['product_name'] ?? value['source_item_name'] ?? 'Source line'}'),
                subtitle: Text('Quantity: ${value['quantity'] ?? 'Unavailable'} · '
                  'Unit price: ${value['unit_price_iqd'] ?? 'Unavailable'} IQD\n'
                  'Source: ${value['source_order_id'] ?? value['source_request_id'] ?? 'Unavailable'}'),
                trailing: Text('${value['line_total_iqd'] ?? '—'} IQD'),
              ),
          ]),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          const FilledButton(onPressed: null, child: Text('Pay')),
        ],
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Motel source details unavailable. Check permission, connection and migration.'),
      ));
    }
  }

  // Match Dashboard's strict whole-IQD handling: never silently truncate
  // fractional or non-finite ledger values into financial figures.
  int? _wholeIqd(dynamic value) {
    if (value is! num || !value.isFinite ||
        value.abs() > 9007199254740991 ||
        value != value.truncateToDouble()) return null;
    return value.toInt();
  }

  String _cashStatus(Map<String, dynamic> row) {
    final total = _wholeIqd(row['order_total_iqd']);
    final paid = _wholeIqd(row['cash_paid_iqd']);
    if (total == null || paid == null || total < 0 || paid < 0) return 'Amount unavailable';
    if (total <= 0) return 'No total';
    if (paid <= 0) return 'Unpaid';
    if (paid >= total) return 'Paid in cash';
    return 'Partially paid';
  }
  // Ledger integrity warnings are distinct from the server's cash-discrepancy
  // metric. These flag malformed reconciliation rows for manual review; they
  // do not claim that a payment discrepancy has been proven.
  bool _hasLedgerWarning(Map<String, dynamic> row) {
    final total = _wholeIqd(row['order_total_iqd']);
    final paid = _wholeIqd(row['cash_paid_iqd']);
    final balance = _wholeIqd(row['balance_iqd']);
    final entries = _wholeIqd(row['cash_payment_count']);
    final id = _wholeIqd(row['order_id']);
    // This is a cash-only sample: validate arithmetic without claiming
    // that non-cash settlement or refunds have been reconciled.
    return total == null || total < 0 || paid == null || paid < 0 ||
        balance == null || entries == null || entries < 0 ||
        id == null || id <= 0 ||
        (total - paid != balance);
  }

  // Dashboard money cards open this ledger, but gs_cash_reconciliation is
  // CASH-ONLY and capped at 200 orders. It cannot substantiate all-channel
  // revenue, income, outstanding balances or an arbitrary employee filter.
  // Add scoped finance RPCs before displaying those breakdowns as verified.
  Future<List<Map<String, dynamic>>> _load() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      throw StateError('Employee login required.');
    }
    // Bound a stalled network request so employees can retry from the ledger.
    final result = await Supabase.instance.client
        .rpc('gs_cash_reconciliation', params: {'p_limit': 200})
        .timeout(const Duration(seconds: 20));
    if (result is! List || result.length > 200 ||
        result.any((entry) => entry is! Map<String, dynamic>)) {
      throw const FormatException('Unexpected cash reconciliation response.');
    }
    // Duplicate order identities in a paged cash sample can inflate the
    // displayed cash total. Reject the sample rather than double-counting.
    final seenOrderIds = <int>{};
    for (final entry in result) {
      final orderId = _wholeIqd(entry['order_id']);
      if (orderId == null || orderId <= 0 || !seenOrderIds.add(orderId)) {
        throw const FormatException(
          'Cash ledger contains an invalid or repeated order identity.');
      }
      // Do not treat malformed cash evidence as a reconciled source row.
      // This RPC is cash-only: passing these checks does not verify credit,
      // prepaid packages, refunds or all-method outstanding balances.
      if (_hasLedgerWarning(Map<String, dynamic>.from(entry))) {
        throw const FormatException(
          'Cash reconciliation has contradictory or invalid amounts.');
      }
    }
    return List<Map<String, dynamic>>.from(result);
  }
  Future<Map<String, dynamic>?> _loadLiveUnpaidBalances() async {
    if (Supabase.instance.client.auth.currentUser == null) return null;
    try {
      final raw = await Supabase.instance.client
          .rpc('gs_financial_live_unpaid_balances')
          .timeout(const Duration(seconds: 15));
      if (raw is! Map) return null;
      final result = Map<String, dynamic>.from(raw);
      // P1: strict server certification, not a truthy string or partial report.
      if (result['verified_complete'] != true) return null;
      // P2: require a valid server timestamp.
      final generated = DateTime.tryParse(result['generated_at']?.toString() ?? '');
      if (generated == null) return null;
      // P3: reject stale/future snapshots to avoid acting on outdated money.
      final age = DateTime.now().toUtc().difference(generated.toUtc());
      if (age.isNegative || age > const Duration(minutes: 5)) return null;
      for (final key in ['standing_cash_active_visits_iqd',
                         'pending_online_motel_unpaid_iqd']) {
        // P4: reject missing, fractional, negative, and non-finite IQD.
        final rawAmount = result[key];
        if (rawAmount is! num || !rawAmount.isFinite || rawAmount < 0 ||
            rawAmount > 9007199254740991 ||
            rawAmount != rawAmount.truncateToDouble()) return null;
        // P5: enforce the same integer parser as the linked ledger details.
        final value = _wholeIqd(rawAmount);
        if (value == null || value < 0) return null;
      }
      return result;
    } catch (_) { return null; }
  }

  // Readiness metadata is not a financial balance; the server authorizes this RPC.
  Future<Map<String, dynamic>?> _loadReconciliationReadiness() async {
    if (Supabase.instance.client.auth.currentUser == null) return null;
    try {
      final raw = await Supabase.instance.client
          .rpc('gs_financial_reconciliation_readiness')
          .timeout(const Duration(seconds: 15));
      if (raw is! Map) return null;
      final result = Map<String, dynamic>.from(raw);
      if (result['verified_complete'] is! bool ||
          result['source_tables'] is! Map) return null;
      return result;
    } catch (_) { return null; }
  }

  // Independent server-side certification gate diagnostics; never a money source.
  Future<List<Map<String, dynamic>>?> _loadCertificationGates() async {
    if (Supabase.instance.client.auth.currentUser == null) return null;
    try {
      final raw = await Supabase.instance.client
          .rpc('gs_financial_unpaid_certification_gates')
          .timeout(const Duration(seconds: 15));
      if (raw is! Map || raw['verified_complete'] != false ||
          raw['standing_cash_active_visits_iqd'] != null ||
          raw['pending_online_motel_unpaid_iqd'] != null ||
          raw['certification_gates'] is! List) return null;
      final rows = List<Map<String, dynamic>>.from(
          (raw['certification_gates'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
      if (rows.length != 10 || rows.any((r) => r['verified'] != false ||
          r['id'] is! String || r['reason'] is! String)) return null;
      final ids = rows.map((r) => r['id'] as String).toSet();
      if (ids.length != 10) return null;
      return rows;
    } catch (_) { return null; }
  }

  late Future<List<Map<String, dynamic>>?> _certificationGates =
      _loadCertificationGates();

  Widget _certificationGatesPanel() =>
      FutureBuilder<List<Map<String, dynamic>>?>(
        future: _certificationGates,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Text('Checking payment certification requirements…');
          }
          final gates = snapshot.data;
          if (gates == null) return const Text(
              'Certification requirements unavailable; amounts remain blocked.');
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Ten server-reported settlement certification blockers',
                style: TextStyle(fontWeight: FontWeight.w600)),
            for (final gate in gates)
              Text('Not verified · ${gate['reason']}'),
            const Text('These checks are unresolved, not ten verified fixes. '
                'No Standing Cash or Pending Payment total is certified.'),
          ]);
        },
      );

  late Future<Map<String, dynamic>?> _readiness = _loadReconciliationReadiness();

  Widget _readinessPanel() => FutureBuilder<Map<String, dynamic>?>(
    future: _readiness,
    builder: (context, snapshot) {
      final report = snapshot.data;
      if (report == null) return const Text(
        'Reconciliation readiness unavailable (permission, migration or connection).');
      final tables = Map<String, dynamic>.from(report['source_tables'] as Map);
      final names = <String, String>{
        'orders': 'Orders',
        'order_items': 'Order items',
        'table_visits': 'Table visits',
        'cafe_tables': 'Café tables',
        'cash_payments': 'Cash payments',
        'motel_requests': 'Motel food requests',
        'motel_finance_invoices': 'Motel finance invoices',
      };
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Source availability (not settlement verification)',
            style: TextStyle(fontWeight: FontWeight.w600)),
        for (final entry in names.entries)
          Text('${entry.value}: ${tables[entry.key] == true ? "Schema present" : "Schema missing"}'),
        if (report['binding_diagnostics'] is Map) ...[
          const SizedBox(height: 8),
          const Text('Order/visit and settlement diagnostics (counts only)',
              style: TextStyle(fontWeight: FontWeight.w600)),
          for (final entry in <String, String>{
            'active_visits': 'Active visits',
            'active_visit_orders': 'Orders linked to active visits',
            'unbound_cafe_orders': 'Café orders missing visit binding',
            'orders_linked_to_inactive_visits': 'Orders linked to non-active visits',
            'orders_with_cash_and_unified_ledger': 'Orders with both legacy cash and unified ledger entries',
            'unpaid_motel_finance_invoices': 'Motel finance invoices marked unpaid',
            'cross_order_reversal_links': 'Refund/reversal linked to another order',
            'over_reversed_ledger_entries': 'Ledger entries reversed beyond original amount',
            'tables_with_multiple_active_visits': 'Tables with multiple active visits',
            'reversals_without_original_entry': 'Reversals without a matching original entry',
            'ledger_entries_without_order': 'Payment ledger entries without a matching order',
            'cafe_orders_with_missing_visit': 'Café orders referencing a missing visit',
          }.entries)
            Text('${entry.value}: ${_validEntryCount((report['binding_diagnostics'] as Map)[entry.key])}'),
          const Text('These are diagnostic counts, not unpaid amounts or proof of settlement.'),
        ],
        _certificationGatesPanel(),
        const Text('Blocked: no canonical all-method payment allocations, '
            'order-to-visit source binding, or verified motel prepayment deduplication. '
            'No live unpaid amount is approved for display.'),
      ]);
    },
  );

  late Future<Map<String, dynamic>?> _liveBalances = _loadLiveUnpaidBalances();

  // Refresh the cash sample and both independent finance diagnostics together.
  // No client-side addition of cash, external evidence, or motel prepayments.
  void _refreshFinancialSources() {
    if (!mounted) return;
    setState(() {
      _rows = _load();
      _readiness = _loadReconciliationReadiness();
      _certificationGates = _loadCertificationGates();
      _liveBalances = _loadLiveUnpaidBalances();
      _standingOrders = _loadStandingOrders();
      _pendingSources = _loadPendingSources();
    _pendingAllocations = _loadPendingAllocations();
    });
  }


  Future<List<Map<String, dynamic>>> _loadStandingOrders() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      throw StateError('Employee login required.');
    }
    final raw = await Supabase.instance.client
        .rpc('gs_standing_cash_active_orders')
        .timeout(const Duration(seconds: 15));
    if (raw is! Map || raw['complete'] != false || raw['orders'] is! List) {
      throw const FormatException('Unexpected Standing Cash response.');
    }
    final orders = raw['orders'] as List;
    if (orders.length > 200 || orders.any((o) => o is! Map)) {
      throw const FormatException('Invalid Standing Cash sample.');
    }
    final seen = <int>{};
    return orders.map((o) => Map<String, dynamic>.from(o as Map)).where((o) {
      final id = _wholeIqd(o['order_id']);
      final due = _wholeIqd(o['cash_only_remaining_iqd']);
      if (id == null || id <= 0 || !seen.add(id) || due == null || due <= 0) {
        throw const FormatException('Invalid or duplicated active order.');
      }
      return true;
    }).toList();
  }

  late Future<List<Map<String, dynamic>>> _standingOrders = _loadStandingOrders();

  Future<void> _receiveStandingCash(Map<String, dynamic> order) async {
    final orderId = _wholeIqd(order['order_id']);
    final due = _wholeIqd(order['cash_only_remaining_iqd']);
    if (orderId == null || orderId <= 0 || due == null || due <= 0 ||
        order['cash_collection_eligible'] != true) return;
    final controller = TextEditingController(text: '$due');
    bool busy = false;
    String? error;
    // One reference per user confirmation, retained across retry attempts.
    String? reference;
    try {
      await showDialog<void>(context: context, builder: (dialogContext) =>
        StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
          title: Text('Receive cash · Order #$orderId'),
          content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Cash-only remaining: ${_iqd(due)}'),
            const Text('Other payment methods and motel prepayments require verified settlement.'),
            TextField(controller: controller, enabled: !busy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (IQD)')),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
          ]),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
            FilledButton(onPressed: busy ? null : () async {
              final amount = int.tryParse(controller.text.trim());
              if (amount == null || amount <= 0 || amount > due) {
                setDialogState(() => error = 'Enter a whole IQD amount within the remaining balance.');
                return;
              }
              setDialogState(() { busy = true; error = null; });
              try {
                reference ??= (await Supabase.instance.client
                    .rpc('gs_new_payment_reference')
                    .timeout(const Duration(seconds: 10))).toString();
                await Supabase.instance.client.rpc('gs_standing_cash_collect_cash',
                  params: {'p_order_id': orderId, 'p_amount_iqd': amount,
                    'p_reference': reference}).timeout(const Duration(seconds: 20));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  _refreshFinancialSources();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Cash receipt recorded. Balances refreshing.')));
                }
              } catch (e) {
                if (dialogContext.mounted) setDialogState(() {
                  error = 'Payment not confirmed. Check receipts before retrying with the same reference; do not create another payment. $e';
                  busy = false;
                });
              }
            }, child: const Text('Confirm cash payment')),
          ],
        )));
    } finally { controller.dispose(); }
  }

  // Client-side ordering applies ONLY to records already returned by the
  // permission-scoped RPC (maximum 200), not the complete business ledger.
  void _sortSourceSample(List<Map<String, dynamic>> rows, String amountField) {
    if (_sourceSort == 'original') return;
    rows.sort((a, b) {
      final aAmount = _wholeIqd(a[amountField]) ?? -1;
      final bAmount = _wholeIqd(b[amountField]) ?? -1;
      final compare = aAmount.compareTo(bAmount);
      return _sourceSort == 'amount_low' ? compare : -compare;
    });
  }

  Widget _standingCashCollectionPanel() => Card(child: Padding(
    padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(header: true, child: Text('Standing Cash · Active tables',
        style: TextStyle(fontWeight: FontWeight.bold))),
      const Text('Cash-only order sample (up to 200). NOT a verified all-method Standing Cash total.'),
      const Text('Collection is per eligible order, not the whole table. The server rechecks eligibility and the remaining cash-only amount before posting.'),
      _cardFilters(),
      TextButton.icon(onPressed: () => setState(() => _standingOrders = _loadStandingOrders()),
        icon: const Icon(Icons.refresh), label: const Text('Refresh active orders')),
      FutureBuilder<List<Map<String, dynamic>>>(future: _standingOrders,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Text(
            'Active orders unavailable. Verify permissions and database migration.');
          if (!snapshot.hasData) return const LinearProgressIndicator();
          // A positive cash-only balance cannot distinguish unpaid from
          // partially paid: other methods may have settled part of this order.
          // Never fabricate a payment status from the remaining cash amount.
          final matching = snapshot.data!.where((order) =>
             (!_standingEligibleOnly || order['cash_collection_eligible'] == true) &&
             _sourceAmountMatches(order['cash_only_remaining_iqd']) &&
             _cardMatches(order,
               '${order['order_id']} ${order['table_id']}', 'unverified')).toList();
          _sortSourceSample(matching, 'cash_only_remaining_iqd');
          // Empty filtered results do not prove the account has no other orders.
          var total = 0;
          var totalsVerified = true;
          for (final order in matching) {
            final due = _wholeIqd(order['cash_only_remaining_iqd']);
            if (due == null || due < 0 || total > 9007199254740991 - due) {
              totalsVerified = false; break;
            }
            total += due;
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${snapshot.data!.length} active-table order records in the authorized cash-only sample (eligibility varies by record).',
              style: const TextStyle(fontWeight: FontWeight.w600)),
            const Text('Select an order to review it. Receive cash is available only for server-marked eligible orders.'),
            for (final order in matching)
            ListTile(
              title: Text('Table ${order['table_id']} · Order #${order['order_id']}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Cash-only remaining: ${_iqd(order['cash_only_remaining_iqd'])}'),
                  if (order['cash_collection_eligible'] != true)
                    const Text('Collection unavailable: server has not marked this order eligible.',
                      style: TextStyle(fontSize: 12)),
                ],
              ),
              onTap: () => _inspectItemizedOrder(order),
              trailing: Wrap(spacing: 4, children: [
                OutlinedButton(onPressed: () => _inspectItemizedOrder(order),
                  child: const Text('More Details')),
                FilledButton(
                onPressed: order['cash_collection_eligible'] == true
                  ? () => _receiveStandingCash(order) : null,
                child: const Text('Pay')),
              ]),
            ),
            const Divider(),
            if (matching.isEmpty) const Text('No matching orders in this authorized sample; other orders may exist.'),
            Text('Filtered records: ${matching.length}'),
            Text('Server cash-eligible records: ${matching.where((order) => order['cash_collection_eligible'] == true).length}'),
            Text('Not approved for cash collection: ${matching.where((order) => order['cash_collection_eligible'] != true).length}'),
            Text(snapshot.data!.length >= 200
              ? 'Filtered cash-only total withheld: 200-record source cap reached; additional orders may be missing.'
              : totalsVerified ? 'Filtered cash-only remaining (returned sample only): ${_iqd(total)}'
              : 'Filtered total unavailable: invalid source amounts'),
            Text('Not an all-method balance; source sample ${snapshot.data!.length >= 200 ? 'has reached the 200-record cap and may be incomplete' : 'is limited to authorized returned records'}.'),
          ]);
        }),
    ])));

  // Source-classified inspection only: invoice status is not an all-method
  // unpaid balance. Online order linkage is not yet established by schema.
  Future<List<Map<String, dynamic>>> _loadPendingSources() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      throw StateError('Employee login required.');
    }
    final raw = await Supabase.instance.client
        .rpc('gs_financial_pending_source_inspection')
        .timeout(const Duration(seconds: 15));
    if (raw is! Map || raw['verified_complete'] != false ||
        raw['collection_enabled'] != false || raw['online_classified'] != false ||
        raw['motel_invoices'] is! List) {
      throw const FormatException('Unexpected Pending Payment inspection contract.');
    }
    final rows = raw['motel_invoices'] as List;
    if (rows.length > 200 || rows.any((row) => row is! Map)) {
      throw const FormatException('Invalid Pending Payment source list.');
    }
    final seen = <String>{};
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).map((row) {
      final id = row['finance_invoice_id'];
      final amount = _wholeIqd(row['invoice_total_iqd']);
      if (id is! String || id.isEmpty || !seen.add(id) ||
          amount == null || amount < 0 || row['source'] != 'motel_finance_invoice' ||
          row['payment_status'] != 'unpaid' || row['collection_eligible'] != false) {
        throw const FormatException('Invalid or repeated Pending Payment invoice.');
      }
      return row;
    }).toList();
  }

  late Future<List<Map<String, dynamic>>> _pendingSources = _loadPendingSources();
  // UUID motel invoice settlement evidence, not a remaining-due calculation.
  Future<List<Map<String, dynamic>>> _loadPendingAllocations() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      throw StateError('Employee login required.');
    }
    final raw = await Supabase.instance.client
        .rpc('gs_financial_pending_allocation_diagnostics')
        .timeout(const Duration(seconds: 15));
    if (raw is! Map || raw['verified_complete'] != false ||
        raw['collection_enabled'] != false || raw['online_classified'] != false ||
        raw['motel_allocation_diagnostics'] is! List) {
      throw const FormatException('Invalid motel allocation diagnostics contract.');
    }
    final records = raw['motel_allocation_diagnostics'] as List;
    if (records.length > 200 || records.any((e) => e is! Map)) {
      throw const FormatException('Invalid motel allocation diagnostics rows.');
    }
    final ids = <String>{};
    return records.map((e) => Map<String, dynamic>.from(e as Map)).map((row) {
      final id = row['finance_invoice_id'];
      final total = _wholeIqd(row['invoice_total_iqd']);
      final cash = _wholeIqd(row['confirmed_cash_settlement_iqd']);
      // A diagnostic cannot be called safe when its cash evidence exceeds
      // its own posted invoice, even if an older RPC omitted the risk flag.
      // Do not silently coerce the amount or infer any remaining balance.
      if (id is! String || id.isEmpty || !ids.add(id) ||
          total == null || total < 0 || cash == null || cash < 0 ||
          cash > total ||
          row['collection_eligible'] != false ||
          row['identity_verified'] != false ||
          row['bridge_identity_consistent'] is! bool ||
          row['source_fingerprint_collision'] is! bool ||
          row['bridge_amount_mismatch'] is! bool ||
          row['cash_evidence_exceeds_invoice'] is! bool ||
          row['invalid_cash_settlement_amount'] is! bool ||
          row['invalid_invoice_total'] is! bool ||
          row['invoice_cash_status_inconsistent'] is! bool ||
          row['requires_manual_review'] is! bool ||
          !['unpaid', 'partially_paid', 'paid', 'paid_cash'].contains(row['invoice_status']) ||
          ['bridge_count','draft_intent_count','review_plan_count',
           'confirmed_cash_settlement_count'].any((key) =>
              _wholeIqd(row[key]) == null || _wholeIqd(row[key])! < 0)) {
        throw const FormatException('Invalid or duplicate motel settlement evidence.');
      }
      return row;
    }).toList();
  }

  late Future<List<Map<String, dynamic>>> _pendingAllocations =
      _loadPendingAllocations();


  // Pending Payment deliberately cannot post cash from an unverified source.
  // Online/motel orders require a source-classified, provider-finalized,
  // prepaid-package-aware backend allocation before collection is enabled.
  Widget _pendingPaymentPanel() => Card(child: Padding(
    padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(header: true, child: Text('Pending Payment · Online & motel',
        style: TextStyle(fontWeight: FontWeight.bold))),
      const SizedBox(height: 8),
      const Text('Payment collection unavailable until the server can identify '
        'eligible unpaid online/motel orders and verify all payment methods, '
        'prepaid meal packages, refunds, and duplicate-source protection.'),
      _cardFilters(),
      TextButton.icon(
        onPressed: () => setState(() {
          _pendingSources = _loadPendingSources();
          _pendingAllocations = _loadPendingAllocations();
        }),
        icon: const Icon(Icons.refresh), label: const Text('Refresh sources and settlement evidence')),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _pendingSources,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Text(
            'Pending sources unavailable. Check permission, deployment and connection.');
          if (!snapshot.hasData) return const LinearProgressIndicator();
          final matching = snapshot.data!.where((invoice) =>
            _sourceAmountMatches(invoice['invoice_total_iqd']) && _cardMatches(invoice,
            '${invoice['finance_invoice_id']}', '${invoice['payment_status']}')).toList();
          _sortSourceSample(matching, 'invoice_total_iqd');
          // A filtered sample cannot establish database-wide completeness.
          var postedTotal = 0;
          var totalsVerified = true;
          for (final invoice in matching) {
            final value = _wholeIqd(invoice['invoice_total_iqd']);
            if (value == null || value < 0 || postedTotal > 9007199254740991 - value) {
              totalsVerified = false; break;
            }
            postedTotal += value;
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Online orders: no proven online-source identity in the current finance schema; collection blocked.'),
            const Text('Motel invoices below are posted source records, NOT verified unpaid balances.'),
            Text('${snapshot.data!.length} posted motel invoice records in this authorized sample. Payment collection disabled.',
              style: const TextStyle(fontWeight: FontWeight.w600)),
            if (snapshot.data!.isEmpty)
              const Text('No posted unpaid-status motel invoices in this limited sample.'),
            for (final invoice in matching) ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text('Motel invoice ${invoice['finance_invoice_id']}'),
              onTap: () => _inspectMotelInvoice(invoice),
              subtitle: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Posted invoice total: ${_iqd(invoice['invoice_total_iqd'])} · '
                    'Status: ${invoice['payment_status']} · Collection blocked'),
                  // Show read-only evidence on the source row, without treating
                  // it as a paid amount or authorizing collection. A duplicate,
                  // mismatched or absent diagnostic record fails closed.
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _pendingAllocations,
                    builder: (context, diagnosticSnapshot) {
                      if (diagnosticSnapshot.hasError) return const Text(
                        'Settlement evidence unavailable · review required');
                      if (!diagnosticSnapshot.hasData) return const Text(
                        'Checking settlement evidence…');
                      // At the 200-row RPC ceiling the evidence set may be
                      // truncated. Do not describe a matched invoice as fully
                      // covered or settled when other records may be omitted.
                      if (diagnosticSnapshot.data!.length >= 200) {
                        return const Text(
                          'Settlement evidence reached the 200-record source limit · '
                          'coverage unverified; manual review required');
                      }
                      final invoiceId = invoice['finance_invoice_id'];
                      final matches = diagnosticSnapshot.data!.where(
                        (row) => row['finance_invoice_id'] == invoiceId).toList();
                      if (matches.length != 1) return Text(matches.isEmpty
                        ? 'Settlement evidence missing · review required'
                        : 'Duplicate settlement evidence · review required');
                      final evidence = matches.single;
                      final sourceTotal = _wholeIqd(invoice['invoice_total_iqd']);
                      final diagnosticTotal = _wholeIqd(evidence['invoice_total_iqd']);
                      final cashAmount = _wholeIqd(evidence['confirmed_cash_settlement_iqd']);
                      final needsReview = sourceTotal == null ||
                        diagnosticTotal != sourceTotal ||
                        cashAmount == null || cashAmount < 0 ||
                        (diagnosticTotal != null && cashAmount > diagnosticTotal) ||
                        evidence['invoice_status'] != invoice['payment_status'] ||
                        evidence['requires_manual_review'] == true ||
                        evidence['bridge_identity_consistent'] != true ||
                        evidence['source_fingerprint_collision'] == true ||
                        evidence['bridge_amount_mismatch'] == true ||
                        evidence['cash_evidence_exceeds_invoice'] == true ||
                        evidence['invalid_cash_settlement_amount'] == true ||
                        evidence['invalid_invoice_total'] == true ||
                        evidence['invoice_cash_status_inconsistent'] == true;
                      return Text(needsReview
                        ? 'Settlement evidence flagged · manual review required'
                        : 'Matching read-only cash diagnostics · payment still blocked');
                    },
                  ),
                ],
              ),
              trailing: Wrap(spacing: 4, children: [
                OutlinedButton(onPressed: () => _inspectMotelInvoice(invoice),
                  child: const Text('More Details')),
                const FilledButton(onPressed: null, child: Text('Pay')),
              ]),
            ),
            const Divider(),
            // Read-only per-invoice evidence is scoped to the SAME filtered
            // invoices. Missing or ambiguous evidence never implies paid/unpaid.
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _pendingAllocations,
              builder: (context, evidenceSnapshot) {
                if (evidenceSnapshot.hasError) return const Text(
                  'Filtered settlement evidence unavailable; do not infer unpaid totals.');
                if (!evidenceSnapshot.hasData) return const Text(
                  'Loading filtered settlement diagnostics…');
                // Never silently overwrite duplicate invoice diagnostics.
                // An ambiguous one-to-many mapping cannot prove settlement.
                final evidenceById = <String, Map<String, dynamic>>{};
                final ambiguousEvidenceIds = <String>{};
                for (final row in evidenceSnapshot.data!) {
                  final id = row['finance_invoice_id'];
                  if (id is! String || id.isEmpty) continue;
                  if (evidenceById.containsKey(id)) {
                    ambiguousEvidenceIds.add(id);
                  } else {
                    evidenceById[id] = row;
                  }
                }
                var matchedEvidence = 0;
                var reviewRequired = 0;
                var missingEvidence = 0;
                // A missing or contradictory diagnostic record needs follow-up,
                // even when the diagnostic RPC itself reports no review flag.
                var followUpRequired = 0;
                var cleanEvidenceInvoices = 0;
                var confirmedCashEvidence = 0;
                var safeCashEvidenceTotal = true;
                for (final invoice in matching) {
                  final row = evidenceById[invoice['finance_invoice_id']];
                  if (row == null ||
                      ambiguousEvidenceIds.contains(invoice['finance_invoice_id']) ||
                      _wholeIqd(row['invoice_total_iqd']) == null ||
                      _wholeIqd(row['invoice_total_iqd']) !=
                          _wholeIqd(invoice['invoice_total_iqd'])) {
                    missingEvidence++;
                    followUpRequired++;
                    continue;
                  }
                  matchedEvidence++;
                  // Source-status disagreement and any diagnostic risk flag
                  // require review. These are NOT proof of a payable balance.
                  final needsReview = row['requires_manual_review'] == true ||
                      row['invoice_status'] != invoice['payment_status'] ||
                      row['bridge_identity_consistent'] != true ||
                      row['source_fingerprint_collision'] == true ||
                      row['bridge_amount_mismatch'] == true ||
                      row['cash_evidence_exceeds_invoice'] == true ||
                      row['invalid_cash_settlement_amount'] == true ||
                      row['invalid_invoice_total'] == true ||
                      row['invoice_cash_status_inconsistent'] == true;
                  if (needsReview) {
                    reviewRequired++;
                    followUpRequired++;
                    // Quarantine contradictory or risky diagnostics. Cash
                    // evidence on these invoices cannot be called clean.
                    continue;
                  }
                  cleanEvidenceInvoices++;
                  final cash = _wholeIqd(row['confirmed_cash_settlement_iqd']);
                  if (cash == null || cash < 0 ||
                      confirmedCashEvidence > 9007199254740991 - cash) {
                    safeCashEvidenceTotal = false;
                  } else if (safeCashEvidenceTotal) {
                    confirmedCashEvidence += cash;
                  }
                }
                // The two read-only RPCs are separately sampled. Do not
                // present a cash-evidence sum as complete if either sample
                // hit its cap or a displayed invoice lacks unique matching
                // diagnostics. The sum is NEVER an all-method paid balance.
                final diagnosticCoverageUsable = missingEvidence == 0 &&
                    ambiguousEvidenceIds.isEmpty &&
                    snapshot.data!.length < 200 &&
                    evidenceSnapshot.data!.length < 200;
                return Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filtered invoices with matching diagnostic evidence: $matchedEvidence'),
                    Text('Ambiguous diagnostic invoice IDs in returned sample: ${ambiguousEvidenceIds.length}; excluded from verified matching and cash evidence totals.'),
                    Text('Filtered invoices missing or mismatching evidence: $missingEvidence'),
                    Text('Filtered invoices requiring source review (including status and settlement integrity checks): $reviewRequired'),
                    Text('Filtered invoices with clean, matching diagnostic evidence: $cleanEvidenceInvoices'),
                    Text('Risk-flagged or contradictory diagnostics are excluded from clean cash evidence totals.'),
                    Text('Filtered invoices needing follow-up (missing/mismatched evidence OR review flags): $followUpRequired'),
                    Text('Diagnostic sample: ${evidenceSnapshot.data!.length} rows; ${evidenceSnapshot.data!.length >= 200 ? '200-record cap reached, matching evidence may be missing' : 'limited to authorized returned rows'}.'),
                    Text(!diagnosticCoverageUsable
                      ? 'Filtered clean-diagnostic cash evidence total withheld: missing/ambiguous invoice evidence or a 200-record source/diagnostic cap. Inspect individual invoices; no outstanding balance is inferred.'
                      : safeCashEvidenceTotal
                        ? 'Filtered clean-diagnostic cash evidence (returned sample only; NOT all-method paid): ${_iqd(confirmedCashEvidence)}'
                        : 'Filtered cash evidence total unavailable: invalid or overflowing source amounts'),
                    Text('Cross-RPC diagnostic coverage for displayed invoices: ${diagnosticCoverageUsable ? 'No missing or ambiguous matches within uncapped returned samples' : 'Incomplete or ambiguous — totals withheld'}. This does not certify database-wide coverage.'),
                    const Text('Diagnostic cash evidence can overlap other records; never subtract it from invoice totals to invent an unpaid balance.'),
                  ]);
              },
            ),
            const Divider(),
            if (matching.isEmpty) const Text('No matching invoices in this authorized sample; this does not establish a zero outstanding balance.'),
            Text('Filtered invoice records: ${matching.length}'),
            const Text('Verified online-order records: unavailable (source identity not established).'),
            const Text('Pay actions: 0 enabled (source settlement unverified).'),
            Text(snapshot.data!.length >= 200
              ? 'Filtered posted invoice total withheld: 200-record source cap reached; more invoices may exist.'
              : totalsVerified ? 'Filtered posted invoice total (returned sample only): ${_iqd(postedTotal)}'
              : 'Posted total unavailable: invalid source amounts'),
            Text('Posted total is NOT an outstanding balance. Collection blocked. Source sample ${snapshot.data!.length >= 200 ? 'reached the 200-record cap and may be incomplete' : 'contains only authorized returned records'}.'),
          ]);
        },
      ),
      const Divider(),
      const Text('Invalid or nonpositive invoice totals require manual review; collection stays disabled.'),
      const Text('Motel settlement evidence · read-only',
          style: TextStyle(fontWeight: FontWeight.w600)),
      TextButton.icon(
        onPressed: () => setState(() =>
            _pendingAllocations = _loadPendingAllocations()),
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh settlement evidence')),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _pendingAllocations,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Text(
            'Settlement evidence unavailable (permissions, migration or connection).');
          if (!snapshot.hasData) return const LinearProgressIndicator();
          if (snapshot.data!.isEmpty) return const Text('No posted motel finance invoices in sample.');
          return Column(children: [
            for (final row in snapshot.data!) ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: Text('Invoice ${row['finance_invoice_id']}'),
              subtitle: Text('Posted: ${_iqd(row['invoice_total_iqd'])} · '
                  'Confirmed cash evidence: ${_iqd(row['confirmed_cash_settlement_iqd'])}\n'
                  'Source bridges: ${row['bridge_count']} · '
                  'Draft intents: ${row['draft_intent_count']} · '
                  'Review plans: ${row['review_plan_count']} · '
                  'Cash settlements: ${row['confirmed_cash_settlement_count']}\n'
                  'Source bridge consistent: ${row['bridge_identity_consistent'] == true ? 'Yes' : 'No / missing'} · '
                  'Fingerprint collision: ${row['source_fingerprint_collision'] == true ? 'Review required' : 'None detected'} · '
                  'Bridge amount mismatch: ${row['bridge_amount_mismatch'] == true ? 'Review required' : 'None detected'}\n' 
                  'Cash exceeds invoice: ${row['cash_evidence_exceeds_invoice'] == true ? 'Review required' : 'No'}\n'
                  'Invalid cash evidence amount: ${row['invalid_cash_settlement_amount'] == true ? 'Review required' : 'None detected'}\n'
                  'Invoice/cash status inconsistent: ${row['invoice_cash_status_inconsistent'] == true ? 'Review required' : 'None detected'}\n'
                  'Manual review: ${row['requires_manual_review'] == true ? 'Required' : 'No issue in checked sources'} · '
                  'Identity verified: No · Collection blocked.'),
              trailing: const Icon(Icons.lock_outline),
            ),
          ]);
        },
      ),
      const SizedBox(height: 8),
      const ListTile(
        leading: Icon(Icons.lock_outline),
        title: Text('Receive payment'),
        subtitle: Text('Disabled: pending order settlement is not verified.'),
        enabled: false,
      ),
    ])));

  Widget _liveBalancesPanel() => Card(child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Live unpaid balances', style: TextStyle(fontWeight: FontWeight.bold)),
      _readinessPanel(),
      const Text('Standing Cash: customers currently present. Pending Payment: unpaid online and motel orders.'),
      const Text('Refresh reloads cash sample, source diagnostics and unpaid balances together. It does not certify settlement.'),
      FutureBuilder<Map<String, dynamic>?>(
        future: _liveBalances,
        builder: (context, snapshot) {
          final value = snapshot.data;
          if (value == null) return const Text(
            'Live balances unavailable — full payment-channel and order-source verification is required.');
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Standing Cash: ${_iqd(value['standing_cash_active_visits_iqd'])}'),
            Text('Pending Payment: ${_iqd(value['pending_online_motel_unpaid_iqd'])}'),
          ]);
        },
      ),
      TextButton.icon(
        onPressed: _refreshFinancialSources,
        icon: const Icon(Icons.refresh), label: const Text('Refresh live balances'),
      ),
    ]),
  ));

  // Ledger counts must be nonnegative whole numbers, never raw malformed data.
  String _validEntryCount(dynamic value) {
    final count = _wholeIqd(value);
    return count == null || count < 0 ? 'Unavailable' : '$count';
  }

  // Receipt amounts use the same whole-IQD validation as ledger figures.
  // A malformed amount must never be copied as a valid cash receipt.
  // A receipt is valid only for the order currently being reviewed. The
  // server filters by order, but the UI also checks the returned identity
  // before displaying or copying payment proof.
  bool _validReceipt(Map<String, dynamic> order, Map<String, dynamic> receipt) {
    final requestedOrderId = _wholeIqd(order['order_id']);
    final receiptOrderId = _wholeIqd(receipt['order_id']);
    if (requestedOrderId == null || requestedOrderId <= 0 ||
        receiptOrderId != requestedOrderId) return false;
    final amount = _wholeIqd(receipt['amount_iqd']);
    return amount != null && amount > 0 &&
        receipt['receipt_id'] != null &&
        _receiptField(receipt['receipt_id']) != '-' &&
        DateTime.tryParse('${receipt['collected_at'] ?? ''}') != null;
  }

  // Treat receipt metadata as untrusted text. Strip line/control separators
  // so a reference or employee ID cannot forge additional receipt fields.
  String _receiptField(dynamic value) {
    final raw = value == null ? '-' : value.toString();
    final cleaned = raw.replaceAll(RegExp(r'[\x00-\x1f\x7f-\x9f\u2028\u2029]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return '-';
    return cleaned.length <= 160 ? cleaned : '${cleaned.substring(0, 160)}…';
  }

  String _receiptText(Map<String, dynamic> order, Map<String, dynamic> receipt) {
    final date = DateTime.tryParse('${receipt['collected_at'] ?? ''}')?.toLocal();
    final when = date == null ? '${receipt['collected_at'] ?? 'Unknown'}'
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return 'Gelye Sherane Cafe & Restaurant\n'
        'CASH PAYMENT RECEIPT\n'
        'Receipt: ${_receiptField(receipt['receipt_id'])}\n'
        'Order: ${order['order_id']}\n'
        'Amount: ${_iqd(receipt['amount_iqd'])}\n'
        'Recorded: $when (device local time)\n'
        'Reference: ${_receiptField(receipt['reference'])}\n'
        'Employee ID: ${_receiptField(receipt['collected_by'])}\n'
        'Payment method: Cash\n'
        'This receipt confirms recorded cash only.';
  }
  // Server-authorized diagnostic; never interpret as a certified balance.
  Future<void> _showSettlementPreview(Map<String, dynamic> order) async {
    final id = _wholeIqd(order['order_id']);
    if (id == null || id <= 0) return;
    try {
      final raw = await Supabase.instance.client.rpc(
        'gs_financial_order_settlement_preview',
        params: {'p_order_id': id},
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (raw is! Map) throw const FormatException('Invalid settlement preview.');
      final report = Map<String, dynamic>.from(raw);
      if (report['settlement_confirmed'] != false ||
          _wholeIqd(report['order_id']) != id ||
          report['visit_status'] is! String ||
          report['is_motel'] is! bool ||
          _wholeIqd(report['ledger_credits_iqd']) == null ||
          _wholeIqd(report['ledger_debits_iqd']) == null ||
          _wholeIqd(report['ledger_entries']) == null) {
        throw const FormatException('Incomplete settlement preview.');
      }
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (context) => AlertDialog(
        title: Text('Settlement checks · Order #$id'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Diagnostic only — NOT a verified outstanding balance.'),
          const SizedBox(height: 8),
          Text('Visit status: ${_receiptField(report['visit_status'])}'),
          Text('Motel order: ${report['is_motel'] == true ? 'Yes' : 'No'}'),
          Text('Ledger credits: ${_iqd(report['ledger_credits_iqd'])}'),
          Text('Ledger reversals: ${_iqd(report['ledger_debits_iqd'])}'),
          Text('Ledger entries: ${report['ledger_entries']}'),
          const SizedBox(height: 8),
          const Text('Legacy cash, prepaid packages, transfers and external settlements are not fully reconciled.'),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Settlement preview unavailable. Check permissions, migration and connection.'),
      ));
    }
  }

  // Crosswalk-aware source inspection; figures must never be summed as settled.
  Future<void> _showAllMethodCoverage(Map<String, dynamic> order) async {
    final id = _wholeIqd(order['order_id']);
    if (id == null || id <= 0) return;
    try {
      final raw = await Supabase.instance.client.rpc(
        'gs_financial_order_all_method_coverage',
        params: {'p_order_id': id},
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (raw is! Map) throw const FormatException('Invalid source coverage response.');
      final report = Map<String, dynamic>.from(raw);
      const fields = [
        'order_items_total_iqd','legacy_cash_iqd','crosswalk_matched_cash_iqd',
        'unlinked_legacy_cash_iqd','unified_non_cash_credits_iqd',
        'unified_reversals_iqd','verified_external_evidence_iqd',
        'invalid_cash_crosswalk_count',
      ];
      if (report['settlement_confirmed'] != false ||
          report['verified_complete'] != false ||
          _wholeIqd(report['order_id']) != id ||
          report['visit_status'] is! String ||
          fields.any((key) => _wholeIqd(report[key]) == null)) {
        throw const FormatException('Incomplete source coverage response.');
      }
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (context) => AlertDialog(
        title: Text('Payment source coverage · Order #$id'),
        content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Diagnostic only — NOT a verified paid or unpaid balance.'),
            Text('Visit status: ${_receiptField(report['visit_status'])}'),
            Text('Order items: ${_iqd(report['order_items_total_iqd'])}'),
            Text('Legacy cash: ${_iqd(report['legacy_cash_iqd'])}'),
            Text('Cash matched to unified ledger: ${_iqd(report['crosswalk_matched_cash_iqd'])}'),
            Text('Unlinked legacy cash: ${_iqd(report['unlinked_legacy_cash_iqd'])}'),
            Text('Non-cash ledger credits: ${_iqd(report['unified_non_cash_credits_iqd'])}'),
            Text('Ledger reversals: ${_iqd(report['unified_reversals_iqd'])}'),
            Text('Verified external evidence: ${_iqd(report['verified_external_evidence_iqd'])}'),
            Text('Invalid cash crosswalks: ${report['invalid_cash_crosswalk_count']}'),
            const SizedBox(height: 8),
            const Text('External evidence can overlap ledger credits. Never add these categories into a settled amount.'),
          ],
        )),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Payment source coverage unavailable. Check migration, permission and connection.'),
      ));
    }
  }

  // Reference identity is diagnostic: no sum or allocation is certified.
  // Read-only amount and motel source checks; never a certified payment allocation.
  Future<void> _showAmountMotelSafety(Map<String, dynamic> order) async {
    final id = _wholeIqd(order['order_id']);
    if (id == null || id <= 0) return;
    try {
      final raw = await Supabase.instance.client.rpc(
        'gs_financial_order_amount_motel_safety',
        params: {'p_order_id': id},
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (raw is! Map) throw const FormatException('Invalid safety response');
      final report = Map<String, dynamic>.from(raw);
      const fields = [
        'verified_external_evidence_count',
        'external_reference_amount_mismatch_count',
        'external_reference_cross_order_conflict_count',
        'external_reference_without_ledger_count',
        'legacy_order_motel_bridge_count',
        'legacy_order_motel_bridge_amount_iqd',
        'motel_finance_invoices_without_bridge_count',
        'motel_finance_bridge_source_conflict_count',
      ];
      if (_wholeIqd(report['order_id']) != id ||
          report['verified_complete'] != false ||
          report['settlement_confirmed'] != false ||
          report['visit_status'] is! String ||
          fields.any((key) => _wholeIqd(report[key]) == null)) {
        throw const FormatException('Untrusted safety report');
      }
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (context) => AlertDialog(
        title: Text('Amount & motel safety · Order #$id'),
        content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Read-only diagnostic. No payment is certified.'),
            Text('Visit: ${_receiptField(report['visit_status'])}'),
            Text('Motel order: ${report['is_motel'] == true ? 'Yes' : 'No'}'),
            Text('Verified external evidence: ${report['verified_external_evidence_count']}'),
            Text('Reference amount mismatches: ${report['external_reference_amount_mismatch_count']}'),
            Text('Cross-order reference conflicts: ${report['external_reference_cross_order_conflict_count']}'),
            Text('External references without ledger: ${report['external_reference_without_ledger_count']}'),
            Text('Legacy motel bridge mappings: ${report['legacy_order_motel_bridge_count']}'),
            Text('Legacy bridge amount: ${report['legacy_order_motel_bridge_amount_iqd']} IQD'),
            Text('Motel finance invoices without bridge: ${report['motel_finance_invoices_without_bridge_count']}'),
            Text('Motel bridge source conflicts: ${report['motel_finance_bridge_source_conflict_count']}'),
            const SizedBox(height: 8),
            const Text('Prepaid motel coverage and all-method settlement remain unverified.'),
          ],
        )),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Amount/motel safety unavailable. Check migration, access and connection.'),
      ));
    }
  }

  Future<void> _showSourceIdentity(Map<String, dynamic> order) async {
    final id = _wholeIqd(order['order_id']);
    if (id == null || id <= 0) return;
    try {
      final raw = await Supabase.instance.client.rpc(
        'gs_financial_order_source_identity',
        params: {'p_order_id': id},
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (raw is! Map) throw const FormatException('Invalid identity response');
      final report = Map<String, dynamic>.from(raw);
      const fields = [
        'external_same_order_reference_candidates',
        'external_cross_order_reference_conflicts',
        'external_without_ledger_reference',
        'legacy_cash_without_crosswalk',
      ];
      if (_wholeIqd(report['order_id']) != id ||
          report['verified_complete'] != false ||
          report['source_identity_complete'] != false ||
          report['visit_status'] is! String ||
          fields.any((key) => _wholeIqd(report[key]) == null)) {
        throw const FormatException('Untrusted identity report');
      }
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (context) => AlertDialog(
        title: Text('Source identity · Order #$id'),
        content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Diagnostic only — no payment allocation is certified.'),
            Text('Visit: ${_receiptField(report['visit_status'])}'),
            Text('Motel order: ${report['is_motel'] == true ? 'Yes' : 'No'}'),
            Text('Same-order reference candidates: ${report['external_same_order_reference_candidates']}'),
            Text('Cross-order reference conflicts: ${report['external_cross_order_reference_conflicts']}'),
            Text('External evidence without ledger reference: ${report['external_without_ledger_reference']}'),
            Text('Legacy cash without crosswalk: ${report['legacy_cash_without_crosswalk']}'),
            const SizedBox(height: 8),
            const Text('Matching references do not prove settlement or authorize adding sources together.'),
          ],
        )),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Source identity unavailable. Check deployment, permissions and connectivity.'),
      ));
    }
  }


  // Read-only, permission-scoped per-order integrity audit. Never infer an
  // outstanding amount from these checks or enable settlement based on them.


  // Read-only cross-source reconciliation. Never promotes candidate amounts to payable totals.
  Future<void> _showSourceReconciliation(Map<String, dynamic> order) async {
    final id = _wholeIqd(order['order_id']);
    if (id == null || id <= 0) return;
    try {
      if (Supabase.instance.client.auth.currentUser == null) {
        throw StateError('Authentication required');
      }
      final raw = await Supabase.instance.client.rpc(
        'gs_financial_order_source_reconciliation',
        params: {'p_order_id': id},
      ).timeout(const Duration(seconds: 15));
      if (raw is! Map) throw const FormatException('Invalid source reconciliation');
      final report = Map<String, dynamic>.from(raw);
      const amountKeys = <String>[
        'legacy_cash_iqd', 'crosswalked_cash_iqd', 'item_allocated_iqd',
        'order_total_iqd', 'net_ledger_settlement_iqd',
      ];
      const countKeys = <String>[
        'unlinked_cash_count', 'verified_external_count',
        'matched_external_count', 'unmatched_external_count',
        'verified_credit_count', 'matched_credit_count',
        'unmatched_credit_count', 'unbacked_credit_ledger_count',
        'cross_order_reference_count', 'duplicate_external_reference_count',
        'invalid_item_allocation_count',
      ];
      const checkNames = <String, String>{
        'cash_receipts_all_crosswalked': 'Every cash receipt linked',
        'cash_amount_crosswalk_matches': 'Cash crosswalk amount',
        'external_evidence_matched': 'Verified external evidence linked',
        'credit_evidence_matched': 'Credit evidence linked',
        'credit_ledger_backed_by_evidence': 'Credit ledger evidence',
        'no_cross_order_external_reference': 'No cross-order references',
        'no_duplicate_external_reference': 'No duplicate external references',
        'item_allocations_bind_to_order': 'Item allocations match order',
        'item_allocations_not_above_ledger': 'Item allocations within settlement',
        'order_audit_checks_pass': 'Order integrity checks',
        'method_allocation_checks_pass': 'Method allocation checks',
        'motel_prepayments_authoritatively_bound': 'Motel prepaid binding',
        'credit_account_debit_authoritatively_confirmed': 'Credit debit confirmation',
        'all_payment_sources_exhaustively_enumerated': 'All sources enumerated',
      };
      final generated = DateTime.tryParse('${report['generated_at'] ?? ''}');
      final now = DateTime.now().toUtc();
      final checksRaw = report['checks'];
      if (_wholeIqd(report['order_id']) != id ||
          report['verified_complete'] != false ||
          report['settlement_confirmed'] != false ||
          report['motel_prepayments_certified_iqd'] != null ||
          report['partial_settlement_observed'] is! bool ||
          report['mixed_methods_observed'] is! bool ||
          generated == null ||
          generated.toUtc().isAfter(now.add(const Duration(minutes: 1))) ||
          now.difference(generated.toUtc()) > const Duration(minutes: 5) ||
          amountKeys.any((k) => _wholeIqd(report[k]) == null) ||
          countKeys.any((k) => _wholeIqd(report[k]) == null || _wholeIqd(report[k])! < 0) ||
          checksRaw is! Map || checksRaw.length != checkNames.length ||
          checksRaw.keys.any((k) => !checkNames.containsKey(k)) ||
          checkNames.keys.any((k) => checksRaw[k] is! bool) ||
          checksRaw['motel_prepayments_authoritatively_bound'] != false ||
          checksRaw['credit_account_debit_authoritatively_confirmed'] != false ||
          checksRaw['all_payment_sources_exhaustively_enumerated'] != false) {
        throw const FormatException('Incomplete or stale source reconciliation');
      }
      final amounts = {for (final k in amountKeys) k: _wholeIqd(report[k])!};
      final counts = {for (final k in countKeys) k: _wholeIqd(report[k])!};
      if (amounts['legacy_cash_iqd']! < 0 ||
          amounts['crosswalked_cash_iqd']! < 0 ||
          amounts['item_allocated_iqd']! < 0 ||
          amounts['order_total_iqd']! < 0 ||
          amounts['crosswalked_cash_iqd']! > amounts['legacy_cash_iqd']! ||
          counts['matched_external_count']! > counts['verified_external_count']! ||
          counts['matched_credit_count']! > counts['verified_credit_count']! ||
          counts['matched_external_count']! + counts['unmatched_external_count']! !=
              counts['verified_external_count']! ||
          counts['matched_credit_count']! + counts['unmatched_credit_count']! !=
              counts['verified_credit_count']!) {
        throw const FormatException('Source reconciliation arithmetic inconsistent');
      }
      if (!mounted) return;
      final checks = Map<String, dynamic>.from(checksRaw);
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text('Settlement sources · order #$id'),
        content: SizedBox(width: 520, child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Read-only evidence. Settlement and remaining payable amount are NOT certified.'),
              const Divider(),
              for (final k in amountKeys)
                ListTile(dense: true, title: Text(k.replaceAll('_iqd', '').replaceAll('_', ' ')),
                  trailing: Text('${_iqd(amounts[k])} IQD')),
              ListTile(dense: true, title: const Text('Partial settlement observed'),
                trailing: Text(report['partial_settlement_observed'] == true ? 'Yes' : 'No')),
              ListTile(dense: true, title: const Text('Mixed payment methods observed'),
                trailing: Text(report['mixed_methods_observed'] == true ? 'Yes' : 'No')),
              const Divider(),
              for (final k in countKeys)
                ListTile(dense: true, title: Text(k.replaceAll('_', ' ')),
                  trailing: Text('${counts[k]}')),
              const Divider(),
              for (final entry in checkNames.entries)
                ListTile(dense: true,
                  leading: Icon(checks[entry.key] == true
                    ? Icons.check_circle_outline : Icons.warning_amber_outlined),
                  title: Text(entry.value),
                  subtitle: Text(checks[entry.key] == true
                    ? 'Evidence check passed — not certified' : 'Unresolved or failed')),
              const Text('Motel prepaid packages, credit-account debits and exhaustive payment-source coverage remain unverified.'),
            ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(
        'Source reconciliation unavailable or inconsistent. No amount is certified.',
      )));
    }
  }

  // Per-order ledger allocation evidence, never a certified payable amount.
  Future<void> _showMethodAllocation(Map<String, dynamic> order) async {
    final id = _wholeIqd(order['order_id']);
    if (id == null || id <= 0) return;
    try {
      if (Supabase.instance.client.auth.currentUser == null) {
        throw StateError('Authentication required');
      }
      final raw = await Supabase.instance.client.rpc(
        'gs_financial_order_method_allocation',
        params: {'p_order_id': id},
      ).timeout(const Duration(seconds: 15));
      if (raw is! Map) throw const FormatException('Invalid allocation report');
      final r = Map<String, dynamic>.from(raw);
      const fields = <String>[
        'order_total_iqd', 'cash_credits_iqd', 'card_credits_iqd',
        'online_credits_iqd', 'credit_account_credits_iqd',
        'owner_waiver_credits_iqd', 'refund_debits_iqd',
        'reversal_debits_iqd', 'total_credits_iqd', 'total_debits_iqd',
        'net_ledger_settlement_iqd', 'candidate_remaining_iqd',
      ];
      const counts = <String>[
        'credit_entry_count', 'debit_entry_count', 'duplicate_source_count',
        'unlinked_cash_count', 'unmatched_external_count', 'failed_audit_checks',
      ];
      const checkNames = <String, String>{
        'order_audit_passes': 'Underlying order integrity audit',
        'no_unlinked_legacy_cash': 'Legacy cash linked',
        'external_references_matched': 'External evidence matched',
        'no_duplicate_ledger_source': 'No duplicate ledger source',
        'all_credits_classified': 'All credits classified',
        'credits_match_method_breakdown': 'Credits reconcile by method',
        'debits_match_reversal_breakdown': 'Debits reconcile by method',
        'no_negative_net_settlement': 'Nonnegative net settlement',
        'no_negative_remaining': 'Nonnegative candidate remaining',
        'nonnegative_order_total': 'Nonnegative order total',
      };
      final checksRaw = r['checks'];
      final generated = DateTime.tryParse('${r['generated_at'] ?? ''}');
      if (_wholeIqd(r['order_id']) != id ||
          r['verified_complete'] != false ||
          r['settlement_confirmed'] != false ||
          r['candidate_only'] != true ||
          generated == null ||
          generated.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 1))) ||
          DateTime.now().toUtc().difference(generated.toUtc()) > const Duration(minutes: 5) ||
          fields.any((f) => _wholeIqd(r[f]) == null) ||
          counts.any((f) => _wholeIqd(r[f]) == null || _wholeIqd(r[f])! < 0) ||
          checksRaw is! Map || checksRaw.length != checkNames.length ||
          checksRaw.keys.any((key) => !checkNames.containsKey(key)) ||
          checkNames.keys.any((key) => checksRaw[key] is! bool)) {
        throw const FormatException('Incomplete or stale allocation report');
      }
      final values = {for (final f in fields) f: _wholeIqd(r[f])!};
      if (values['cash_credits_iqd']! < 0 ||
          values['card_credits_iqd']! < 0 ||
          values['online_credits_iqd']! < 0 ||
          values['credit_account_credits_iqd']! < 0 ||
          values['owner_waiver_credits_iqd']! < 0 ||
          values['refund_debits_iqd']! < 0 ||
          values['reversal_debits_iqd']! < 0 ||
          values['total_credits_iqd']! < 0 ||
          values['total_debits_iqd']! < 0 ||
          values['order_total_iqd']! < 0 ||
          values['total_credits_iqd'] != values['cash_credits_iqd']! +
              values['card_credits_iqd']! + values['online_credits_iqd']! +
              values['credit_account_credits_iqd']! + values['owner_waiver_credits_iqd']! ||
          values['total_debits_iqd'] != values['refund_debits_iqd']! +
              values['reversal_debits_iqd']! ||
          values['net_ledger_settlement_iqd'] != values['total_credits_iqd']! -
              values['total_debits_iqd']! ||
          values['candidate_remaining_iqd'] != values['order_total_iqd']! -
              values['net_ledger_settlement_iqd']!) {
        throw const FormatException('Allocation arithmetic inconsistent');
      }
      if (!mounted) return;
      final checks = Map<String, dynamic>.from(checksRaw);
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text('Payment methods · order #$id'),
        content: SizedBox(width: 480, child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Ledger evidence only. Do not use candidate remaining as an amount due or payment authorization.'),
            const Divider(),
            for (final f in fields)
              ListTile(dense: true, title: Text(f.replaceAll('_iqd','').replaceAll('_',' ')),
                trailing: Text('${_iqd(values[f])} IQD')),
            const Divider(),
            for (final f in counts)
              ListTile(dense: true, title: Text(f.replaceAll('_',' ')),
                trailing: Text('${r[f]}')),
            const Divider(),
            for (final check in checkNames.entries)
              ListTile(dense: true,
                leading: Icon(checks[check.key] == true
                  ? Icons.check_circle_outline : Icons.warning_amber_outlined),
                title: Text(check.value),
                subtitle: Text(checks[check.key] == true ? 'Check passed, not certified'
                  : 'Needs investigation')),
            const Text('Prepaid, credit-account debit confirmation, source completeness and full pagination remain unverified.'),
          ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(
        'Method allocation unavailable or inconsistent. No amount is certified.',
      )));
    }
  }

  Future<void> _showOrderIntegrityAudit(Map<String, dynamic> order) async {
    final id = _wholeIqd(order['order_id']);
    if (id == null || id <= 0) return;
    try {
      if (Supabase.instance.client.auth.currentUser == null) {
        throw StateError('Employee authentication required');
      }
      final raw = await Supabase.instance.client.rpc(
        'gs_financial_order_integrity_audit',
        params: {'p_order_id': id},
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (raw is! Map) throw const FormatException('Invalid integrity audit');
      final report = Map<String, dynamic>.from(raw);
      final rawChecks = report['checks'];
      const checkNames = <String, String>{
        'order_exists': 'Order identity',
        'order_has_items': 'Billable order items',
        'cash_crosswalk_valid': 'Cash ledger crosswalk',
        'all_legacy_cash_crosswalked': 'Legacy cash linkage',
        'reversal_originals_valid': 'Reversal origin',
        'reversals_not_overallocated': 'Reversal allocation',
        'no_unverified_external_evidence': 'Unverified external evidence',
        'verified_external_refs_have_ledger_match': 'External evidence ledger match',
        'ledger_not_over_order_total': 'Overpayment protection',
        'visit_reference_resolves': 'Table visit identity',
        'motel_not_bound_to_table_visit': 'Motel and table separation',
        'cancelled_order_has_no_net_ledger_credit': 'Cancelled order settlement',
      };
      if (_wholeIqd(report['order_id']) != id ||
          report['verified_complete'] != false ||
          report['settlement_confirmed'] != false ||
          report['order_status'] is! String ||
          report['is_motel'] is! bool ||
          rawChecks is! Map || rawChecks.length != checkNames.length ||
          rawChecks.keys.any((key) => !checkNames.containsKey(key)) ||
          checkNames.keys.any((key) => rawChecks[key] is! bool) ||
          _wholeIqd(report['order_items_total_iqd']) == null ||
          _wholeIqd(report['ledger_credits_iqd']) == null ||
          _wholeIqd(report['ledger_debits_iqd']) == null ||
          _wholeIqd(report['ledger_entry_count']) == null ||
          DateTime.tryParse('${report['generated_at'] ?? ''}') == null) {
        throw const FormatException('Incomplete or inconsistent integrity audit');
      }
      final checks = Map<String, dynamic>.from(rawChecks);
      final passed = checkNames.keys.where((key) => checks[key] == true).length;
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text('Order integrity · #$id'),
        content: SizedBox(width: 480, child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Read-only checks; not a verified unpaid balance or permission to collect payment.'),
            Text('Order status: ${report['order_status']}'),
            Text('Source: ${report['is_motel'] == true ? 'Motel' : 'Other / café'}'),
            Text('Checks passing: $passed of ${checkNames.length}'),
            Text('Order items: ${_iqd(report['order_items_total_iqd'])}'),
            Text('Ledger credits: ${_iqd(report['ledger_credits_iqd'])}'),
            Text('Ledger debits: ${_iqd(report['ledger_debits_iqd'])}'),
            const Divider(),
            for (final entry in checkNames.entries)
              ListTile(dense: true,
                leading: Icon(checks[entry.key] == true
                    ? Icons.check_circle_outline : Icons.warning_amber_outlined),
                title: Text(entry.value),
                subtitle: Text(checks[entry.key] == true
                    ? 'Check passed (not settlement certification)'
                    : 'Requires investigation'),
              ),
            const Text('Prepaid, credit, mixed/partial allocation and complete pagination remain uncertified.'),
          ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'))],
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(
        'Order integrity audit unavailable. Verify migration, permissions and connectivity; no settlement is certified.')));
    }
  }

  Future<void> _showReceipts(Map<String, dynamic> order) async {
    final orderId = _wholeIqd(order['order_id']);
    if (orderId == null || orderId <= 0) return;
    try {
      // A stalled receipt request must not leave the employee waiting forever.
      final result = await Supabase.instance.client.rpc(
        'gs_cash_receipts_for_order',
        params: {'p_order_id': orderId},
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (result is! List || result.length > 500 ||
          result.any((entry) => entry is! Map<String, dynamic>)) {
        throw const FormatException('Unexpected cash receipts response.');
      }
      final receipts = List<Map<String, dynamic>>.from(result);
      // Duplicate receipt IDs make payment evidence ambiguous. Detect them
      // within the returned order before allowing receipt text to be copied.
      final receiptIdCounts = <String, int>{};
      for (final receipt in receipts) {
        final id = _receiptField(receipt['receipt_id']);
        // Receipt identifiers are compared case-insensitively after display
        // normalization. A differently cased copy must not be treated as
        // independent proof of payment.
        if (id != '-') {
          final key = id.toLowerCase();
          receiptIdCounts[key] = (receiptIdCounts[key] ?? 0) + 1;
        }
      }
      bool uniqueReceipt(Map<String, dynamic> receipt) {
        final id = _receiptField(receipt['receipt_id']);
        return id != '-' && receiptIdCounts[id.toLowerCase()] == 1;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Cash receipts · Order #${order['order_id']}'),
          content: SizedBox(
            width: 460,
            child: receipts.isEmpty
                ? const Text('No recorded cash receipts for this order.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: receipts.length,
                    itemBuilder: (context, index) {
                      final receipt = receipts[index];
                      final canCopy = _validReceipt(order, receipt) && uniqueReceipt(receipt);
                      return ListTile(
                        title: Text('Receipt #${_receiptField(receipt['receipt_id'])} · ${canCopy ? _iqd(receipt['amount_iqd']) : 'Invalid receipt'}'),
                        subtitle: canCopy
                            ? SelectableText(_receiptText(order, receipt))
                            : const Text('Receipt details unavailable: invalid amount, ID, date, order mismatch, or duplicate receipt ID. Do not use as payment proof.'),
                        trailing: IconButton(
                          tooltip: canCopy
                              ? 'Copy formatted cash receipt'
                              : 'Invalid receipt data — copying disabled',
                          icon: const Icon(Icons.copy_outlined),
                          onPressed: !canCopy ? null : () async {
                            await Clipboard.setData(ClipboardData(text: _receiptText(order, receipt)));
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(content: Text('Receipt copied to clipboard')),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      // A failed receipt request should be retryable for the same order,
      // without forcing the employee to return to the ledger or reselect it.
      // Clear any older error so its Retry action cannot target stale state.
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: const Text('Unable to load cash receipts. Check your connection and permissions, then retry.'),
        action: SnackBarAction(
          label: 'Retry receipts',
          onPressed: () {
            if (mounted) _showReceipts(order);
          },
        ),
      ));
    }
  }
  // Format validated whole-IQD amounts consistently with Dashboard.
  // Grouping digits avoids reading 2500000 as an unseparated number.
  String _iqd(dynamic n) {
    final amount = _wholeIqd(n);
    if (amount == null) return '—';
    final digits = amount.abs().toString();
    final grouped = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',',
    );
    return '${amount < 0 ? '-' : ''}$grouped IQD';
  }

  // UUID-based finance sources cannot be inferred from a numeric café order ID.

  // Read-only source identity. An invoice registration never proves payment.
  Future<void> _showOrderMotelUuidLinks(Map<String, dynamic> order) async {
    final id = _wholeIqd(order['order_id']);
    if (id == null || id <= 0) return;
    try {
      if (Supabase.instance.client.auth.currentUser == null) {
        throw StateError('Authentication required');
      }
      final raw = await Supabase.instance.client.rpc(
        'gs_financial_order_motel_uuid_links',
        params: {'p_order_id': id},
      ).timeout(const Duration(seconds: 15));
      if (raw is! Map) throw const FormatException('Invalid motel link report');
      final report = Map<String, dynamic>.from(raw);
      if (_wholeIqd(report['order_id']) != id ||
          report['verified_complete'] != false ||
          report['prepaid_certified_iqd'] != null ||
          report['settled_iqd'] != null ||
          report['outstanding_iqd'] != null ||
          report['credit_debit_confirmed'] != false) {
        throw const FormatException('Unexpected settlement certification or order identity');
      }
      final timestamp = report['generated_at'];
      if (timestamp is! String) throw const FormatException('Missing report timestamp');
      final generated = DateTime.tryParse(timestamp)?.toUtc();
      if (generated == null) throw const FormatException('Invalid report timestamp');
      final age = DateTime.now().toUtc().difference(generated);
      if (age.isNegative || age > const Duration(minutes: 5)) {
        throw const FormatException('Stale report');
      }
      // The server deliberately refuses to cast bigint cafe orders to UUID
      // motel food requests. Treat this as a supported blocked result, not an
      // empty invoice search and never infer that a customer owes zero.
      if (report['mapping_status'] != 'incompatible_source_identity_domains' ||
          report['identity_mapping_verified'] != false ||
          report['source_order_id_type'] != 'uuid' ||
          report['cafe_order_id_type'] != 'bigint' ||
          report['motel_source_line_count'] != null ||
          report['distinct_invoice_count'] != null ||
          report['linked_source_total_iqd'] != null ||
          report['invoice_links'] is! List ||
          (report['invoice_links'] as List).isNotEmpty) {
        throw const FormatException('Unexpected motel identity mapping response');
      }
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text('Motel source identity · order #$id'),
        content: const SizedBox(width: 460, child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MAPPING BLOCKED · Not a payment confirmation.'),
            SizedBox(height: 12),
            Text('Café orders use numeric IDs. Motel finance invoice source lines identify UUID guest-food requests.'),
            SizedBox(height: 12),
            Text('An audited, explicit identity crosswalk is required before linking these records.'),
            SizedBox(height: 12),
            Text('Invoice count, prepaid allocation, settlement and outstanding IQD remain unavailable.'),
          ],
        )),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Motel UUID links unavailable. Check deployment, permissions and source integrity.')));
    }
  }

  // UUID-native, permission-scoped trace. Journal linkage alone cannot prove a debit.

  // Read-only motel settlement gate. A journal charge or draft is never a debit receipt.

  // Preflight evidence only. Neither RPC posts a debit nor binds an order to an invoice.

  // Candidate evidence is not an authoritative crosswalk or a payment receipt.
  Future<void> _crosswalkEvidenceAction(String action) async {
    if (!mounted) return;
    final input = TextEditingController();
    final uuidPattern = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$');
    final digestPattern = RegExp(r'^[0-9a-f]{64}$');
    try {
      final guidance = action == 'status' ? 'Order ID | motel invoice UUID' :
          action == 'submit' ? 'Order ID | invoice UUID | evidence reference | SHA-256 digest | evidence description' :
          'Evidence UUID | accept or reject | independent review note';
      final supplied = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        title: Text(action == 'status' ? 'Crosswalk evidence status' :
            action == 'submit' ? 'Submit identity evidence' : 'Independently review identity evidence'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Documentary review never certifies identity, allocates prepaid funds, or posts a credit debit.'),
          const SizedBox(height: 12),
          Text(guidance),
          TextField(controller: input, maxLines: action == 'status' ? 2 : 5,
            autocorrect: false, enableSuggestions: false,
            inputFormatters: [LengthLimitingTextInputFormatter(1600)],
            decoration: const InputDecoration(labelText: 'Fields separated by |')),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, input.text.trim()),
            child: Text(action == 'status' ? 'Inspect' : 'Submit for server validation'))],
      ));
      if (supplied == null || !mounted) return;
      final parts = supplied.split('|').map((e) => e.trim()).toList();
      final expected = action == 'status' ? 2 : action == 'submit' ? 5 : 3;
      if (parts.length != expected) throw FormatException('Expected $expected separated fields');
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) throw StateError('Authentication required');
      late final String rpc;
      late final Map<String, dynamic> params;
      if (action == 'review') {
        if (!uuidPattern.hasMatch(parts[0]) || !['accept', 'reject'].contains(parts[1].toLowerCase()) ||
            parts[2].length < 20 || parts[2].length > 1000) {
          throw const FormatException('Valid evidence UUID, accept/reject decision, and 20–1000 character review note required');
        }
        rpc = 'gs_financial_review_crosswalk_evidence';
        params = {'p_evidence_id': parts[0].toLowerCase(),
          'p_accept_for_review': parts[1].toLowerCase() == 'accept', 'p_note': parts[2]};
      } else {
        if (!RegExp(r'^[1-9][0-9]{0,14}$').hasMatch(parts[0]) || !uuidPattern.hasMatch(parts[1])) {
          throw const FormatException('Valid numeric café order and motel invoice UUID required');
        }
        final order = int.parse(parts[0]);
        final invoice = parts[1].toLowerCase();
        if (action == 'status') {
          rpc = 'gs_financial_crosswalk_evidence_status';
          params = {'p_order_id': order, 'p_invoice_id': invoice};
        } else {
          if (parts[2].length < 12 || parts[2].length > 240 ||
              !digestPattern.hasMatch(parts[3]) || parts[4].length < 20 || parts[4].length > 1000) {
            throw const FormatException('Evidence reference (12–240), lowercase SHA-256 and description (20–1000) required');
          }
          rpc = 'gs_financial_submit_crosswalk_evidence';
          params = {'p_order_id': order, 'p_invoice_id': invoice,
            'p_reference': parts[2], 'p_sha256': parts[3], 'p_description': parts[4]};
        }
      }
      final raw = await client.rpc(rpc, params: params).timeout(const Duration(seconds: 20));
      String summary;
      if (action == 'submit') {
        if (!uuidPattern.hasMatch(raw?.toString() ?? '')) throw const FormatException('Invalid evidence receipt UUID');
        summary = 'Evidence submission recorded: $raw. Pending independent review. Identity and settlement remain unverified.';
      } else {
        if (raw is! Map) throw const FormatException('Invalid evidence response');
        final result = Map<String, dynamic>.from(raw);
        if (result['identity_verified'] != false || result['verified_complete'] != false ||
            (action == 'review' && result['settlement_confirmed'] != false) ||
            (action == 'status' && (result['credit_debit_confirmed'] != false ||
                result['prepaid_allocation_confirmed'] != false || result['certified_unpaid_iqd'] != null ||
                result['order_id'] != params['p_order_id'] ||
                result['invoice_id']?.toString().toLowerCase() != params['p_invoice_id']))) {
          throw const FormatException('Unexpected identity or settlement certification');
        }
        if (action == 'review' && (result['evidence_id']?.toString().toLowerCase() != params['p_evidence_id'] ||
            !['reviewed_unverified','rejected'].contains(result['review_state']))) {
          throw const FormatException('Unexpected review identity or status');
        }
        summary = 'Review state: ${result['review_state'] ?? 'no evidence'}. '
            'Evidence exists: ${result['evidence_exists'] ?? 'not reported'}. '
            'Identity verified: false. Payment confirmed: false.';
      }
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Crosswalk evidence — not certified'),
        content: SelectableText(summary),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Crosswalk evidence: $e')));
    } finally {
      input.dispose();
    }
  }

  Future<void> _inspectSettlementPreflight({required bool credit}) async {
    if (!mounted) return;
    final controller = TextEditingController();
    final uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$');
    try {
      final selected = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        title: Text(credit ? 'Credit debit preflight' : 'Café / motel identity preflight'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(credit ? 'Enter a credit verification request UUID. No debit will be made.'
              : 'Enter a numeric café order ID and a motel finance invoice UUID, separated by a comma. No identity link will be created.'),
          TextField(controller: controller, autocorrect: false, enableSuggestions: false,
            inputFormatters: [LengthLimitingTextInputFormatter(90)],
            decoration: InputDecoration(labelText: credit ? 'Verification request UUID' : 'Order ID, invoice UUID')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Inspect'))],
      ));
      if (selected == null || !mounted) return;
      int? orderId;
      String sourceId;
      if (credit) {
        sourceId = selected.toLowerCase();
      } else {
        final parts = selected.split(',').map((e) => e.trim()).toList();
        if (parts.length != 2 || !RegExp(r'^[1-9][0-9]{0,14}$').hasMatch(parts[0])) {
          throw const FormatException('Invalid order and invoice input');
        }
        orderId = int.tryParse(parts[0]);
        sourceId = parts[1].toLowerCase();
      }
      if (!uuid.hasMatch(sourceId) || (orderId != null && orderId <= 0)) {
        throw const FormatException('Invalid source UUID or order ID');
      }
      if (Supabase.instance.client.auth.currentUser == null) throw StateError('Authentication required');
      final raw = await Supabase.instance.client.rpc(
        credit ? 'gs_financial_credit_debit_preflight' : 'gs_financial_cross_domain_preflight',
        params: credit ? {'p_request_id': sourceId} : {'p_order_id': orderId, 'p_invoice_id': sourceId},
      ).timeout(const Duration(seconds: 15));
      if (raw is! Map) throw const FormatException('Invalid preflight report');
      final r = Map<String, dynamic>.from(raw);
      if (r['verified_complete'] != false || r['generated_at'] is! String ||
          r[credit ? 'request_id' : 'invoice_id']?.toString().toLowerCase() != sourceId ||
          (orderId != null && _wholeIqd(r['order_id']) != orderId)) {
        throw const FormatException('Unexpected preflight identity or certification');
      }
      final generated = DateTime.tryParse(r['generated_at'] as String)?.toUtc();
      final now = DateTime.now().toUtc();
      if (generated == null || generated.isAfter(now.add(const Duration(minutes: 2))) ||
          now.difference(generated) > const Duration(minutes: 10)) {
        throw const FormatException('Stale preflight report');
      }
      final counts = credit ? ['verified_registry_link_count','existing_charge_count','other_journal_events_on_request']
          : ['other_invoice_crosswalk_conflicts'];
      final amounts = credit ? ['request_amount_iqd','intent_amount_iqd','invoice_amount_iqd','existing_charge_amount_iqd']
          : ['order_total_iqd','invoice_total_iqd'];
      for (final key in [...counts, ...amounts]) {
        final n = _wholeIqd(r[key]);
        if (n == null || n < 0) throw FormatException('Invalid $key');
      }
      if (credit) {
        if (r['eligible_for_debit'] != false || r['authorized_debit_confirmed'] != false ||
            r['amounts_consistent'] is! bool || r['request_pending'] is! bool ||
            r['single_verified_account'] is! bool) {
          throw const FormatException('Unexpected debit authorization state');
        }
        for (final key in ['invoice_id','intent_id']) {
          if (!uuid.hasMatch(r[key]?.toString() ?? '')) throw FormatException('Invalid $key');
        }
        if (r['account_id'] != null && !uuid.hasMatch(r['account_id'].toString())) {
          throw const FormatException('Invalid account identity');
        }
      } else {
        if (r['explicit_crosswalk_exists'] != false || r['identity_verified'] != false ||
            r['prepaid_allocation_confirmed'] != false || r['credit_debit_confirmed'] != false ||
            r['certified_unpaid_iqd'] != null || r['order_is_motel'] is! bool ||
            r['source_bridge_exists'] is! bool || r['bridge_invoice_matches'] is! bool ||
            r['amounts_equal'] is! bool) {
          throw const FormatException('Unexpected identity certification');
        }
      }
      if (!mounted) return;
      final keys = credit ? [
        'request_id','invoice_id','intent_id','request_status','intent_method','request_amount_iqd',
        'intent_amount_iqd','invoice_amount_iqd','invoice_payment_status','verified_registry_link_count',
        'account_id','account_status','customer_verification_status','existing_charge_count',
        'existing_charge_amount_iqd','other_journal_events_on_request','amounts_consistent',
        'request_pending','single_verified_account'
      ] : [
        'order_id','invoice_id','order_is_motel','order_total_iqd','invoice_total_iqd',
        'source_bridge_exists','bridge_invoice_matches','other_invoice_crosswalk_conflicts','amounts_equal'
      ];
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text(credit ? 'Credit debit evidence · Read only' : 'Cross-domain identity · Read only'),
        content: SizedBox(width: 540, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NOT a payment receipt, debit approval, verified crosswalk or certified unpaid balance.'),
            for (final key in keys) ListTile(dense: true,
              title: Text(key.replaceAll('_',' ')),
              subtitle: SelectableText('${r[key] ?? 'Unavailable'}')),
            Text('${r['warning'] ?? 'Independent settlement evidence required.'}'),
          ],
        ))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(credit ? 'Credit preflight unavailable. Verify request, permissions and migration.'
            : 'Identity preflight unavailable. Verify order, invoice, permissions and migration.')));
    } finally {
      controller.dispose();
    }
  }

  Future<void> _inspectMotelSettlementGate() async {
    if (!mounted) return;
    final controller = TextEditingController();
    final uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$');
    try {
      final requested = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Motel settlement identity gate'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Enter the actual motel finance invoice UUID. This checks source identity; it does not collect or confirm payment.'),
          TextField(controller: controller, autocorrect: false, enableSuggestions: false,
            inputFormatters: [LengthLimitingTextInputFormatter(36)],
            decoration: const InputDecoration(labelText: 'Finance invoice UUID')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Inspect'))],
      ));
      if (requested == null || !mounted) return;
      if (!uuid.hasMatch(requested)) throw const FormatException('Invalid finance invoice UUID');
      if (Supabase.instance.client.auth.currentUser == null) throw StateError('Login required');
      final raw = await Supabase.instance.client.rpc(
        'gs_financial_motel_settlement_identity_gate',
        params: {'p_invoice_id': requested.toLowerCase()},
      ).timeout(const Duration(seconds: 15));
      if (raw is! Map) throw const FormatException('Invalid settlement gate response');
      final r = Map<String, dynamic>.from(raw);
      if (r['invoice_id']?.toString().toLowerCase() != requested.toLowerCase() ||
          r['verified_complete'] != false || r['certified_unpaid_iqd'] != null ||
          r['prepaid_allocation_confirmed'] != false ||
          r['credit_debit_confirmed'] != false ||
          r['numeric_order_mapping_verified'] != false ||
          r['all_sources_exhaustively_reconciled'] != false) {
        throw const FormatException('Unexpected identity or financial certification');
      }
      final generated = DateTime.tryParse(r['generated_at']?.toString() ?? '')?.toUtc();
      final now = DateTime.now().toUtc();
      if (generated == null || generated.isAfter(now.add(const Duration(minutes: 2))) ||
          now.difference(generated) > const Duration(minutes: 10)) {
        throw const FormatException('Stale settlement gate report');
      }
      final counts = ['legacy_crosswalk_count','cash_settlement_count','cash_amount_conflicts',
        'draft_intent_count','credit_draft_count','electronic_draft_count',
        'credit_verification_request_count','credit_journal_charge_count'];
      for (final key in counts) {
        final n = _wholeIqd(r[key]);
        if (n == null || n < 0) throw FormatException('Invalid $key');
      }
      final total = _wholeIqd(r['invoice_total_iqd']);
      final cash = _wholeIqd(r['cash_settlement_amount_iqd']);
      final credit = _wholeIqd(r['credit_journal_charge_amount_iqd']);
      if (total == null || total < 0 || cash == null || cash < 0 || credit == null || credit < 0 ||
          _wholeIqd(r['credit_draft_count'])! + _wholeIqd(r['electronic_draft_count'])! > _wholeIqd(r['draft_intent_count'])! ||
          (r['bridge_registered'] != true && r['bridge_registered'] != false) ||
          (r['cash_status_consistent'] != true && r['cash_status_consistent'] != false) ||
          (r['bridge_amount_matches'] != null && r['bridge_amount_matches'] != true && r['bridge_amount_matches'] != false)) {
        throw const FormatException('Inconsistent settlement source counts or amounts');
      }
      if (!mounted) return;
      final rows = <String>[
        'Invoice: ${r['invoice_id']}',
        'Invoice total: ${_iqd(total)}',
        'Payment status (recorded): ${r['invoice_payment_status'] ?? 'Unknown'}',
        'Source bridge: ${r['bridge_registered'] == true ? 'Registered' : 'Missing'}',
        'Bridge identity / amount match: ${r['bridge_amount_matches'] ?? 'Unavailable'}',
        'Cash receipts: ${r['cash_settlement_count']} · ${_iqd(cash)}',
        'Cash amount conflicts: ${r['cash_amount_conflicts']}',
        'Cash status consistent: ${r['cash_status_consistent']}',
        'Credit drafts: ${r['credit_draft_count']} · Electronic drafts: ${r['electronic_draft_count']}',
        'Credit verification requests: ${r['credit_verification_request_count']}',
        'Journal charge records: ${r['credit_journal_charge_count']} · ${_iqd(credit)}',
        'Legacy crosswalk count: ${r['legacy_crosswalk_count']}',
        'Prepaid allocation: NOT CERTIFIED',
        'Credit debit: NOT CONFIRMED',
        'Complete source coverage: NOT VERIFIED',
        'Certified outstanding: UNAVAILABLE',
      ];
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Motel settlement gate · Read only'),
        content: SizedBox(width: 540, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final line in rows) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(line)),
            const SizedBox(height: 12),
            const Text('Recorded source events are not payment confirmation. Never collect based on this report.'),
          ],
        ))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Motel settlement gate unavailable. Check identity, permissions, deployment and source consistency.')));
    } finally {
      controller.dispose();
    }
  }


  // Deliberately disabled in release builds until the full trigger chain has
  // passed live staging concurrency, rollback and permission tests.

  // Only enable after receipt-provider ingestion, SQL and Flutter staging approval.
  static const bool _prepaidAllocationStagingApproved = bool.fromEnvironment(
    'GS_ENABLE_VERIFIED_PREPAID_ALLOCATION', defaultValue: false);
  bool _prepaidAllocationBusy = false;

  Future<void> _allocateVerifiedPrepaidReceipt() async {
    if (!_prepaidAllocationStagingApproved || _prepaidAllocationBusy || !mounted) return;
    setState(() => _prepaidAllocationBusy = true);
    final controller = TextEditingController();
    final uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$');
    try {
      final receipt = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Review independently verified prepaid receipt'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Enter an existing provider-verified receipt UUID. A payment draft or screenshot is not sufficient.'),
          TextField(controller: controller, autocorrect: false, enableSuggestions: false,
            inputFormatters: [LengthLimitingTextInputFormatter(36)],
            decoration: const InputDecoration(labelText: 'Verified receipt UUID')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Review receipt'))],
      ));
      if (receipt == null || !mounted) return;
      if (!uuid.hasMatch(receipt)) throw const FormatException('Invalid receipt UUID');
      final employeeId = Supabase.instance.client.auth.currentUser?.id;
      if (employeeId == null) throw StateError('Employee login required');
      final raw = await Supabase.instance.client.rpc('gs_financial_review_verified_prepaid_receipt',
        params: {'p_receipt_id': receipt.toLowerCase()}).timeout(const Duration(seconds: 15));
      if (raw is! Map) throw const FormatException('Invalid prepaid source review');
      final review = Map<String, dynamic>.from(raw);
      final invoice = review['finance_invoice_id'];
      final amount = review['amount_iqd'];
      if (review['receipt_id']?.toString().toLowerCase() != receipt.toLowerCase() ||
          invoice is! String || !uuid.hasMatch(invoice) ||
          amount is! int || amount <= 0 ||
          review['eligible_for_allocation'] != true ||
          review['already_allocated'] is! bool ||
          review['invoice_settled'] != false || review['dashboard_certified'] != false ||
          review['unified_ledger_posted'] != false) {
        throw const FormatException('Receipt review is incomplete or inconsistent');
      }
      if (!mounted || Supabase.instance.client.auth.currentUser?.id != employeeId) {
        throw StateError('Employee session changed during receipt review');
      }
      final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Confirm prepaid invoice allocation'),
        content: Text('Invoice: $invoice\nAmount: $amount IQD\nProvider: ${review['provider']}\n'
          'This atomically records a prepaid allocation and motel-only journal; it does NOT mark the invoice paid, post the café unified ledger or certify revenue.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Allocate verified receipt'))],
      ));
      if (confirmed != true || !mounted) return;
      if (Supabase.instance.client.auth.currentUser?.id != employeeId) {
        throw StateError('Employee session changed before allocation');
      }
      final resultRaw = await Supabase.instance.client.rpc('gs_financial_allocate_and_journal_verified_prepaid',
        params: {'p_receipt_id': receipt.toLowerCase()}).timeout(const Duration(seconds: 25));
      if (resultRaw is! Map) throw const FormatException('Invalid allocation response');
      final result = Map<String, dynamic>.from(resultRaw);
      if (Supabase.instance.client.auth.currentUser?.id != employeeId ||
          result['allocation_id'] is! String || !uuid.hasMatch(result['allocation_id']) ||
          result['journal_id'] is! String || !uuid.hasMatch(result['journal_id']) ||
          result['already_posted'] is! bool ||
          result['invoice_id']?.toString().toLowerCase() != invoice.toLowerCase() ||
          result['amount_iqd'] != amount || result['already_allocated'] is! bool ||
          result['invoice_settled'] != false || result['dashboard_certified'] != false ||
          result['unified_ledger_posted'] != false) {
        throw const FormatException('Allocation result not trusted; reconcile server records');
      }
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text(result['already_allocated'] == true ? 'Allocation already recorded' : 'Prepaid allocation recorded'),
        content: Text('Invoice: $invoice\nAmount: $amount IQD\nAllocation: ${result['allocation_id']}\n'
          'Motel journal: ${result['journal_id']}\nInvoice paid-state, unified ledger and Dashboard totals remain unverified.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Prepaid allocation not confirmed. Check staging, receipt evidence, permissions and reconciliation.')));
    } finally {
      controller.dispose();
      if (mounted) setState(() => _prepaidAllocationBusy = false);
    }
  }

  static const bool _creditPostingStagingApproved = bool.fromEnvironment(
    'GS_ENABLE_VERIFIED_CREDIT_POSTING', defaultValue: false);
  bool _creditPostingBusy = false;

  Future<void> _postVerifiedCreditRequest() async {
    if (!_creditPostingStagingApproved || _creditPostingBusy || !mounted) return;
    setState(() => _creditPostingBusy = true);
    final controller = TextEditingController();
    final uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$');
    try {
      final request = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Charge verified motel credit request'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('This debits a real credit account. It does NOT settle the invoice or certify Dashboard revenue. Enter the verified request UUID, not an invoice UUID.'),
          TextField(controller: controller, autocorrect: false, enableSuggestions: false,
            inputFormatters: [LengthLimitingTextInputFormatter(36)],
            decoration: const InputDecoration(labelText: 'Credit verification request UUID')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Review request'))],
      ));
      if (request == null || !mounted) return;
      if (!uuid.hasMatch(request)) throw const FormatException('Invalid request UUID');
      final postingEmployeeId = Supabase.instance.client.auth.currentUser?.id;
      if (postingEmployeeId == null) throw StateError('Login required');
      // Server-side invoice and amount review before the irreversible account charge.
      // This is a PREVIEW, not authorization to post or a guarantee of settlement.
      final reviewRaw = await Supabase.instance.client.rpc(
        'gs_financial_review_credit_charge_source',
        params: {'p_request_id': request.toLowerCase()},
      ).timeout(const Duration(seconds: 15));
      if (reviewRaw is! Map) throw const FormatException('Malformed credit source review');
      final review = Map<String, dynamic>.from(reviewRaw);
      final reviewAmount = review['amount_iqd'];
      final reviewInvoice = review['finance_invoice_id'];
      if (review['request_id']?.toString().toLowerCase() != request.toLowerCase() ||
          review['eligible_for_charge'] != true || review['invoice_settled'] != false ||
          review['dashboard_certified'] != false ||
          reviewAmount is! int || reviewAmount <= 0 ||
          reviewInvoice is! String || !uuid.hasMatch(reviewInvoice)) {
        throw const FormatException('Credit request not eligible for charge');
      }
      if (!mounted || Supabase.instance.client.auth.currentUser?.id != postingEmployeeId) {
        throw StateError('Employee session changed during credit source review');
      }
      final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Confirm real credit-account debit'),
        content: Text('Invoice: $reviewInvoice\nAmount: $reviewAmount IQD\nRequest: $request\nThis will charge the credit account. It does NOT settle the invoice or certify Dashboard revenue.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Post verified charge'))],
      ));
      if (confirmed != true || !mounted) return;
      if (Supabase.instance.client.auth.currentUser?.id != postingEmployeeId) {
        throw StateError('Employee session changed before posting');
      }
      // Deterministic idempotency key survives retry/reopen/device changes.
      final canonicalRequest = request.toLowerCase();
      final raw = await Supabase.instance.client.rpc('gs_financial_post_verified_credit_charge',
        params: {'p_request_id': canonicalRequest,
          'p_idempotency_key': 'motel-credit-request:$canonicalRequest'})
        .timeout(const Duration(seconds: 25));
      if (raw is! Map) throw const FormatException('Malformed posting result');
      final result = Map<String, dynamic>.from(raw);
      // Validate the complete RPC response before reporting any charge as recorded.
      // The amount is an account debit, NOT a paid invoice or certified revenue.
      final journalId = result['journal_id'];
      final accountId = result['account_id'];
      final amount = result['amount_iqd'];
      final alreadyPosted = result['already_posted'];
      final activeEmployee = Supabase.instance.client.auth.currentUser?.id;
      if (activeEmployee == null || activeEmployee != postingEmployeeId ||
          journalId is! String || !uuid.hasMatch(journalId) ||
          accountId is! String || !uuid.hasMatch(accountId) ||
          amount is! int || amount <= 0 ||
          alreadyPosted is! bool || result['charge_recorded'] != true ||
          result['invoice_settled'] != false ||
          result['prepaid_allocated'] != false ||
          result['dashboard_certified'] != false) {
        throw const FormatException('Untrusted credit posting response or changed employee session');
      }
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text(alreadyPosted ? 'Credit charge already recorded' : 'Credit charge recorded'),
        content: Text('Journal: ${result['journal_id']}\nAccount charge recorded; invoice settlement and prepaid allocation remain unverified.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
      if (mounted) setState(() => _rows = _load());
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Credit charge not confirmed. Check permissions, staging deployment, source records and journal before retrying.')));
    } finally {
      controller.dispose();
      if (mounted) setState(() => _creditPostingBusy = false);
    }
  }

  Future<void> _inspectCreditInvoiceTrace() async {
    if (!mounted) return;
    final controller = TextEditingController();
    final uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$');
    try {
      final value = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Trace credit journal by motel invoice'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Enter the actual motel finance invoice UUID. Read-only evidence, not confirmed payment.'),
          TextField(controller: controller, autocorrect: false, enableSuggestions: false,
            inputFormatters: [LengthLimitingTextInputFormatter(36)],
            decoration: const InputDecoration(labelText: 'Finance invoice UUID')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Inspect'))],
      ));
      if (value == null || !mounted) return;
      if (!uuid.hasMatch(value)) throw const FormatException('Invalid invoice UUID');
      if (Supabase.instance.client.auth.currentUser == null) throw StateError('Login required');
      final raw = await Supabase.instance.client.rpc(
        'gs_financial_credit_journal_invoice_trace',
        params: {'p_invoice_id': value.toLowerCase()},
      ).timeout(const Duration(seconds: 15));
      if (raw is! Map) throw const FormatException('Malformed credit trace');
      final report = Map<String, dynamic>.from(raw);
      if (report['invoice_id']?.toString().toLowerCase() != value.toLowerCase() ||
          report['verified_complete'] != false ||
          report['credit_debit_authoritatively_confirmed'] != false ||
          report['prepaid_certified_iqd'] != null ||
          report['settled_iqd'] != null || report['outstanding_iqd'] != null) {
        throw const FormatException('Untrusted credit trace identity or certification');
      }
      final timestamp = report['generated_at'];
      if (timestamp is! String) throw const FormatException('Missing report timestamp');
      final generated = DateTime.tryParse(timestamp)?.toUtc();
      if (generated == null) throw const FormatException('Invalid report timestamp');
      final age = DateTime.now().toUtc().difference(generated);
      if (age.isNegative || age > const Duration(minutes: 5)) throw const FormatException('Stale report');
      const counts = ['credit_intent_count','verification_request_count',
        'linked_charge_count','mismatched_charge_count',
        'unverified_account_link_count','duplicate_idempotency_count'];
      for (final key in counts) {
        final n = _wholeIqd(report[key]);
        if (n == null || n < 0) throw const FormatException('Invalid trace count');
      }
      final total = _wholeIqd(report['linked_charge_delta_iqd']);
      if (total == null) throw const FormatException('Invalid journal movement');
      final events = report['events_preview'];
      if (events is! List || events.length > 100 ||
          report['events_preview_limit'] != 100 ||
          report['events_preview_exhaustive'] is! bool) {
        throw const FormatException('Invalid or incomplete trace preview');
      }
      final ids = <String>{};
      for (final entry in events) {
        if (entry is! Map) throw const FormatException('Invalid journal event');
        final e = Map<String, dynamic>.from(entry);
        final eventId = e['journal_id']?.toString() ?? '';
        if (!uuid.hasMatch(eventId) || !ids.add(eventId.toLowerCase()) ||
            !uuid.hasMatch(e['request_id']?.toString() ?? '') ||
            !uuid.hasMatch(e['account_id']?.toString() ?? '') ||
            _wholeIqd(e['delta_outstanding_iqd']) == null ||
            _wholeIqd(e['outstanding_after_iqd']) == null ||
            DateTime.tryParse(e['created_at']?.toString() ?? '') == null) {
          throw const FormatException('Invalid journal event identity or amounts');
        }
      }
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Credit journal invoice trace · Read only'),
        content: SizedBox(width: 540, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NOT a confirmed debit, prepaid allocation or certified balance.'),
            SelectableText('Invoice UUID: $value'),
            for (final key in counts) ListTile(dense: true,
              title: Text(key.replaceAll('_',' ')), trailing: Text('${report[key]}')),
            ListTile(dense: true, title: const Text('Linked journal movement'), trailing: Text(_iqd(total))),
            Text(report['events_preview_exhaustive'] == true
              ? 'Journal preview complete for this invoice.'
              : 'Journal preview capped at 100 events; not exhaustive.'),
            for (final rawEvent in events) ListTile(dense: true,
              title: SelectableText('${(rawEvent as Map)['journal_id']}'),
              subtitle: Text('Kind: ${rawEvent['event_kind']} · ${_iqd(rawEvent['delta_outstanding_iqd'])}')),
          ],
        ))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Credit trace unavailable. Verify invoice UUID, permissions, migration and source records.')));
    } finally {
      controller.dispose();
    }
  }

  // Employees must select a real source UUID; the backend enforces both permissions.
  Future<void> _inspectUuidFinancialSource({required bool motel}) async {
    if (!mounted) return;
    final controller = TextEditingController();
    final uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$');
    try {
      final value = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text(motel ? 'Inspect motel finance invoice' : 'Inspect credit account journal'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Read-only. Enter the authoritative UUID from the finance source; a café order number is not interchangeable.'),
          const SizedBox(height: 12),
          TextField(controller: controller, autocorrect: false, enableSuggestions: false,
            inputFormatters: [LengthLimitingTextInputFormatter(36)],
            decoration: InputDecoration(labelText: motel ? 'Finance invoice UUID' : 'Credit account UUID')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Inspect'))],
      ));
      if (value == null || !mounted) return;
      if (!uuid.hasMatch(value)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid source UUID. No records were requested.')));
        return;
      }
      final raw = await Supabase.instance.client.rpc(
        motel ? 'gs_financial_motel_invoice_integrity' : 'gs_financial_credit_journal_integrity',
        params: {motel ? 'p_invoice_id' : 'p_account_id': value.toLowerCase()},
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (raw is! Map) throw const FormatException('Malformed source report');
      final report = Map<String, dynamic>.from(raw);
      if (report[motel ? 'invoice_id' : 'account_id']?.toString().toLowerCase() != value.toLowerCase() ||
          report['verified_complete'] != false ||
          report['generated_at'] is! String ||
          DateTime.tryParse(report['generated_at'] as String) == null) {
        throw const FormatException('Untrusted source report');
      }
      final at = DateTime.parse(report['generated_at'] as String).toUtc();
      final age = DateTime.now().toUtc().difference(at);
      if (age.isNegative || age > const Duration(minutes: 5)) throw const FormatException('Stale source report');
      final amounts = motel
        ? ['invoice_total_iqd', 'line_total_iqd']
        : ['journal_delta_iqd', 'recorded_outstanding_iqd'];
      final counts = motel
        ? ['line_count', 'expected_line_count', 'negative_line_count', 'mismatched_register_line_count',
           'duplicate_source_order_count', 'missing_register_line_count', 'draft_payment_intent_count']
        : ['journal_entry_count', 'invalid_direction_count', 'unlinked_charge_count', 'duplicate_idempotency_count'];
      for (final key in [...amounts, ...counts]) {
        if (_wholeIqd(report[key]) == null || (counts.contains(key) && _wholeIqd(report[key])! < 0)) {
          throw const FormatException('Invalid financial field');
        }
      }
      if (!motel && report['last_journal_outstanding_iqd'] != null &&
          _wholeIqd(report['last_journal_outstanding_iqd']) == null) {
        throw const FormatException('Invalid last journal balance');
      }
      if (motel && (report['prepaid_certified_iqd'] != null || report['settled_iqd'] != null ||
          report['outstanding_iqd'] != null)) throw const FormatException('Unexpected settlement certification');
      if (!motel && report['credit_debit_authoritatively_confirmed'] != false) {
        throw const FormatException('Unexpected credit confirmation');
      }
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text(motel ? 'Motel invoice source integrity' : 'Credit journal source integrity'),
        content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('NOT a payment confirmation or certified outstanding balance.'),
            Text('Source UUID: $value'),
            for (final key in amounts) ListTile(dense: true,
              title: Text(key.replaceAll('_', ' ')), trailing: Text(_iqd(report[key]))),
            for (final key in counts) ListTile(dense: true,
              title: Text(key.replaceAll('_', ' ')), trailing: Text('${report[key]}')),
            if (motel) Text('Source status: ${report['invoice_source_status']}')
            else Text('Journal matches recorded balance: ${report['journal_matches_recorded_balance'] == true ? 'Yes' : 'No'}'),
            const Text('Prepaid allocation and credit debit remain unverified. No collection action is enabled.'),
          ],
        ))),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Source integrity unavailable. Verify UUID, permission, migration and connection.')));
    } finally {
      controller.dispose();
    }
  }


  // Read-only, source-UUID-specific readiness check. Never infers a cafe order ID.
  bool _settlementReadinessBusy = false;
  Future<void> _inspectMotelSettlementReadiness() async {
    if (_settlementReadinessBusy || !mounted) return;
    setState(() => _settlementReadinessBusy = true);
    final controller = TextEditingController();
    final uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$');
    try {
      final invoiceId = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Check motel invoice settlement readiness'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Enter the authoritative motel finance invoice UUID. This check is read-only and does not post a payment.'),
          TextField(controller: controller, autocorrect: false, enableSuggestions: false,
            inputFormatters: [LengthLimitingTextInputFormatter(36)],
            decoration: const InputDecoration(labelText: 'Motel finance invoice UUID')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Check'))],
      ));
      if (invoiceId == null || !mounted) return;
      if (!uuid.hasMatch(invoiceId)) throw const FormatException('Invalid invoice UUID');
      final employeeId = Supabase.instance.client.auth.currentUser?.id;
      if (employeeId == null) throw StateError('Employee login required');
      final raw = await Supabase.instance.client.rpc(
        'gs_financial_motel_invoice_settlement_readiness',
        params: {'p_invoice_id': invoiceId.toLowerCase()},
      ).timeout(const Duration(seconds: 15));
      if (!mounted || Supabase.instance.client.auth.currentUser?.id != employeeId) {
        throw StateError('Employee session changed');
      }
      if (raw is! Map) throw const FormatException('Malformed settlement readiness report');
      final report = Map<String, dynamic>.from(raw);
      final reason = report['block_reason'];
      if (report['finance_invoice_id']?.toString().toLowerCase() != invoiceId.toLowerCase() ||
          report['settlement_ready'] != false || report['invoice_settled'] != false ||
          report['unified_ledger_posted'] != false || report['dashboard_certified'] != false ||
          reason is! String || reason.isEmpty ||
          report['cash_evidence_count'] is! int || report['cash_evidence_count'] < 0 ||
          report['credit_evidence_count'] is! int || report['credit_evidence_count'] < 0 ||
          report['prepaid_evidence_count'] is! int || report['prepaid_evidence_count'] < 0 ||
          report['payment_method_conflict'] is! bool ||
          report['source_integrity_matched'] is! bool) {
        throw const FormatException('Untrusted settlement readiness report');
      }
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Invoice settlement is not yet verified'),
        content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText('Invoice UUID: $invoiceId'),
            Text('Blocked: ${reason.replaceAll('_', ' ')}'),
            Text('Invoice source matched: ${report['source_integrity_matched']}'),
            Text('Payment-method conflict: ${report['payment_method_conflict']}'),
            Text('Cash evidence records: ${report['cash_evidence_count']}'),
            Text('Credit evidence records: ${report['credit_evidence_count']}'),
            Text('Prepaid evidence records: ${report['prepaid_evidence_count']}'),
            const SizedBox(height: 12),
            const Text('No invoice-paid status, unified ledger entry or Dashboard IQD total is certified by this report.'),
          ],
        ))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Settlement readiness unavailable. Check invoice UUID, permissions, migrations and connection.')));
    } finally {
      controller.dispose();
      if (mounted) setState(() => _settlementReadinessBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    ListTile(
      leading: const Icon(Icons.account_balance_wallet_outlined),
      title: const Text('Cash ledger reconciliation'),
      subtitle: const Text('Up to 200 orders from the reconciliation ledger; not a date-filtered Dashboard total or a complete multi-method settlement statement.'),
      trailing: IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh),
        onPressed: _refreshFinancialSources,
      ),
    ),
    Padding(padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Payment cards', style: TextStyle(fontWeight: FontWeight.bold)),
      Row(children: [
        Expanded(child: Card(child: InkWell(
          onTap: () => setState(() { _activePaymentCard = 'standing'; _cardSearch = ''; _cardStatus = 'all'; _standingEligibleOnly = false; _cardSearchController.clear(); _minimumSourceIqd = null; _maximumSourceIqd = null; _minimumSourceController.clear(); _maximumSourceController.clear(); }),
          child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
            const Icon(Icons.account_balance_wallet_outlined),
            const Text('Standing Cash'),
            if (_activePaymentCard == 'standing') const Text('Selected'),
          ]))))),
        Expanded(child: Card(child: InkWell(
          onTap: () => setState(() { _activePaymentCard = 'pending'; _cardSearch = ''; _cardStatus = 'all'; _standingEligibleOnly = false; _cardSearchController.clear(); _minimumSourceIqd = null; _maximumSourceIqd = null; _minimumSourceController.clear(); _maximumSourceController.clear(); }),
          child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
            const Icon(Icons.pending_actions_outlined),
            const Text('Pending Payment'),
            if (_activePaymentCard == 'pending') const Text('Selected'),
          ]))))),
      ]),
      const Text('Tap a card to show its own list below without leaving Payments Management.'),
    ])),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Align(
      alignment: Alignment.centerLeft, child: OutlinedButton.icon(
        onPressed: _settlementReadinessBusy ? null : _inspectMotelSettlementReadiness,
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('Inspect motel invoice settlement readiness (read-only)'),
      ))),
    if (_activePaymentCard == 'standing') _standingCashCollectionPanel()
    else _pendingPaymentPanel(),
    _liveBalancesPanel(),
    const ExpansionTile(
      leading: Icon(Icons.pending_actions_outlined),
      title: Text('Standing Cash vs Pending Payment · definitions'),
      subtitle: Text('Active café guests versus unpaid online/motel orders'),
      children: [
        Padding(padding: EdgeInsets.all(12), child: Text(
          'Standing Cash: live unpaid order balances for occupied café visits '
          'whose customers are still present. Subtract confirmed partial '
          'payments, and exclude fully paid, cancelled or departed visits. '
          'A historical range requires a recorded balance snapshot.\n\n'
          'Pending Payment: unpaid online and motel food orders, net of '
          'confirmed payments and prepaid meal-package coverage. Exclude '
          'cancelled/settled orders and avoid counting the same order as '
          'Standing Cash.\n\n'
          'Both require authorized server-side reporting, reliable order '
          'source and visit state, payment allocation, refund handling, '
          'deduplication, and tenant/employee permissions. They are not '
          'derived from this limited cash ledger.')),
      ],
    ),
    // These financial workflows require their own authorized server reports.
    // This existing cash-only RPC cannot safely calculate them.
    ExpansionTile(
      leading: const Icon(Icons.dashboard_outlined),
      title: const Text('Financial Overview & Payments · 12 additional cards'),
      subtitle: const Text('Reporting coverage and backend requirements'),
      children: const [
        Padding(padding: EdgeInsets.all(12), child: Text(
          'Total Payments Received · Total Expenses · Net Profit · '
          'Pending Payment Confirmations · Refunds & Returns · '
          'Cashier Balances · Cash Handover · Customer Credit Balances · '
          'Discounts & Complimentary Orders · Payments by Method · '
          'Cancelled & Voided Transactions · Daily Cash Closing.\n\n'
          'Values require permission-scoped Supabase financial reports, '
          'transaction-level drilldowns, validated date/time ranges and '
          'authorized employee filters. The cash-only reconciliation sample '
          'below is not a substitute for these reports.')),
      ],
    ),
    Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _rows,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Unable to load cash reconciliation. Check your connection and permissions, then retry.'),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _rows = _load()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry cash ledger'),
                ),
              ]),
            ));
          }
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!;
        final warningCount = rows.where(_hasLedgerWarning).length;
        final visible = rows.where((row) =>
            (_paymentFilter == 'all' || _cashStatus(row) == _paymentFilter) &&
            (!_showLedgerWarningsOnly || _hasLedgerWarning(row))).toList();
        // An invalid amount makes the sample sum unavailable, not zero.
        int? cash = 0;
        for (final row in visible) {
          final amount = _wholeIqd(row['cash_paid_iqd']);
          // Negative cash payments are not valid collections. Do not
          // publish a misleading sample total if the ledger is malformed.
          if (amount == null || amount < 0 || cash == null ||
              (cash + amount).abs() > 9007199254740991) {
            cash = null;
            break;
          }
          cash += amount;
        }
        return Column(children: [
          Padding(padding: const EdgeInsets.all(12), child: Wrap(spacing: 12, children: [
            Chip(label: Text('Orders matching filters: ${visible.length}')),
            Chip(label: Text('Ledger data warnings: $warningCount')),
            const Chip(avatar: Icon(Icons.info_outline, size: 16),
              label: Text('Cash-only sample · max 200 orders')),
            const Tooltip(
              message: 'The current authorized cash-ledger response does not expose a verified employee, date, or cash/credit subtype per row. Those filters must not be fabricated.',
              child: Chip(label: Text('Date / employee / subtype: not in cash sample')),
            ),
            FilterChip(
              label: const Text('Show ledger warnings only'),
              selected: _showLedgerWarningsOnly,
              onSelected: (selected) => setState(() => _showLedgerWarningsOnly = selected),
            ),
            DropdownButton<String>(
              value: _paymentFilter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All cash statuses')),
                DropdownMenuItem(value: 'Unpaid', child: Text('Unpaid')),
                DropdownMenuItem(value: 'Partially paid', child: Text('Partially paid')),
                DropdownMenuItem(value: 'Paid in cash', child: Text('Paid in cash')),
                DropdownMenuItem(value: 'No total', child: Text('No total')),
                DropdownMenuItem(value: 'Amount unavailable', child: Text('Amount unavailable')),
              ],
              onChanged: (value) { if (value != null) setState(() => _paymentFilter = value); },
            ),
          ])),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Align(
            alignment: Alignment.centerLeft, child: OutlinedButton.icon(
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Browse authorized order integrity pages'),
              onPressed: () => showDialog<void>(context: context,
                builder: (_) => const _IntegrityPageDialog()),
            ),
          )),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Wrap(spacing: 8, children: [
            OutlinedButton.icon(icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Inspect motel invoice UUID'),
              onPressed: () => _inspectUuidFinancialSource(motel: true)),
            OutlinedButton.icon(icon: const Icon(Icons.account_balance_outlined),
              label: const Text('Inspect credit account UUID'),
              onPressed: () => _inspectUuidFinancialSource(motel: false)),
            OutlinedButton.icon(icon: const Icon(Icons.account_tree_outlined),
              label: const Text('Trace invoice credit journal'),
              onPressed: _inspectCreditInvoiceTrace),
            if (_prepaidAllocationStagingApproved) OutlinedButton.icon(
              icon: const Icon(Icons.verified_outlined),
              label: Text(_prepaidAllocationBusy ? 'Allocating prepaid…' : 'Allocate verified prepaid receipt'),
              onPressed: _prepaidAllocationBusy ? null : _allocateVerifiedPrepaidReceipt),
            if (_creditPostingStagingApproved) OutlinedButton.icon(
              icon: const Icon(Icons.credit_score_outlined),
              label: Text(_creditPostingBusy ? 'Posting credit charge…' : 'Post verified credit request'),
              onPressed: _creditPostingBusy ? null : _postVerifiedCreditRequest),
            OutlinedButton.icon(icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Inspect motel settlement gate'),
              onPressed: _inspectMotelSettlementGate),
            OutlinedButton.icon(icon: const Icon(Icons.link_outlined),
              label: const Text('Preflight café / motel identity'),
              onPressed: () => _inspectSettlementPreflight(credit: false)),

          OutlinedButton(onPressed: () => _crosswalkEvidenceAction('status'),
              child: const Text('Crosswalk evidence status')),
          OutlinedButton(onPressed: () => _crosswalkEvidenceAction('submit'),
              child: const Text('Submit crosswalk evidence')),
          OutlinedButton(onPressed: () => _crosswalkEvidenceAction('review'),
              child: const Text('Review crosswalk evidence')),
            OutlinedButton.icon(icon: const Icon(Icons.security_outlined),
              label: const Text('Preflight credit debit'),
              onPressed: () => _inspectSettlementPreflight(credit: true)),
          ])),
          Expanded(child: visible.isEmpty ? const Center(child: Text('No orders match the selected cash status')) :
            ListView.builder(itemCount: visible.length, itemBuilder: (context, index) {
              final r = visible[index];
              return Card(child: ListTile(
                // Reuse the existing server-scoped, read-only receipt workflow.
                // Invalid order IDs cannot open transaction details.
                enabled: _wholeIqd(r['order_id']) != null &&
                    _wholeIqd(r['order_id'])! > 0,
                onTap: () => _showReceipts(r),
                title: Text('Order #${_receiptField(r['order_id'])} · ${_receiptField(r['order_status'])} · ${_cashStatus(r)}'),
                subtitle: Text('${_hasLedgerWarning(r) ? 'Ledger data warning · verify record\n' : ''}'
                  'Order total: ${_iqd(r['order_total_iqd'])}\n'
                  'Cash recorded: ${_iqd(r['cash_paid_iqd'])}\n'
                  'Balance after cash only: ${_iqd(r['balance_iqd'])}\n'
                  'Cash entries: ${_validEntryCount(r['cash_payment_count'])}'),
                // A single menu replaces five horizontal IconButtons, which
                // overflowed narrow iPhone screens. Every action calls the
                // same existing permission-scoped inspection workflow.
                trailing: PopupMenuButton<String>(
                  tooltip: 'Inspect payment sources and receipts',
                  icon: const Icon(Icons.more_vert),
                  enabled: _wholeIqd(r['order_id']) != null &&
                      _wholeIqd(r['order_id'])! > 0,
                  onSelected: (action) {
                    switch (action) {
                      case 'motel_uuid_links': _showOrderMotelUuidLinks(r); break;
                      case 'source_reconciliation': _showSourceReconciliation(r); break;
                      case 'method_allocation': _showMethodAllocation(r); break;
                      case 'integrity_audit': _showOrderIntegrityAudit(r); break;
                       case 'all_methods': _showAllMethodCoverage(r); break;
                      case 'amount_motel': _showAmountMotelSafety(r); break;
                      case 'source_identity': _showSourceIdentity(r); break;
                      case 'settlement': _showSettlementPreview(r); break;
                      case 'receipts': _showReceipts(r); break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'motel_uuid_links', child: ListTile(
                      dense: true, leading: Icon(Icons.link_outlined),
                      title: Text('Order to motel invoice UUIDs'))),
                    PopupMenuItem(value: 'source_reconciliation', child: ListTile(
                      dense: true, leading: Icon(Icons.rule_outlined),
                      title: Text('Settlement source reconciliation'))),
                    PopupMenuItem(value: 'method_allocation', child: ListTile(
                      dense: true, leading: Icon(Icons.account_balance_wallet_outlined),
                      title: Text('Payment-method ledger allocation'))),
                    PopupMenuItem(value: 'integrity_audit', child: ListTile(
                       dense: true, leading: Icon(Icons.fact_check_outlined),
                       title: Text('12-check order integrity audit'))),
                     PopupMenuItem(value: 'all_methods', child: ListTile(
                      dense: true, leading: Icon(Icons.account_tree_outlined),
                      title: Text('All-method source coverage'))),
                    PopupMenuItem(value: 'amount_motel', child: ListTile(
                      dense: true, leading: Icon(Icons.fact_check_outlined),
                      title: Text('Amount & motel safety'))),
                    PopupMenuItem(value: 'source_identity', child: ListTile(
                      dense: true, leading: Icon(Icons.link_outlined),
                      title: Text('External source identity'))),
                    PopupMenuItem(value: 'settlement', child: ListTile(
                      dense: true, leading: Icon(Icons.rule_outlined),
                      title: Text('Settlement bindings'))),
                    PopupMenuItem(value: 'receipts', child: ListTile(
                      dense: true, leading: Icon(Icons.receipt_long_outlined),
                      title: Text('Cash receipts'))),
                  ],
                ),
                isThreeLine: true,
              ));
            })),
          // Reconcile only the filtered sample; show its total BELOW all rows.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              const Expanded(child: Text('Total recorded cash in filtered list',
                  style: TextStyle(fontWeight: FontWeight.bold))),
              Text(_iqd(cash), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('  (${visible.length} orders)'),
            ]),
          ),
        ]);
      },
    )),
  ]);
}


/// Diagnostic-only cursor paging. Never certifies or posts a payment.
class _IntegrityPageDialog extends StatefulWidget {
  const _IntegrityPageDialog();
  @override
  State<_IntegrityPageDialog> createState() => _IntegrityPageDialogState();
}

class _IntegrityPageDialogState extends State<_IntegrityPageDialog> {
  String source = 'all';
  String orderSearch = '';
  bool failedOnly = false;
  bool showPassedChecks = false;
  int? expandedOrderId;
  int cursor = 0;
  final List<int> history = [];
  bool loading = false;
  String? error;
  Map<String, dynamic>? page;
  int requestSerial = 0;
  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final serial = ++requestSerial;
    setState(() { loading = true; error = null; page = null; expandedOrderId = null; });
    try {
      if (Supabase.instance.client.auth.currentUser == null) {
        throw StateError('Employee login required');
      }
      final raw = await Supabase.instance.client.rpc('gs_financial_order_integrity_page',
        params: {'p_after_order_id': cursor, 'p_page_size': 20, 'p_source': source},
      ).timeout(const Duration(seconds: 20));
      if (!mounted || serial != requestSerial) return;
      if (raw is! Map) throw const FormatException('Invalid audit page');
      final data = Map<String, dynamic>.from(raw);
      final audits = data['audits'];
      final count = data['returned_count'];
      final next = data['next_after_order_id'];
      if (data['source'] != source || data['after_order_id'] != cursor ||
          data['page_size'] != 20 || data['verified_complete'] != false ||
          data['settlement_confirmed'] != false || data['totals_available'] != false ||
          audits is! List || count is! int || count < 0 || count > 20 ||
          audits.length != count || data['has_more'] is! bool ||
          data['uncertified_orders'] != count ||
          data['orders_with_failed_checks'] is! int ||
          data['orders_with_failed_checks'] < 0 ||
          data['orders_with_failed_checks'] > count ||
          (count == 0 ? next != null : next is! int || next <= cursor) ||
          (data['has_more'] == true && count != 20)) {
        throw const FormatException('Untrusted audit pagination response');
      }
      var previous = cursor;
      for (final rawAudit in audits) {
        if (rawAudit is! Map) throw const FormatException('Invalid order audit');
        final audit = Map<String, dynamic>.from(rawAudit);
        final id = audit['order_id'];
        final checks = audit['checks'];
        if (id is! int || id <= previous ||
            audit['verified_complete'] != false ||
            audit['settlement_confirmed'] != false ||
            checks is! Map || checks.length != 12 ||
            checks.keys.any((key) => key is! String || key.isEmpty) ||
            checks.values.any((value) => value is! bool)) {
          throw const FormatException('Untrusted per-order audit');
        }
        previous = id;
      }
      if (count > 0 && previous != next) {
        throw const FormatException('Cursor does not match last order');
      }
      setState(() { page = data; loading = false; });
    } catch (_) {
      if (!mounted || serial != requestSerial) return;
      setState(() { loading = false; error = 'Audit page unavailable. Check migration, employee permissions and connection.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = page;
    final audits = data?['audits'] is List ? data!['audits'] as List : const [];
    // These filters apply to the currently loaded authorized page only.
    // They must never be described as server-wide search or completeness.
    final visibleAudits = audits.where((entry) {
      if (entry is! Map) return false;
      final id = entry['order_id'];
      final checks = entry['checks'];
      if (id is! int || checks is! Map) return false;
      if (orderSearch.trim().isNotEmpty &&
          !id.toString().contains(orderSearch.trim())) return false;
      if (failedOnly && !checks.values.any((value) => value == false)) return false;
      return true;
    }).toList(growable: false);
    return AlertDialog(
      title: const Text('Order integrity pages · Read only'),
      content: SizedBox(width: 530, height: 450, child: Column(children: [
        const Text('Diagnostic audit only. No amount is certified and no payment can be collected here.'),
        DropdownButton<String>(value: source,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All orders')),
            DropdownMenuItem(value: 'table', child: Text('Table orders')),
            DropdownMenuItem(value: 'motel', child: Text('Motel orders')),
          ],
          onChanged: loading ? null : (value) {
            if (value == null || value == source) return;
            setState(() { source = value; cursor = 0; history.clear(); orderSearch = ''; expandedOrderId = null; });
            _load();
          }),
        if (loading) const LinearProgressIndicator(),
        if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (data != null) Text('Orders on page: ${data['returned_count']} · Failed checks: ${data['orders_with_failed_checks']} · Uncertified: ${data['uncertified_orders']}'),
        TextField(
          decoration: const InputDecoration(labelText: 'Find order ID on this page',
            prefixIcon: Icon(Icons.search), isDense: true),
          keyboardType: TextInputType.number,
          onChanged: (value) => setState(() => orderSearch = value),
        ),
        Wrap(spacing: 8, runSpacing: 0, children: [
          FilterChip(label: const Text('Failed checks only'), selected: failedOnly,
            onSelected: (value) => setState(() => failedOnly = value)),
          FilterChip(label: const Text('Show passed checks'), selected: showPassedChecks,
            onSelected: (value) => setState(() => showPassedChecks = value)),
          TextButton(onPressed: () => setState(() {
            orderSearch = ''; failedOnly = false; showPassedChecks = false;
          }), child: const Text('Clear filters')),
        ]),
        Text('Showing ${visibleAudits.length} of ${audits.length} orders on this page'),
        Expanded(child: visibleAudits.isEmpty
          ? const Center(child: Text('No matching orders on this loaded page'))
          : ListView.builder(itemCount: visibleAudits.length, itemBuilder: (context, index) {
          final a = Map<String, dynamic>.from(visibleAudits[index] as Map);
          final checks = Map<String, dynamic>.from(a['checks'] as Map);
          final passed = checks.values.where((v) => v == true).length;
          final id = a['order_id'] as int;
          final expanded = expandedOrderId == id;
          return Card(child: Column(children: [
            ListTile(dense: true, title: Text('Order #$id'),
              subtitle: Text('$passed/12 integrity checks passed · Settlement unverified'),
              trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              onTap: () => setState(() => expandedOrderId = expanded ? null : id)),
            if (expanded) Padding(padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Read-only checks; a pass does not certify payment.'),
                ...checks.entries.where((e) => showPassedChecks || e.value == false).map((e) =>
                  Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
                    Icon(e.value == true ? Icons.check_circle_outline : Icons.error_outline,
                      size: 16, color: e.value == true ? null : Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.key.replaceAll('_', ' '),
                      style: Theme.of(context).textTheme.bodySmall)),
                  ]))),
              ])),
          ]));
        })),
        Row(children: [
          TextButton(onPressed: loading || history.isEmpty ? null : () {
            setState(() { cursor = history.removeLast(); orderSearch = ''; }); _load();
          }, child: const Text('Previous')),
          const Spacer(),
          TextButton(onPressed: loading || data == null || data['has_more'] != true ? null : () {
            final next = data['next_after_order_id'];
            if (next is! int || next <= cursor) return;
            setState(() { history.add(cursor); cursor = next; orderSearch = ''; }); _load();
          }, child: const Text('Next page')),
          IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'Retry audit page'),
        ]),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}
