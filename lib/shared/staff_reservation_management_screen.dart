import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Staff management view. All reads and writes are authorized by Supabase RPCs.
class StaffReservationManagementScreen extends StatefulWidget {
  const StaffReservationManagementScreen({super.key});
  @override
  State<StaffReservationManagementScreen> createState() => _StaffReservationManagementScreenState();
}

class _StaffReservationManagementScreenState extends State<StaffReservationManagementScreen> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _tables = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await Supabase.instance.client.rpc('gs_staff_specific_reservations', params: {'p_limit': 100});
      if (mounted) setState(() => _items = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) { if (mounted) setState(() => _error = 'Unable to load reservations: $e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _change(Map<String, dynamic> item, {required bool cancel}) async {
    final reason = TextEditingController();
    final start = DateTime.tryParse('${item['requested_at']}')?.toLocal();
    DateTime? selected = start;
    String? tableId = '${item['assigned_table_id'] ?? item['requested_table_id'] ?? ''}';
    int duration = (item['duration_minutes'] as num?)?.toInt() ?? 120;
    try {
      if (!cancel) {
        final result = await Supabase.instance.client.rpc('gs_public_reservable_table_options', params: {'p_party_size': item['party_size']});
        _tables = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (!_tables.any((t) => '${t['table_id']}' == tableId)) tableId = null;
      }
      if (!mounted) return;
      final accepted = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(cancel ? 'Cancel reservation' : 'Change reservation'),
          content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${item['customer_name']} · ${item['party_size']} guests'),
            if (!cancel) ...[
              DropdownButtonFormField<String>(value: tableId, decoration: const InputDecoration(labelText: 'Table'),
                items: _tables.map((t) => DropdownMenuItem(value: '${t['table_id']}', child: Text('${t['table_label']} (${t['seats']})'))).toList(),
                onChanged: (v) => update(() => tableId = v)),
              ListTile(title: Text(selected == null ? 'Select date/time' : selected.toString()),
                onTap: () async {
                  final now = DateTime.now();
                  final day = await showDatePicker(context: ctx, firstDate: now, lastDate: now.add(const Duration(days: 89)), initialDate: selected != null && selected!.isAfter(now) ? selected! : now);
                  if (day == null || !ctx.mounted) return;
                  final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(selected ?? now));
                  if (time != null) update(() => selected = DateTime(day.year,day.month,day.day,time.hour,time.minute));
                }),
              DropdownButtonFormField<int>(value: duration, decoration: const InputDecoration(labelText: 'Duration'),
                items: [30,60,90,120,180,240,300,360].map((v) => DropdownMenuItem(value: v,child: Text('$v minutes'))).toList(),
                onChanged: (v) => update(() => duration = v ?? duration)),
            ],
            TextField(controller: reason, maxLength: 500, decoration: InputDecoration(labelText: cancel ? 'Cancellation reason (required)' : 'Reason (optional)')),
          ]))),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx,false), child: const Text('Back')),
            FilledButton(onPressed: () {
              if (cancel && reason.text.trim().isEmpty) return;
              if (!cancel && (tableId == null || selected == null || !selected!.isAfter(DateTime.now()))) return;
              Navigator.pop(ctx,true);
            }, child: Text(cancel ? 'Cancel reservation' : 'Save changes'))],
        )));
      if (accepted != true) return;
      setState(() { _loading = true; _error = null; });
      await Supabase.instance.client.rpc('gs_staff_change_specific_reservation', params: {
        'p_reservation_id': item['id'], 'p_action': cancel ? 'cancel' : 'reschedule',
        'p_table_id': cancel ? null : tableId,
        'p_start': cancel ? null : selected!.toUtc().toIso8601String(),
        'p_duration': cancel ? null : duration,
        'p_reason': reason.text.trim(),
      });
      await _refresh();
    } catch (e) { if (mounted) setState(() => _error = 'Change failed: $e'); }
    finally { reason.dispose(); if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Manage table reservations'), actions: [IconButton(onPressed: _loading ? null : _refresh, icon: const Icon(Icons.refresh))]),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child:
      ListView(children: [
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        if (!_loading && _items.isEmpty) const ListTile(title: Text('No pending or approved reservations')),
        ..._items.map((r) => Card(child: ListTile(
          title: Text('${r['customer_name']} · ${r['status']}'),
          subtitle: Text('${r['requested_at']} · ${r['party_size']} guests · ${r['phone']}'),
          trailing: Wrap(children: [
            IconButton(tooltip: 'Change time or table', icon: const Icon(Icons.edit_calendar), onPressed: _loading ? null : () => _change(r,cancel:false)),
            IconButton(tooltip: 'Cancel reservation', icon: const Icon(Icons.event_busy), onPressed: _loading ? null : () => _change(r,cancel:true)),
          ]),
        ))),
      ]))),
  );
}
