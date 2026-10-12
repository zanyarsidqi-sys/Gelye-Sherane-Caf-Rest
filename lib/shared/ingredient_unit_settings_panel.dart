import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configures physical ingredient units through permission-checked database RPCs.
/// This never converts existing stock quantities.
class IngredientUnitSettingsPanel extends StatefulWidget {
  const IngredientUnitSettingsPanel({super.key});

  @override
  State<IngredientUnitSettingsPanel> createState() => _IngredientUnitSettingsPanelState();
}

class _IngredientUnitSettingsPanelState extends State<IngredientUnitSettingsPanel> {
  bool _saving = false;
  String? _error;
  Future<List<Map<String, dynamic>>>? _data;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _data = _fetch();
      _error = null;
    });
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final client = Supabase.instance.client;
    final products = await client.from('gs_menu_products')
        .select('id,name,barcode').eq('is_active', true).order('name').limit(500);
    final units = await client.rpc('gs_recipe_stock_units');
    final byId = <String, Map<String, dynamic>>{
      for (final row in List<Map<String, dynamic>>.from(units)) '${row['product_id']}': row,
    };
    return List<Map<String, dynamic>>.from(products).map((product) => {
      ...product,
      'stock_unit': byId['${product['id']}']?['stock_unit'] ?? 'unconfigured',
      'is_configured': byId['${product['id']}']?['is_configured'] == true,
    }).toList();
  }

  Future<void> _configure(Map<String, dynamic> product) async {
    final existing = '${product['stock_unit']}';
    var selection = existing == 'unconfigured' ? 'piece' : existing;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('Stock unit: ${product['name']}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Choose the physical unit used for inventory and recipe quantities. Existing stock is not converted.'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selection,
              decoration: const InputDecoration(labelText: 'Inventory unit'),
              items: const [
                DropdownMenuItem(value: 'piece', child: Text('Pieces')),
                DropdownMenuItem(value: 'gram', child: Text('Grams')),
                DropdownMenuItem(value: 'milliliter', child: Text('Milliliters')),
              ],
              onChanged: (value) => update(() => selection = value ?? selection),
            ),
            if (existing != 'unconfigured' && existing != selection)
              const Padding(padding: EdgeInsets.only(top: 12), child: Text(
                'Changing an established unit may be blocked by the server. An audited conversion is required for existing stock.',
              )),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save unit')),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() { _saving = true; _error = null; });
    try {
      await Supabase.instance.client.rpc('gs_set_inventory_unit', params: {
        'p_product_id': product['id'], 'p_unit': selection,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock unit saved.')));
        _reload();
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to save stock unit: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const Expanded(child: Text('Ingredient stock units', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        IconButton(onPressed: _saving ? null : _reload, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
      ]),
      const Text('Set each ingredient unit before adding it to a recipe. Requires inventory edit permission.'),
      if (_error != null) Padding(padding: const EdgeInsets.all(8), child: SelectableText(_error!, style: const TextStyle(color: Colors.red))),
      if (_saving) const LinearProgressIndicator(),
      Flexible(child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) return SelectableText('Unable to load units: ${snapshot.error}');
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final products = snapshot.data!;
          if (products.isEmpty) return const Text('No active menu products.');
          return ListView.builder(
            shrinkWrap: true,
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                title: Text('${product['name']}'),
                subtitle: Text('Barcode: ${product['barcode'] ?? '—'} · Unit: ${product['stock_unit']}'),
                trailing: TextButton(onPressed: _saving ? null : () => _configure(product), child: const Text('Configure')),
              );
            },
          );
        },
      )),
    ]),
  );
}
