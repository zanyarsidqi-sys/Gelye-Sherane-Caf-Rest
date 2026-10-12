import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Staff-only workflow; customer feedback submission is a separate, pending feature.
class StaffProductRecommendations extends StatefulWidget {
  const StaffProductRecommendations({super.key});
  @override
  State<StaffProductRecommendations> createState() => _StaffProductRecommendationsState();
}

class _StaffProductRecommendationsState extends State<StaffProductRecommendations> {
  bool loading = false;
  String? error;
  List<Map<String, dynamic>> requests = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await Supabase.instance.client.rpc('gs_staff_recommendation_list');
      if (mounted) setState(() => requests = (result as List)
          .map((row) => Map<String, dynamic>.from(row as Map)).toList());
    } catch (e) {
      if (mounted) setState(() => error = 'Unable to load recommendations: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _viewCustomerFeedback() async {
    try {
      final data = await Supabase.instance.client.rpc(
        'gs_staff_customer_feedback_list', params: {'p_limit': 100});
      if (!mounted) return;
      final records = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Customer feedback · Read only'),
          content: SizedBox(
            width: 560,
            height: 420,
            child: records.isEmpty
                ? const Center(child: Text('No customer feedback received yet.'))
                : ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final record = records[index];
                      return Card(child: ListTile(
                        title: Text(record['kind']?.toString() ?? 'Feedback'),
                        subtitle: Text(
                          'Table ID: ${record['table_id'] ?? '-'} · '
                          'Rating: ${record['rating'] ?? '-'}\n'
                          '${record['requested_product'] ?? ''} '
                          '${record['comment'] ?? ''}\n'
                          'Status: ${record['status'] ?? '-'} · '
                          'Received: ${record['created_at'] ?? '-'}',
                        ),
                      ));
                    },
                  ),
          ),
          actions: [TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          )],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Customer feedback unavailable: $e')),
      );
    }
  }

  Future<void> _edit(Map<String, dynamic> request) async {
    String status = request['status']?.toString() ?? 'pending';
    final note = TextEditingController(text: request['employee_note']?.toString() ?? '');
    final menuId = TextEditingController(text: request['linked_menu_product_id']?.toString() ?? '');
    bool saving = false;
    try {
      await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('Recommendation: ${request['product_name']}'),
          content: SizedBox(width: 450, child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('New')),
                DropdownMenuItem(value: 'in_review', child: Text('In review')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'added_to_menu', child: Text('Added to menu')),
                DropdownMenuItem(value: 'done', child: Text('Done')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: saving ? null : (value) { if (value != null) update(() => status = value); },
            ),
            const SizedBox(height: 12),
            TextField(controller: note, maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Employee completion note')),
            TextField(controller: menuId, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Linked menu product ID (for new items)')),
          ])),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
            FilledButton(onPressed: saving ? null : () async {
              update(() => saving = true);
              try {
                final parsedId = menuId.text.trim().isEmpty ? null : int.tryParse(menuId.text.trim());
                if (menuId.text.trim().isNotEmpty && parsedId == null) {
                  throw const FormatException('Enter a valid menu product ID');
                }
                await Supabase.instance.client.rpc('gs_staff_update_recommendation', params: {
                  'p_id': request['id'], 'p_status': status,
                  'p_note': note.text.trim(), 'p_menu_product_id': parsedId,
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                await _load();
              } catch (e) {
                if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext)
                  .showSnackBar(SnackBar(content: Text('Update rejected: $e')));
              } finally { if (dialogContext.mounted) update(() => saving = false); }
            }, child: const Text('Save')),
          ],
        ),
      ));
    } finally { note.dispose(); menuId.dispose(); }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.all(12), child: Row(children: [
      const Expanded(child: Text('Product recommendations · Staff review',
        style: TextStyle(fontWeight: FontWeight.bold))),
      TextButton.icon(
        onPressed: _viewCustomerFeedback,
        icon: const Icon(Icons.rate_review_outlined),
        label: const Text('Customer feedback'),
      ),
      IconButton(tooltip: 'Refresh', onPressed: loading ? null : _load,
        icon: const Icon(Icons.refresh)),
    ])),
    if (loading) const LinearProgressIndicator(),
    if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
    Expanded(child: ListView.builder(
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return Card(child: ListTile(
          title: Text(request['product_name']?.toString() ?? 'Unnamed suggestion'),
          subtitle: Text('${request['type']} · ${request['status']}\n'
            '${request['reason'] ?? ''}\n'
            'Employee note: ${request['employee_note'] ?? 'None'}'),
          isThreeLine: true,
          trailing: IconButton(tooltip: 'Review / mark done',
            icon: const Icon(Icons.edit_note), onPressed: () => _edit(request)),
        ));
      },
    )),
  ]);
}
