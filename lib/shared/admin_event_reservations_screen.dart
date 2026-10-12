import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin event queue. Authorization is enforced by server RPCs, not by this widget.
class AdminEventReservationsScreen extends StatefulWidget {
  const AdminEventReservationsScreen({super.key});
  @override
  State<AdminEventReservationsScreen> createState() => _AdminEventReservationsScreenState();
}

class _AdminEventReservationsScreenState extends State<AdminEventReservationsScreen> {
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _busy = true; _error = null; });
    try {
      final rows = await Supabase.instance.client.rpc('gs_admin_event_queue',
          params: {'p_limit': 100});
      if (mounted) setState(() => _events = (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map)).toList());
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load events. Check Admin access and migrations.');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _review(Map<String, dynamic> event, bool approve) async {
    final note = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(context: context,
        builder: (context) => AlertDialog(
          title: Text(approve ? 'Approve event?' : 'Reject event?'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${event['event_type']} · ${event['guest_count']} guests'),
            const SizedBox(height: 12),
            TextField(controller: note, maxLength: 1000, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Admin review note')),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Back')),
            FilledButton(onPressed: () {
              if (!approve && note.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            }, child: Text(approve ? 'Approve' : 'Reject'))],
        ));
      if (confirmed != true) return;
      setState(() { _busy = true; _error = null; });
      await Supabase.instance.client.rpc('gs_admin_review_event', params: {
        'p_event_id': event['event_id'], 'p_approve': approve,
        'p_note': note.text.trim(),
      });
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'Review failed. The event may conflict or your session may lack Admin access.');
    } finally { note.dispose(); if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Admin · Event reservations'), actions: [
      IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh)),
    ]),
    body: Column(children: [
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) Padding(padding: const EdgeInsets.all(12),
        child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      Expanded(child: _events.isEmpty
        ? const Center(child: Text('No events to review, or events have not loaded.'))
        : ListView.builder(itemCount: _events.length, itemBuilder: (context, index) {
          final e = _events[index];
          final products = (e['products'] as List?) ?? const [];
          final start = DateTime.tryParse('${e['event_start']}')?.toLocal();
          final end = DateTime.tryParse('${e['event_end']}')?.toLocal();
          final pending = e['status'] == 'pending_admin';
          return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Padding(padding: const EdgeInsets.all(12), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${e['event_type']} · ${e['status']}', style: Theme.of(context).textTheme.titleMedium),
                Text('${e['customer_name']} · ${e['customer_phone']}'),
                Text('Guests: ${e['guest_count']} · Model: ${e['business_model']}'),
                Text('Start: ${start ?? e['event_start']}'),
                Text('End: ${end ?? e['event_end']}'),
                Text('Table: ${e['requested_table_id'] ?? 'Venue / not selected'}'),
                Text('Services: ${e['requested_services'] ?? 'None'}'),
                Text('Rental quote (IQD): ${e['rental_quote_iqd'] ?? 'Not quoted'}'),
                const SizedBox(height: 8),
                Text('Advance preparation (${products.length} items)',
                    style: Theme.of(context).textTheme.titleSmall),
                ...products.map((p) { final item = Map<String, dynamic>.from(p as Map);
                  return Text('• ${item['product_name']} × ${item['quantity']} · ${item['serve_at'] ?? 'time not specified'}');
                }),
                if (pending) Wrap(spacing: 8, children: [
                  FilledButton(onPressed: _busy ? null : () => _review(e, true),
                      child: const Text('Approve')),
                  OutlinedButton(onPressed: _busy ? null : () => _review(e, false),
                      child: const Text('Reject')),
                ]),
              ])));
        })),
    ]),
  );
}
