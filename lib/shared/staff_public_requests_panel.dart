import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffPublicRequestsPanel extends StatefulWidget {
  const StaffPublicRequestsPanel({super.key});
  @override
  State<StaffPublicRequestsPanel> createState() => _StaffPublicRequestsPanelState();
}

class _StaffPublicRequestsPanelState extends State<StaffPublicRequestsPanel> {
  String statusFilter = 'all';
  String searchText = '';
  bool loading = false;
  String? error;
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> reservations = [];
  @override
  void initState() { super.initState(); refresh(); }
  Future<void> refresh() async {
    setState(() { loading = true; error = null; });
    try {
      final data = await Supabase.instance.client.rpc('gs_staff_public_requests');
      if (!mounted) return;
      final map = Map<String, dynamic>.from(data as Map);
      setState(() {
        orders = (map['orders'] as List).map((e) => Map<String,dynamic>.from(e as Map)).toList();
        reservations = (map['reservations'] as List).map((e) => Map<String,dynamic>.from(e as Map)).toList();
      });
    } catch (e) { if (mounted) setState(() => error = 'Unable to load requests: $e'); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> review(String type, String id, String action) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Confirm staff decision'),
      content: Text('Apply "$action" to this $type request?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx,false),child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx,true),child: const Text('Confirm'))]));
    if (confirmed != true || !mounted) return;
    setState(() => loading = true);
    try {
      if (type == 'reservation' && action == 'cancel') {
        await Supabase.instance.client.rpc('gs_cancel_reservation', params: {'p_id':id});
      } else {
        await Supabase.instance.client.rpc('gs_staff_review_public_request', params: {'p_type':type,'p_id':id,'p_action':action});
      }
      await refresh();
    } catch (e) { if (mounted) setState(() { error = 'Decision failed: $e'; loading = false; }); }
  }
  Widget entries(String type, List<Map<String,dynamic>> data) {
    final query = searchText.trim().toLowerCase();
    final visible = data.where((r) {
      if (statusFilter != 'all' && r['status']?.toString() != statusFilter) return false;
      if (query.isEmpty) return true;
      return [r['customer_name'], r['phone'], r['id']]
          .any((v) => (v ?? '').toString().toLowerCase().contains(query));
    }).toList();
    if (visible.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: Text('No matching requests'));

    return Column(children: visible.map((r) {
      final pending = r['status'] == 'pending';
      final id = r['id'].toString();
      return Card(child: Padding(padding: const EdgeInsets.all(12),child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${r['customer_name']} — ${r['status']}',style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Phone: ${r['phone']}'),
          if(type == 'order') Text('Total: ${r['total_iqd']} IQD'),
          if(type == 'reservation') Text('Guests: ${r['party_size']} | Requested: ${r['requested_at']}'),
          if ((r['notes'] ?? '').toString().isNotEmpty) Text('Notes: ${r['notes']}'),
          if (type == 'reservation' && (pending || r['status'] == 'approved'))
            OutlinedButton.icon(onPressed: loading ? null : () => review(type,id,'cancel'),
              icon: const Icon(Icons.event_busy), label: const Text('Cancel reservation')),
          if (pending) Wrap(spacing: 8,children: [
            FilledButton(onPressed: loading ? null : () => review(type,id,type == 'order' ? 'accept':'approve'),child: Text(type == 'order'?'Accept':'Approve')),
            OutlinedButton(onPressed: loading ? null : () => review(type,id,'decline'),child: const Text('Decline')),
          ])
        ])));
    }).toList());
  }
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [const Expanded(child: Text('Public request review',style: TextStyle(fontSize: 19,fontWeight: FontWeight.bold))), IconButton(onPressed: loading ? null : refresh, icon: const Icon(Icons.refresh))]),
    const Text('Staff decisions are enforced by the server. Reservations require capacity validation.'),
    Text('Orders: ${orders.length} (${orders.where((e) => e['status'] == 'pending').length} pending)  •  Reservations: ${reservations.length} (${reservations.where((e) => e['status'] == 'pending').length} pending)'),
    TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search customer, phone or request ID'), onChanged: (value) => setState(() => searchText = value)),
    DropdownButton<String>(value: statusFilter, isExpanded: true, items: const [DropdownMenuItem(value: 'all', child: Text('All statuses')), DropdownMenuItem(value: 'pending', child: Text('Pending')), DropdownMenuItem(value: 'accepted', child: Text('Accepted')), DropdownMenuItem(value: 'approved', child: Text('Approved')), DropdownMenuItem(value: 'declined', child: Text('Declined')), DropdownMenuItem(value: 'cancelled', child: Text('Cancelled'))], onChanged: (v) => setState(() => statusFilter = v ?? 'all')), 
    if (loading) const LinearProgressIndicator(),
    if (error != null) Text(error!,style: TextStyle(color: Theme.of(context).colorScheme.error)),
    const SizedBox(height: 12),
    const Text('Online orders',style: TextStyle(fontSize: 17,fontWeight: FontWeight.bold)),
    entries('order',orders),
    const SizedBox(height: 12),
    const Text('Table reservations',style: TextStyle(fontSize: 17,fontWeight: FontWeight.bold)),
    entries('reservation',reservations),
  ]);
}
