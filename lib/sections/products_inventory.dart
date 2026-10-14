import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/section_shell.dart';
import '../shared/product_station_mapping_panel.dart';

class ProductsInventoryScreen extends StatelessWidget {
  const ProductsInventoryScreen({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => SectionShell(
    title: 'Products & Inventory',
    description: 'Live stock quantities, movements and low-stock alerts',
    sectionId: 'products_inventory',
    compact: compact,
    authorizedContent: DefaultTabController(length: 2, child: Column(children: [
      TabBar(tabs: [Tab(text: 'Inventory'), Tab(text: 'Product Stations')]),
      Expanded(child: TabBarView(children: [_InventoryLive(), ProductStationMappingPanel()])),
    ])),
  );
}

class _InventoryLive extends StatefulWidget {
  const _InventoryLive();
  @override
  State<_InventoryLive> createState() => _InventoryLiveState();
}

class _InventoryLiveState extends State<_InventoryLive> {
  late Future<List<Map<String, dynamic>>> _future;
  late final StreamSubscription<AuthState> _authSubscription;
  String? _inventoryEmployeeId;
  @override
  void initState() {
    super.initState();
    _inventoryEmployeeId = Supabase.instance.client.auth.currentUser?.id;
    _future = _load();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      // Some auth notifications omit a session even while the active user is
      // still available. Compare against the authoritative current user to
      // avoid needless stock RPCs and false session-change refreshes.
      final currentId = Supabase.instance.client.auth.currentUser?.id;
      if (!mounted || currentId == _inventoryEmployeeId) return;
      _refresh();
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
  String _search = '';
  bool _lowOnly = false;
  bool _outOnly = false;
  bool _submitting = false;
  // PostgREST can represent PostgreSQL bigint values as JSON numbers or
  // decimal strings. Keep stock values exact: reject fractions and malformed
  // values instead of treating them as zero or hiding valid stock records.
  static int? _stockInteger(Object? value) {
    if (value is int) return value >= 0 ? value : null;
    if (value is String && RegExp(r'^[0-9]+$').hasMatch(value)) {
      final parsed = int.tryParse(value);
      return parsed != null && parsed >= 0 ? parsed : null;
    }
    return null;
  }

  // Stock movement deltas can be negative PostgreSQL bigint values. Parse
  // decimal strings without floating-point conversion, which can round large
  // movements and incorrectly display a different financial/stock audit value.
  static int? _movementInteger(Object? value) {
    if (value is int) return value;
    if (value is String && RegExp(r'^-?[0-9]+$').hasMatch(value)) {
      return int.tryParse(value);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _load() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      throw StateError('Sign in to view inventory.');
    }
    final requestedEmployeeId = Supabase.instance.client.auth.currentUser!.id;
    final rows = await Supabase.instance.client.rpc('gs_inventory_overview');
    if (Supabase.instance.client.auth.currentUser?.id != requestedEmployeeId) {
      throw StateError('Employee session changed. Refresh inventory.');
    }
    if (rows is! List) throw const FormatException('Invalid inventory response');
    return rows.map((row) {
      if (row is! Map || row.keys.any((key) => key is! String)) {
        throw const FormatException('Invalid inventory row');
      }
      final item = Map<String, dynamic>.from(row);
      final quantity = _stockInteger(item['quantity']);
      if (quantity == null) throw const FormatException('Invalid inventory quantity');
      final minimum = _stockInteger(item['minimum_quantity']);
      if (minimum == null) throw const FormatException('Invalid minimum stock quantity');
      item['quantity'] = quantity;
      item['minimum_quantity'] = minimum;
      return item;
    }).toList();
  }
  void _refresh() {
    if (!mounted) return;
    setState(() {
      _inventoryEmployeeId = Supabase.instance.client.auth.currentUser?.id;
      _future = _load();
    });
  }

  Future<void> _edit(Map<String, dynamic> item, {required bool minimum}) async {
    if (_submitting) return;
    if (item['product_id'] is! int || (item['product_id'] as int) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product ID missing; cannot update stock.')));
      return;
    }
    final editorUserId = Supabase.instance.client.auth.currentUser?.id;
    if (editorUserId == null) return;
    final amount = TextEditingController(text: minimum ? '${item['minimum_quantity']}' : '1');
    final reason = TextEditingController();
    bool incoming = true;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: Text(minimum ? 'Minimum stock: ${item['name']}' : 'Stock movement: ${item['name']}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!minimum) SwitchListTile(title: Text(incoming ? 'Stock in' : 'Stock out'), value: incoming,
            onChanged: (v) => setDialogState(() => incoming = v)),
          TextField(controller: amount, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: minimum ? 'Minimum quantity' : 'Quantity')),
          if (!minimum) TextField(controller: reason, maxLength: 300,
            decoration: const InputDecoration(labelText: 'Reason (required)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, {
            'amount': amount.text.trim(), 'reason': reason.text.trim(), 'incoming': incoming,
          }), child: const Text('Save')),
        ],
      )),
    );
    amount.dispose(); reason.dispose();
    if (result == null || !mounted ||
        Supabase.instance.client.auth.currentUser?.id != editorUserId) return;
    final value = int.tryParse('${result['amount']}');
    if (value == null || value < (minimum ? 0 : 1) || value > 1000000 ||
        (!minimum && ('${result['reason']}'.trim().length < 3 || result['incoming'] is! bool))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid quantity and reason.')));
      }
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      if (Supabase.instance.client.auth.currentUser?.id != editorUserId) return;
      if (minimum) {
        await Supabase.instance.client.rpc('gs_inventory_set_minimum', params: {
          'p_product_id': item['product_id'], 'p_minimum': value,
        });
      } else {
        await Supabase.instance.client.rpc('gs_inventory_adjust', params: {
          'p_product_id': item['product_id'],
          'p_delta': result['incoming'] == true ? value : -value,
          'p_reason': result['reason'],
        });
      }
      if (mounted && Supabase.instance.client.auth.currentUser?.id == editorUserId) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Inventory update saved. Refreshing stock.')));
      }
    } catch (_) {
      if (mounted && Supabase.instance.client.auth.currentUser?.id == editorUserId) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inventory update failed. Check permissions and stock availability, then refresh.')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _history(Map<String, dynamic> item) async {
    final historyEmployeeId = Supabase.instance.client.auth.currentUser?.id;
    if (historyEmployeeId == null || item['product_id'] is! int || (item['product_id'] as int) <= 0) return;
    // Create the request once, outside the dialog builder. Rebuilding the dialog
    // must not launch another network request or replace its in-flight result.
    final historyRequest = Supabase.instance.client.rpc('gs_inventory_history', params: {
      'p_product_id': item['product_id'], 'p_limit': 50,
    });
    if (!mounted || Supabase.instance.client.auth.currentUser?.id != historyEmployeeId) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Stock history — ${item['name']}'),
        content: SizedBox(
          width: 560,
          height: 420,
          child: StreamBuilder<AuthState>(
            stream: Supabase.instance.client.auth.onAuthStateChange,
            builder: (context, authSnapshot) {
              // The dialog has its own widget tree. Rebuild it on auth changes
              // rather than depending on the parent inventory screen rebuilding.
              if (Supabase.instance.client.auth.currentUser?.id != historyEmployeeId) {
                return const Center(child: Text('Employee changed. Close and reopen history.'));
              }
              return FutureBuilder<dynamic>(
                future: historyRequest,
                builder: (context, snapshot) {
                  if (Supabase.instance.client.auth.currentUser?.id != historyEmployeeId) {
                    return const Center(child: Text('Employee changed. Close and reopen history.'));
                  }
                  if (!snapshot.hasData) {
                return Center(child: snapshot.hasError
                    ? const Text('History unavailable. Check your connection and permissions, then reopen.')
                    : const CircularProgressIndicator());
              }
              if (snapshot.data is! List) return const Center(child: Text('Invalid stock history response.'));
              // Do not silently drop malformed ledger entries: an incomplete audit
              // trail can mislead employees about stock adjustments.
              if ((snapshot.data as List).any((row) => row is! Map || row.keys.any((key) => key is! String))) {
                return const Center(child: Text('Invalid stock history response. Reopen history.'));
              }
              final rows = (snapshot.data as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
              // A ledger must be complete: flag an invalid delta before showing
              // any movements, rather than displaying a partial history.
              if (rows.any((row) => _movementInteger(row['delta']) == null)) {
                return const Center(child: Text('Invalid stock history movement. Reopen history.'));
              }
              if (rows.isEmpty) return const Center(child: Text('No stock movements recorded.'));
              return ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final delta = _movementInteger(row['delta']);
                  if (delta == null) {
                    return const ListTile(title: Text('Invalid stock movement record. Reopen history.'));
                  }
                  return ListTile(
                    leading: Icon(delta > 0 ? Icons.arrow_downward : (delta < 0 ? Icons.arrow_upward : Icons.remove),
                        color: delta > 0 ? Colors.green : Colors.orange),
                    title: Text('${delta > 0 ? '+' : ''}$delta · ${row['reason']}'),
                    subtitle: Text('${row['created_at']}\nEmployee: ${row['employee_id']}'),
                    isThreeLine: true,
                  );
                },
              );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    ListTile(title: const Text('Live inventory'), subtitle: const Text('All quantities are server-controlled.'),
      trailing: IconButton(onPressed: _submitting ? null : _refresh, icon: const Icon(Icons.refresh))),
    TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search name or barcode'),
      onChanged: (v) => setState(() => _search = v.trim().toLowerCase())),
    FutureBuilder<List<Map<String, dynamic>>>(future: _future, builder: (context, snapshot) {
      if (Supabase.instance.client.auth.currentUser?.id != _inventoryEmployeeId) {
        return const Text('Employee session changed. Refresh inventory.');
      }
      if (snapshot.hasError) return const Padding(padding: EdgeInsets.all(8),
        child: Text('Stock summary unavailable; use Refresh to retry.'));
      if (!snapshot.hasData) return const SizedBox.shrink();
      final rows = snapshot.data!;
      final low = rows.where((r) => r['is_low'] == true).length;
      final out = rows.where((r) => r['quantity'] == 0).length;
      return Card(child: Padding(padding: const EdgeInsets.all(12), child: Wrap(
        spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(avatar: const Icon(Icons.inventory_2_outlined, size: 18), label: Text('${rows.length} tracked products')),
          ActionChip(avatar: const Icon(Icons.warning_amber, size: 18),
            label: Text('$low low-stock alerts'),
            onPressed: () => setState(() { _lowOnly = true; _outOnly = false; })),
          ActionChip(avatar: const Icon(Icons.error_outline, size: 18),
            label: Text('$out out of stock'),
            onPressed: () => setState(() { _outOnly = true; _lowOnly = false; })),
          TextButton(onPressed: () => setState(() { _lowOnly = false; _outOnly = false; }),
            child: const Text('Show all')),
        ],
      )));
    }),
    SwitchListTile(title: const Text('Low stock only'), value: _lowOnly,
      onChanged: (v) => setState(() { _lowOnly = v; if (v) _outOnly = false; })),
    if (_outOnly) const Padding(padding: EdgeInsets.all(8),
      child: Text('Showing products with zero stock. Select Show all to clear this filter.')),
    Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: _future, builder: (context, snapshot) {
      if (Supabase.instance.client.auth.currentUser?.id != _inventoryEmployeeId) {
        return const Center(child: Text('Employee session changed. Refresh inventory.'));
      }
      if (!snapshot.hasData) {
        return Center(child: snapshot.hasError
          ? const Text('Inventory unavailable. Check your connection and permissions, then refresh.') : const CircularProgressIndicator());
      }
      final items = snapshot.data!.where((r) =>
        (!_lowOnly || r['is_low'] == true) &&
        (!_outOnly || r['quantity'] == 0) &&
        '${r['name']} ${r['barcode']}'.toLowerCase().contains(_search)).toList();
      if (items.isEmpty) return Center(child: Text(snapshot.data!.isEmpty
        ? 'No inventory products are available.'
        : 'No products match the selected stock alert filters.'));
      return ListView.builder(itemCount: items.length, itemBuilder: (context, index) {
        final item = items[index];
        return Card(child: ListTile(
          title: Text('${item['name']}'),
          subtitle: Text('Barcode: ${item['barcode'] ?? '-'} · Stock: ${item['quantity']} · Minimum: ${item['minimum_quantity']}'),
          leading: Icon(item['is_low'] == true ? Icons.warning_amber : Icons.inventory_2_outlined,
            color: item['is_low'] == true ? Colors.orange : null),
          trailing: Wrap(children: [
            IconButton(tooltip: 'Stock history', onPressed: () => _history(item), icon: const Icon(Icons.history)),
            IconButton(tooltip: 'Set minimum', onPressed: _submitting ? null : () => _edit(item, minimum: true), icon: const Icon(Icons.tune)),
            IconButton(tooltip: 'Stock movement', onPressed: _submitting ? null : () => _edit(item, minimum: false), icon: const Icon(Icons.add_circle_outline)),
          ]),
        ));
      });
    })),
  ]);
}
