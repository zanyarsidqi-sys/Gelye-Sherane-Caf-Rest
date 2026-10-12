import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Staff-only, permission-gated guest/notes editor. No prices or quantities change.
class StaffOrderGuestEditor extends StatefulWidget {
  const StaffOrderGuestEditor({super.key});
  @override
  State<StaffOrderGuestEditor> createState() => _StaffOrderGuestEditorState();
}

class _StaffOrderGuestEditorState extends State<StaffOrderGuestEditor> {
  final _orderId = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  String? _error;
  int _requestVersion = 0;
  String? _employeeId;

  @override
  void dispose() {
    _requestVersion++;
    _orderId.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = int.tryParse(_orderId.text.trim());
    if (id == null || id <= 0) {
      setState(() => _error = 'Enter a valid table order number.');
      return;
    }
    final employee = Supabase.instance.client.auth.currentUser?.id;
    final version = ++_requestVersion;
    setState(() { _loading = true; _error = null; _items = []; _employeeId = employee; });
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_staff_table_order_items', params: {'p_order_id': id});
      if (!mounted || version != _requestVersion ||
          employee != Supabase.instance.client.auth.currentUser?.id) return;
      final rows = List<dynamic>.from(response as List);
      setState(() {
        _items = rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
        if (_items.isEmpty) _error = 'No table-order items found.';
      });
    } catch (_) {
      if (mounted && version == _requestVersion) {
        setState(() => _error = 'Unable to load order items. Check access and try again.');
      }
    } finally {
      if (mounted && version == _requestVersion) setState(() => _loading = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    if (item['order_status'] != 'new' || _loading) return;
    final guest = TextEditingController(text: item['guest_label']?.toString() ?? '');
    final notes = TextEditingController(text: item['preparation_notes']?.toString() ?? '');
    final employee = _employeeId;
    final version = _requestVersion;
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Item #${item['item_id']} · ${item['product_name']}'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: guest, maxLength: 80,
            inputFormatters: [LengthLimitingTextInputFormatter(80)],
            decoration: const InputDecoration(labelText: 'Customer name (optional)',
              hintText: 'Ahmed, Sara, or leave blank')),
          TextField(controller: notes, maxLength: 500, maxLines: 3,
            inputFormatters: [LengthLimitingTextInputFormatter(500)],
            decoration: const InputDecoration(labelText: 'Preparation instructions',
              hintText: 'No onions, extra spicy, napkins...')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, (guest.text, notes.text)),
            child: const Text('Save instructions')),
        ],
      ),
    );
    // Dialog controllers can be disposed after the route has fully closed.
    if (result == null || !mounted || version != _requestVersion ||
        employee != Supabase.instance.client.auth.currentUser?.id) return;
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.rpc('gs_set_kitchen_item_instructions', params: {
        'p_item_id': item['item_id'],
        'p_guest_label': result.$1,
        'p_preparation_notes': result.$2,
      });
      if (mounted && version == _requestVersion &&
          employee == Supabase.instance.client.auth.currentUser?.id) {
        await _load();
      }
    } catch (_) {
      if (mounted && version == _requestVersion) {
        setState(() => _error = 'Could not save. Order may have been accepted or access changed.');
      }
    } finally {
      if (mounted && version == _requestVersion) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Guest names & preparation instructions',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    const Text('Optional names per item. All items remain on the same table bill. '
      'Instructions can be edited only before the order is accepted.'),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: TextField(controller: _orderId,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(labelText: 'Table order number'))),
      const SizedBox(width: 8),
      FilledButton(onPressed: _loading ? null : _load, child: const Text('Find')),
    ]),
    if (_loading) const LinearProgressIndicator(),
    if (_error != null) Padding(padding: const EdgeInsets.all(8),
      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    for (final item in _items) Card(child: ListTile(
      title: Text('${item['product_name']} × ${item['quantity']}'),
      subtitle: Text('Guest: ${item['guest_label'] ?? 'Unnamed guest'}'
        '\nInstructions: ${item['preparation_notes'] ?? 'None'}'
        '\nStatus: ${item['order_status']}'),
      isThreeLine: true,
      trailing: IconButton(tooltip: 'Edit guest and instructions',
        icon: const Icon(Icons.edit_note),
        onPressed: !_loading && item['order_status'] == 'new' ? () => _edit(item) : null),
    )),
  ]);
}
