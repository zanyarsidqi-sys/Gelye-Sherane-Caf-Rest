import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supervisor-only station assignment UI. Authorization is enforced by RPCs.
class StationAssignmentPanel extends StatefulWidget {
  const StationAssignmentPanel({super.key});

  @override
  State<StationAssignmentPanel> createState() => _StationAssignmentPanelState();
}

class _StationAssignmentPanelState extends State<StationAssignmentPanel> {
  final _employee = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _supervisor = false;
  String? _error;
  String? _station;
  List<Map<String, dynamic>> _rows = [];
  String? _loadedUserId;
  int _reloadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _employee.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final request = ++_reloadGeneration;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    setState(() { _loading = true; _error = null; _rows = []; _loadedUserId = null; });
    if (uid == null) {
      if (mounted) setState(() { _loading = false; _error = 'Employee sign-in required.'; });
      return;
    }
    try {
      final client = Supabase.instance.client;
      final allowed = await client.rpc('gs_is_station_supervisor') == true;
      final rows = allowed
          ? await client.rpc('gs_station_assignment_directory') as List<dynamic>
          : <dynamic>[];
      if (!mounted) return;
      final parsed = rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
      final stations = parsed.map((row) => row['station_key']?.toString()).whereType<String>().toSet();
      setState(() {
        _supervisor = allowed;
        _rows = parsed;
        if (!stations.contains(_station)) _station = stations.isEmpty ? null : stations.first;
      });
    } catch (_) {
      if (mounted && request == _reloadGeneration) setState(() { _error = 'Unable to load station assignments. Check permissions and retry.'; });
    } finally {
      if (mounted && request == _reloadGeneration) setState(() { _loading = false; });
    }
  }

  Future<void> _assign(String employeeId, bool active) async {
    if (_saving || _station == null || _loadedUserId == null ||
        Supabase.instance.client.auth.currentUser?.id != _loadedUserId) return;
    final uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (!uuid.hasMatch(employeeId)) {
      setState(() { _error = 'Enter a valid employee account UUID.'; });
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await Supabase.instance.client.rpc('gs_assign_station_employee', params: {
        'p_station_key': _station,
        'p_employee_id': employeeId,
        'p_active': active,
      });
      if (!mounted) return;
      _employee.clear();
      await _reload();
    } catch (_) {
      if (mounted) setState(() { _error = 'Assignment failed. Confirm the employee exists and you are an authorized supervisor.'; });
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && !_supervisor) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!), TextButton(onPressed: _reload, child: const Text('Retry')),
      ]));
    }
    if (!_supervisor) return const Center(child: Text('Station supervisor access required.'));
    if (_loadedUserId == null || Supabase.instance.client.auth.currentUser?.id != _loadedUserId) {
      return Center(child: FilledButton(onPressed: _reload, child: const Text('Session changed — reload')));
    }
    final stationNames = <String, String>{};
    for (final row in _rows) {
      final key = row['station_key']?.toString();
      if (key != null) stationNames[key] = row['station_name']?.toString() ?? key;
    }
    final visible = _rows.where((row) => row['station_key'] == _station && row['employee_id'] != null).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Station employee assignments', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Assign existing employee account IDs. Staff must also have Kitchen permissions.'),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _station,
        decoration: const InputDecoration(labelText: 'Preparation station'),
        items: stationNames.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: _saving ? null : (value) => setState(() { _station = value; }),
      ),
      const SizedBox(height: 12),
      TextField(controller: _employee, decoration: const InputDecoration(labelText: 'Employee account UUID')),
      const SizedBox(height: 8),
      FilledButton(onPressed: _saving || _station == null ? null : () => _assign(_employee.text.trim(), true),
        child: const Text('Assign employee')),
      if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
      const Divider(),
      Text('Assigned employees (${visible.length})'),
      for (final row in visible)
        ListTile(
          title: Text(row['employee_id'].toString()),
          subtitle: Text(row['active'] == true ? 'Active' : 'Inactive'),
          trailing: Switch(
            value: row['active'] == true,
            onChanged: _saving ? null : (active) => _assign(row['employee_id'].toString(), active),
          ),
        ),
      TextButton(onPressed: _saving ? null : _reload, child: const Text('Refresh assignments')),
    ]);
  }
}
