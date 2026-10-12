import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Device-local maintenance drafts. Not a shared task or dispatch system.
class MaintenanceWorkspacePanel extends StatefulWidget {
  const MaintenanceWorkspacePanel({super.key});

  @override
  State<MaintenanceWorkspacePanel> createState() => _MaintenanceWorkspacePanelState();
}

class _MaintenanceWorkspacePanelState extends State<MaintenanceWorkspacePanel> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _assignee = TextEditingController();
  final _details = TextEditingController();
  List<Map<String, dynamic>> _records = [];
  String _priority = 'Normal';
  String _filter = 'All';
  bool _loading = true;

  String? get _storageKey {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return userId == null ? null : 'maintenance_drafts_v1_$userId';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = _storageKey;
    if (key == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      final decoded = raw == null ? <dynamic>[] : jsonDecode(raw) as List<dynamic>;
      if (mounted) {
        setState(() {
          _records = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final key = _storageKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(_records));
  }

  Future<void> _create() async {
    if (_title.text.trim().isEmpty) return;
    setState(() {
      _records.insert(0, {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'title': _title.text.trim(),
        'location': _location.text.trim(),
        'assignee': _assignee.text.trim(),
        'details': _details.text.trim(),
        'priority': _priority,
        'status': 'Open',
        'created': DateTime.now().toIso8601String(),
      });
    });
    await _save();
    _title.clear();
    _location.clear();
    _assignee.clear();
    _details.clear();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _changeStatus(String id, String status) async {
    setState(() {
      final index = _records.indexWhere((r) => r['id'] == id);
      if (index >= 0) _records[index]['status'] = status;
    });
    await _save();
  }

  void _newRequest() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New maintenance draft'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: _title, decoration: const InputDecoration(labelText: 'Issue *')),
                TextField(controller: _location, decoration: const InputDecoration(labelText: 'Location / equipment')),
                TextField(controller: _assignee, decoration: const InputDecoration(labelText: 'Suggested assignee (not notified)')),
                TextField(controller: _details, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: ['Low', 'Normal', 'High', 'Urgent']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (value) => setDialogState(() => _priority = value ?? 'Normal'),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            FilledButton(onPressed: _create, child: const Text('Save draft')),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _assignee.dispose();
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final visible = _records.where((r) => _filter == 'All' || r['status'] == _filter).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Card(child: ListTile(
        leading: Icon(Icons.phone_iphone),
        title: Text('Device-only maintenance drafts'),
        subtitle: Text('Saved for this signed-in user on this device. No Supabase sync, staff notification or real assignment.'),
      )),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Text('Maintenance', style: Theme.of(context).textTheme.headlineSmall)),
        FilledButton.icon(onPressed: _storageKey == null ? null : _newRequest,
          icon: const Icon(Icons.add), label: const Text('New draft')),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: ['All', 'Open', 'In Progress', 'Resolved']
        .map((status) => ChoiceChip(label: Text(status), selected: _filter == status,
          onSelected: (_) => setState(() => _filter = status))).toList()),
      const SizedBox(height: 12),
      if (visible.isEmpty) const Center(child: Padding(
        padding: EdgeInsets.all(28), child: Text('No maintenance drafts match this filter.'))),
      for (final record in visible)
        Card(child: ExpansionTile(
          title: Text(record['title']?.toString() ?? ''),
          subtitle: Text('${record['priority']} priority • ${record['status']} • ${record['location']}'),
          childrenPadding: const EdgeInsets.all(12),
          children: [
            Align(alignment: Alignment.centerLeft, child: Text(record['details']?.toString() ?? '')),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: Text('Suggested assignee: ${record['assignee']}')),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: ['Open', 'In Progress', 'Resolved'].map((status) =>
              OutlinedButton(onPressed: () => _changeStatus(record['id'].toString(), status),
                child: Text(status))).toList()),
          ],
        )),
    ]);
  }
}
