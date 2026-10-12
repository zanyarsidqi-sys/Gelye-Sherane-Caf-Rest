import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only handoff visibility; actions remain in permission-checked Kitchen RPCs.
class TableOrdersReplacementDeliveryProgress extends StatefulWidget {
  const TableOrdersReplacementDeliveryProgress({super.key});
  @override
  State<TableOrdersReplacementDeliveryProgress> createState() =>
      _TableOrdersReplacementDeliveryProgressState();
}

class _TableOrdersReplacementDeliveryProgressState
    extends State<TableOrdersReplacementDeliveryProgress> {
  Timer? _timer;
  bool _busy = false;
  int _loadGeneration = 0;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];
  List<Map<String, dynamic>> _notifications = const [];
  List<Map<String, dynamic>> _handoffs = const [];
  List<Map<String, dynamic>> _issues = const [];
  final _orderId = TextEditingController();
  bool _showOnlyIssues = false;

  String _issueDescription(String code) {
    const descriptions = <String, String>{
      'READY_WITHOUT_DELIVERY_TASK': 'Ready item has no delivery task',
      'TASK_BEFORE_READY': 'Delivery task exists before preparation is ready',
      'READY_WITHOUT_TIMESTAMP': 'Ready item is missing its ready timestamp',
      'DELIVERED_WITHOUT_PICKUP': 'Delivered without a recorded pickup',
      'PICKED_UP_WITHOUT_ACCEPTANCE': 'Picked up without employee acceptance',
      'ACCEPTED_WITHOUT_ASSIGNEE': 'Accepted without an assigned employee',
      'ASSIGNED_WITHOUT_TIMESTAMP': 'Assignment is missing its timestamp',
      'UNASSIGNED_WITH_ACCEPTANCE': 'Unassigned task still shows acceptance',
      'ACCEPTED_BEFORE_ASSIGNMENT': 'Acceptance predates assignment',
      'PICKUP_BEFORE_ACCEPTANCE': 'Pickup predates acceptance',
      'DELIVERY_BEFORE_PICKUP': 'Delivery predates pickup',
      'TASK_CREATED_BEFORE_READY': 'Delivery task predates ready time',
      'DELIVERY_WITHOUT_EVENT': 'Delivered status lacks an audit event',
      'PICKUP_WITHOUT_EVENT': 'Pickup status lacks an audit event',
    };
    return descriptions[code] ?? code;
  }

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _loadGeneration++;
    _orderId.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy || !mounted) return;
    final text = _orderId.text.trim();
    final id = text.isEmpty ? null : int.tryParse(text);
    if (text.isNotEmpty && (id == null || id <= 0)) {
      setState(() => _error = 'Enter a valid positive order number.');
      return;
    }
    _busy = true;
    final generation = ++_loadGeneration;
    try {
      final data = await Supabase.instance.client.rpc(
        'gs_table_orders_replacement_delivery_progress',
        params: {'p_order_id': id},
      );
      final notices = await Supabase.instance.client.rpc(
        'gs_list_table_replacement_notifications',
        params: {'p_order_id': id},
      );
      final history = await Supabase.instance.client.rpc(
        'gs_table_replacement_handoff_history', params: {'p_order_id': id});
      final issues = await Supabase.instance.client.rpc(
        'gs_replacement_handoff_consistency', params: {'p_order_id': id});
      if (mounted && generation == _loadGeneration) setState(() {
        _handoffs = (history as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _issues = (issues as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _notifications = (notices as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _error = null;
      });
    } catch (_) {
      if (mounted && generation == _loadGeneration) setState(() => _error =
          'Unable to load delivery progress. Check permissions or connection.');
    } finally {
      if (generation == _loadGeneration) _busy = false;
    }
  }

  Future<void> _markRead(int notificationId) async {
    if (!mounted) return;
    try {
      await Supabase.instance.client.rpc(
        'gs_mark_table_replacement_notification_read',
        params: {'p_notification_id': notificationId},
      );
      // The read RPC can finish during an existing poll; invalidate and refresh
      // only after that poll finishes, without issuing overlapping requests.
      if (!mounted) return;
      if (_busy) {
        _loadGeneration++;
        _busy = false;
      }
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to mark notification as read.');
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(child: TextField(
          controller: _orderId,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Order number (optional)',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _load(),
        )),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh),
          tooltip: 'Refresh delivery progress'),
      ]),
    ),
    if (_error != null) Padding(
      padding: const EdgeInsets.all(8),
      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ),
    if (_notifications.isNotEmpty) SizedBox(
      height: 190,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            const Expanded(child: Text('Replacement delivery notifications',
              style: TextStyle(fontWeight: FontWeight.bold))),
            Chip(label: Text('${_notifications.where((n) => n['is_read'] != true).length} unread')),
          ]),
        ),
        Expanded(child: ListView.builder(
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            final n = _notifications[index];
            final read = n['is_read'] == true;
            final event = (n['event_kind'] ?? '').toString();
            final label = event == 'picked_up' ? 'Picked up'
              : event == 'accepted' ? 'Accepted' : 'Delivered';
            return ListTile(
              dense: true,
              leading: Icon(read ? Icons.notifications_none : Icons.notifications_active),
              title: Text('Order #${n['order_id']} · $label'),
              subtitle: Text('Replacement #${n['revision_id']} · ${n['created_at'] ?? ''}'),
              trailing: read ? const Icon(Icons.done) : TextButton(
                onPressed: () => _markRead(n['notification_id'] as int),
                child: const Text('Mark seen'),
              ),
            );
          },
        )),
      ]),
    ),
    if (_issues.isNotEmpty) Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(child: ListTile(
        leading: const Icon(Icons.warning_amber_outlined),
        title: Text('${_issues.length} delivery consistency issue(s)'),
        subtitle: Text(_issues.take(3).map((e) =>
          'Order #${e['order_id']}: ${_issueDescription((e['issue_code'] ?? '').toString())}').join(' • ')),
      )),
    ),
    if (_issues.isNotEmpty) ExpansionTile(
      title: const Text('Review all consistency findings'),
      children: [SizedBox(height: 180, child: ListView.builder(
        itemCount: _issues.length,
        itemBuilder: (context, index) {
          final issue = _issues[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.report_problem_outlined),
            title: Text('Order #${issue['order_id']} · Replacement #${issue['revision_id']}'),
            subtitle: Text(_issueDescription((issue['issue_code'] ?? '').toString())),
          );
        },
      ))],
    ),
    if (_handoffs.isNotEmpty) ExpansionTile(
      title: Text('Employee handoff history (${_handoffs.length})'),
      children: [SizedBox(height: 220, child: ListView.builder(
        itemCount: _handoffs.length,
        itemBuilder: (context, index) {
          final h = _handoffs[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.history),
            title: Text('Order #${h['order_id']} · ${h['event_kind']}'),
            subtitle: Text('By ${h['actor_name']} · ${h['event_at']}'),
            trailing: h['assigned_employee_name'] == null ? null
              : Text('To: ${h['assigned_employee_name']}'),
          );
        },
      ))],
    ),
    SwitchListTile(
      dense: true,
      title: const Text('Show only replacements with consistency issues'),
      value: _showOnlyIssues,
      onChanged: (value) => setState(() => _showOnlyIssues = value),
    ),
    Expanded(child: _rows.where((r) => !_showOnlyIssues || _issues.any(
      (issue) => issue['revision_id'] == r['revision_id'])).isEmpty
      ? const Center(child: Text('No replacement deliveries found.'))
      : ListView.builder(
        itemCount: _rows.where((r) => !_showOnlyIssues || _issues.any(
          (issue) => issue['revision_id'] == r['revision_id'])).length,
        itemBuilder: (context, index) {
          final filteredRows = _rows.where((r) => !_showOnlyIssues || _issues.any(
            (issue) => issue['revision_id'] == r['revision_id'])).toList();
          final r = filteredRows[index];
          final status = (r['delivery_status'] ?? 'Preparing').toString();
          final delivered = status == 'Delivered';
          return Card(child: ListTile(
            leading: Icon(delivered ? Icons.check_circle : Icons.local_shipping_outlined,
              color: delivered ? Colors.green : null),
            title: Text('Order #${r['order_id']} · ${r['product_name']} × ${r['quantity']}'),
            subtitle: Text('Station: ${r['station_key']} · ${r['preparation_state']}\n'
              'Delivery: $status · Employee: ${r['assigned_employee'] ?? 'Unassigned'}'),
            isThreeLine: true,
            trailing: Text('Revision #${r['revision_id']}'),
          ));
        },
      )),
  ]);
}
