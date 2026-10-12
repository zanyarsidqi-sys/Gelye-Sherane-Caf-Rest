import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider inbox is evidence only. Only a trusted signed provider callback
/// can verify a transaction; no employee button can mark it paid.
class ProviderVerificationQueue extends StatefulWidget {
  const ProviderVerificationQueue({super.key});
  @override
  State<ProviderVerificationQueue> createState() => _ProviderVerificationQueueState();
}

class _ProviderVerificationQueueState extends State<ProviderVerificationQueue> {
  late Future<List<Map<String, dynamic>>> _rows = _load();
  Future<List<Map<String, dynamic>>> _load() async {
    final raw = await Supabase.instance.client.rpc(
      'gs_dashboard_payment_verification_queue', params: {'p_limit': 100});
    return (raw as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }
  void _refresh() => setState(() => _rows = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Electronic payment verification'), actions: [
      IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
    ]),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _rows,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Padding(
          padding: EdgeInsets.all(24), child: Text(
            'Verification inbox unavailable. Confirm staff permissions and deployed Supabase migrations.')));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!;
        if (rows.isEmpty) return const Center(child: Text('No outstanding provider events.'));
        return ListView.builder(itemCount: rows.length, itemBuilder: (context, i) {
          final r = rows[i];
          final matched = r['amount_matches'] == true;
          final amount = r['reported_amount_iqd'];
          final expected = r['expected_amount_iqd'];
          return Card(child: ListTile(
            leading: Icon(matched ? Icons.hourglass_top : Icons.warning_amber,
              color: matched ? null : Theme.of(context).colorScheme.error),
            title: Text('${r['provider'] ?? 'Provider'} · ${amount ?? '—'} IQD'),
            subtitle: Text('Order ${r['order_id'] ?? '—'} · ${r['method'] ?? '—'}\n'
              'Expected: ${expected ?? '—'} IQD · ${r['intake_status'] ?? 'unknown'}\n'
              '${matched ? 'Amount matches; still NOT verified' : 'Amount/currency mismatch; review required'}'),
            isThreeLine: true,
            trailing: const Icon(Icons.lock_outline),
            onTap: () => showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
              title: const Text('Payment evidence — not settlement'),
              content: Text('Inbox event: ${r['inbox_id']}\nEvidence: ${r['evidence_id']}\n'
                'Order: ${r['order_id']}\nReported: $amount ${r['reported_currency']}\n'
                'Expected: $expected IQD\n\nOnly a trusted server-side provider verification '
                'can confirm this payment. Staff cannot approve it from this screen.'),
              actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'))],
            )),
          ));
        });
      },
    ),
  );
}
