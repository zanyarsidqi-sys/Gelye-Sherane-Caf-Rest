import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Optional live product editor; requires reviewed migration 004 and menu.can_edit.
class LiveMenuProductEdit extends StatefulWidget {
  const LiveMenuProductEdit({super.key});
  @override
  State<LiveMenuProductEdit> createState() => _LiveMenuProductEditState();
}

class _LiveMenuProductEditState extends State<LiveMenuProductEdit> {
  final _name = TextEditingController();
  final _barcode = TextEditingController();
  final _normal = TextEditingController();
  final _tourism = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  int? _selectedId;
  bool _active = true;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _normal.dispose();
    _tourism.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final rows = await Supabase.instance.client
          .from('gs_menu_products')
          .select(
              'id,name,barcode,normal_price_iqd,tourism_price_iqd,is_active')
          .order('name')
          .limit(200);
      if (!mounted) return;
      setState(() {
        _products = List<Map<String, dynamic>>.from(rows);
        _selectedId = null;
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'Unable to load products: Please retry or contact a manager');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _select(int? id) {
    setState(() {
      _selectedId = id;
      if (id == null) return;
      final item = _products.firstWhere((p) => p['id'] == id);
      _name.text = '${item['name'] ?? ''}';
      _barcode.text = '${item['barcode'] ?? ''}';
      _normal.text = '${item['normal_price_iqd'] ?? ''}';
      _tourism.text = '${item['tourism_price_iqd'] ?? ''}';
      _active = item['is_active'] == true;
    });
  }

  Future<void> _save() async {
    final normal = int.tryParse(_normal.text.trim());
    final tourism = int.tryParse(_tourism.text.trim());
    if (_selectedId == null ||
        _name.text.trim().isEmpty ||
        _name.text.trim().length > 150 ||
        _barcode.text.trim().isEmpty ||
        _barcode.text.trim().length > 80 ||
        normal == null ||
        tourism == null ||
        normal < 0 ||
        tourism < 0 ||
        normal > 1000000000 ||
        tourism > 1000000000) {
      setState(() => _message =
          'Select a product and enter valid details and IQD prices.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.rpc('gs_update_menu_product', params: {
        'p_id': _selectedId,
        'p_name': _name.text.trim(),
        'p_barcode': _barcode.text.trim(),
        'p_normal_price_iqd': normal,
        'p_tourism_price_iqd': tourism,
        'p_is_active': _active,
      });
      if (!mounted) return;
      setState(() => _message =
          'Product updated. Refresh the product list to see changes.');
      await _load();
    } catch (e) {
      if (mounted) setState(() => _message = 'Update failed: Please retry or contact a manager');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Edit Supabase menu product',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Text(
                'Requires migration 004 and backend menu.can_edit permission.'),
            Row(children: [
              Expanded(
                  child: DropdownButtonFormField<int>(
                initialValue: _selectedId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Choose product'),
                items: _products
                    .map((p) => DropdownMenuItem<int>(
                          value: p['id'] as int,
                          child: Text('${p['name']} (${p['barcode']})',
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: _busy ? null : _select,
              )),
              IconButton(
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reload products'),
            ]),
            if (_selectedId != null) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                SizedBox(
                    width: 220,
                    child: TextField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'Name'))),
                SizedBox(
                    width: 180,
                    child: TextField(
                        controller: _barcode,
                        decoration:
                            const InputDecoration(labelText: 'Barcode'))),
                SizedBox(
                    width: 150,
                    child: TextField(
                        controller: _normal,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Normal IQD'))),
                SizedBox(
                    width: 150,
                    child: TextField(
                        controller: _tourism,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Tourism IQD'))),
              ]),
              SwitchListTile(
                  title: const Text('Active product'),
                  value: _active,
                  onChanged: _busy ? null : (v) => setState(() => _active = v)),
              FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_busy ? 'Saving...' : 'Save changes')),
            ],
            if (_message != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SelectableText(_message!)),
          ]),
        ),
      );
}
