import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Staff-only diagnostic. The RPC enforces finance permissions server-side.
/// This screen NEVER approves settlement or alters a payment record.
class StaffBillReconciliationScreen extends StatefulWidget {
  const StaffBillReconciliationScreen({super.key});
  @override
  State<StaffBillReconciliationScreen> createState() => _StaffBillReconciliationScreenState();
}

class _StaffBillReconciliationScreenState extends State<StaffBillReconciliationScreen> {
  final _orderId = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;
  int _generation = 0;

  @override
  void dispose() {
    _generation++;
    _orderId.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final id = int.tryParse(_orderId.text.trim());
    if (id == null || id <= 0) {
      setState(() { _result = null; _error = 'Enter a valid order ID.'; });
      return;
    }
    final generation = ++_generation;
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_dashboard_payment_reconciliation_summary',
        params: {'p_order_id': id},
      );
      if (!mounted || generation != _generation) return;
      final data = response is List && response.isNotEmpty ? response.first : response;
      if (data is! Map) throw const FormatException('Unexpected reconciliation response');
      final verified = Map<String, dynamic>.from(data);
      const requiredAmounts = <String>[
        'order_total_iqd', 'legacy_cash_iqd', 'matched_cash_iqd',
        'unlinked_cash_iqd', 'nonmirrored_ledger_net_iqd',
        'provisional_net_iqd', 'apparent_remaining_iqd',
        'reconciliation_exceptions',
      ];
      for (final key in requiredAmounts) {
        final value = verified[key];
        if (value is! int) {
          throw FormatException('Invalid financial field: $key');
        }
      }
      // These values represent non-negative recorded totals; a negative
      // amount indicates a malformed or incompatible backend response.
      for (final key in <String>[
        'order_total_iqd', 'legacy_cash_iqd', 'matched_cash_iqd',
        'unlinked_cash_iqd', 'reconciliation_exceptions',
      ]) {
        if ((verified[key] as int) < 0) {
          throw FormatException('Negative reconciliation field: $key');
        }
      }
      // Validate the arithmetic invariants of the read-only SQL summary.
      // BigInt prevents an overflow in this diagnostic check when the database
      // returns amounts close to the signed 64-bit limit.
      BigInt amount(String key) => BigInt.from(verified[key] as int);
      if (amount('matched_cash_iqd') > amount('legacy_cash_iqd') ||
          amount('unlinked_cash_iqd') !=
              amount('legacy_cash_iqd') - amount('matched_cash_iqd') ||
          amount('provisional_net_iqd') !=
              amount('legacy_cash_iqd') + amount('nonmirrored_ledger_net_iqd') ||
          amount('apparent_remaining_iqd') !=
              amount('order_total_iqd') - amount('provisional_net_iqd')) {
        throw const FormatException('Reconciliation totals do not agree');
      }
      if (verified['order_id'] != id ||
          verified['settlement_confirmed'] != false ||
          verified['transfer_allowed'] != false ||
          verified['warning'] is! String ||
          (verified['warning'] as String).trim().isEmpty ||
          (verified['reconciliation_exceptions'] as int) < 0) {
        throw const FormatException('Unsafe reconciliation response');
      }
      setState(() { _result = verified; });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() { _error = 'Reconciliation unavailable or response failed safety checks. Ask finance to verify this order; do not settle or release the table.'; });
    } finally {
      if (mounted && generation == _generation) setState(() { _loading = false; });
    }
  }

  String _amount(Object? value) {
    if (value is! num) return 'Unavailable';
    final digits = value.toInt().abs().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '${value.toInt() < 0 ? '-' : ''}$digits IQD';
  }

  @override
  Widget build(BuildContext context) {
    final data = _result;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Payment reconciliation — staff diagnostic only',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 8),
      const Text('Requires Invoices & Payments or Payments Management view permission. '
          'Values are provisional; they cannot authorize table release, refunds or final settlement.'),
      const SizedBox(height: 12),
      TextField(
        controller: _orderId,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 18,
        decoration: const InputDecoration(labelText: 'Order ID', border: OutlineInputBorder()),
        onChanged: (_) {
          _generation++;
          // Invalidate any in-flight response and unlock the button so staff
          // can immediately check the newly entered order ID.
          setState(() { _loading = false; _result = null; _error = null; });
        },
      ),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: _loading ? null : _check,
          icon: const Icon(Icons.fact_check_outlined), label: const Text('Check reconciliation')),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if (data != null) ...[
        const Divider(),
        for (final entry in <String, String>{
          'order_total_iqd': 'Order gross total',
          'legacy_cash_iqd': 'Recorded legacy cash',
          'matched_cash_iqd': 'Matched cash mirrors (not counted twice)',
          'unlinked_cash_iqd': 'Unlinked cash',
          'nonmirrored_ledger_net_iqd': 'Non-mirrored ledger net',
          'provisional_net_iqd': 'Provisional received net',
          'apparent_remaining_iqd': 'Apparent remaining (not certified)',
        }.entries)
          ListTile(dense: true, title: Text(entry.value), trailing: Text(_amount(data[entry.key]))),
        if ((data['reconciliation_exceptions'] as int) > 0)
          const ListTile(
            leading: Icon(Icons.warning_amber_rounded),
            title: Text('Unresolved payment evidence'),
            subtitle: Text('Finance must investigate these exceptions before any settlement.'),
          ),
        ListTile(title: const Text('Reconciliation exceptions'),
          trailing: Text('${data['reconciliation_exceptions'] ?? 'Unknown'}')),
        ListTile(
          title: const Text('Settlement / table transfer'),
          subtitle: const Text('Not authorized by this diagnostic'),
          trailing: Icon(Icons.block, color: Theme.of(context).colorScheme.error),
        ),
        const Text('Settlement confirmed: NO — diagnostic results are not payment confirmation.',
          style: TextStyle(fontWeight: FontWeight.bold)),
        Text(data['warning']?.toString() ?? 'Financial verification required before settlement.'),
      ],
    ]);
  }
}
