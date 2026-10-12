import '../shared/professional_section_summary.dart';
import 'package:flutter/material.dart';
import '../shared/section_shell.dart';
import '../services/local_menu_preview.dart';
import '../shared/live_records_panel.dart';
import '../shared/live_menu_product_create.dart';
import '../shared/live_menu_product_edit.dart';
import '../shared/recipe_management_panel.dart';
import '../shared/ingredient_unit_settings_panel.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});
  @override
  Widget build(BuildContext context) => const SectionShell(
        title: 'Menu',
        description: 'Normal and Tourism menu pricing',
        sectionId: 'menu',
        authorizedContent: _MenuWorkspace(),
      );
}

class _MenuWorkspace extends StatefulWidget {
  const _MenuWorkspace();
  @override
  State<_MenuWorkspace> createState() => _MenuWorkspaceState();
}

class _MenuWorkspaceState extends State<_MenuWorkspace> {
  final _store = LocalMenuPreview.instance;
  final _name = TextEditingController();
  final _barcode = TextEditingController();
  final _normal = TextEditingController();
  final _tourism = TextEditingController();
  String _query = '';
  bool _showLive = true;
  @override
  void initState() {
    super.initState();
    _store.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_refresh);
    _name.dispose();
    _barcode.dispose();
    _normal.dispose();
    _tourism.dispose();
    super.dispose();
  }

  void _add() {
    final normal = int.tryParse(_normal.text.trim());
    final tourism = int.tryParse(_tourism.text.trim());
    if (normal == null ||
        tourism == null || normal < 0 || tourism < 0 || _name.text.trim().isEmpty || _name.text.trim().length > 200 || _barcode.text.trim().isEmpty || _barcode.text.trim().length > 100 || normal > 1000000000 || tourism > 1000000000 ||
        !_store.add(PreviewMenuItem(
            name: _name.text.trim().replaceAll(RegExp(r'\s+'), ' '),
            barcode: _barcode.text.trim().replaceAll(RegExp(r'\s+'), ''),
            normalPrice: normal,
            tourismPrice: tourism))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Enter a name (max 200 characters), unique barcode (max 100), and IQD prices between 0 and 1,000,000,000.')));
      return;
    }
    _name.clear();
    _barcode.clear();
    _normal.clear();
    _tourism.clear();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _store.items
        .where((p) =>
            p.name.toLowerCase().contains(_query) ||
            p.barcode.contains(_query))
        .toList();
    if (_showLive) {
      return Column(children: [
        const ProfessionalSectionSummary(title: 'Menu management', subtitle: 'Live products, ingredients and recipes', icon: Icons.menu_book_outlined, items: ['Products', 'Ingredients', 'Recipes']),
        SwitchListTile(
            title: const Text('Live Supabase menu management'),
            subtitle:
                const Text('Create and edit products with separate Normal and Tourism prices. Turn off for offline demo only.'),
            value: _showLive,
            onChanged: (value) => setState(() => _showLive = value)),
        LiveMenuProductCreate(onCreated: () => setState(() {})),
        const LiveMenuProductEdit(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
            icon: const Icon(Icons.straighten),
            label: const Text('Configure ingredient stock units'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => Dialog(child: SizedBox(
                width: 650,
                height: 550,
                child: IngredientUnitSettingsPanel(),
              )),
            ),
          )),
        ),
        const RecipeManagementPanel(),
        const Expanded(child: LiveRecordsPanel(kind: 'menu')),
      ]);
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      const ProfessionalSectionSummary(title: 'Menu preview', subtitle: 'Local demonstration only — not saved to Supabase', icon: Icons.science_outlined, items: ['Preview', 'Barcode', 'IQD']),
      SwitchListTile(
          title: const Text('Live Supabase menu management'),
          subtitle: const Text(
              'Turn on to manage real products; local preview changes are not saved to Supabase'),
          value: _showLive,
          onChanged: (value) => setState(() => _showLive = value)),
      const Card(
          child: ListTile(
        leading: Icon(Icons.science_outlined),
        title: Text('Shared local menu demonstration — NOT LIVE'),
        subtitle: Text(
            'Products created here can be selected by barcode in preview orders during this app session. Nothing is saved to Supabase or live inventory. Real prices and stock must be enforced by the backend.'),
      )),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(
            width: 250,
            child: TextField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: 'Product name', border: OutlineInputBorder()))),
        SizedBox(
            width: 210,
            child: TextField(
                controller: _barcode,
                decoration: const InputDecoration(
                    labelText: 'Barcode', border: OutlineInputBorder()))),
        SizedBox(
            width: 190,
            child: TextField(
                controller: _normal,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Normal price (IQD)',
                    border: OutlineInputBorder()))),
        SizedBox(
            width: 190,
            child: TextField(
                controller: _tourism,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Tourism price (IQD)',
                    border: OutlineInputBorder()))),
      ]),
      const SizedBox(height: 12),
      Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Add preview product'))),
      const SizedBox(height: 20),
      TextField(
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search products or barcodes',
              border: OutlineInputBorder())),
      const SizedBox(height: 12),
      if (shown.isEmpty)
        const ListTile(title: Text('No preview products found')),
      for (final item in shown)
        Card(
            child: ListTile(
          title: Text(item.name),
          subtitle: Text(
              'Barcode: ${item.barcode}\nNormal: ${item.normalPrice} IQD  •  Tourism: ${item.tourismPrice} IQD'),
          isThreeLine: true,
          trailing: IconButton(
              tooltip: 'Remove preview item',
              onPressed: () => _store.remove(item),
              icon: const Icon(Icons.delete_outline)),
        )),
    ]);
  }
}
