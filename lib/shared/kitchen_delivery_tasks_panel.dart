import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-app ready-to-deliver inbox; server enforces station and employee permissions.
class KitchenDeliveryTasksPanel extends StatefulWidget {
  const KitchenDeliveryTasksPanel({super.key});
  @override
  State<KitchenDeliveryTasksPanel> createState() => _KitchenDeliveryTasksPanelState();
}

class _KitchenDeliveryTasksPanelState extends State<KitchenDeliveryTasksPanel> {
  final _employee = TextEditingController();
  List<Map<String, dynamic>> _tickets = [];
  bool _busy = false;
  int _loadGeneration = 0;
  String? _error;

  @override
  void initState() { super.initState(); _reload(); }
  @override
  void dispose() { _loadGeneration++; _employee.dispose(); super.dispose(); }

  Future<void> _reload() async {
    if (!mounted || _busy) return;
    final generation = ++_loadGeneration;
    setState(() { _busy = true; _error = null; });
    try {
      final result = await Supabase.instance.client.rpc('gs_list_ready_delivery_tasks');
      if (mounted && generation == _loadGeneration) setState(() => _tickets = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (_) {
      if (mounted && generation == _loadGeneration) setState(() => _error = 'Could not load delivery notifications.');
    } finally { if (mounted && generation == _loadGeneration) setState(() => _busy = false); }
  }

  Future<void> _action(String rpc, Map<String, dynamic> params) async {
    if (!mounted || _busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.rpc(rpc, params: params);
      final result = await Supabase.instance.client.rpc('gs_list_ready_delivery_tasks');
      if (mounted) setState(() => _tickets = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (_) {
      if (mounted) setState(() => _error = 'Action rejected. Check assignment and permissions.');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _assign(int id) async {
    _employee.clear();
    final employee = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Assign delivery employee'),
      content: TextField(controller: _employee,
          decoration: const InputDecoration(labelText: 'Employee UUID')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, _employee.text.trim()),
            child: const Text('Assign')),
      ],
    ));
    if (!mounted || employee == null ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(employee)) return;
    await _action('gs_assign_delivery_employee',
        {'p_ticket_id': id, 'p_employee_id': employee});
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Ready for Delivery', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const Text('In-app ready notifications. Refresh to check for newly prepared tickets.'),
    OutlinedButton(onPressed: _busy ? null : _reload, child: const Text('Refresh notifications')),
    if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
    for (final ticket in _tickets) Card(child: ListTile(
      title: Text('Order #${ticket['order_id']} · ${ticket['station_name']}'),
      subtitle: Text('Ready: ${ticket['ready_at']}\n'
          'Assigned: ${ticket['assigned_to'] ?? 'Unassigned'}\n'
          '${ticket['picked_up_at'] == null ? 'Waiting for pickup' : 'Picked up — waiting for delivery'}'),
      isThreeLine: true,
      trailing: Wrap(spacing: 4, children: [
        if (ticket['picked_up_at'] == null)
          IconButton(tooltip: 'Assign employee', icon: const Icon(Icons.person_add_alt_1),
            onPressed: _busy ? null : () => _assign((ticket['ticket_id'] as num).toInt())),
        if (ticket['assigned_to'] == Supabase.instance.client.auth.currentUser?.id &&
            ticket['accepted_at'] == null)
          TextButton(onPressed: _busy ? null : () => _action('gs_accept_delivery_assignment',
              {'p_ticket_id': ticket['ticket_id']}), child: const Text('Accept')),
        if (ticket['assigned_to'] == Supabase.instance.client.auth.currentUser?.id &&
            ticket['accepted_at'] != null)
          TextButton(onPressed: _busy ? null : () => _action('gs_record_station_handover',
              {'p_ticket_id': ticket['ticket_id'],
               'p_action': ticket['picked_up_at'] == null ? 'picked_up' : 'delivered'}),
            child: Text(ticket['picked_up_at'] == null ? 'Pickup' : 'Delivered')),
      ]),
    )),
  ]);
}
