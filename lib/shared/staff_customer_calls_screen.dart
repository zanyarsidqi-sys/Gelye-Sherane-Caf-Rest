import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Staff-only customer call queue. Permission is also checked by each RPC.
class StaffCustomerCallsScreen extends StatefulWidget {
  const StaffCustomerCallsScreen({super.key});
  @override
  State<StaffCustomerCallsScreen> createState() => _StaffCustomerCallsScreenState();
}

class _StaffCustomerCallsScreenState extends State<StaffCustomerCallsScreen> {
  Timer? _poll;
  List<Map<String, dynamic>> _calls = [];
  String? _error;
  bool _loading = false;
  bool _initialLoadComplete = false;
  bool _firstFetchInProgress = true;
  bool _onlyWaiting = false;
  bool _urgentFirst = true;
  bool _canManage = false;
  static const _attentionAfter = Duration(minutes: 5);
  final Set<String> _updating = {};

  @override
  void initState() {
    super.initState();
    _load();
    _loadManagePermission();
    // Polling works without granting customer-call table SELECT privileges.
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _load());
  }

  Future<void> _load() async {
    if (_loading || !mounted) return;
    _loading = true;
    try {
      final result = await Supabase.instance.client.rpc('gs_staff_customer_call_queue');
      if (!mounted) return;
      final calls = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final hadLoaded = _initialLoadComplete;
      final newWaiting = calls.where((c) => c['status'] == 'waiting' &&
          !_calls.any((old) => old['id'] == c['id'])).length;
      setState(() { _calls = calls; _error = null; _initialLoadComplete = true; _firstFetchInProgress = false; });
      if (hadLoaded && newWaiting > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$newWaiting new customer assistance request(s)'),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load customer calls. Check your permissions or connection.');
    } finally { _loading = false; }
  }

  Future<void> _loadManagePermission() async {
    try {
      final allowed = await Supabase.instance.client.rpc('gs_staff_can_manage_customer_calls');
      if (mounted) setState(() => _canManage = allowed == true);
    } catch (_) {
      // Fail closed: employees may still view the queue, but cannot change it.
      if (mounted) setState(() => _canManage = false);
    }
  }

  Future<void> _change(Map<String, dynamic> call, String status) async {
    final id = call['id'].toString();
    if (!_canManage || _updating.contains(id)) return;
    setState(() => _updating.add(id));
    try {
      await Supabase.instance.client.rpc('gs_staff_update_customer_call', params: {
        'p_id': id, 'p_status': status,
      });
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not update request. It may belong to another employee.'),
      ));
    } finally {
      if (mounted) setState(() => _updating.remove(id));
    }
  }

  String _callLabel(String type) => switch (type) {
    'waiter' => 'Waiter assistance',
    'cashier' => 'Cashier / bill',
    'shisha' => 'Shisha service',
    'supervisor' => 'Supervisor',
    'any' => 'Any available employee',
    'specific_order' => 'Specific order / item',
    'extra_chairs' => 'Extra chairs',
    'long_wait' => 'Long wait / delayed order',
    'pick_dishes' => 'Pick up used dishes',
    'clean_table' => 'Clean table',
    _ => 'Customer assistance',
  };

  IconData _callIcon(String type) => switch (type) {
    'specific_order' => Icons.receipt_long,
    'extra_chairs' => Icons.chair_alt,
    'long_wait' => Icons.hourglass_bottom,
    'pick_dishes' => Icons.dining_outlined,
    'clean_table' => Icons.cleaning_services_outlined,
    'cashier' => Icons.payments_outlined,
    'shisha' => Icons.smoking_rooms,
    _ => Icons.notifications_active_outlined,
  };

  DateTime? _requestedAt(Map<String, dynamic> call) =>
      DateTime.tryParse(call['requested_at']?.toString() ?? '')?.toLocal();

  bool _needsAttention(Map<String, dynamic> call) {
    if (call['status'] != 'waiting') return false;
    final requested = _requestedAt(call);
    return call['call_type'] == 'long_wait' ||
        (requested != null && DateTime.now().difference(requested) >= _attentionAfter);
  }

  List<Map<String, dynamic>> get _visibleCalls {
    final calls = _calls.where((call) => !_onlyWaiting || call['status'] == 'waiting').toList();
    if (_urgentFirst) {
      calls.sort((a, b) {
        final priority = (_needsAttention(b) ? 1 : 0) - (_needsAttention(a) ? 1 : 0);
        if (priority != 0) return priority;
        return (_requestedAt(a) ?? DateTime.now()).compareTo(_requestedAt(b) ?? DateTime.now());
      });
    }
    return calls;
  }

  String _elapsed(Map<String, dynamic> call) {
    final requested = _requestedAt(call);
    if (requested == null) return 'Time unavailable';
    final age = DateTime.now().difference(requested);
    if (age.isNegative) return 'Just now';
    if (age.inHours > 0) return '${age.inHours}h ${age.inMinutes.remainder(60)}m ago';
    return '${age.inMinutes}m ago';
  }

  @override
  void dispose() { _poll?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.all(12), child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Customer Calls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text('${_calls.where((c) => c['status'] == 'waiting').length} waiting · ${_calls.where((c) => c['status'] != 'waiting').length} being handled',
          style: Theme.of(context).textTheme.bodySmall),
      ])),
      IconButton(tooltip: 'Refresh requests', onPressed: _load,
        icon: const Icon(Icons.refresh)),
    ])),
    if (!_canManage) const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Text('Read-only queue: Table Orders edit permission is required to accept or complete requests.'),
    ),
    if (_error != null) Padding(padding: const EdgeInsets.all(12),
      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    SwitchListTile(
      title: const Text('Show waiting requests only'),
      value: _onlyWaiting,
      onChanged: (value) => setState(() => _onlyWaiting = value),
    ),
    SwitchListTile(
      title: const Text('Show urgent requests first'),
      subtitle: const Text('Long waits and unanswered calls older than 5 minutes'),
      value: _urgentFirst,
      onChanged: (value) => setState(() => _urgentFirst = value),
    ),
    Expanded(child: _visibleCalls.isEmpty
      ? Center(child: Text(_error != null ? 'Customer call queue unavailable' : _firstFetchInProgress ? 'Loading customer calls…' : 'No active customer calls'))
      : ListView.builder(itemCount: _visibleCalls.length, itemBuilder: (context, index) {
        final call = _visibleCalls[index];
        final status = call['status']?.toString() ?? 'waiting';
        final busy = _updating.contains(call['id'].toString());
        return Card(child: Padding(padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(_callIcon(call['call_type']?.toString() ?? '')),
              const SizedBox(width: 8),
              Expanded(child: Text('Table ${call['table_id']} · ${_callLabel(call['call_type']?.toString() ?? '')}',
                style: const TextStyle(fontWeight: FontWeight.bold))),
            ]),
            Text('Status: $status · ${_elapsed(call)}'),
            if (_needsAttention(call))
              Padding(padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Icon(Icons.priority_high, color: Theme.of(context).colorScheme.error, size: 18),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Needs prompt attention',
                    style: TextStyle(color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold))),
                ])),
            if (call['call_type'] == 'long_wait')
              const Text('Priority: delayed service — please investigate promptly.'),
            if (call['call_type'] == 'extra_chairs')
              const Text('Confirm chair availability before fulfilling.'),
            if (call['assigned_employee'] != null)
              Text('Assigned employee: ${call['assigned_employee']}'),
            if ((call['note'] ?? '').toString().isNotEmpty) Text(call['note'].toString()),
            Wrap(spacing: 8, children: [
              if (status == 'waiting')
                FilledButton(onPressed: busy || !_canManage ? null : () => _change(call, 'accepted'),
                  child: const Text('Accept')),
              if (status == 'accepted')
                FilledButton(onPressed: busy || !_canManage ? null : () => _change(call, 'on_way'),
                  child: const Text('On my way')),
              if (status == 'accepted' || status == 'on_way')
                OutlinedButton(onPressed: busy || !_canManage ? null : () => _change(call, 'completed'),
                  child: const Text('Complete')),
            ]),
          ])));
      })),
  ]);
}
