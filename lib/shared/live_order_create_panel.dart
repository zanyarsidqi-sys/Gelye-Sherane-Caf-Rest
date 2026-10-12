import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/secure_order_service.dart';

/// Optional live order creation. Requires reviewed gs_ migration and backend
/// can_create permission. The server determines prices; no client price input.
class LiveOrderCreatePanel extends StatefulWidget {
  const LiveOrderCreatePanel({super.key, required this.isMotel});
  final bool isMotel;

  @override
  State<LiveOrderCreatePanel> createState() => _LiveOrderCreatePanelState();
}

class _LiveOrderCreatePanelState extends State<LiveOrderCreatePanel> {
  final _destination = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _barcode = TextEditingController();
  final _productSearch = TextEditingController();
  bool _lookingUpBarcode = false;
  String? _barcodeFeedback;
  late Future<List<Map<String, dynamic>>> _products = _loadProducts();
  int? _productId;
  Map<String, dynamic>? _scannedProduct;
  int? _tableNumber;
  late Future<List<Map<String, dynamic>>> _tables = _loadTables();

  Future<List<Map<String, dynamic>>> _loadTables() async {
    final rows = await Supabase.instance.client.from('gs_cafe_tables').select('table_number,occupied,tourism_mode').eq('occupied', true).order('table_number');
    final tables = List<Map<String, dynamic>>.from(rows);
    _occupiedTables = tables;
    return tables;
  }
  bool _submitting = false;
  final Map<int, int> _cart = {};
  final Map<int, String> _cartNames = {};
  final Map<int, Map<String, dynamic>> _cartProducts = {};
  bool _confirmOrder = false;
  bool _motelDestinationConfirmed = false;
  List<Map<String, dynamic>> _occupiedTables = [];

  String get _selectedMode {
    if (widget.isMotel) return 'tourism';
    for (final table in _occupiedTables) {
      if (table['table_number'] == _tableNumber) {
        return table['tourism_mode'] == true ? 'tourism' : 'normal';
      }
    }
    return 'unknown';
  }

  int? _estimatedLineTotal(int id, int quantity) {
    final product = _cartProducts[id];
    if (product == null || _selectedMode == 'unknown') return null;
    final raw = product[_selectedMode == 'tourism'
        ? 'tourism_price_iqd' : 'normal_price_iqd'];
    if (raw is! num) return null;
    return raw.toInt() * quantity;
  }


  void _addToCart() {
    final id = _productId;
    final quantity = int.tryParse(_quantity.text.trim());
    if (id == null || quantity == null || quantity < 1 || quantity > 999 ||
        (_cart[id] ?? 0) + quantity > 999 ||
        (!_cart.containsKey(id) && _cart.length >= 100)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a product and valid quantity (1–999 per product; maximum 100 products).')));
      return;
    }
    setState(() {
      _cart[id] = (_cart[id] ?? 0) + quantity;
      if (_scannedProduct?['id'] == id) {
        _cartProducts[id] = Map<String, dynamic>.from(_scannedProduct!);
      }
      _cartNames[id] = _cartProducts[id]?['name']?.toString() ?? 'Product #$id';
      _confirmOrder = false;
      _quantity.text = '1';
      _barcode.clear();
      _barcodeFeedback = null;
    });
  }


  void _refreshLiveData() {
    setState(() {
      _productId = null;
      _scannedProduct = null;
      _tableNumber = null;
      _barcode.clear();
      _barcodeFeedback = null;
      _products = _loadProducts();
      _tables = _loadTables();
      _confirmOrder = false;
    });
  }


  Future<List<Map<String, dynamic>>> _loadProducts() async {
    final result = await Supabase.instance.client
        .from('gs_menu_products')
        .select('id,name,barcode,normal_price_iqd,tourism_price_iqd')
        .eq('is_active', true)
        .order('name')
        .limit(200);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<void> _findBarcode() async {
    final barcode = _barcode.text.trim();
    if (barcode.isEmpty) return;
    setState(() { _lookingUpBarcode = true; _barcodeFeedback = null; });
    try {
      final rows = await Supabase.instance.client
          .from('gs_menu_products')
          .select('id,name,barcode,normal_price_iqd,tourism_price_iqd')
          .eq('barcode', barcode)
          .eq('is_active', true)
          .limit(2);
      if (!mounted) return;
      if (rows.length != 1) {
        setState(() => _barcodeFeedback = rows.isEmpty
            ? 'No active product matches this barcode.'
            : 'Duplicate barcode records. Ask an administrator to resolve them.');
        return;
      }
      final product = Map<String, dynamic>.from(rows.single);
      setState(() {
        _productId = (product['id'] as num).toInt();
        _scannedProduct = product;
        _barcodeFeedback = 'Selected: ${product['name']}. Server calculates the final price.';
      });
    } catch (error) {
      if (mounted) setState(() => _barcodeFeedback = 'Barcode lookup failed: Please retry or contact a manager');
    } finally {
      if (mounted) setState(() => _lookingUpBarcode = false);
    }
  }

  Future<void> _submit() async {
    if (widget.isMotel && !_motelDestinationConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Verify the guest room or villa with reception before submitting.')));
      return;
    }
    if (!_confirmOrder) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Review the cart and confirm the order before submitting.')));
      return;
    }
    final destination = widget.isMotel ? _destination.text.trim() : (_tableNumber?.toString() ?? '');
    if (_cart.isEmpty || destination.isEmpty || destination.length > 120) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add items and select a valid table or motel destination.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final orderId = await SecureOrderService().createCartOrder(
        destination: destination,
        isMotel: widget.isMotel,
        tableNumber: widget.isMotel ? null : _tableNumber,
        items: _cart.entries.map((e) => {'product_id': e.key, 'quantity': e.value}).toList(),
      );
      if (!mounted) return;
      _cart.clear();
      _cartNames.clear();
      _cartProducts.clear();
      _confirmOrder = false;
      _destination.clear();
      _motelDestinationConfirmed = false;
      _quantity.text = '1';
      _refreshLiveData();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Live order #$orderId created. Price set by server.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Order not created: $error')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // Edit a saved order line before the order is accepted. The database
  // validates ownership/permissions, status and immutable ticket snapshots.
  Future<void> _editPreparationInstructions() async {
    final itemId = TextEditingController();
    final note = TextEditingController();
    bool saving = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, update) => AlertDialog(
            title: const Text('Preparation instructions'),
            content: SizedBox(
              width: 420,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Enter the saved order-item ID. Instructions can only be edited before the order is accepted.'),
                const SizedBox(height: 12),
                TextField(
                  controller: itemId,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Order item ID', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Instructions (blank clears)', hintText: 'No onion, less sugar...', border: OutlineInputBorder()),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton(
                onPressed: saving ? null : () async {
                  final id = int.tryParse(itemId.text.trim());
                  if (id == null || id <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid order-item ID.')));
                    return;
                  }
                  update(() => saving = true);
                  try {
                    await Supabase.instance.client.rpc('gs_set_order_item_preparation_instructions', params: {
                      'p_order_item_id': id,
                      'p_instructions': note.text,
                    });
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preparation instructions saved.')));
                  } catch (error) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save instructions: $error')));
                  } finally {
                    if (dialogContext.mounted) update(() => saving = false);
                  }
                },
                child: Text(saving ? 'Saving...' : 'Save instructions'),
              ),
            ],
          ),
        ),
      );
    } finally {
      itemId.dispose();
      note.dispose();
    }
  }

  @override
  void dispose() {
    _destination.dispose();
    _quantity.dispose();
    _barcode.dispose();
    _productSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
              child: ListTile(
            leading: Icon(Icons.verified_user_outlined),
            title: Text('LIVE SUPABASE ORDER CREATION'),
            subtitle: Text(
                'Requires reviewed gs_ migration and employee can_create permission. Server selects and stores the charged price. This creates a real order.'),
          )),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _submitting ? null : _refreshLiveData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh tables and products'),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.isMotel)
            Column(children: [
              TextField(
                controller: _destination,
                maxLength: 120,
                onChanged: (_) => setState(() {
                  _motelDestinationConfirmed = false;
                  _confirmOrder = false;
                }),
                decoration: const InputDecoration(
                  labelText: 'Motel room / villa',
                  helperText: 'Use the exact guest destination confirmed by reception.',
                  border: OutlineInputBorder(),
                ),
              ),
              CheckboxListTile(
                value: _motelDestinationConfirmed,
                onChanged: _submitting ? null : (value) => setState(() {
                  _motelDestinationConfirmed = value ?? false;
                  _confirmOrder = false;
                }),
                title: const Text('I verified this guest room / villa with reception'),
                subtitle: const Text('Manual staff confirmation only; no live occupancy lookup is connected yet.'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ])
          else
            FutureBuilder<List<Map<String, dynamic>>>(future: _tables, builder: (context, snapshot) {
              if (snapshot.hasError) return Text('Unable to load occupied tables: ${snapshot.error}');
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final tables = snapshot.data!;
              if (tables.isEmpty) return const Text('No occupied tables configured. Mark a table occupied in Tables first.');
              return DropdownButtonFormField<int>(initialValue: tables.any((t) => t['table_number'] == _tableNumber) ? _tableNumber : null,
                decoration: const InputDecoration(labelText: 'Occupied table', border: OutlineInputBorder()),
                items: [for (final table in tables) DropdownMenuItem<int>(value: (table['table_number'] as num).toInt(),
                  child: Text('Table ${table['table_number']} — ${table['tourism_mode'] == true ? 'Tourism' : 'Normal'}'))],
                onChanged: (value) => setState(() { _tableNumber = value; _confirmOrder = false; }));
            }),
          const SizedBox(height: 12),
          TextField(
            controller: _barcode,
            onSubmitted: (_) => _findBarcode(),
            decoration: InputDecoration(
              labelText: 'Scan or enter product barcode',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Find barcode',
                onPressed: _lookingUpBarcode ? null : _findBarcode,
                icon: const Icon(Icons.search),
              ),
            ),
          ),
          if (_lookingUpBarcode) const LinearProgressIndicator(),
          if (_barcodeFeedback != null) Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_barcodeFeedback!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _productSearch,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Filter loaded products by name or barcode',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _products,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                if (snapshot.hasError) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                            'Unable to load live products. Check migration, access and connection.'),
                        SelectableText('${snapshot.error}'),
                        TextButton(
                            onPressed: () => setState(() {
                                  _productId = null;
                                  _products = _loadProducts();
                                }),
                            child: const Text('Retry')),
                      ]);
                }
                return const Center(child: CircularProgressIndicator());
              }
              final query = _productSearch.text.trim().toLowerCase();
              final products = <Map<String, dynamic>>[
                ...snapshot.data!.where((p) => query.isEmpty ||
                    '${p['name']} ${p['barcode']}'.toLowerCase().contains(query)),
              ];
              if (_scannedProduct != null &&
                  !products.any((p) => p['id'] == _scannedProduct!['id'])) {
                products.insert(0, _scannedProduct!);
              }
              if (products.isEmpty) {
                return const Text(
                    'No matching products in the first 200 loaded records. Scan a barcode or adjust your search.');
              }
              return DropdownButtonFormField<int>(
                key: ValueKey('product-${_productId ?? 'none'}-${_scannedProduct?['id'] ?? 'none'}'),
                initialValue: products.any((p) => p['id'] == _productId)
                    ? _productId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Live product', border: OutlineInputBorder()),
                items: [
                  for (final p in products)
                    DropdownMenuItem<int>(
                        value: (p['id'] as num).toInt(),
                        child: Text('${p['name']} (${p['barcode']})',
                            overflow: TextOverflow.ellipsis))
                ],
                onChanged: (value) => setState(() {
                  _productId = value;
                  for (final p in products) {
                    if (p['id'] == value) { _scannedProduct = p; break; }
                  }
                }),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Quantity (1–999)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          if (widget.isMotel)
            const ListTile(
                leading: Icon(Icons.hotel_outlined),
                title: Text('Tourism Mode is mandatory for Motel Orders'))
          else
            const ListTile(title: Text('Price mode comes from Tables Management'),
              subtitle: Text('The server locks the table record and selects its saved Normal/Tourism mode.')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _addToCart,
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Add selected product to cart'),
          ),
          const SizedBox(height: 8),
          Text('Cart — ${_cart.length} products', style: Theme.of(context).textTheme.titleMedium),
          Text('Selected base mode: ${_selectedMode.toUpperCase()} · Prices below are estimates only. '
              'Admin discounts and Owner Mode may change the server-calculated total.'),
          for (final item in _cart.entries)
            Card(child: ListTile(
              title: Text(_cartNames[item.key] ?? 'Product #${item.key}'),
              subtitle: Text('Quantity: ${item.value} · '
                  '${_estimatedLineTotal(item.key, item.value) == null ? 'Price unavailable' : '${_estimatedLineTotal(item.key, item.value)} IQD estimate'}'),
              trailing: Wrap(spacing: 0, children: [
                IconButton(
                  tooltip: 'Decrease quantity',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _submitting ? null : () => setState(() {
                    if (item.value <= 1) { _cart.remove(item.key); _cartNames.remove(item.key); _cartProducts.remove(item.key); }
                    else { _cart[item.key] = item.value - 1; }
                    _confirmOrder = false;
                  }),
                ),
                IconButton(
                  tooltip: 'Increase quantity',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _submitting || item.value >= 999 ? null : () => setState(() {
                    _cart[item.key] = item.value + 1;
                    _confirmOrder = false;
                  }),
                ),
                IconButton(
                  tooltip: 'Remove item',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _submitting ? null : () => setState(() {
                    _cart.remove(item.key);
                    _cartNames.remove(item.key);
                    _cartProducts.remove(item.key);
                    _confirmOrder = false;
                  }),
                ),
              ]),
            )),
          if (_cart.isNotEmpty) ...[
            Builder(builder: (context) {
              int estimate = 0;
              bool complete = true;
              for (final entry in _cart.entries) {
                final amount = _estimatedLineTotal(entry.key, entry.value);
                if (amount == null) complete = false;
                else estimate += amount;
              }
              return ListTile(
                title: const Text('Estimated base-price total'),
                subtitle: const Text('Not a final charge. Supabase calculates Owner/Discount Mode and stores final prices.'),
                trailing: Text(complete ? '$estimate IQD' : 'Unavailable'),
              );
            }),
            CheckboxListTile(
              value: _confirmOrder,
              onChanged: _submitting ? null : (v) => setState(() => _confirmOrder = v ?? false),
              title: Text(widget.isMotel
                  ? 'I reviewed the room / villa, products and quantities'
                  : 'I reviewed the table, products and quantities'),
              subtitle: const Text('Submitting creates a real order. This is not a test order.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
          FilledButton.icon(
              onPressed: _submitting || _cart.isEmpty || !_confirmOrder ||
                  (widget.isMotel && !_motelDestinationConfirmed) ? null : _submit,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(_submitting ? 'Submitting...' : 'Submit entire cart as ONE order')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _editPreparationInstructions,
            icon: const Icon(Icons.edit_note),
            label: const Text('Edit saved order-item preparation instructions'),
          ),
          const Text('Requires an existing order-item ID. Save notes before accepting the order; printing uses the saved snapshot.'),
          const SizedBox(height: 12),
          const Text(
              'Prices shown in other screens are informational; the server is authoritative.'),
        ],
      );
}
