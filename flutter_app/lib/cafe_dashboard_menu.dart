import 'package:flutter/material.dart';
import 'cafe_finance_surface.dart';
import 'cafe_language.dart';
import 'cafe_menu_workspace.dart';

const dashboardMenuCards = {'Menu', 'Menu Availability'};

class CafeDashboardMenu extends StatefulWidget {
  const CafeDashboardMenu({super.key, required this.title, this.store});
  final String title;
  final CafeMenuStore? store;
  @override
  State<CafeDashboardMenu> createState() => _CafeDashboardMenuState();
}

class _CafeDashboardMenuState extends State<CafeDashboardMenu> {
  final _search = TextEditingController();
  List<CafeMenuItem> _items = [];
  String _query = '', _category = '', _availability = 'All';
  DateTime? _loadedAt;
  String? _error;
  bool _loading = true;
  int _request = 0;
  @override
  void initState() { super.initState(); _load(); }
  @override
  void didUpdateWidget(CafeDashboardMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title || oldWidget.store != widget.store) {
      _clear();
      _load();
    }
  }
  @override
  void dispose() { _request++; _search.dispose(); super.dispose(); }
  void _clear() { _query = _category = ''; _availability = 'All'; _search.clear(); }
  Future<void> _load() async {
    final request = ++_request;
    setState(() { _loading = true; _error = null; _items = []; _loadedAt = null; });
    try {
      if (widget.store == null) throw StateError('Menu unavailable');
      final items = await widget.store!.load();
      if (mounted && request == _request) {
        setState(() {
          _items = items;
          _loadedAt = DateTime.now().toUtc();
          if (!_items.any((i) => i.category == _category)) _category = '';
        });
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _error = 'Could not load products. Refresh or ask an administrator to check your menu access.');
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => CafeFinanceSurface(builder: (context) {
    final categories = _items.map((i) => i.category).toSet().toList()..sort();
    final matches = _items.where((i) =>
      (_category.isEmpty || i.category == _category) &&
      (_availability == 'All' || i.available == (_availability == 'Available')) &&
      '${i.name} ${i.category} ${i.description} ${i.stationNames.join(' ')}'
        .toLowerCase().contains(_query.trim().toLowerCase())
    ).toList()..sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CafeText(widget.title, style: Theme.of(context).textTheme.headlineSmall),
      const CafeText('Current menu snapshot. Use Menu Management to edit products or availability.'),
      Align(alignment: AlignmentDirectional.centerStart, child: OutlinedButton.icon(
        onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh),
        label: const CafeText('Refresh products'))),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) CafeText(_error!),
      if (!_loading && _error == null) ...[
        CafeText('Last updated: ${cafeFinanceTimestamp(_loadedAt?.toIso8601String())} · Baghdad'),
        const SizedBox(height: 12),
        TextField(controller: _search, decoration: const InputDecoration(
          label: CafeText('Search products, categories or stations'), prefixIcon: Icon(Icons.search)),
          onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(width: 240, child: DropdownButtonFormField<String>(
            key: ValueKey('menu-category-$_category'), initialValue: _category, isExpanded: true,
            decoration: const InputDecoration(label: CafeText('Category')),
            items: [const DropdownMenuItem(value: '', child: CafeText('All categories')),
              for (final c in categories.where((c) => c.isNotEmpty)) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => _category = v ?? ''),
          )),
          SizedBox(width: 240, child: DropdownButtonFormField<String>(
            key: ValueKey('menu-availability-$_availability'), initialValue: _availability, isExpanded: true,
            decoration: const InputDecoration(label: CafeText('Availability')),
            items: [for (final s in const ['All','Available','Unavailable'])
              DropdownMenuItem(value: s, child: CafeText(s))],
            onChanged: (v) => setState(() => _availability = v ?? 'All'),
          )),
          TextButton(onPressed: () => setState(_clear), child: const CafeText('Clear filters')),
        ]),
        const SizedBox(height: 12),
        CafeText('${matches.length} matching products · ${_items.length} loaded'),
        CafeText('Available: ${_items.where((i) => i.available).length} · Unavailable: ${_items.where((i) => !i.available).length} · all loaded products'),
        if (matches.isEmpty) const Padding(padding: EdgeInsets.all(16), child: CafeText('No matching products.')),
        for (final item in matches) Card(child: Padding(padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: Theme.of(context).textTheme.titleMedium),
            CafeText('${item.category} · ${item.available ? 'Available' : 'Unavailable'}'),
            if (item.description.isNotEmpty) Text(item.description),
            CafeText('Normal: ${item.priceIqd} IQD'),
            CafeText('Tourism: ${item.tourismPriceIqd == null ? 'Not recorded' : '${item.tourismPriceIqd} IQD'}'),
            CafeText('Owner: ${item.ownerPriceIqd == null ? 'Not recorded' : '${item.ownerPriceIqd} IQD'}'),
            CafeText('Preparation stations: ${item.stationNames.isEmpty ? 'Not recorded' : item.stationNames.join(', ')}'),
          ]))),
      ],
    ]));
  });
}
