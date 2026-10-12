import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Staff-facing service and cleaning tasks. Server RPCs enforce authorization.
class KitchenServiceTasksPanel extends StatefulWidget {
  const KitchenServiceTasksPanel({super.key});
  @override
  State<KitchenServiceTasksPanel> createState() => _KitchenServiceTasksPanelState();
}

class _KitchenServiceTasksPanelState extends State<KitchenServiceTasksPanel> {
  final _table = TextEditingController();
  final _notes = TextEditingController();
  final _employee = TextEditingController();
  String _type = 'dish_pickup';
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _tasks = [];
  final _types = const ['dish_pickup','table_cleaning','utensils','napkins','water','shisha_coal','other'];

  @override
  void initState() { super.initState(); _reload(); }
  @override
  void dispose() { _table.dispose(); _notes.dispose(); _employee.dispose(); super.dispose(); }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      final rows = await Supabase.instance.client.rpc('gs_list_service_tasks', params: {'p_limit': 150}) as List<dynamic>;
      if (mounted) setState(() => _tasks = rows.map((r) => Map<String,dynamic>.from(r as Map)).toList());
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load service tasks. Check access and retry.');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _create() async {
    if (_busy || _table.text.trim().isEmpty || _table.text.trim().length > 80 || _notes.text.length > 500) return;
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.rpc('gs_create_service_task', params: {
        'p_table_label': _table.text.trim(), 'p_task_type': _type, 'p_notes': _notes.text.trim(),
      });
      _notes.clear();
      await _reload();
    } catch (_) { if (mounted) setState(() => _error = 'Could not create task. Confirm your permissions.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _act(int id, String action, {String? employee}) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.rpc('gs_transition_service_task', params: {
        'p_task_id': id, 'p_action': action, 'p_employee_id': employee,
      });
      await _reload();
    } catch (_) { if (mounted) setState(() => _error = 'Task update rejected. Check assignment, status and permissions.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _assign(int id) async {
    _employee.clear();
    final employee = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: const Text('Assign service employee'),
      content: TextField(controller: _employee, decoration: const InputDecoration(labelText: 'Employee UUID')),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _employee.text.trim()), child: const Text('Assign'))],
    ));
    if (!mounted || employee == null || !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(employee)) return;
    await _act(id, 'assign', employee: employee);
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Service requests & cleaning', style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    TextField(controller: _table, maxLength: 80, decoration: const InputDecoration(labelText: 'Table number or label')),
    DropdownButtonFormField<String>(value: _type, decoration: const InputDecoration(labelText: 'Request type'),
      items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t.replaceAll('_',' ')))).toList(),
      onChanged: _busy ? null : (v) { if (v != null) setState(() => _type = v); }),
    TextField(controller: _notes, maxLength: 500, decoration: const InputDecoration(labelText: 'Instructions (optional)')),
    FilledButton(onPressed: _busy ? null : _create, child: const Text('Create task')),
    OutlinedButton(onPressed: _busy ? null : _reload, child: const Text('Refresh tasks')),
    if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
    for (final t in _tasks) Card(child: ExpansionTile(
      title: Text('${t['table_label']} · ${t['task_type'].toString().replaceAll('_',' ')}'),
      subtitle: Text('${t['status']} · Requested ${t['requested_at']}'),
      children: [
        if (t['notes'] != null) ListTile(title: const Text('Instructions'), subtitle: Text('${t['notes']}')),
        ListTile(title: const Text('Assigned employee'), subtitle: Text('${t['assigned_to'] ?? 'Not assigned'}')),
        if (t['accepted_at'] != null) ListTile(title: const Text('Accepted'), subtitle: Text('${t['accepted_at']}')),
        if (t['completed_at'] != null) ListTile(title: const Text('Completed'), subtitle: Text('${t['completed_at']}')),
        Wrap(spacing: 8, children: [
          if (t['status'] == 'new' || t['status'] == 'assigned')
            OutlinedButton(onPressed: _busy ? null : () => _assign((t['id'] as num).toInt()), child: const Text('Assign')),
          if (t['status'] == 'assigned' && t['assigned_to'] == Supabase.instance.client.auth.currentUser?.id)
            FilledButton(onPressed: _busy ? null : () => _act((t['id'] as num).toInt(), 'accept'), child: const Text('Accept')),
          if (t['status'] == 'accepted' && t['assigned_to'] == Supabase.instance.client.auth.currentUser?.id)
            FilledButton(onPressed: _busy ? null : () => _act((t['id'] as num).toInt(), 'complete'), child: const Text('Complete')),
          if (t['status'] != 'completed' && t['status'] != 'cancelled')
            TextButton(onPressed: _busy ? null : () => _act((t['id'] as num).toInt(), 'cancel'), child: const Text('Cancel')),
        ]),
        FutureBuilder<dynamic>(future: Supabase.instance.client.rpc('gs_service_task_history',params: {'p_task_id': t['id']}),
          builder: (context,snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final events = snapshot.data as List<dynamic>;
            return Column(children: [const ListTile(title: Text('Task history')),
              for (final event in events) ListTile(dense: true,
                title: Text('${event['event_type']} by ${event['actor_id']}'),
                subtitle: Text('${event['event_at']}'))]);
          }),
      ],
    )),
  ]);
}
