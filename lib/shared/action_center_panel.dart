import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only operational queue. Every row comes from the current user's
/// RLS-filtered Supabase access; this screen does not approve or edit orders.
class ActionCenterPanel extends StatefulWidget {
  const ActionCenterPanel({super.key});

  @override
  State<ActionCenterPanel> createState() => _ActionCenterPanelState();
}

class _ActionCenterPanelState extends State<ActionCenterPanel> {
  late Future<List<Map<String, dynamic>>> _orders = _load();
  String _filter = 'all';

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw StateError('Sign in to view the Action Center.');
    }
    return List<Map<String, dynamic>>.from(await client
        .from('gs_orders')
        .select('id,created_at,status,tourism_mode,is_motel')
        .order('created_at', ascending: false)
        .limit(100));
  }

  bool _isActive(String status) =>
      status == 'new' || status == 'pending' || status == 'preparing' ||
      status == 'ready';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ListTile(
        leading: const Icon(Icons.assignment_outlined),
        title: const Text('Operational Action Center'),
        subtitle: const Text('Read-only · recent accessible orders · maximum 100'),
        trailing: IconButton(
          tooltip: 'Refresh actions',
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(() => _orders = _load()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DropdownButtonFormField<String>(
          initialValue: _filter,
          decoration: const InputDecoration(
            labelText: 'Show orders', border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All active')),
            DropdownMenuItem(value: 'new', child: Text('New / pending')),
            DropdownMenuItem(value: 'preparing', child: Text('Preparing')),
            DropdownMenuItem(value: 'ready', child: Text('Ready')),
          ],
          onChanged: (value) => setState(() => _filter = value ?? 'all'),
        ),
      ),
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _orders,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText('Action Center unavailable: ${snapshot.error}'),
            ));
          }
          final rows = snapshot.data!.where((order) {
            final status = '${order['status'] ?? ''}'.toLowerCase();
            if (!_isActive(status)) return false;
            if (_filter == 'new') return status == 'new' || status == 'pending';
            return _filter == 'all' || status == _filter;
          }).toList();
          if (rows.isEmpty) {
            return const Center(child: Text('No matching active orders in the recent sample.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('${rows.length} matching orders · not an exhaustive count',
                      style: Theme.of(context).textTheme.labelMedium),
                );
              }
              final order = rows[index - 1];
              final motel = order['is_motel'] == true;
              final tourism = motel || order['tourism_mode'] == true;
              final status = '${order['status'] ?? 'Unknown'}';
              return Card(child: ListTile(
                leading: Icon(motel ? Icons.hotel_outlined : Icons.table_restaurant_outlined),
                title: Text('Order ${order['id']}'),
                subtitle: Text('$status · ${motel ? 'Motel' : 'Table'} · ${tourism ? 'Tourism' : 'Normal'} mode'),
                trailing: const Icon(Icons.visibility_outlined),
              ));
            },
          );
        },
      )),
    ]);
  }
}
