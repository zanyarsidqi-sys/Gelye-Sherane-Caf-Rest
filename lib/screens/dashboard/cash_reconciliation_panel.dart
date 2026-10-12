import 'package:flutter/material.dart';
import '../../sections/payments_management.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-authorized reconciliation with explicit MFA-protected finance action.
/// Credit/online pending requests are NOT treated as collected cash.
class CashReconciliationPanel extends StatefulWidget {
  const CashReconciliationPanel({super.key});

  @override
  State<CashReconciliationPanel> createState() => _CashReconciliationPanelState();
}

class _CashReconciliationPanelState extends State<CashReconciliationPanel> {
  static const int _reconciliationFetchLimit = 100;
  late Future<List<Map<String, dynamic>>> _rows = _fetch();
  String _cashFilter = 'All orders';
  String _receiptFilter = 'All receipt counts';
  String _cashDifferenceFilter = 'All cash-only differences';
  String _orderSearch = ''; // Searches only the order_id from the authorized RPC.
  final TextEditingController _orderSearchController = TextEditingController();

  @override
  void dispose() {
    _orderSearchController.dispose();
    super.dispose();
  }


  // Cash receipt count is supplied by the same authorized reconciliation RPC.
  // Unknown/malformed counts must never be silently treated as zero.
  int? _safeReceiptCount(Object? value) {
    if (value is int) return value >= 0 ? value : null;
    if (value is num && value.isFinite && value >= 0 &&
        value == value.roundToDouble()) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed >= 0 ? parsed : null;
  }

  // Display the same validated receipt count used by the filter.
  // Malformed or negative values must never appear as legitimate counts.
  String _receiptCountLabel(Object? raw) =>
      _safeReceiptCount(raw)?.toString() ?? 'Unavailable';

  bool _canInspectOrder(Map<String, dynamic> row) =>
      (_safeSignedIqd(row['order_id']) ?? 0) > 0;

  // Classification is based only on cash_paid_iqd returned by the authorized RPC.
  // It must not be interpreted as a complete payment settlement status.
  List<Map<String, dynamic>> _filteredCashRows(List<Map<String, dynamic>> rows) {
    return rows.where((row) {
      final orderId = _safeSignedIqd(row['order_id']);
      if (_orderSearch.trim().isNotEmpty &&
          (orderId == null || orderId <= 0 ||
           !orderId.toString().contains(_orderSearch.trim()))) return false;
      final receipts = _safeReceiptCount(row['cash_payment_count']);
      if (_receiptFilter == 'Has cash receipts' &&
          (receipts == null || receipts == 0)) return false;
      if (_receiptFilter == 'No cash receipts' && receipts != 0) return false;
      if (_receiptFilter == 'Receipt count unavailable' && receipts != null) return false;
      // A cash-only difference is not the all-method amount due.
      // Negative values may indicate an exception; do not suppress them.
      final difference = _safeSignedIqd(row['balance_iqd']);
      if (_cashDifferenceFilter == 'Positive cash-only difference' &&
          (difference == null || difference <= 0)) return false;
      if (_cashDifferenceFilter == 'Zero cash-only difference' &&
          difference != 0) return false;
      if (_cashDifferenceFilter == 'Negative cash-only difference' &&
          (difference == null || difference >= 0)) return false;
      if (_cashDifferenceFilter == 'Difference unavailable' &&
          difference != null) return false;
      final amount = _safeCashAmount(row['cash_paid_iqd']);
      if (_cashFilter == 'Cash recorded') return amount != null && amount > 0;
      if (_cashFilter == 'No cash recorded') return amount == 0;
      if (_cashFilter == 'Amount unavailable') return amount == null;
      return true;
    }).toList();
  }


  Future<List<Map<String, dynamic>>> _fetch() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      throw StateError('Employee login required');
    }
    final response = await Supabase.instance.client
        .rpc('gs_cash_reconciliation', params: {'p_limit': _reconciliationFetchLimit});
    final rows = List<Map<String, dynamic>>.from(response as List);
    // A bounded response is a sample, not proof of complete ledger coverage.
    // Reject impossible result sizes and repeated valid order identities before
    // any totals or receipt counts are presented as reconciled evidence.
    if (rows.length > _reconciliationFetchLimit) {
      throw StateError('Cash reconciliation source exceeded authorized limit');
    }
    final seenOrderIds = <int>{};
    for (final row in rows) {
      final id = _safeSignedIqd(row['order_id']);
      if (id != null && id > 0 && !seenOrderIds.add(id)) {
        throw StateError('Duplicate order identity in cash reconciliation');
      }
    }
    return rows;
  }

  void _refresh() => setState(() => _rows = _fetch());

  bool get _hasActiveFilters => _orderSearch.trim().isNotEmpty ||
      _cashFilter != 'All orders' ||
      _receiptFilter != 'All receipt counts' ||
      _cashDifferenceFilter != 'All cash-only differences';

  void _clearFilters() {
    _orderSearchController.clear();
    setState(() {
    _orderSearch = '';
    _cashFilter = 'All orders';
    _receiptFilter = 'All receipt counts';
    _cashDifferenceFilter = 'All cash-only differences';
    });
  }


  Future<void> _inspectOrder(Object? rawId) async {
    final orderId = _safeSignedIqd(rawId);
    if (orderId == null || orderId <= 0 || !mounted) return;
    try {
      final raw = await Supabase.instance.client.rpc(
        'gs_dashboard_payment_reconciliation_summary',
        params: {'p_order_id': orderId},
      );
      final row = raw is List
          ? (raw.isNotEmpty ? Map<String, dynamic>.from(raw.first as Map) : null)
          : raw is Map ? Map<String, dynamic>.from(raw) : null;
      if (!mounted) return;
      if (row == null) throw StateError('No reconciliation summary returned');
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Order $orderId — financial review'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('PROVISIONAL ONLY — not verified payment settlement.',
                style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Order total: ${_money(row['order_total_iqd'])}'),
              Text('Adjusted cash: ${_money(row['legacy_cash_iqd'])}'),
              Text('Matched cash: ${_money(row['matched_cash_iqd'])}'),
              Text('Unmatched cash: ${_money(row['unlinked_cash_iqd'])}'),
              Text('Other ledger net: ${_money(row['nonmirrored_ledger_net_iqd'])}'),
              Text('Provisional remaining: ${_money(row['apparent_remaining_iqd'])}'),
              Text('Reconciliation exceptions: ${row['reconciliation_exceptions'] ?? 'Unknown'}'),
              const SizedBox(height: 12),
              Text('${row['warning'] ?? 'Verification required'}'),
              const SizedBox(height: 8),
              const Text('This screen cannot release tables, approve refunds, '
                'or transfer bills. Accounting corrections do not prove '
                'physical cash refunds.'),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close')),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _attestCashOnlySettlement(orderId);
              },
              child: const Text('Attest cash-only settlement'),
            ),
            FilledButton.tonal(
              onPressed: () {
                Navigator.pop(dialogContext);
                _attestMixedSettlement(orderId);
              },
              child: const Text('Attest verified mixed payment'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Financial review unavailable. Check employee permissions '
          'and deployed reconciliation migrations.'),
      ));
    }
  }

  /// Explicit finance action. The server verifies MFA, reviewer role,
  /// separation of duties, exact cash totals and excluded payment methods.
  Future<void> _attestCashOnlySettlement(int orderId) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve cash-only settlement?'),
        content: Text('Order $orderId: confirm that you independently verified '
            'the physical cash receipts and the order amount. '
            'This creates an immutable finance attestation. '
            'It does not refund money or release the table. '
            'Mixed payments, corrections and self-collected payments are rejected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Attest cash settlement')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        throw StateError('Authenticated employee session required');
      }
      await Supabase.instance.client.rpc(
        'gs_attest_cash_only_order_settlement',
        params: {'p_order_id': orderId},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cash-only attestation recorded. '
            'Table release still requires independent checkout approval.'),
      ));
      _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Attestation rejected or unavailable. '
            'Check MFA, finance reviewer permission, cash receipts, '
            'and deployed database migrations.'),
      ));
    }
  }

  /// This is a real finance attestation request, NOT a client-side
  /// confirmation that an electronic payment succeeded. The backend must
  /// validate independently verified, ledger-posted provider events.
  Future<void> _attestMixedSettlement(int orderId) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Attest verified mixed payment?'),
        content: Text('Order $orderId: independently review the cash receipts '
            'and provider-confirmed electronic payments before attesting. '
            'Unverified provider claims and unposted electronic payments '
            'must not be counted. This does not release the table or refund '
            'money. Finance reviewer permissions and MFA are required.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Attest mixed settlement')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (Supabase.instance.client.auth.currentSession == null) {
        throw StateError('Authenticated employee session required');
      }
      await Supabase.instance.client.rpc(
        'gs_attest_mixed_order_settlement',
        params: {'p_order_id': orderId},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Mixed-payment finance attestation recorded. '
            'Mixed-payment table release is not yet enabled.'),
      ));
      _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Mixed-payment attestation rejected or unavailable. '
            'Check MFA, reviewer permissions, provider verification, '
            'ledger posting, exact amounts, and deployed migrations.'),
      ));
    }
  }

  String _money(Object? value) {
    final amount = _safeSignedIqd(value);
    if (amount != null) return '$amount IQD';
    return 'Unavailable';
  }

  int? _safeSignedIqd(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite &&
        value == value.roundToDouble()) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  // This cash-only sum is not total revenue or an all-method balance.
  int? _safeCashAmount(Object? value) {
    if (value is int) return value >= 0 ? value : null;
    if (value is num && value.isFinite && value >= 0 &&
        value == value.roundToDouble()) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed >= 0 ? parsed : null;
  }

  Widget _cashListFooter(List<Map<String, dynamic>> rows) {
    final amounts = rows.map((row) => _safeCashAmount(row['cash_paid_iqd'])).toList();
    // A capped sample cannot substantiate a complete cash total. Also fail
    // closed on overflow instead of displaying a wrapped financial figure.
    var complete = rows.length < _reconciliationFetchLimit &&
        amounts.every((value) => value != null);
    var total = 0;
    for (final amount in amounts) {
      if (amount == null || amount > 9007199254740991 - total) {
        complete = false;
        break;
      }
      total += amount;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        const Expanded(child: Text('Total recorded cash in listed orders',
            style: TextStyle(fontWeight: FontWeight.bold))),
        Flexible(child: Text(
          complete ? '$total IQD (${rows.length} orders)' :
              rows.length >= _reconciliationFetchLimit ?
              'Withheld — 100-record source cap reached' :
              'Unavailable — check cash amounts or overflow (${rows.length} orders)',
          textAlign: TextAlign.end,
          style: const TextStyle(fontWeight: FontWeight.bold),
        )),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cash reconciliation'), actions: [
      IconButton(
        tooltip: 'Review Standing Cash source',
        icon: const Icon(Icons.account_balance_wallet_outlined),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const PaymentsManagementScreen(initialFocus: 'standing'),
        )),
      ),
      IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
    ]),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _rows,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Cash reconciliation unavailable. Check backend permissions and migration 022.'),
          ));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty) return RefreshIndicator(
          onRefresh: () async {
            final refreshed = _fetch();
            setState(() => _rows = refreshed);
            try { await refreshed; } catch (_) { /* FutureBuilder displays the error. */ }
          },
          child: ListView(
            physics: AlwaysScrollableScrollPhysics(),
            children: [
              Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No orders to reconcile.')),
              ),
            ],
          ),
        );
        final displayedRows = _filteredCashRows(snapshot.data!);
        return RefreshIndicator(
          onRefresh: () async {
            // Refresh only the authorized reconciliation query; keep filter choices.
            final refreshed = _fetch();
            setState(() => _rows = refreshed);
            try { await refreshed; } catch (_) { /* FutureBuilder displays the error. */ }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              Expanded(child: Text(
                '${displayedRows.length} of ${snapshot.data!.length} loaded authorized orders',
                style: Theme.of(context).textTheme.bodyMedium,
              )),
              if (_hasActiveFilters)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Clear filters'),
                ),
            ]),
          ),
          if (snapshot.data!.length >= _reconciliationFetchLimit)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Showing at most 100 authorized orders returned by the server. '
                'Search and totals apply only to these loaded orders; '
                'they are not a complete historical cash report.',
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextFormField(
              controller: _orderSearchController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Find recorded order ID',
                helperText: 'Matches only authorized reconciliation results',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _orderSearch = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              key: ValueKey(_cashFilter),
              value: _cashFilter,
              decoration: const InputDecoration(labelText: 'Recorded cash filter'),
              items: ['All orders', 'Cash recorded', 'No cash recorded',
                      'Amount unavailable']
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) => setState(() => _cashFilter = value ?? 'All orders'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              key: ValueKey(_receiptFilter),
              value: _receiptFilter,
              decoration: const InputDecoration(labelText: 'Recorded cash receipt count'),
              items: ['All receipt counts', 'Has cash receipts',
                      'No cash receipts', 'Receipt count unavailable']
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) => setState(
                  () => _receiptFilter = value ?? 'All receipt counts'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              key: ValueKey(_cashDifferenceFilter),
              value: _cashDifferenceFilter,
              decoration: const InputDecoration(labelText: 'Cash-only difference'),
              items: ['All cash-only differences', 'Positive cash-only difference',
                      'Zero cash-only difference', 'Negative cash-only difference',
                      'Difference unavailable']
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) => setState(() =>
                  _cashDifferenceFilter = value ?? 'All cash-only differences'),
            ),
          ),
          const Padding(padding: EdgeInsets.all(16), child: Text(
            'Read-only order cash ledger. Balance is order total minus recorded cash payments; '
            'it is NOT a complete all-method outstanding balance. Pending credit and online '
            'confirmations are not counted as received funds.',
          )),
          if (displayedRows.isEmpty)
            const ListTile(title: Text('No orders match the selected cash filter.')),
          for (final row in displayedRows)
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              onTap: _canInspectOrder(row)
                  ? () => _inspectOrder(row['order_id']) : null,
              trailing: _canInspectOrder(row)
                  ? const Icon(Icons.chevron_right) : null,
              title: Text('Order ${row['order_id'] ?? 'Unknown'}'),
              subtitle: Text('Total: ${_money(row['order_total_iqd'])} · '
                  'Cash paid: ${_money(row['cash_paid_iqd'])}\n'
                  'Cash-only difference: ${_money(row['balance_iqd'])} · '
                  'Cash records: ${_receiptCountLabel(row['cash_payment_count'])}\n'
                  '${_canInspectOrder(row) ? 'Tap to inspect adjusted cash and reconciliation exceptions.' : 'Financial review unavailable: invalid order ID.'}'),
              isThreeLine: true,
            ),
          // The aggregate must appear after the exact displayed order rows.
          const Divider(height: 1),
          _cashListFooter(displayedRows),
        ],
          ),
        );
      },
    ),
  );
}
