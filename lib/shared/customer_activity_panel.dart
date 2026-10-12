import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only order activity. This is NOT a customer directory: the current
/// gs_orders projection does not establish customer identity.
class CustomerActivityPanel extends StatefulWidget {
  const CustomerActivityPanel({super.key});

  @override
  State<CustomerActivityPanel> createState() => _CustomerActivityPanelState();
}

class _CustomerActivityPanelState extends State<CustomerActivityPanel> {
  late Future<List<Map<String, dynamic>>> _future = _load();
  String _filter = 'all';
  String _search = '';

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw StateError('Sign in to view order activity.');
    }
    final result = await client.from('gs_orders')
        .select('id,destination,is_motel,tourism_mode,status,created_at')
        .order('created_at', ascending: false).limit(100);
    return List<Map<String, dynamic>>.from(result);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    const ListTile(
      leading: Icon(Icons.people_outline),
      title: Text('Customer activity'),
      subtitle: Text('Read-only recent order activity. Customer profiles and identities are not connected yet.'),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        decoration: const InputDecoration(
          labelText: 'Search destination or order ID',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
        onChanged: (value) => setState(() => _search = value.trim().toLowerCase()),
      ),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          initialValue: _filter,
          decoration: const InputDecoration(labelText: 'Order mode', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All modes')),
            DropdownMenuItem(value: 'normal', child: Text('Normal')),
            DropdownMenuItem(value: 'tourism', child: Text('Tourism')),
          ],
          onChanged: (value) => setState(() => _filter = value ?? 'all'),
        )),
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => setState(() => _future = _load()),
          icon: const Icon(Icons.refresh),
        ),
      ]),
    ),
    Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Unable to load authorized order activity: ${snapshot.error}'),
          ));
        }
        final rows = snapshot.data!.where((row) {
          final tourism = row['tourism_mode'] == true || row['is_motel'] == true;
          if (_filter == 'tourism' && !tourism) return false;
          if (_filter == 'normal' && tourism) return false;
          final haystack = '${row['id']} ${row['destination']}'.toLowerCase();
          return haystack.contains(_search);
        }).toList();
        if (rows.isEmpty) return const Center(child: Text('No matching recent orders'));
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            final tourism = row['tourism_mode'] == true || row['is_motel'] == true;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: Icon(tourism ? Icons.travel_explore : Icons.receipt_long),
                title: Text('Order ${row['id']}'),
                subtitle: Text('${row['destination'] ?? 'Unassigned'} · ${row['status'] ?? 'Unknown'}'),
                trailing: Text(tourism ? 'Tourism' : 'Normal'),
              ),
            );
          },
        );
      },
    )),
    const Padding(
      padding: EdgeInsets.all(12),
      child: Text('Showing at most 100 recent authorized orders. This does not count unique customers.'),
    ),
  ]);
}
