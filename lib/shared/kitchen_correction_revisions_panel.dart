import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Station revision notices. Acknowledgment is not proof of physical printing
/// or cancellation of a previously dispatched ticket.
class KitchenCorrectionRevisionsPanel extends StatefulWidget {
  const KitchenCorrectionRevisionsPanel({super.key});

  @override
  State<KitchenCorrectionRevisionsPanel> createState() =>
      _KitchenCorrectionRevisionsPanelState();
}

class _KitchenCorrectionRevisionsPanelState
    extends State<KitchenCorrectionRevisionsPanel> {
  List<Map<String, dynamic>> _revisions = [];
  bool _loading = false;
  List<Map<String, dynamic>> _deliveries = [];
  String? _error;
  Timer? _refreshTimer;
  List<Map<String,dynamic>> _overdue = [];
  Map<String,dynamic> _counts = {};
  List<Map<String,dynamic>> _escalations = [];
  List<Map<String,dynamic>> _myNotifications = [];
  static const _alertAfterMinutes = 15;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Permission-scoped polling; does not require exposing RLS-protected tables.
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted || _loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await Supabase.instance.client
          .rpc('gs_kitchen_correction_revision_queue') as List<dynamic>;
      final deliveryRows = await Supabase.instance.client.rpc('gs_replacement_delivery_priority_inbox', params: {'p_threshold_minutes': _alertAfterMinutes}) as List<dynamic>;
      final overdueRows = await Supabase.instance.client.rpc('gs_replacement_delivery_overdue', params: {'p_threshold_minutes': _alertAfterMinutes}) as List<dynamic>;
      final countRows = await Supabase.instance.client.rpc('gs_replacement_delivery_notification_counts', params: {'p_threshold_minutes': _alertAfterMinutes}) as List<dynamic>;
      final notificationRows = await Supabase.instance.client.rpc(
          'gs_my_replacement_delivery_notifications') as List<dynamic>;
      // Supervisor polling performs idempotent escalation, not just a manual button.
      try { await Supabase.instance.client.rpc('gs_supervisor_auto_escalation_poll',
          params: {'p_threshold_minutes': _alertAfterMinutes}); }
      catch (_) { /* Non-supervisors are not authorized to escalate. */ }
      // Supervisor-only inbox. Ordinary station employees must not see other employees' assignments.
      List<dynamic> escalationRows = [];
      try { escalationRows = await Supabase.instance.client.rpc('gs_replacement_delivery_escalation_inbox') as List<dynamic>; }
      catch (_) { /* Non-supervisors cannot access the escalation inbox. */ }
      if (mounted) {
        _counts = countRows.isEmpty ? {} : Map<String,dynamic>.from(countRows.first as Map);
        _myNotifications = notificationRows.map((e) => Map<String,dynamic>.from(e as Map)).toList();
        _escalations = escalationRows.map((e) => Map<String,dynamic>.from(e as Map)).toList();
        _overdue = overdueRows.map((row) => Map<String,dynamic>.from(row as Map)).toList();
        _deliveries = deliveryRows.map((row) => Map<String,dynamic>.from(row as Map)).toList();
        setState(() => _revisions = rows
            .map((row) => Map<String, dynamic>.from(row as Map)).toList());
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load correction notices. Check Kitchen access.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ackNotification(int revisionId) async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.rpc('gs_ack_replacement_delivery_notification',
          params: {'p_revision_id': revisionId});
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not acknowledge this assignment.');
    } finally { if (mounted) setState(() => _loading = false); }
    await _refresh();
  }

  Future<void> _escalate() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.rpc('gs_escalate_overdue_replacement_deliveries',
          params: {'p_threshold_minutes': _alertAfterMinutes});
    } catch (_) {
      if (mounted) setState(() => _error = 'Only an authorized Kitchen supervisor can escalate overdue tasks.');
    } finally { if (mounted) setState(() => _loading = false); }
    await _refresh();
  }

  Future<void> _acknowledge(int id, {bool unableToStop = false}) async {
    if (_loading) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(unableToStop ? 'Confirm item already prepared?' : 'Acknowledge station notice?'),
        content: Text(unableToStop
            ? 'Use only when the incorrect item cannot be stopped. This records the preparation outcome; waste quantity and inventory reconciliation still require separate confirmation.'
            : 'Confirm the employee has seen this notice. This does not automatically cancel or print any physical ticket.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.rpc('gs_ack_correction_station_revision', params: {
        'p_revision_id': id,
        'p_unable_to_stop': unableToStop,
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Action rejected. Check station permissions and retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    await _refresh();
  }

  Future<void> _transition(int id, String action, {String? employeeId}) async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (action == 'accept' || action == 'prepare' || action == 'ready') {
        await Supabase.instance.client.rpc('gs_transition_replacement_preparation', params: {'p_revision_id': id, 'p_action': action});
      } else {
        await Supabase.instance.client.rpc('gs_transition_replacement_delivery', params: {
          'p_revision_id': id, 'p_action': action == 'accept_delivery' ? 'accept' : action, 'p_employee_id': employeeId,
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Action rejected. Check employee assignment, permissions and current status.');
    } finally { if (mounted) setState(() => _loading = false); }
    await _refresh();
  }

  Future<void> _assign(int id, String stationKey) async {
    List<Map<String,dynamic>> options;
    try {
      final rows = await Supabase.instance.client.rpc(
        'gs_replacement_delivery_eligible_employees',
        params: {'p_station_key': stationKey}) as List<dynamic>;
      options = rows.map((r) => Map<String,dynamic>.from(r as Map)).toList();
    } catch (_) {
      if (mounted) setState(() => _error = 'Only authorized supervisors can assign employees.');
      return;
    }
    if (!mounted) return;
    final employee = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: const Text('Assign replacement delivery'),
      content: SizedBox(width: 380, child: options.isEmpty
        ? const Text('No active employees assigned to this station.')
        : ListView(shrinkWrap: true, children: [for (final option in options)
          ListTile(title: Text('${option['employee_name']}'),
            onTap: () => Navigator.pop(c, '${option['employee_id']}'))])),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel'))],
    ));
    if (employee != null && mounted) await _transition(id,'assign',employeeId:employee);
  }

  @override
  Widget build(BuildContext context) {
    final pending = _revisions.where((r) => r['state'] == 'pending').length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Wrong Order & Replacement Notices', style: Theme.of(context).textTheme.titleLarge),
      Text('$pending pending notices. Stop incorrect preparation when possible; prepare the correct replacement.'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Chip(label: Text('Unassigned: ${_counts['ready_unassigned'] ?? 0}')),
        Chip(label: Text('My tasks: ${_counts['my_assigned'] ?? 0}')),
        Chip(label: Text('Awaiting acceptance: ${_counts['my_unaccepted'] ?? 0}')),
        Chip(label: Text('Pickup: ${_counts['my_awaiting_pickup'] ?? 0}')),
        Chip(label: Text('Delivery: ${_counts['my_awaiting_delivery'] ?? 0}')),
        Chip(label: Text('Overdue: ${_counts['overdue_total'] ?? 0}')),
      ]),
      if (_myNotifications.isNotEmpty) ...[
        Text('My delivery notifications (${_myNotifications.where((n) => n['acknowledged_at'] == null).length} unread)',
            style: Theme.of(context).textTheme.titleMedium),
        for (final notice in _myNotifications) ListTile(
          leading: Icon(notice['acknowledged_at'] == null ? Icons.notifications_active : Icons.done_all),
          title: Text('Order #${notice['order_id']} · ${notice['station_key']}'),
          subtitle: Text('${notice['delivery_status']} · ${notice['acknowledged_at'] == null ? 'Unread' : 'Seen'}'),
          trailing: notice['acknowledged_at'] == null
              ? TextButton(onPressed: _loading ? null : () => _ackNotification((notice['revision_id'] as num).toInt()),
                  child: const Text('Mark seen')) : null,
        ),
      ],
      if ((_counts['supervisor_overdue'] as num? ?? 0) > 0)
        OutlinedButton.icon(onPressed: _loading ? null : _escalate,
          icon: const Icon(Icons.notification_important_outlined),
          label: const Text('Escalate overdue to supervisor inbox')),
      if (_escalations.isNotEmpty) ...[
        Text('Supervisor escalation inbox (${_escalations.length})', style: Theme.of(context).textTheme.titleMedium),
        for (final alert in _escalations) ListTile(
          leading: const Icon(Icons.warning_amber_rounded),
          title: Text('Order #${alert['order_id']} · ${alert['alert_kind']}'),
          subtitle: Text('Station ${alert['station_key']} · Assigned ID ${alert['assigned_to'] ?? 'Unassigned'}'),
        ),
      ],
      if (_overdue.isNotEmpty) Card(child: ListTile(leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange), title: Text('${_overdue.length} overdue replacement deliveries'), subtitle: const Text('Ready for more than 15 minutes. Assign or follow up promptly.'))),
      const Text('Auto-refresh every 15 seconds while this screen is open.'),
      Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
        onPressed: _loading ? null : _refresh,
        icon: const Icon(Icons.refresh), label: const Text('Refresh notices'),
      )),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      if (!_loading && _revisions.isEmpty) const Padding(
        padding: EdgeInsets.all(16), child: Text('No correction notices available.'),
      ),
      for (final revision in _revisions) Card(child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(revision['revision_kind'] == 'stop_wrong_item'
              ? 'STOP WRONG ITEM' : 'PREPARE REPLACEMENT',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('${revision['product_name'] ?? 'Product'} × ${revision['quantity']}'),
          Text('Order #${revision['order_id']} · Station ${revision['station_key']}'),
          Text('Status: ${revision['state']} · ${revision['created_at']}'),
          if (revision['revision_kind'] == 'prepare_replacement') Text('Preparation: ${revision['preparation_state'] ?? 'awaiting_acceptance'}'),
          if (revision['revision_kind'] == 'prepare_replacement' && revision['state'] == 'acknowledged')
            Wrap(spacing: 8, children: [
              if (revision['preparation_state'] == 'awaiting_acceptance') OutlinedButton(onPressed: _loading ? null : () => _transition((revision['revision_id'] as num).toInt(),'accept'), child: const Text('Accept replacement')),
              if (revision['preparation_state'] == 'accepted') OutlinedButton(onPressed: _loading ? null : () => _transition((revision['revision_id'] as num).toInt(),'prepare'), child: const Text('Start preparation')),
              if (revision['preparation_state'] == 'preparing') FilledButton(onPressed: _loading ? null : () => _transition((revision['revision_id'] as num).toInt(),'ready'), child: const Text('Mark ready / notify delivery')),
            ]),
          if (revision['state'] == 'pending') Wrap(spacing: 8, children: [
            OutlinedButton(onPressed: _loading ? null : () => _acknowledge(
                (revision['revision_id'] as num).toInt()),
                child: Text(revision['revision_kind'] == 'stop_wrong_item'
                    ? 'Stop acknowledged' : 'Preparation acknowledged')),
            if (revision['revision_kind'] == 'stop_wrong_item')
              TextButton(onPressed: _loading ? null : () => _acknowledge(
                  (revision['revision_id'] as num).toInt(), unableToStop: true),
                  child: const Text('Already prepared / cannot stop')),
          ]),
        ]),
      )),
      const Divider(),
      Text('Replacement delivery notifications', style: Theme.of(context).textTheme.titleMedium),
      for (final task in _deliveries) Card(child: Column(children: [
        ListTile(
          leading: Icon(task['priority'] == 'Overdue' ? Icons.warning_amber_rounded :
            task['priority'] == 'Needs assignment' ? Icons.person_add_alt_1 : Icons.delivery_dining,
            color: task['priority'] == 'Overdue' ? Colors.deepOrange : null),
          title: Text('${task['product_name']} × ${task['quantity']} · Order #${task['order_id']}'),
          subtitle: Text('Station ${task['station_key']} · ${task['delivery_status']}\n'
            'Employee: ${task['employee_name'] ?? 'Unassigned'} · Waiting ${task['minutes_waiting']} min'),
          isThreeLine: true,
          trailing: Chip(label: Text('${task['priority']}'),
            backgroundColor: task['priority'] == 'Overdue' ? Colors.orange.shade100 : null)),
        Wrap(spacing: 8, children: [
          OutlinedButton(onPressed: _loading ? null : () => _assign((task['revision_id'] as num).toInt(), '${task['station_key']}'), child: const Text('Assign employee')),
          if (task['assigned_to'] == Supabase.instance.client.auth.currentUser?.id && task['accepted_at'] == null) OutlinedButton(onPressed: _loading ? null : () => _transition((task['revision_id'] as num).toInt(),'accept_delivery'), child: const Text('Accept delivery')),
          if (task['assigned_to'] == Supabase.instance.client.auth.currentUser?.id && task['accepted_at'] != null && task['picked_up_at'] == null) OutlinedButton(onPressed: _loading ? null : () => _transition((task['revision_id'] as num).toInt(),'pickup'), child: const Text('Picked up')),
          if (task['assigned_to'] == Supabase.instance.client.auth.currentUser?.id && task['picked_up_at'] != null) FilledButton(onPressed: _loading ? null : () => _transition((task['revision_id'] as num).toInt(),'deliver'), child: const Text('Delivered')),
        ]),
      ])),
      const Padding(padding: EdgeInsets.only(top: 12), child: Text(
        'Notice acknowledgment does not itself update stock, record confirmed waste, or verify printer delivery.',
      )),
    ]);
  }
}
