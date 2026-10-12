import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cash_reconciliation_panel.dart';
import 'provider_verification_queue.dart';

/// Read-only payment confirmation queue. Never marks a payment settled locally.
/// The RPC must enforce employee access and return only authorized records.
class PaymentConfirmationPanel extends StatefulWidget {
  const PaymentConfirmationPanel({super.key});
  @override
  State<PaymentConfirmationPanel> createState() => _PaymentConfirmationPanelState();
}

class _PaymentConfirmationPanelState extends State<PaymentConfirmationPanel> {
  late Future<List<Map<String, dynamic>>> _pending = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      throw StateError('Employee login required');
    }
    final data = await Supabase.instance.client.rpc('gs_pending_payment_confirmations');
    return List<Map<String, dynamic>>.from(data as List);
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      SelectableText(value),
    ]),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Payment confirmations'), actions: [
      IconButton(icon: const Icon(Icons.verified_user_outlined),
        tooltip: 'Electronic payment verification inbox',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const ProviderVerificationQueue()))),
      IconButton(icon: const Icon(Icons.account_balance_wallet_outlined),
        tooltip: 'Cash reconciliation', onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CashReconciliationPanel()))),
      IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh',
        onPressed: () => setState(() => _pending = _load())),
    ]),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _pending,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Confirmation queue unavailable. Backend authorization and RPC setup required.'));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!;
        if (rows.isEmpty) return const Center(child: Text('No pending confirmations.'));
        return ListView.builder(itemCount: rows.length, itemBuilder: (context, i) {
          final row = rows[i];
          final method = '${row['method'] ?? 'Unknown'}';
          final amount = row['amount_iqd'];
          return ListTile(
            leading: Icon(method.toLowerCase() == 'credit' ? Icons.credit_card : Icons.qr_code),
            title: Text('$method · ${amount is num ? amount.toInt() : '—'} IQD'),
            subtitle: Text('Order ${row['order_id'] ?? '—'} · Pending receiver verification'),
            trailing: const Icon(Icons.lock_outline),
            onTap: () => showDialog<void>(context: context, builder: (dialogContext) {
              String field(String key) {
                final value = row[key];
                return value == null || value.toString().trim().isEmpty ? 'Not provided' : value.toString();
              }
              return AlertDialog(
                title: const Text('Receiver verification required'),
                content: SizedBox(
                  width: 440,
                  child: SingleChildScrollView(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Pending — this payment is NOT confirmed.',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _detail('Payment method', method),
                      _detail('Amount', '${amount is num ? amount.toInt() : '—'} IQD'),
                      _detail('Order ID', field('order_id')),
                      _detail('Payment ID', field('id')),
                      _detail('Transaction reference', field('transaction_reference')),
                      _detail('Submitted by', field('submitted_by')),
                      _detail('Submitted at', field('created_at')),
                      _detail('Evidence status', row['evidence_path'] == null && row['screenshot_path'] == null
                        ? 'Not provided in queue' : 'Evidence reference recorded; secure viewer pending'),
                      const SizedBox(height: 12),
                      const Text('Screenshot evidence is not proof of receipt. '
                        'An authorized receiver must independently verify the funds. '
                        'Approval and rejection remain disabled until server-side authorization, '
                        'duplicate protection, and audit logging are implemented.'),
                    ],
                  )),
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'))],
              );
            }),
          );
        });
      },
    ),
  );
}
