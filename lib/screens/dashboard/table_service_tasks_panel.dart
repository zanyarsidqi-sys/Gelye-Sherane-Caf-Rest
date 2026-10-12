import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Task queue with server-authorized assignment and status actions.
/// Actions require the draft RPCs to be deployed and verified.
class TableServiceTasksPanel extends StatefulWidget {
  const TableServiceTasksPanel({super.key, this.tableId});
  final String? tableId;
  @override
  State<TableServiceTasksPanel> createState() => _TableServiceTasksPanelState();
}

class _TableServiceTasksPanelState extends State<TableServiceTasksPanel> {
  late Future<List<Map<String, dynamic>>> _rows = _load();
  String filter = 'active';
  Future<List<Map<String, dynamic>>> _load() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      throw StateError('Employee login required');
    }
    // Draft server RPC; no direct table reads or client-side authorization.
    final result = await Supabase.instance.client.rpc(
      'gs_dashboard_table_service_tasks',
      params: {'p_table_id': widget.tableId},
    );
    return (result as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  bool _busy = false;

  Future<void> _changeStatus(Map<String, dynamic> task, String status) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc(
        'gs_update_table_service_task_status',
        params: {'p_task_id': task['id'], 'p_new_status': status},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task status updated: $status')),
      );
      setState(() => _rows = _load());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Task update rejected or backend unavailable. Check permissions and deployment.'),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign(Map<String, dynamic> task) async {
    String? employeeId;
    try {
      final response = await Supabase.instance.client.rpc('gs_service_assignable_employees');
      if (!mounted) return;
      final employees = (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      if (employees.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active employees available for assignment.')));
        return;
      }
      employeeId = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Assign to an active employee'),
          children: [
            SizedBox(
              width: 360,
              height: 320,
              child: ListView.builder(
                itemCount: employees.length,
                itemBuilder: (context, index) {
                  final employee = employees[index];
                  return ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text('${employee['full_name'] ?? 'Employee'}'),
                    onTap: () => Navigator.pop(ctx, '${employee['user_id']}'),
                  );
                },
              ),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Employee directory unavailable. Check server permissions and deployment.'),
      ));
      return;
    }
    if (employeeId == null || _busy) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc('gs_assign_table_service_task',
        params: {'p_task_id': task['id'], 'p_employee_id': employeeId});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task assigned. In-app notification queued by backend if deployed.')));
      setState(() => _rows = _load());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Assignment rejected or backend unavailable. Check permissions and deployment.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createRequest() async {
    final tableController = TextEditingController(text: widget.tableId ?? '');
    final notesController = TextEditingController();
    String type = 'extra_tissues';
    String priority = 'normal';
    int quantity = 1;
    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('New table service request'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: tableController,
                enabled: widget.tableId == null,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Table ID')),
              DropdownButtonFormField<String>(value: type,
                decoration: const InputDecoration(labelText: 'Request'),
                isExpanded: true,
                items: tableServiceRequestTypes.map((v) => DropdownMenuItem(
                  value: v, child: Text(v.replaceAll('_', ' ')))).toList(),
                onChanged: (v) => update(() => type = v ?? type)),
              DropdownButtonFormField<int>(value: quantity,
                decoration: const InputDecoration(labelText: 'Quantity'),
                items: List.generate(10, (i) => DropdownMenuItem(
                  value: i + 1, child: Text('${i + 1}'))),
                onChanged: (v) => update(() => quantity = v ?? quantity)),
              DropdownButtonFormField<String>(value: priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [DropdownMenuItem(value: 'normal', child: Text('Normal')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent'))],
                onChanged: (v) => update(() => priority = v ?? priority)),
              TextField(controller: notesController, maxLength: 1000,
                decoration: const InputDecoration(labelText: 'Notes (optional)')),
              const Text('Chargeable products require a separate confirmed order.'),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () {
              final tableId = int.tryParse(tableController.text.trim());
              if (tableId == null || tableId <= 0) return;
              Navigator.pop(dialogContext, {
                'p_table_id': tableId, 'p_request_type': type,
                'p_quantity': quantity, 'p_priority': priority,
                'p_notes': notesController.text.trim(),
              });
            }, child: const Text('Create request')),
          ],
        ),
      ),
    );
    tableController.dispose();
    notesController.dispose();
    if (request == null || _busy || !mounted) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc('gs_create_table_service_task', params: request);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Service request created. Assign an employee to continue.')));
      setState(() => _rows = _load());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Request rejected. Check table, permissions, duplicate requests or backend deployment.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Table service requests'), actions: [
      IconButton(tooltip: 'New request', icon: const Icon(Icons.add_circle_outline),
        onPressed: _busy ? null : _createRequest),
      IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh),
        onPressed: () => setState(() => _rows = _load())),
    ]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          value: filter,
          decoration: const InputDecoration(labelText: 'Show requests'),
          items: const [
            DropdownMenuItem(value: 'active', child: Text('Active')),
            DropdownMenuItem(value: 'all', child: Text('All')),
            DropdownMenuItem(value: 'completed', child: Text('Completed')),
          ],
          onChanged: (v) => setState(() => filter = v ?? 'active'),
        )),
      ])),
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _rows,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Padding(
            padding: EdgeInsets.all(20), child: Text(
              'Service task queue unavailable. Deploy the permission-checked backend before use.',
              textAlign: TextAlign.center,
            ),
          ));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snapshot.data!.where((r) {
            final status = '${r['status'] ?? ''}'.toLowerCase();
            if (filter == 'completed') return status == 'completed';
            if (filter == 'active') return status != 'completed' && status != 'cancelled';
            return true;
          }).toList();
          if (rows.isEmpty) return const Center(child: Text('No matching service requests.'));
          return ListView.builder(itemCount: rows.length, itemBuilder: (context, i) {
            final r = rows[i];
            final title = '${r['request_type'] ?? 'Service request'}';
            final status = '${r['status'] ?? 'Unknown'}';
            final table = '${r['table_label'] ?? r['table_id'] ?? 'Unknown table'}';
            final assignee = '${r['assigned_employee_name'] ?? 'Unassigned'}';
            return ListTile(
              leading: Icon(title.toLowerCase().contains('shisha') ? Icons.local_fire_department_outlined
                  : title.toLowerCase().contains('clean') ? Icons.cleaning_services_outlined
                  : Icons.room_service_outlined),
              title: Text(title),
              subtitle: Text('Table $table · $status · Assigned: $assignee'),
              trailing: const Icon(Icons.info_outline),
              onTap: () => showDialog<void>(context: context, builder: (ctx) => AlertDialog(
                title: Text(title),
                content: SingleChildScrollView(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Table: $table'), Text('Status: $status'),
                    Text('Employee: $assignee'),
                    Text('Quantity: ${r['quantity'] ?? 'Not provided'}'),
                    Text('Priority: ${r['priority'] ?? 'Normal'}'),
                    Text('Notes: ${r['notes'] ?? 'None'}'),
                    Text('Requested: ${r['created_at'] ?? 'Unavailable'}'),
                    const SizedBox(height: 12),
                    const Text('Assignment and completion require audited server-side actions.'),
                  ],
                )),
                actions: [
                  if (!_busy && status != 'completed' && status != 'cancelled')
                    TextButton(
                      onPressed: () { Navigator.pop(ctx); _assign(r); },
                      child: const Text('Assign'),
                    ),
                  if (!_busy && status == 'assigned')
                    TextButton(
                      onPressed: () { Navigator.pop(ctx); _changeStatus(r, 'accepted'); },
                      child: const Text('Accept'),
                    ),
                  if (!_busy && status == 'accepted')
                    TextButton(
                      onPressed: () { Navigator.pop(ctx); _changeStatus(r, 'in_progress'); },
                      child: const Text('Start'),
                    ),
                  if (!_busy && status == 'in_progress')
                    TextButton(
                      onPressed: () { Navigator.pop(ctx); _changeStatus(r, 'completed'); },
                      child: const Text('Complete'),
                    ),
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                ],
              )),
            );
          });
        },
      )),
    ]),
  );
}

/// Explicit supported service request types. Chargeable items must be
/// confirmed through the regular priced-order flow, not this task queue.
const tableServiceRequestTypes = <String>[
  'extra_tissues', 'fork', 'spoon', 'knife', 'extra_plate', 'extra_glass',
  'extra_chair', 'water_request', 'condiments', 'call_waiter',
  'dish_pickup', 'shisha_pickup', 'shisha_service', 'table_cleaning',
  'other',
];
