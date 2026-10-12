import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-authorized, read-only employee activity history.
/// The server RPC must enforce permissions; hiding a card is not security.
class SystemAuditPanel extends StatefulWidget {
  const SystemAuditPanel({super.key});
  @override
  State<SystemAuditPanel> createState() => _SystemAuditPanelState();
}

class _SystemAuditPanelState extends State<SystemAuditPanel> {
  late Future<List<Map<String, dynamic>>> _events = _load();
  String _query = '';
  Future<List<Map<String, dynamic>>> _load() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      throw StateError('Sign in to view audit history');
    }
    final result = await Supabase.instance.client.rpc('gs_dashboard_audit_events', params: {'p_limit': 100});
    return List<Map<String, dynamic>>.from(result as List);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('System Audit & Employee History'), actions: [
      IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: () => setState(() => _events = _load())),
    ]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: TextField(
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search employee, action, or section'),
        onChanged: (value) => setState(() => _query = value.toLowerCase().trim()),
      )),
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: _events, builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Audit history unavailable or access denied. Check server migration and permissions.'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!.where((e) => _query.isEmpty ||
          '${e['actor_id']} ${e['action']} ${e['section']} ${e['record_id']}'.toLowerCase().contains(_query)).toList();
        if (rows.isEmpty) return const Center(child: Text('No matching audit events.'));
        return ListView.builder(itemCount: rows.length, itemBuilder: (context, i) {
          final e = rows[i];
          return ListTile(
            leading: const Icon(Icons.history),
            title: Text('${e['action'] ?? 'Activity'} · ${e['section'] ?? 'System'}'),
            subtitle: Text('Employee ${e['actor_id'] ?? 'System'} · ${e['created_at'] ?? ''}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog<void>(context: context, builder: (ctx) => AlertDialog(
              title: const Text('Audit event details'),
              content: SingleChildScrollView(child: SelectableText(
                'Event: ${e['id']}\nEmployee: ${e['actor_id'] ?? 'System'}\nSection: ${e['section']}\nAction: ${e['action']}\nRecord: ${e['record_id']}\nTime (UTC): ${e['created_at']}\nPrevious: ${e['before_data'] ?? '—'}\nNew: ${e['after_data'] ?? '—'}')),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
            )),
          );
        });
      })),
    ]),
  );
}
