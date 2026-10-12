import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only operational order-value summary, NOT cash received or accounting revenue.
/// Queries remain subject to the signed-in employee's Supabase RLS policies.
class LiveOrderValuePanel extends StatefulWidget {
  const LiveOrderValuePanel({super.key});

  @override
  State<LiveOrderValuePanel> createState() => _LiveOrderValuePanelState();
}

class _LiveOrderValuePanelState extends State<LiveOrderValuePanel> {
  late Future<_OrderValueSummary> _summary = _load();
  String _mode = 'all';

  Future<_OrderValueSummary> _load() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw StateError('Sign in to access order value.');
    }
    final orders = List<Map<String, dynamic>>.from(await client
        .from('gs_orders')
        .select('id,is_motel,tourism_mode,status,created_at')
        .order('created_at', ascending: false)
        .limit(100));
    if (orders.isEmpty) return _OrderValueSummary(orders, const {});
    final ids = orders.map((o) => o['id']).toList();
    final items = List<Map<String, dynamic>>.from(await client
        .from('gs_order_items')
        .select('order_id,line_total_iqd')
        .inFilter('order_id', ids)
        .limit(1000));
    final totals = <String, int>{};
    for (final item in items) {
      final key = '${item['order_id']}';
      totals[key] = (totals[key] ?? 0) +
          ((item['line_total_iqd'] as num?)?.toInt() ?? 0);
    }
    return _OrderValueSummary(orders, totals, itemLimitReached: items.length == 1000);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    ListTile(
      leading: const Icon(Icons.assessment_outlined),
      title: const Text('Live order value'),
      subtitle: const Text('Read-only Supabase sample · not settled revenue'),
      trailing: IconButton(
        tooltip: 'Refresh',
        icon: const Icon(Icons.refresh),
        onPressed: () => setState(() => _summary = _load()),
      ),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonFormField<String>(
        initialValue: _mode,
        decoration: const InputDecoration(
          labelText: 'Pricing mode', border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All orders')),
          DropdownMenuItem(value: 'normal', child: Text('Normal')),
          DropdownMenuItem(value: 'tourism', child: Text('Tourism')),
        ],
        onChanged: (value) => setState(() => _mode = value ?? 'all'),
      ),
    ),
    Expanded(child: FutureBuilder<_OrderValueSummary>(
      future: _summary,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText('Cannot load authorized order value: ${snapshot.error}'),
          ));
        }
        final data = snapshot.data!;
        final rows = data.orders.where((o) {
          final tourism = o['tourism_mode'] == true || o['is_motel'] == true;
          return _mode == 'all' || (_mode == 'tourism' ? tourism : !tourism);
        }).toList();
        var activeValue = 0;
        var cancelledValue = 0;
        var normalValue = 0;
        var tourismValue = 0;
        for (final order in rows) {
          final value = data.totals['${order['id']}'] ?? 0;
          if ('${order['status']}'.toLowerCase() == 'cancelled') {
            cancelledValue += value;
          } else {
            activeValue += value;
            if (order['tourism_mode'] == true || order['is_motel'] == true) {
              tourismValue += value;
            } else {
              normalValue += value;
            }
          }
        }
        Widget metric(String label, int value) => Card(child: ListTile(
          title: Text(label),
          trailing: Text('$value IQD', style: const TextStyle(fontWeight: FontWeight.bold)),
        ));
        return ListView(padding: const EdgeInsets.all(12), children: [
          metric('Non-cancelled order value', activeValue),
          metric('Normal order value', normalValue),
          metric('Tourism order value', tourismValue),
          metric('Cancelled order value (excluded)', cancelledValue),
          Card(child: ListTile(
            title: Text('${rows.length} recent accessible orders'),
            subtitle: const Text('At most 100 orders and 1,000 line items are fetched. ' 
              'These totals may be incomplete due to limits or RLS.'),
          )),
          if (data.itemLimitReached)
            const Card(child: ListTile(
              leading: Icon(Icons.warning_amber_outlined),
              title: Text('Line-item limit reached'),
              subtitle: Text('Totals are incomplete; use paginated reporting for financial decisions.'),
            )),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Order values are not payment receipts, recognized revenue, or profit. '
              'Refunds, discounts, settlement, taxes and accounting reconciliation are not included.'),
          ),
        ]);
      },
    )),
  ]);
}

class _OrderValueSummary {
  const _OrderValueSummary(this.orders, this.totals, {this.itemLimitReached = false});
  final List<Map<String, dynamic>> orders;
  final Map<String, int> totals;
  final bool itemLimitReached;
}
