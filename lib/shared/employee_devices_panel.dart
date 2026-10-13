import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeDevicesPanel extends StatefulWidget {
  const EmployeeDevicesPanel({super.key});

  @override
  State<EmployeeDevicesPanel> createState() => _EmployeeDevicesPanelState();
}

class _EmployeeDevicesPanelState extends State<EmployeeDevicesPanel> {
  bool _loading = true;
  bool _acting = false;
  bool _refreshing = false;
  bool _canRevoke = false;
  int _onlineCount = 0;
  List<Map<String, dynamic>> _devices = [];
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDevices(showLoading: true);
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_acting && !_loading) _loadDevices();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDevices({bool showLoading = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_list_online_employee_devices',
      ).timeout(const Duration(seconds: 12));
      final data = Map<String, dynamic>.from(result as Map);
      final devices = (data['devices'] as List? ?? const [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _onlineCount = (data['online_count'] as num?)?.toInt() ?? devices.length;
        _canRevoke = data['can_revoke'] == true;
        _devices = devices;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Could not load active devices. Owner/manager access and the device-presence migration are required.';
        _loading = false;
      });
    } finally {
      _refreshing = false;
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _revokeDevice(Map<String, dynamic> device) async {
    final employee = device['employee_name']?.toString() ?? 'Employee';
    final label = device['device_label']?.toString() ?? 'Device';
    final accepted = await _confirm(
      title: 'Sign out this device?',
      message:
          '$employee will lose access on $label. Permission-checked app '
          'actions stop immediately; the app signs out on its next check, '
          'within 30 seconds.',
      confirmLabel: 'Sign out device',
    );
    if (!accepted || !mounted) return;

    setState(() => _acting = true);
    try {
      final revoked = await Supabase.instance.client.rpc(
        'gs_revoke_employee_device',
        params: {
          'p_user_id': device['user_id'],
          'p_session_id': device['session_id'],
        },
      ).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (revoked == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$employee’s device signed out.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That device is no longer online.')),
        );
      }
      await _loadDevices(showLoading: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not sign out this device.')),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _revokeOthers() async {
    final count =
        _devices.where((device) => device['is_current'] != true).length;
    if (count == 0) return;
    final accepted = await _confirm(
      title: 'Sign out all other online devices?',
      message:
          'This signs out $count other employee device${count == 1 ? '' : 's'}. '
          'Your current device stays signed in.',
      confirmLabel: 'Sign out devices',
    );
    if (!accepted || !mounted) return;

    setState(() => _acting = true);
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_revoke_other_online_employee_devices',
      ).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      final revoked = (result as num?)?.toInt() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$revoked device${revoked == 1 ? '' : 's'} signed out.'),
      ),
      );
      await _loadDevices(showLoading: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not sign out online devices.')),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  String _lastSeen(Object? raw) {
    final value = raw?.toString();
    final timestamp = value == null ? null : DateTime.tryParse(value);
    if (timestamp == null) return 'Last active time unavailable';
    return 'Last active ${timestamp.toLocal().toString().substring(0, 16)}';
  }

  Widget _deviceTile(Map<String, dynamic> device) {
    final current = device['is_current'] == true;
    final name = device['employee_name']?.toString() ?? 'Employee';
    final role = device['role']?.toString() ?? 'Staff';
    final label = device['device_label']?.toString() ?? 'Device';
    final userAgent = device['user_agent']?.toString() ?? '';
    return Card(
      child: ListTile(
        leading: Icon(
          label == 'Web app' ? Icons.web : Icons.phone_android,
        ),
        title: Text('$name · $role'),
        subtitle: Text(
          '$label${userAgent.isEmpty ? '' : '\n$userAgent'}\n${_lastSeen(device['last_seen_at'])}',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: current
            ? const Chip(label: Text('This device'))
            : !_canRevoke
                ? null
                : TextButton(
                onPressed: _acting ? null : () => _revokeDevice(device),
                child: const Text('Sign out'),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.devices_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$_onlineCount devices online now',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh devices',
                        onPressed: _loading || _acting
                            ? null
                            : () => _loadDevices(showLoading: true),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const Text(
                    'Online means an employee app sent a heartbeat in the last 2 minutes.',
                  ),
                  if (_canRevoke &&
                      _devices.any((device) => device['is_current'] != true))
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: OutlinedButton.icon(
                        onPressed: _acting ? null : _revokeOthers,
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign out all other online devices'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              ),
            )
          else if (_devices.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No employee devices have checked in recently.'),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                itemCount: _devices.length,
                itemBuilder: (context, index) => _deviceTile(_devices[index]),
              ),
            ),
        ],
      );
}
