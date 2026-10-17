import 'cafe_language.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CafeMenuItem {
  const CafeMenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.priceIqd,
    this.tourismPriceIqd,
    this.ownerPriceIqd,
    this.imagePath,
    this.stationIds = const [],
    this.stationNames = const [],
    required this.available,
  });
  factory CafeMenuItem.fromJson(Map<String, dynamic> row) => CafeMenuItem(
    id: row['id'] as String,
    name: row['name'] as String,
    category: row['category'] as String,
    description: row['description'] as String,
    priceIqd: (row['price_iqd'] as num).toInt(),
    tourismPriceIqd: (row['tourism_price_iqd'] as num?)?.toInt(),
    ownerPriceIqd: (row['owner_price_iqd'] as num?)?.toInt(),
    imagePath: row['image_path'] as String?,
    stationIds: List<String>.from(row['station_ids'] ?? []),
    stationNames: List<String>.from(row['station_names'] ?? []),
    available: row['available'] as bool,
  );
  final String id, name, category, description;
  final String? imagePath;
  final int priceIqd;
  final int? tourismPriceIqd, ownerPriceIqd;
  final List<String> stationIds, stationNames;
  final bool available;
}

abstract class CafeMenuStore {
  Future<List<CafeMenuItem>> load();
  Future<List<String>> categories();
  Future<List<Map<String,dynamic>>> stations();
  Future<void> save({
    String? id,
    required String name,
    required String category,
    required String description,
    required int priceIqd,
    required int tourismPriceIqd,
    required int ownerPriceIqd,
    required List<String> stationIds,
    required bool available,
  });
}

class SupabaseCafeMenuStore implements CafeMenuStore {
  SupabaseCafeMenuStore(this.client);
  final SupabaseClient client;
  @override
  Future<List<CafeMenuItem>> load() async {
    final rows = await client.rpc('list_cafe_menu_routed') as List;
    return rows
        .map(
          (row) => CafeMenuItem.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  @override
  Future<List<String>> categories() async {
    final rows=await client.rpc('manage_cafe_menu_assets',params:{'p_action':'categories'}) as List;
    return rows.map((row)=>(row as Map)['name'] as String).toList();
  }

  @override
  Future<List<Map<String,dynamic>>> stations() async {
    final result = await client.rpc('get_cafe_print_stations') as Map;
    return (result['stations'] as List).map((e)=>Map<String,dynamic>.from(e)).toList();
  }

  @override
  Future<void> save({
    String? id,
    required String name,
    required String category,
    required String description,
    required int priceIqd,
    required int tourismPriceIqd,
    required int ownerPriceIqd,
    required List<String> stationIds,
    required bool available,
  }) async {
    if (name.trim().isEmpty ||
        name.trim().length > 120 ||
        category.trim().isEmpty ||
        category.trim().length > 60 ||
        description.length > 500 ||
        priceIqd < 1 ||
        priceIqd > 999999999 || tourismPriceIqd < 1 || tourismPriceIqd > 999999999 || ownerPriceIqd < 0 || ownerPriceIqd > 999999999) {
      throw const FormatException(
        'Enter a name and category. Normal/Tourism prices must be positive; Owner price may be zero.',
      );
    }
    if (client.auth.currentUser == null) {
      throw const AuthException('Sign in to save menu products.');
    }
    await client.rpc(
      'save_cafe_menu_routed',
      params: {
        'p_id': id,
        'p_name': name.trim(),
        'p_category': category.trim(),
        'p_description': description.trim(),
        'p_price_iqd': priceIqd,
        'p_tourism_price_iqd': tourismPriceIqd,
        'p_owner_price_iqd': ownerPriceIqd,
        'p_available': available,
        'p_station_ids': stationIds,
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
            const CafeText(
              'Product catalog',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const CafeText(
              'Normal, Tourism and Owner prices in IQD. Available products can be added to orders.',
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
                    label: const CafeText('Add product'),
                  ),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: const CafeText('Refresh products'),
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
                  label: CafeText('Search products or categories'),
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              CafeText('${matches.length} products'),
              if (matches.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CafeText(
                    'No products match. Add a product or change your search.',
                  ),
                ),
              for (final item in matches)
                ListTile(
                  leading: item.imagePath == null ? null : Image.network(Supabase.instance.client.storage.from('cafe-product-images').getPublicUrl(item.imagePath!),width:54,height:54,fit:BoxFit.cover,errorBuilder:(_,e,s)=>const Icon(Icons.broken_image_outlined)),
                  title: Text(item.name),

                  subtitle: CafeText(
                    '${item.category} \nNormal: ${item.priceIqd} IQD · Tourism: ${item.tourismPriceIqd ?? item.priceIqd} IQD · Owner: ${item.ownerPriceIqd ?? item.priceIqd} IQD\nPrint to: ${item.stationNames.isEmpty ? 'Choose a station' : item.stationNames.join(', ')}\n${item.available ? 'Available' : 'Unavailable'}',
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
  List<Map<String,dynamic>> _stations = [];
  List<String> _categories = [];
  late final Set<String> _stationIds = {...?widget.item?.stationIds};
  bool _loadingStations = true;
  String? _stationError;
  @override
  void initState() { super.initState(); _loadStations(); }
  Future<void> _loadStations() async {
    setState(() { _loadingStations=true; _stationError=null; });
    try {
      final rows=await widget.store.stations();
      final categories=await widget.store.categories();
      if(mounted)setState((){_stations=rows;_categories=categories;});
    } catch (_) { if(mounted)setState(()=>_stationError='Could not load categories and print stations. Retry before saving.'); }
    finally { if(mounted)setState(()=>_loadingStations=false); }
  }
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name);
  late final _category = TextEditingController(text: widget.item?.category);
  late final _description = TextEditingController(
    text: widget.item?.description,
  );
  late final _price = TextEditingController(
    text: widget.item?.priceIqd.toString(),
  );
  late final _tourismPrice = TextEditingController(text: widget.item == null ? '' : (widget.item!.tourismPriceIqd ?? widget.item!.priceIqd).toString());
  late final _ownerPrice = TextEditingController(text: widget.item == null ? '' : (widget.item!.ownerPriceIqd ?? widget.item!.priceIqd).toString());
  late bool _available = widget.item?.available ?? true;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _description.dispose();
    _price.dispose();
    _tourismPrice.dispose();
    _ownerPrice.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_loadingStations || _stationError != null || _stationIds.isEmpty) {
      setState(()=>_stationError='Select at least one print station.'); return;
    }
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
        tourismPriceIqd: int.parse(_tourismPrice.text.trim()),
        ownerPriceIqd: int.parse(_ownerPrice.text.trim()),
        available: _available,
        stationIds: _stationIds.toList(),
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
                  decoration: const InputDecoration(label: CafeText('Product name')),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter a product name.'
                      : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _category.text.isEmpty ? null : _category.text,
                  isExpanded: true,
                  decoration: const InputDecoration(label: CafeText('Category'),helperText:'Add categories in Product Categories.'),
                  items: {..._categories, if (_category.text.isNotEmpty) _category.text}.map((name)=>DropdownMenuItem(value:name,child:Text(name))).toList(),
                  onChanged: _saving || _loadingStations ? null : (value)=>setState(()=>_category.text=value??''),
                  validator: (value)=>value==null||value.isEmpty?'Choose a category':null,
                ),
                TextFormField(
                  controller: _description,
                  enabled: !_saving,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(label: CafeText('Description')),
                ),
                TextFormField(
                  controller: _price,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    label: CafeText('Normal price IQD'),
                  ),
                  validator: (v) {
                    final value = int.tryParse(v?.trim() ?? '');
                    return value == null || value < 1 || value > 999999999
                        ? 'Enter a whole IQD amount from 1 to 999999999.'
                        : null;
                  },
                ),
                TextFormField(
                  controller: _tourismPrice,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    label: CafeText('Tourism price IQD'),
                  ),
                  validator: (v) {
                    final value = int.tryParse(v?.trim() ?? '');
                    return value == null || value < 1 || value > 999999999
                        ? 'Enter a whole IQD amount from 1 to 999999999.'
                        : null;
                  },
                ),
                TextFormField(
                  controller: _ownerPrice,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    label: CafeText('Owner price IQD'),
                  ),
                  validator: (v) {
                    final value = int.tryParse(v?.trim() ?? '');
                    return value == null || value < 0 || value > 999999999
                        ? 'Enter a whole IQD amount from 0 to 999999999.'
                        : null;
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const CafeText('Available to order'),
                  value: _available,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _available = v),
                ),
                const Align(alignment:Alignment.centerLeft,child:CafeText('Print destinations',style:TextStyle(fontWeight:FontWeight.bold))),
                const CafeText('Select every station that should receive this item. Manage additional stations in Product Printing Routing.'),
                if(_loadingStations) const LinearProgressIndicator(),
                for(final station in _stations)
                  CheckboxListTile(contentPadding:EdgeInsets.zero,title:CafeText('${station['name']}${station['active']==true ? '' : ' (disabled)'}'),value:_stationIds.contains(station['id']),
                    onChanged:_saving ? null : (v)=>setState(() {
                      if(v==true && station['active']==true) { _stationIds.add('${station['id']}'); } else { _stationIds.remove(station['id']); }
                      _stationError=null;
                    })),
                if(_stationError!=null) Text(_stationError!),
                if(_stationError!=null) TextButton(onPressed:_saving?null:_loadStations,child:const CafeText('Reload stations')),
                if (_error != null) Text(_error!),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const CafeText('Close'),
        ),
        FilledButton(
          onPressed: _saving || _error != null ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save product'),
        ),
      ],
    ),
  );
}
