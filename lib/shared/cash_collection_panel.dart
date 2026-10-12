import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Staff-confirmed cash collection. Totals are for display only; the server
/// function must independently enforce the outstanding balance and permissions.
class CashCollectionPanel extends StatefulWidget {
  const CashCollectionPanel({super.key});
  @override
  State<CashCollectionPanel> createState() => _CashCollectionPanelState();
}

class _CashCollectionPanelState extends State<CashCollectionPanel> {
  late Future<List<Map<String, dynamic>>> _orders = _load();
  bool _saving = false;

  Future<List<Map<String, dynamic>>> _load() async {
    final db = Supabase.instance.client;
    final orders = List<Map<String, dynamic>>.from(await db.from('gs_orders')
        .select('id,destination,status').neq('status', 'cancelled')
        .order('created_at', ascending: false).limit(100));
    if (orders.isEmpty) return orders;
    final ids = orders.map((o) => o['id']).toList();
    // Fetch in batches rather than issuing two queries for every order.
    final items = List<Map<String, dynamic>>.from(await db.from('gs_order_items')
        .select('order_id,line_total_iqd').inFilter('order_id', ids));
    final payments = List<Map<String, dynamic>>.from(await db.from('gs_cash_payments')
        .select('order_id,amount_iqd').inFilter('order_id', ids));
    final totals = <String, int>{};
    final paid = <String, int>{};
    for (final item in items) {
      final key = '${item['order_id']}';
      totals[key] = (totals[key] ?? 0) + ((item['line_total_iqd'] as num).toInt());
    }
    for (final payment in payments) {
      final key = '${payment['order_id']}';
      paid[key] = (paid[key] ?? 0) + ((payment['amount_iqd'] as num).toInt());
    }
    for (final order in orders) {
      final key = '${order['id']}';
      order['total'] = totals[key] ?? 0;
      order['paid'] = paid[key] ?? 0;
      order['due'] = (totals[key] ?? 0) - (paid[key] ?? 0);
    }
    return orders;
  }

  Future<void> _collect(Map<String, dynamic> order) async {
    final due = order['due'] as int;
    if (due <= 0 || _saving) return;
    final controller = TextEditingController(text: '$due');
    final amount = await showDialog<int>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text('Confirm cash received — order #${order['id']}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Outstanding: $due IQD. Record only cash physically received.'),
        TextField(controller: controller, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Received amount (IQD)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          final value = int.tryParse(controller.text.trim());
          if (value == null || value <= 0 || value > due) return;
          Navigator.pop(dialogContext, value);
        }, child: const Text('Confirm received')),
      ],
    ));
    controller.dispose();
    if (amount == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final ref = await Supabase.instance.client.rpc('gs_new_payment_reference');
      await Supabase.instance.client.rpc('gs_record_cash_payment', params: {
        'p_order_id': order['id'], 'p_amount_iqd': amount, 'p_reference': ref,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cash collection recorded in ledger')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        'Payment confirmation failed or is uncertain. Refresh the ledger before retrying: $e')));
    } finally {
      if (mounted) setState(() { _saving = false; _orders = _load(); });
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    ListTile(title: const Text('Cash collection'),
      subtitle: const Text('Cash only. Card and customer credit are not connected.'),
      trailing: IconButton(onPressed: _saving ? null : () => setState(() => _orders = _load()),
        icon: const Icon(Icons.refresh))),
    Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: _orders, builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Center(child: snapshot.hasError
          ? Text('Cannot load ledger: ${snapshot.error}') : const CircularProgressIndicator());
      }
      final orders = snapshot.data!;
      if (orders.isEmpty) return const Center(child: Text('No orders to collect.'));
      return ListView.builder(itemCount: orders.length, itemBuilder: (context, index) {
        final order = orders[index];
        final due = order['due'] as int;
        return ListTile(title: Text('Order #${order['id']} — ${order['destination']}'),
          subtitle: Text('Total: ${order['total']} IQD  •  Cash paid: ${order['paid']} IQD\nOutstanding: $due IQD'),
          isThreeLine: true,
          trailing: FilledButton(onPressed: _saving || due <= 0 ? null : () => _collect(order),
            child: Text(due <= 0 ? 'Paid in cash' : 'Record cash')));
      });
    })),
  ]);
}
