import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only fulfillment visibility; status changes must go through authorized kitchen workflows.
class StaffFulfillmentPanel extends StatefulWidget {
  const StaffFulfillmentPanel({super.key});
  @override
  State<StaffFulfillmentPanel> createState() => _StaffFulfillmentPanelState();
}

class _StaffFulfillmentPanelState extends State<StaffFulfillmentPanel> {
  bool loading = false;
  String? error;
  String filter = 'all';
  List<Map<String, dynamic>> records = [];

  @override
  void initState() { super.initState(); refresh(); }

  Future<void> refresh() async {
    if (loading) return;
    setState(() { loading = true; error = null; });
    try {
      final result = await Supabase.instance.client.rpc('gs_staff_public_fulfillment_status');
      if (!mounted) return;
      setState(() => records = (result as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList());
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to load fulfillment statuses. Check staff permissions and database migrations.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = records.where((r) => filter == 'all' || r['request_status'] == filter).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(child: Text('Online order fulfillment', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
        IconButton(tooltip: 'Refresh', onPressed: loading ? null : refresh, icon: const Icon(Icons.refresh)),
      ]),
      const Text('Read-only status tracking. Kitchen staff update order status through authorized kitchen screens.'),
      const SizedBox(height: 8),
      Text('Linked orders: ${records.length} • Fulfilled: ${records.where((r) => r['request_status'] == 'fulfilled').length}'),
      DropdownButton<String>(value: filter, isExpanded: true, items: const [
        DropdownMenuItem(value: 'all', child: Text('All linked orders')),
        DropdownMenuItem(value: 'accepted', child: Text('Accepted / in kitchen')),
        DropdownMenuItem(value: 'fulfilled', child: Text('Fulfilled')),
      ], onChanged: (v) => setState(() => filter = v ?? 'all')),
      if (loading) const LinearProgressIndicator(),
      if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if (!loading && visible.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No matching linked orders.')),
      ...visible.map((r) => Card(child: ListTile(
        title: Text('Kitchen order #${r['kitchen_order_id']}'),
        subtitle: Text('Request: ${r['request_id']}\nKitchen: ${r['kitchen_status']}'),
        isThreeLine: true,
        trailing: Chip(label: Text('${r['request_status']}')),
      ))),
    ]);
  }
}
