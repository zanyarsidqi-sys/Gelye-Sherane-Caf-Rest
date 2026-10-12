import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'customer_call_employee_screen.dart';

/// Visit-scoped gross order preview. Never treat it as a payment balance.
class CustomerTableBillScreen extends StatefulWidget {
  const CustomerTableBillScreen({super.key, required this.visitSessionToken});
  final String visitSessionToken;

  @override
  State<CustomerTableBillScreen> createState() => _CustomerTableBillScreenState();
}

class _CustomerTableBillScreenState extends State<CustomerTableBillScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _stationTracking = [];
  bool _loading = false;
  String? _error;
  DateTime? _lastUpdated;
  bool _appVisible = true;
  Timer? _foregroundRefreshTimer;
  Timer? _countdownTimer;
  DateTime _clockNow = DateTime.now();

  int _requestGeneration = 0;
  // Use arbitrary-precision arithmetic for totals; never silently overflow.
  static final BigInt _maxSupportedTotal = BigInt.from(9000000000000000);

  @override
  void didUpdateWidget(covariant CustomerTableBillScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visitSessionToken != widget.visitSessionToken) {
      _requestGeneration++;
      setState(() {
        _items = [];
        _stationTracking = [];
        _error = null;
        _lastUpdated = null;
        _loading = false;
      });
      _refresh();
    }
  }

  @override
  void dispose() {
    _foregroundRefreshTimer?.cancel();
    _countdownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _requestGeneration++;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Periodic reauthorization prevents a long-open customer bill from
    // remaining stale. Poll only while this screen is active and visible.
    _foregroundRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && _appVisible && !_loading) _refresh();
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _appVisible && _stationTracking.isNotEmpty) {
        setState(() => _clockNow = DateTime.now());
      }
    });
    _refresh();
  }

  String _customerEta(Map<String, dynamic> ticket) {
    final status = ticket['preparation_state']?.toString() ?? 'pending';
    if (status == 'delivered') return 'Delivered';
    if (status == 'picked_up') return 'Picked up — on the way';
    if (status == 'ready') return 'Ready for pickup';
    final raw = ticket['estimated_ready_at'];
    if (raw == null) return 'Waiting for preparation estimate';
    final readyAt = DateTime.tryParse(raw.toString());
    if (readyAt == null) return 'Estimated time unavailable';
    final remaining = readyAt.difference(_clockNow);
    if (remaining.isNegative || remaining == Duration.zero) {
      return 'Past estimated ready time — please ask staff for an update';
    }
    final minutes = (remaining.inSeconds / 60).ceil();
    return 'Approximately $minutes min until estimated ready time';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // A foreground transition must reauthorize before displaying amounts.
      _requestGeneration++;
      setState(() {
        _appVisible = true;
        _clockNow = DateTime.now();
        _loading = false;
      });
      _refresh();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Clear sensitive visit data from the app switcher and reject in-flight
      // responses while the app is backgrounded.
      _requestGeneration++;
      setState(() {
        _appVisible = false;
        _loading = false;
        _items = [];
        _stationTracking = [];
        _error = null;
        _lastUpdated = null;
      });
    }
  }

  Future<void> _refresh() async {
    if (_loading || !mounted || !_appVisible) return;
    final generation = ++_requestGeneration;
    // Invalidate the displayed snapshot while reauthorizing the visit.
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
      _lastUpdated = null;
    });
    try {
      final rows = await Supabase.instance.client.rpc(
        'gs_customer_visit_bill_preview',
        params: {'p_session_token': widget.visitSessionToken},
      );
      final tracking = await Supabase.instance.client.rpc(
        'gs_customer_visit_station_tracking',
        params: {'p_session_token': widget.visitSessionToken},
      );
      if (!mounted || generation != _requestGeneration) return;
      if (tracking is! List) throw const FormatException('Invalid tracking response');
      final stationRows = tracking.map((row) =>
        Map<String, dynamic>.from(row as Map)).toList();
      // Reject incomplete or malformed monetary data instead of silently
      // displaying a misleading 0 IQD amount or quantity.
      if (rows is! List) throw const FormatException('Invalid bill response');
      final verified = <Map<String, dynamic>>[];
      for (final raw in rows) {
        if (raw is! Map) throw const FormatException('Invalid bill item');
        final item = Map<String, dynamic>.from(raw);
        final quantity = item['quantity'];
        final amount = item['amount_iqd'];
        if (quantity is! num || !quantity.isFinite || quantity <= 0 ||
            amount is! num || !amount.isFinite || amount < 0 ||
            quantity != quantity.toInt() || amount != amount.toInt()) {
          throw const FormatException('Invalid bill quantity or amount');
        }
        final productName = item['product_name'];
        if (productName is! String || productName.trim().isEmpty) {
          throw const FormatException('Missing bill product name');
        }
        // A bill must not display a mathematically valid but implausible
        // amount produced by an upstream conversion or overflow.
        if (amount > 9000000000000000 || quantity > 1000000) {
          throw const FormatException('Bill value outside supported range');
        }
        verified.add(item);
      }
      // Validate the entire bill, not just each individual row.
      final gross = verified.fold<BigInt>(BigInt.zero, (sum, row) =>
          sum + BigInt.from((row['amount_iqd'] as num).toInt()));
      final units = verified.fold<BigInt>(BigInt.zero, (sum, row) =>
          sum + BigInt.from((row['quantity'] as num).toInt()));
      if (gross > _maxSupportedTotal || units > BigInt.from(1000000)) {
        throw const FormatException('Bill total outside supported range');
      }
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _items = verified;
        _stationTracking = stationRows;
        _lastUpdated = DateTime.now();
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      // Never show a stale amount after a failed authorization or refresh.
      setState(() {
        _items = [];
        _stationTracking = [];
        _lastUpdated = null;
        _error = 'Order preview unavailable. Please ask the cashier.';
      });
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _reportItemIssue(Map<String, dynamic> item) async {
    // Reasons are selected locally; submission still uses the existing
    // visit-authorized cashier request RPC and employee audit workflow.
    final sessionAtStart = widget.visitSessionToken;
    final generationAtStart = _requestGeneration;
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('What is wrong with this item?')),
            for (final option in const [
              ('wrong_item', 'I did not order this item'),
              ('wrong_quantity', 'The quantity is incorrect'),
              ('wrong_price', 'The price looks incorrect'),
              ('other', 'Another issue with this item'),
            ])
              ListTile(
                title: Text(option.$2),
                onTap: () => Navigator.of(sheetContext).pop(option.$2),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || reason == null || !_appVisible ||
        sessionAtStart != widget.visitSessionToken ||
        generationAtStart != _requestGeneration) return;
    final name = (item['product_name'] as String);
    final shortName = name.length > 65 ? '${name.substring(0, 65)}…' : name;
    final note = 'Bill item issue: $reason. Item: $shortName; '
        'quantity: ${item['quantity']}; displayed amount: '
        '${_iqd((item['amount_iqd'] as num).toInt())}.';
    // The staff-call RPC enforces a 300-character note limit. Truncate
    // safely here rather than letting the customer hit a submission error.
    final safeNote = note.length > 300 ? note.substring(0, 300) : note;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CustomerCallEmployeeScreen(
        visitSessionToken: widget.visitSessionToken,
        initialType: 'cashier',
        initialNote: safeNote,
      ),
    ));
  }

  String _iqd(int amount) {
    final digits = amount.abs().toString();
    final grouped = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
    return '${amount < 0 ? '-' : ''}$grouped IQD';
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<BigInt>(BigInt.zero, (sum, row) =>
        sum + BigInt.from((row['amount_iqd'] as num).toInt()));
    final itemCount = _items.fold<BigInt>(BigInt.zero, (sum, row) =>
        sum + BigInt.from((row['quantity'] as num).toInt()));
    return Scaffold(
      appBar: AppBar(title: const Text('Check Table Bill')),
      body: !_appVisible
          ? const Center(child: Text('Order summary hidden while the app is inactive.'))
          : RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Order summary — not the final amount due',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Payments, discounts, refunds and table transfers may change the final balance.'),
            const Text('This preview refreshes automatically every minute while open.'),
            TextButton.icon(
              onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh order summary'),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (!_loading && _error == null && _items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No ordered items are currently available for this visit.'),
              ),
            if (_stationTracking.isNotEmpty) ...[
              const Divider(),
              const Text('Preparation tracking',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const Text('Estimated ready times may change. Delivery is tracked separately.'),
              for (final ticket in _stationTracking)
                ListTile(
                  leading: const Icon(Icons.restaurant),
                  title: Text('Order #${ticket['order_id']} · ${ticket['station_name']}'),
                  subtitle: Text(
                    '${ticket['preparation_state']}'
                    '${ticket['estimated_minutes'] == null ? '' : ' · Estimate: ${ticket['estimated_minutes']} min'}'
                    '${ticket['estimated_ready_at'] == null ? '' : '\nExpected ready: ${DateTime.tryParse(ticket['estimated_ready_at'].toString())?.toLocal() ?? 'Unavailable'}'}'
                    '\n${_customerEta(ticket)}'),
                ),
              const Divider(),
            ],
            for (final item in _items)
              ListTile(
                title: Text(item['product_name']?.toString() ?? 'Product'),
                subtitle: Text('Quantity: ${item['quantity']}'),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_iqd((item['amount_iqd'] as num).toInt())),
                    TextButton(
                      onPressed: _loading ? null : () => _reportItemIssue(item),
                      child: const Text('Report issue'),
                    ),
                  ],
                ),
              ),
            if (!_loading && _error == null) ...[
              const Divider(),
              Text('Products: ${_items.length} · Total units: $itemCount'),
              Text('Gross ordered items: ${_iqd(total.toInt())}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
            if (_lastUpdated != null)
              Text('Updated: ${TimeOfDay.fromDateTime(_lastUpdated!).format(context)}'),
            const SizedBox(height: 12),
            const Text('Ask the cashier for your confirmed balance before payment.'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.support_agent),
              label: const Text('Ask cashier about this bill'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CustomerCallEmployeeScreen(
                    visitSessionToken: widget.visitSessionToken,
                    initialType: 'cashier',
                    initialNote: 'Please review my table bill and confirm the amount payable.',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
