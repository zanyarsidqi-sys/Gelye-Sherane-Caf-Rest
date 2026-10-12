import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Administrative device registry. Registration does not authenticate a device.
class StationDevicePanel extends StatefulWidget {
  const StationDevicePanel({super.key});
  @override
  State<StationDevicePanel> createState() => _StationDevicePanelState();
}

class _StationDevicePanelState extends State<StationDevicePanel> {
  final _name = TextEditingController();
  final _reference = TextEditingController();
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _stations = [];
  String? _station;
  String _type = 'tablet';
  final _employeeId = TextEditingController();
  String? _deviceForUser;
  bool _busy = false;
  String? _error;

  @override
  void initState() { super.initState(); _reload(); }
  @override
  void dispose() { _name.dispose(); _reference.dispose(); _employeeId.dispose(); super.dispose(); }

  Future<void> _reload() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final client = Supabase.instance.client;
      final raw = await Future.wait([
        client.rpc('gs_station_device_directory'),
        client.rpc('gs_station_assignment_directory'),
      ]);
      if (!mounted) return;
      final devices = (raw[0] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final stationMap = <String, Map<String, dynamic>>{};
      for (final value in raw[1] as List) {
        final row = Map<String, dynamic>.from(value as Map);
        final key = row['station_key']?.toString();
        if (key != null) stationMap[key] = row;
      }
      setState(() {
        _devices = devices;
        _stations = stationMap.values.toList();
        if (!stationMap.containsKey(_station)) _station = stationMap.isEmpty ? null : stationMap.keys.first;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load devices. Supervisor access is required.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({String? id, bool? enabled, Map<String, dynamic>? existing}) async {
    if (_busy) return;
    final station = existing?['station_key']?.toString() ?? _station;
    final name = existing?['display_name']?.toString() ?? _name.text.trim();
    final type = existing?['device_type']?.toString() ?? _type;
    final reference = existing?['device_reference']?.toString() ?? _reference.text.trim();
    if (station == null || name.isEmpty || name.length > 100 || reference.length > 160) {
      setState(() => _error = 'Select a station and enter a valid device name (1–100 characters).');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.rpc('gs_manage_station_device', params: {
        'p_id': id,
        'p_station_key': station,
        'p_name': name,
        'p_type': type,
        'p_reference': reference,
        'p_enabled': enabled ?? true,
      });
      if (!mounted) return;
      _name.clear(); _reference.clear();
    } catch (_) {
      if (mounted) setState(() => _error = 'Device could not be saved. Check MFA and your assigned Kitchen station permissions.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _reload();
  }

  Future<void> _assignDeviceUser({required bool active}) async {
    if (_busy || _deviceForUser == null || _employeeId.text.trim().isEmpty) return;
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.rpc('gs_assign_station_device_user', params: {
        'p_device_id': _deviceForUser,
        'p_employee_id': _employeeId.text.trim(),
        'p_active': active,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device employee authorization updated')));
    } catch (_) {
      if (mounted) setState(() => _error =
        'Unable to update device authorization. Verify employee ID and station assignment.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Station devices', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const Text('Register screens, tablets, POS terminals and printers. This registry does not authenticate hardware or configure printing.'),
    if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      value: _station,
      decoration: const InputDecoration(labelText: 'Station'),
      items: _stations.map((s) => DropdownMenuItem(value: s['station_key'].toString(), child: Text(s['station_name'].toString()))).toList(),
      onChanged: _busy ? null : (value) => setState(() => _station = value),
    ),
    TextField(controller: _name, maxLength: 100, decoration: const InputDecoration(labelText: 'Device name')),
    DropdownButtonFormField<String>(
      value: _type,
      decoration: const InputDecoration(labelText: 'Device type'),
      items: const ['tablet','screen','printer','pos','other'].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
      onChanged: _busy ? null : (value) { if (value != null) setState(() => _type = value); },
    ),
    TextField(controller: _reference, maxLength: 160, decoration: const InputDecoration(labelText: 'Optional device reference / printer label')),
    FilledButton(onPressed: _busy || _station == null ? null : () => _save(), child: const Text('Register device')),
    const Divider(),
    const Text('Authorize employee on device', style: TextStyle(fontWeight: FontWeight.bold)),
    const Text('Supervisor-only assignment. The employee must also have active station access. This is not hardware authentication.'),
    DropdownButtonFormField<String>(
      value: _devices.any((d) => d['id'] == _deviceForUser) ? _deviceForUser : null,
      decoration: const InputDecoration(labelText: 'Registered device'),
      items: _devices.where((d) => d['enabled'] == true).map((d) =>
        DropdownMenuItem<String>(value: d['id'].toString(), child: Text(d['display_name'].toString()))).toList(),
      onChanged: _busy ? null : (v) => setState(() => _deviceForUser = v),
    ),
    TextField(controller: _employeeId, decoration: const InputDecoration(labelText: 'Employee account UUID')),
    Wrap(spacing: 8, children: [
      FilledButton(onPressed: _busy ? null : () => _assignDeviceUser(active: true), child: const Text('Authorize')),
      OutlinedButton(onPressed: _busy ? null : () => _assignDeviceUser(active: false), child: const Text('Revoke')),
    ]),
    const Divider(),
    Text('Registered devices (${_devices.length})'),
    for (final device in _devices)
      ListTile(
        title: Text(device['display_name'].toString()),
        subtitle: Text('${device['station_name']} · ${device['device_type']} · ${device['device_reference'] ?? 'No reference'}'),
        trailing: Switch(
          value: device['enabled'] == true,
          onChanged: _busy ? null : (value) => _save(id: device['id'].toString(), enabled: value, existing: device),
        ),
      ),
    TextButton(onPressed: _busy ? null : _reload, child: const Text('Refresh devices')),
  ]);
}
