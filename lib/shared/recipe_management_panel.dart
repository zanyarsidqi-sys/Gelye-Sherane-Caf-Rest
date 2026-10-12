import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Recipe configuration backed by migration 029. Quantities are integer stock units.
class RecipeManagementPanel extends StatefulWidget {
  const RecipeManagementPanel({super.key});
  @override
  State<RecipeManagementPanel> createState() => _RecipeManagementPanelState();
}

class _RecipeManagementPanelState extends State<RecipeManagementPanel> {
  final _quantity = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _components = [];
  Map<int, String> _units = {};
  int? _menuId;
  int? _ingredientId;
  bool _busy = false;
  String? _error;

  @override
  void initState() { super.initState(); _loadProducts(); }
  @override
  void dispose() { _quantity.dispose(); super.dispose(); }

  Future<void> _loadProducts() async {
    setState(() { _busy = true; _error = null; });
    try {
      final rows = await Supabase.instance.client.from('gs_menu_products')
          .select('id,name,is_active').eq('is_active', true).order('name').limit(500);
      final units = await Supabase.instance.client.rpc('gs_recipe_stock_units');
      if (!mounted) return;
      setState(() {
        _products = List<Map<String, dynamic>>.from(rows);
        _units = {for (final u in (units as List)) (u['product_id'] as num).toInt(): u['stock_unit'] as String};
      });
    } catch (e) { if (mounted) setState(() => _error = 'Products unavailable: $e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _loadRecipe() async {
    final id = _menuId;
    if (id == null) return;
    setState(() { _busy = true; _error = null; _components = []; });
    try {
      final result = await Supabase.instance.client.rpc('gs_recipe_components', params: {'p_menu_product_id': id});
      if (!mounted || _menuId != id) return;
      setState(() => _components = List<Map<String, dynamic>>.from(result as List));
    } catch (e) { if (mounted) setState(() => _error = 'Recipe unavailable: $e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _setComponent(int ingredientId, int quantity) async {
    if (_menuId == null || _busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.rpc('gs_recipe_set_component', params: {
        'p_menu_product_id': _menuId,
        'p_ingredient_product_id': ingredientId,
        'p_quantity': quantity,
      });
      if (!mounted) return;
      setState(() => _busy = false);
      await _loadRecipe();
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = 'Recipe update failed: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = _products.where((p) => p['id'] != _menuId).toList();
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const ListTile(title: Text('Recipe ingredients'), subtitle: Text('Requires migrations 029–030. Set each ingredient unit before adding a recipe; existing stock is never auto-converted.')),
        if (_error != null) SelectableText(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (_busy) const LinearProgressIndicator(),
        DropdownButtonFormField<int>(
          initialValue: _menuId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Menu product', border: OutlineInputBorder()),
          items: _products.map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text('${p['name']}'))).toList(),
          onChanged: _busy ? null : (id) { setState(() { _menuId = id; _ingredientId = null; _components = []; }); _loadRecipe(); },
        ),
        if (_menuId != null) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _ingredientId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Ingredient product', border: OutlineInputBorder()),
            items: ingredients.map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text("${p['name']} (${_units[(p['id'] as num).toInt()] ?? 'unconfigured'})"))).toList(),
            onChanged: _busy ? null : (id) => setState(() => _ingredientId = id),
          ),
          const SizedBox(height: 8),
          if (_ingredientId != null && _units[_ingredientId] == 'unconfigured')
            const Text('Set the stock unit before using this ingredient.', style: TextStyle(color: Colors.orange)),
          if (_ingredientId != null) Text('Unit: ${_units[_ingredientId] ?? 'unconfigured'}'),
          const SizedBox(height: 8),
          TextField(controller: _quantity, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity per menu item (whole stock units)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          FilledButton.icon(icon: const Icon(Icons.save_outlined), label: const Text('Save ingredient'),
            onPressed: _busy ? null : () {
              final qty = int.tryParse(_quantity.text.trim());
              if (_ingredientId == null || _units[_ingredientId] == null || _units[_ingredientId] == 'unconfigured' || qty == null || qty < 1 || qty > 1000000) {
                setState(() => _error = 'Configure its stock unit and enter a quantity from 1 to 1,000,000.');
                return;
              }
              _setComponent(_ingredientId!, qty);
            }),
          const Divider(),
          if (_components.isEmpty) const Text('No recipe ingredients configured. Products without recipes use finished-product stock deduction.'),
          for (final c in _components) ListTile(
            title: Text('${c['ingredient_name']}'),
            subtitle: Text("${c['quantity_per_item']} ${_units[(c['ingredient_product_id'] as num).toInt()] ?? 'units'} per item"),
            trailing: IconButton(tooltip: 'Remove ingredient', icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : () => _setComponent((c['ingredient_product_id'] as num).toInt(), 0)),
          ),
        ],
      ],
    )));
  }
}
