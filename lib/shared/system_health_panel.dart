import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only diagnostics. Never displays secrets or modifies database records.
class SystemHealthPanel extends StatefulWidget {
  const SystemHealthPanel({super.key});

  @override
  State<SystemHealthPanel> createState() => _SystemHealthPanelState();
}

class _SystemHealthPanelState extends State<SystemHealthPanel> {
  bool _checking = false;
  String _session = 'Not checked';
  String _database = 'Not checked';
  DateTime? _checkedAt;

  Future<void> _runChecks() async {
    if (_checking) return;
    setState(() => _checking = true);
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final session = user == null ? 'No signed-in user' : 'Signed in';
    String database;
    try {
      // A minimal, read-only request; access is subject to Supabase RLS.
      await client.from('products').select('id').limit(1);
      database = 'Reachable (products read permitted)';
    } on PostgrestException catch (e) {
      database = 'Request denied or schema mismatch (code: ${e.code ?? 'unknown'})';
    } catch (_) {
      database = 'Unable to confirm connection';
    }
    if (!mounted) return;
    setState(() {
      _session = session;
      _database = database;
      _checkedAt = DateTime.now();
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Read-only diagnostics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Checks the current authentication session and attempts a limited Supabase read. No records are changed.'),
        const SizedBox(height: 16),
        ListTile(leading: const Icon(Icons.person_outline), title: const Text('Authentication'), subtitle: Text(_session)),
        ListTile(leading: const Icon(Icons.storage_outlined), title: const Text('Supabase products read'), subtitle: Text(_database)),
        if (_checkedAt != null) Text('Last checked: ${_checkedAt!.toLocal()}', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _checking ? null : _runChecks,
          icon: _checking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
          label: Text(_checking ? 'Checking…' : 'Run diagnostics'),
        ),
        const SizedBox(height: 12),
        const Text('A successful read does not prove all tables, payment flows, or RLS policies are correct. Those require separate tests.'),
      ],
    ),
  );
}
