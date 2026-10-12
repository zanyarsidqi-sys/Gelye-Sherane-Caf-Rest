import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only order review. Order values are NOT proof of payment or invoices.
class InvoiceReviewPanel extends StatefulWidget {
  const InvoiceReviewPanel({super.key});

  @override
  State<InvoiceReviewPanel> createState() => _InvoiceReviewPanelState();
}

class _InvoiceReviewPanelState extends State<InvoiceReviewPanel> {
  late Future<List<Map<String, dynamic>>> _future = _load();
  String _query = '';
  String _filter = 'all';

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw StateError('Sign in to review orders.');
    }
    final orders = List<Map<String, dynamic>>.from(await client
        .from('gs_orders')
        .select('id,destination,is_motel,tourism_mode,status,created_at')
        .order('created_at', ascending: false)
        .limit(100));
    if (orders.isEmpty) return orders;
    final items = List<Map<String, dynamic>>.from(await client
        .from('gs_order_items')
        .select('order_id,line_total_iqd')
        .inFilter('order_id', orders.map((e) => e['id']).toList())
        .limit(1000));
    final totals = <String, int>{};
    for (final item in items) {
      final id = '${item['order_id']}';
      totals[id] = (totals[id] ?? 0) +
          ((item['line_total_iqd'] as num?)?.toInt() ?? 0);
    }
    for (final order in orders) {
      order['review_total_iqd'] = totals['${order['id']}'] ?? 0;
      order['partial_item_sample'] = items.length == 1000;
    }
    return orders;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: const Text('Order review — read only'),
        subtitle: const Text('Not issued invoices, settled payments, or accounting revenue.'),
        trailing: IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(() => _future = _load()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search order ID or table / room',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _query = value.toLowerCase().trim()),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _filter,
            decoration: const InputDecoration(
              labelText: 'Order type', border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All orders')),
              DropdownMenuItem(value: 'table', child: Text('Table orders')),
              DropdownMenuItem(value: 'motel', child: Text('Motel orders')),
            ],
            onChanged: (value) => setState(() => _filter = value ?? 'all'),
          ),
        ]),
      ),
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText('Unable to load authorized orders: ${snapshot.error}'),
            ));
          }
          final all = snapshot.data ?? [];
          final rows = all.where((order) {
            final motel = order['is_motel'] == true;
            final matchesType = _filter == 'all' ||
                (_filter == 'motel' ? motel : !motel);
            final searchText = '${order['id']} ${order['destination']}'.toLowerCase();
            return matchesType && searchText.contains(_query);
          }).toList();
          if (rows.isEmpty) {
            return const Center(child: Text('No matching accessible orders.'));
          }
          return ListView.builder(
            itemCount: rows.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Recent accessible orders only (max 100). '
                      'Item totals may be incomplete when the 1,000-item query limit is reached.'),
                );
              }
              final order = rows[index - 1];
              final motel = order['is_motel'] == true;
              final tourism = motel || order['tourism_mode'] == true;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: Icon(motel ? Icons.hotel_outlined : Icons.table_restaurant_outlined),
                  title: Text('${motel ? 'Motel' : 'Table'} · ${order['destination'] ?? 'Unknown'}'),
                  subtitle: Text('Order ${order['id']}\n'
                      '${order['status']} · ${tourism ? 'Tourism' : 'Normal'} pricing'),
                  isThreeLine: true,
                  trailing: Text('${order['review_total_iqd']} IQD',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              );
            },
          );
        },
      )),
    ]);
  }
}
