import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CafeMenuItem {
  const CafeMenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.priceIqd,
    required this.available,
  });
  factory CafeMenuItem.fromJson(Map<String, dynamic> row) => CafeMenuItem(
    id: row['id'] as String,
    name: row['name'] as String,
    category: row['category'] as String,
    description: row['description'] as String,
    priceIqd: (row['price_iqd'] as num).toInt(),
    available: row['available'] as bool,
  );
  final String id, name, category, description;
  final int priceIqd;
  final bool available;
}

abstract class CafeMenuStore {
  Future<List<CafeMenuItem>> load();
  Future<void> save({
    String? id,
    required String name,
    required String category,
    required String description,
    required int priceIqd,
    required bool available,
  });
}

class SupabaseCafeMenuStore implements CafeMenuStore {
  SupabaseCafeMenuStore(this.client);
  final SupabaseClient client;
  @override
  Future<List<CafeMenuItem>> load() async {
    final rows = await client.rpc('list_cafe_menu_items') as List;
    return rows
        .map(
          (row) => CafeMenuItem.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  @override
  Future<void> save({
    String? id,
    required String name,
    required String category,
    required String description,
    required int priceIqd,
    required bool available,
  }) async {
    if (name.trim().isEmpty ||
        name.trim().length > 120 ||
        category.trim().isEmpty ||
        category.trim().length > 60 ||
        description.length > 500 ||
        priceIqd < 1 ||
        priceIqd > 999999999) {
      throw const FormatException(
        'Enter a name, category and whole IQD price from 1 to 999999999.',
      );
    }
    if (client.auth.currentUser == null) {
      throw const AuthException('Sign in to save menu products.');
    }
    await client.rpc(
      'save_cafe_menu_item',
      params: {
        'p_id': id,
        'p_name': name.trim(),
        'p_category': category.trim(),
        'p_description': description.trim(),
        'p_price_iqd': priceIqd,
        'p_available': available,
      },
    );
  }
}

class CafeMenuWorkspace extends StatefulWidget {
  const CafeMenuWorkspace({
    super.key,
    required this.store,
    required this.canCreate,
    required this.canEdit,
  });
  final CafeMenuStore? store;
  final bool canCreate, canEdit;
  @override
  State<CafeMenuWorkspace> createState() => _CafeMenuWorkspaceState();
}

class _CafeMenuWorkspaceState extends State<CafeMenuWorkspace> {
  List<CafeMenuItem> _items = [];
  String _query = '';
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.store == null) {
        throw StateError('Menu connection is not configured.');
      }
      final items = await widget.store!.load();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not load products. Check your connection, menu permissions , then retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([CafeMenuItem? item]) async {
    if (item == null ? !widget.canCreate : !widget.canEdit) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MenuEditor(store: widget.store!, item: item),
    );
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _items
        .where(
          (i) => '${i.name} ${i.category} ${i.description}'
              .toLowerCase()
              .contains(_query.toLowerCase()),
        )
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Product catalog',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Saved products and base prices in IQD. Available products can be added to orders.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (widget.canCreate)
                  FilledButton.icon(
                    onPressed: _loading || _error != null
                        ? null
                        : () => _edit(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add product'),
                  ),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh products'),
                ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(padding: const EdgeInsets.all(16), child: Text(_error!))
            else ...[
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search products or categories',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              Text('${matches.length} products'),
              if (matches.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No products match. Add a product or change your search.',
                  ),
                ),
              for (final item in matches)
                ListTile(
                  title: Text(item.name),
                  isThreeLine: true,
                  subtitle: Text(
                    '${item.category} · ${item.priceIqd} IQD\n${item.available ? 'Available' : 'Unavailable'}',
                  ),
                  trailing: widget.canEdit
                      ? IconButton(
                          tooltip: 'Edit ${item.name}',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _edit(item),
                        )
                      : null,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuEditor extends StatefulWidget {
  const _MenuEditor({required this.store, this.item});
  final CafeMenuStore store;
  final CafeMenuItem? item;
  @override
  State<_MenuEditor> createState() => _MenuEditorState();
}

class _MenuEditorState extends State<_MenuEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name);
  late final _category = TextEditingController(text: widget.item?.category);
  late final _description = TextEditingController(
    text: widget.item?.description,
  );
  late final _price = TextEditingController(
    text: widget.item?.priceIqd.toString(),
  );
  late bool _available = widget.item?.available ?? true;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.save(
        id: widget.item?.id,
        name: _name.text,
        category: _category.text,
        description: _description.text,
        priceIqd: int.parse(_price.text.trim()),
        available: _available,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Save could not be confirmed. Close and refresh products before retrying to avoid creating a duplicate.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(widget.item == null ? 'Add product' : 'Edit product'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Product name'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter a product name.'
                      : null,
                ),
                TextFormField(
                  controller: _category,
                  enabled: !_saving,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: 'Category'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter a category.'
                      : null,
                ),
                TextFormField(
                  controller: _description,
                  enabled: !_saving,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                TextFormField(
                  controller: _price,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Base price IQD',
                  ),
                  validator: (v) {
                    final value = int.tryParse(v?.trim() ?? '');
                    return value == null || value < 1 || value > 999999999
                        ? 'Enter a whole IQD amount from 1 to 999999999.'
                        : null;
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available to order'),
                  value: _available,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _available = v),
                ),
                if (_error != null) Text(_error!),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _saving || _error != null ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save product'),
        ),
      ],
    ),
  );
}
