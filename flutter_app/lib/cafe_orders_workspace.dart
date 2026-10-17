import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class CafeOrderStore {
  Future<List<Map<String, dynamic>>> load();
  Future<void> transition(String id, String status);
}

class SupabaseCafeOrderStore implements CafeOrderStore {
  SupabaseCafeOrderStore(this.client);
  final SupabaseClient client;
  @override
  Future<List<Map<String, dynamic>>> load() async {
    final rows = await client.rpc('list_cafe_table_orders') as List;
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  @override
  Future<void> transition(String id, String status) async {
    if (!const {'preparing', 'ready', 'served', 'cancelled'}.contains(status)) {
      throw const FormatException('Invalid order status.');
    }
    await client.rpc(
      'update_cafe_table_order_status',
      params: {'p_order_id': id, 'p_status': status},
    );
  }
}

class CafeOrdersWorkspace extends StatefulWidget {
  const CafeOrdersWorkspace({super.key, required this.store});
  final CafeOrderStore? store;
  @override
  State<CafeOrdersWorkspace> createState() => _CafeOrdersWorkspaceState();
}

class _CafeOrdersWorkspaceState extends State<CafeOrdersWorkspace> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;
  final _busy = <String>{};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.store == null) throw StateError('Connection not configured');
      final rows = await widget.store!.load();
      if (mounted) setState(() => _orders = rows);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not load orders. Check your connection, permissions and staging setup, then refresh.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _transition(String id, String status) async {
    if (_busy.contains(id)) return;
    if (status == 'cancelled') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel this order?'),
          content: const Text(
            'This ends preparation. Any payment or stock adjustment must be handled separately.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep order'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel order'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busy.add(id));
    try {
      await widget.store!.transition(id, status);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Update could not be confirmed. Refresh orders before retrying; another staff member may have changed this order.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Active table orders',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const Text(
            'Received → Preparing → Ready → Served. Refresh for the latest status. Payments, printing and stock deductions are not connected yet.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _loading || _busy.isNotEmpty ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh orders'),
            ),
          ),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error == null) ...[
            if (_orders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No active table orders.'),
              ),
            for (final order in _orders)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${order['table_name']} · ${order['area']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Order ${order['id']}'),
                      Text('${order['status']} · ${order['total_iqd']} IQD'),
                      for (final item in order['items'] as List)
                        Text(
                          '${item['quantity']} × ${item['name']} · ${item['unit_price_iqd']} IQD each',
                        ),
                      if ((order['notes'] as String).isNotEmpty)
                        Text('Notes: ${order['notes']}'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final action in switch (order['status']) {
                            'received' => const [
                              ('preparing', 'Start preparation'),
                              ('cancelled', 'Cancel'),
                            ],
                            'preparing' => const [
                              ('ready', 'Mark ready'),
                              ('cancelled', 'Cancel'),
                            ],
                            'ready' => const [('served', 'Mark served')],
                            _ => const <(String, String)>[],
                          })
                            OutlinedButton(
                              onPressed: _busy.contains(order['id'])
                                  ? null
                                  : () => _transition(
                                      order['id'] as String,
                                      action.$1,
                                    ),
                              child: Text(action.$2),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}
