import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only product catalog readiness view. This is not a stock ledger.
/// Supabase RLS remains responsible for limiting visible records.
class InventoryCatalogPanel extends StatefulWidget {
  const InventoryCatalogPanel({super.key});

  @override
  State<InventoryCatalogPanel> createState() => _InventoryCatalogPanelState();
}

class _InventoryCatalogPanelState extends State<InventoryCatalogPanel> {
  late Future<List<Map<String, dynamic>>> _future = _load();
  StreamSubscription<AuthState>? _authSubscription;
  String? _loadedEmployeeId;

  @override
  void initState() {
    super.initState();
    _loadedEmployeeId = Supabase.instance.client.auth.currentUser?.id;
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      final currentId = Supabase.instance.client.auth.currentUser?.id;
      if (mounted && currentId != _loadedEmployeeId) _refresh();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  String _query = '';
  String _filter = 'all';

  Future<List<Map<String, dynamic>>> _load() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      throw StateError('Sign in to view the product catalog.');
    }
    final employeeId = Supabase.instance.client.auth.currentUser!.id;
    const pageSize = 500;
    const maximumRows = 5000;
    final products = <Map<String, dynamic>>[];
    for (var offset = 0; offset <= maximumRows; offset += pageSize) {
      final page = await Supabase.instance.client
          .from('gs_menu_products')
          .select('id,name,barcode,normal_price_iqd,tourism_price_iqd,is_active')
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1);
      if (Supabase.instance.client.auth.currentUser?.id != employeeId) {
        throw StateError('Employee session changed. Reload the catalog.');
      }
      if (page is! List) throw const FormatException('Invalid catalog response');
      for (final raw in page) {
        if (raw is! Map || raw.keys.any((key) => key is! String)) {
          throw const FormatException('Invalid catalog row');
        }
        products.add(Map<String, dynamic>.from(raw));
      }
      if (page.length < pageSize) break;
    }
    return products;
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _loadedEmployeeId = Supabase.instance.client.auth.currentUser?.id;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: const Text('Product catalog readiness'),
        subtitle: const Text('Read-only · paginated catalog (maximum 5,000)'),
        trailing: IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('Stock quantities, low-stock alerts and stock movements are not yet connected. Product readiness is not inventory availability.'),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          decoration: const InputDecoration(
            labelText: 'Search product or barcode',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonFormField<String>(
          initialValue: _filter,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Catalog filter', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All products')),
            DropdownMenuItem(value: 'active', child: Text('Active products')),
            DropdownMenuItem(value: 'inactive', child: Text('Inactive products')),
            DropdownMenuItem(value: 'missing_barcode', child: Text('Missing barcode')),
            DropdownMenuItem(value: 'missing_price', child: Text('Missing or zero price')),
          ],
          onChanged: (value) => setState(() => _filter = value ?? 'all'),
        ),
      ),
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (Supabase.instance.client.auth.currentUser?.id != _loadedEmployeeId) {
            return const Center(child: Text('Employee session changed. Reload the catalog.'));
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(children: [
              const ListTile(title: Text('Catalog unavailable'), subtitle: Text('Check gs_menu_products migration, connection and employee RLS permissions.')),
              const Padding(padding: EdgeInsets.all(16), child: Text('Catalog could not be loaded. Check permissions or your connection, then refresh.')),
            ]);
          }
          final all = snapshot.data ?? <Map<String, dynamic>>[];
          final loaded = all;
          const maximumRows = 5000;
          final hasMore = loaded.length > maximumRows;
          final visible = hasMore ? loaded.take(maximumRows).toList() : loaded;
          bool invalidPrice(Object? value) {
            if (value is num) return !value.isFinite || value <= 0;
            if (value is String) {
              final parsed = num.tryParse(value.trim());
              return parsed == null || !parsed.isFinite || parsed <= 0;
            }
            return true;
          }
          bool missingPrice(Map<String, dynamic> row) =>
              invalidPrice(row['normal_price_iqd']) ||
              invalidPrice(row['tourism_price_iqd']);
          final rows = all.where((row) {
            final match = '${row['name'] ?? ''} ${row['barcode'] ?? ''}'.toLowerCase().contains(_query);
            if (!match) return false;
            switch (_filter) {
              case 'active': return row['is_active'] == true;
              case 'inactive': return row['is_active'] != true;
              case 'missing_barcode': return '${row['barcode'] ?? ''}'.trim().isEmpty;
              case 'missing_price': return missingPrice(row);
              default: return true;
            }
          }).toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(alignment: Alignment.centerLeft, child: Text('${rows.length} matching · ${all.length} loaded${hasMore ? ' · Limit reached: some products may be missing' : ''}')),
            ),
            Expanded(child: rows.isEmpty
              ? const Center(child: Text('No matching accessible products'))
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final flags = <String>[
                      if ('${row['barcode'] ?? ''}'.trim().isEmpty) 'Missing barcode',
                      if (missingPrice(row)) 'Check prices',
                      if (row['is_active'] != true) 'Inactive',
                    ];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        title: Text('${row['name'] ?? 'Unnamed product'}'),
                        subtitle: Text('Barcode: ${row['barcode'] ?? '—'}\nNormal: ${row['normal_price_iqd'] ?? '—'} IQD · Tourism: ${row['tourism_price_iqd'] ?? '—'} IQD${flags.isEmpty ? '' : '\n${flags.join(' · ')}'}'),
                        isThreeLine: true,
                        trailing: Icon(flags.isEmpty ? Icons.check_circle_outline : Icons.info_outline),
                      ),
                    );
                  },
                )),
          ]);
        },
      )),
    ]);
  }
}
