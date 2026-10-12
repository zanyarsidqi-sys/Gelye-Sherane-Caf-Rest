import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MotelFoodRequestsScreen extends StatefulWidget {
  const MotelFoodRequestsScreen({super.key});
  @override
  State<MotelFoodRequestsScreen> createState() => _MotelFoodRequestsScreenState();
}
class _MotelFoodRequestsScreenState extends State<MotelFoodRequestsScreen> {
  bool loading = false;
  String? error;
  List<Map<String, dynamic>> requests = [];
  @override
  void initState() { super.initState(); refresh(); }
  Future<void> refresh() async {
    if (loading) return;
    setState(() { loading = true; error = null; });
    try {
      final result = await Supabase.instance.client.rpc('gs_staff_list_motel_food_requests');
      if (!mounted) return;
      setState(() => requests = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> decide(Map<String,dynamic> order, String decision) async {
    String? reason;
    if (decision == 'reject') {
      final controller = TextEditingController();
      try {
        final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('Reject food request'),
          content: TextField(controller: controller, maxLength: 300, decoration: const InputDecoration(labelText: 'Reason (required)')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx,false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx,true), child: const Text('Reject'))]));
        if (confirmed != true || !mounted) return;
        reason = controller.text.trim();
        if (reason.length < 3) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a rejection reason'))); return; }
      } finally { controller.dispose(); }
    }
    try {
      await Supabase.instance.client.rpc('gs_staff_decide_motel_food_request', params: {
        'p_request_id': order['id'], 'p_decision': decision, 'p_reason': reason,
      });
      await refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to update: $e')));
    }
  }
  Future<void> advanceDelivery(Map<String,dynamic> order, String action) async {
    try {
      await Supabase.instance.client.rpc('gs_staff_advance_motel_food_delivery', params: {
        'p_request_id': order['id'], 'p_action': action,
      });
      await refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delivery update failed: $e')));
    }
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    ListTile(title: const Text('Guest food requests'), subtitle: const Text('Review requests before kitchen dispatch or room billing'),
      trailing: IconButton(onPressed: loading ? null : refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh')),
    if (loading) const LinearProgressIndicator(),
    if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    Expanded(child: requests.isEmpty ? const Center(child: Text('No guest food requests')) : ListView.builder(
      itemCount: requests.length, itemBuilder: (context,index) {
        final order = requests[index];
        final lines = (order['items'] as List? ?? []);
        return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Room ${order['room_label'] ?? ''} · ${order['room_name'] ?? ''}', style: Theme.of(context).textTheme.titleMedium),
          Text('Status: ${order['status']} · Total: ${order['total_iqd']} IQD'),
          for (final item in lines) Text('${item['quantity']} × ${item['name']} — ${item['price_iqd']} IQD each'),
          if (order['delivery_employee_id'] != null)
            Text('Delivery employee: ${order['delivery_employee_id']}'),
          if (order['status'] == 'ready' && order['delivery_employee_id'] == null)
            FilledButton.icon(onPressed: () => advanceDelivery(order,'assign_to_me'),
              icon: const Icon(Icons.person_add), label: const Text('Assign Delivery to Me')),
          if (order['status'] == 'ready' && order['delivery_employee_id'] == Supabase.instance.client.auth.currentUser?.id)
            FilledButton.icon(onPressed: () => advanceDelivery(order,'on_way'),
              icon: const Icon(Icons.delivery_dining), label: const Text('On the Way')),
          if (order['status'] == 'on_way' && order['delivery_employee_id'] == Supabase.instance.client.auth.currentUser?.id)
            FilledButton.icon(onPressed: () => advanceDelivery(order,'delivered'),
              icon: const Icon(Icons.check_circle), label: const Text('Delivered')),
          if (order['status'] == 'pending') Wrap(spacing: 8, children: [
            FilledButton(onPressed: () => decide(order,'accept'), child: const Text('Accept')),
            OutlinedButton(onPressed: () => decide(order,'reject'), child: const Text('Reject')),
          ]),
        ])));
      })),
  ]);
}
