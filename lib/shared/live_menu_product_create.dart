import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Optional live product creation; requires migration 003 and menu.can_create.
class LiveMenuProductCreate extends StatefulWidget {
  const LiveMenuProductCreate({super.key, required this.onCreated});
  final VoidCallback onCreated;
  @override
  State<LiveMenuProductCreate> createState() => _LiveMenuProductCreateState();
}

class _LiveMenuProductCreateState extends State<LiveMenuProductCreate> {
  final _name = TextEditingController();
  final _barcode = TextEditingController();
  final _normal = TextEditingController();
  final _tourism = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _normal.dispose();
    _tourism.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final barcode = _barcode.text.trim();
    final normal = int.tryParse(_normal.text.trim());
    final tourism = int.tryParse(_tourism.text.trim());
    if (name.isEmpty || name.length > 150 || barcode.isEmpty || barcode.length > 80 ||
        normal == null || tourism == null || normal < 0 || tourism < 0 ||
        normal > 1000000000 || tourism > 1000000000) {
      setState(() => _message = 'Enter a name, barcode and valid IQD prices.');
      return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      await Supabase.instance.client.rpc('gs_create_menu_product', params: {
        'p_name': name,
        'p_barcode': barcode,
        'p_normal_price_iqd': normal,
        'p_tourism_price_iqd': tourism,
      });
      if (!mounted) return;
      _name.clear(); _barcode.clear(); _normal.clear(); _tourism.clear();
      setState(() => _message = 'Product saved to Supabase. Refresh the product list.');
      widget.onCreated();
    } catch (error) {
      if (mounted) setState(() => _message = 'Could not save product. Check your permissions and connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Create Supabase menu product', style: TextStyle(fontWeight: FontWeight.bold)),
        const Text('Requires menu.can_create permission and optional SQL migration 003.'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          SizedBox(width: 220, child: TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name'))),
          SizedBox(width: 180, child: TextField(controller: _barcode, decoration: const InputDecoration(labelText: 'Barcode'))),
          SizedBox(width: 160, child: TextField(controller: _normal, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Normal IQD'))),
          SizedBox(width: 160, child: TextField(controller: _tourism, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tourism IQD'))),
        ]),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: _busy ? null : _submit,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: Text(_busy ? 'Saving...' : 'Save product securely')),
        if (_message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message!)),
      ]),
    ),
  );
}
