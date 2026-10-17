import 'package:flutter/material.dart';
import 'cafe_language.dart';
import 'cafe_finance_surface.dart';
import 'cafe_operations_workspace.dart';

const dashboardTableCards = {
  'Live Tables', 'Tables Occupied', 'Available Tables',
  'Table Cleaning', 'Cleaning Needed', 'Table Service Requests',
};

String dashboardTableStatus(Map<String, dynamic> table) {
  if (table['visit_id'] != null) return 'Occupied';
  return switch (table['status']) {
    'available' => 'Available',
    'cleaning' => 'Cleaning',
    'reserved' => (table['reservation'] as Map?)?['arrived_at'] == null ? 'Reserved' : 'Arrived',
    'occupied' => 'Occupied',
    _ => 'Unknown',
  };
}

List<Map<String, dynamic>> dashboardOpenRequests(Map<String, dynamic> table) =>
    cafeRows(table['requests'] ?? []).where((r) => r['status'] != 'completed').toList();

bool dashboardTableMatches(String title, Map<String, dynamic> table) {
  final status = dashboardTableStatus(table);
  return switch (title) {
    'Tables Occupied' => status == 'Occupied',
    'Available Tables' => status == 'Available',
    'Table Cleaning' || 'Cleaning Needed' => status == 'Cleaning',
    'Table Service Requests' => dashboardOpenRequests(table).isNotEmpty,
    'Live Tables' => true,
    _ => false,
  };
}

class CafeDashboardTables extends StatefulWidget {
  const CafeDashboardTables({super.key, required this.title, this.rpc});
  final String title;
  final CafeRpc? rpc;
  @override
  State<CafeDashboardTables> createState() => _CafeDashboardTablesState();
}

class _CafeDashboardTablesState extends State<CafeDashboardTables> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _tables = [];
  String _area = '', _mode = '', _query = '';
  bool _loading = true;
  String? _error;
  DateTime? _loadedAt;
  int _request = 0;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void didUpdateWidget(CafeDashboardTables oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title || oldWidget.rpc != widget.rpc) {
      _clear();
      _load();
    }
  }
  @override
  void dispose() { _request++; _search.dispose(); super.dispose(); }

  void _clear() {
    _area = _mode = _query = '';
    _search.clear();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() { _loading = true; _error = null; _tables = []; _loadedAt = null; });
    try {
      if (widget.rpc == null) throw StateError('Unavailable');
      final data = Map<String, dynamic>.from(await widget.rpc!('get_cafe_table_overview', {}));
      final tables = cafeRows(data['tables']);
      for (final table in tables) {
        if (table['id'] is! String || table['name'] is! String ||
            table['area'] is! String || table['status'] is! String ||
            table['pricing_mode'] is! String) {
          throw const FormatException('Invalid table record');
        }
        dashboardOpenRequests(table);
        dashboardTableStatus(table);
      }
      if (!mounted || request != _request) return;
      setState(() {
        _tables = tables;
        _loadedAt = DateTime.now().toUtc();
        if (!_tables.any((t) => t['area'] == _area)) _area = '';
        if (!_tables.any((t) => t['pricing_mode'] == _mode)) _mode = '';
      });
    } catch (_) {
      if (mounted && request == _request) setState(() => _error =
        'Could not load tables. Refresh or ask an administrator to check your Table Overview access.');
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Widget _filter(String label, String value, List<String> values, void Function(String) change) =>
    SizedBox(width: 220, child: DropdownButtonFormField<String>(
      key: ValueKey('dashboard-table-$label-$value'), initialValue: value,
      isExpanded: true, decoration: InputDecoration(label: CafeText(label)),
      items: [const DropdownMenuItem(value: '', child: CafeText('All')),
        for (final v in values) DropdownMenuItem(value: v, child: Text(v))],
      onChanged: (v) => setState(() => change(v ?? '')),
    ));

  @override
  Widget build(BuildContext context) => CafeFinanceSurface(builder: (context) {
    final scoped = _tables.where((t) => dashboardTableMatches(widget.title, t)).toList();
    final rows = scoped.where((t) =>
      (_area.isEmpty || t['area'] == _area) &&
      (_mode.isEmpty || t['pricing_mode'] == _mode) &&
      '${t['name']} ${t['area']} ${t['customer_name'] ?? ''}'.toLowerCase().contains(_query.trim().toLowerCase())
    ).toList()..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
    final areas = _tables.map((t) => '${t['area']}').toSet().toList()..sort();
    final modes = _tables.map((t) => '${t['pricing_mode']}').toSet().toList()..sort();
    return Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CafeText(widget.title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const CafeText('Current table snapshot. Use Table Overview for operational actions.'),
      if (widget.title == 'Available Tables')
        const CafeText('Recorded availability only. Check the next reservation before seating guests.'),
      Align(alignment: AlignmentDirectional.centerStart, child: OutlinedButton.icon(
        onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), label: const CafeText('Refresh'))),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) CafeText(_error!),
      if (!_loading && _error == null) ...[
        CafeText('Last updated: ${cafeFinanceTimestamp(_loadedAt?.toIso8601String())} · Baghdad'),
        const SizedBox(height: 12),
        TextField(controller: _search, decoration: const InputDecoration(
          label: CafeText('Search table, area or customer'), prefixIcon: Icon(Icons.search)),
          onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _filter('Area', _area, areas, (v) => _area = v),
          _filter('Mode', _mode, modes, (v) => _mode = v),
          TextButton(onPressed: () => setState(_clear), child: const CafeText('Clear filters')),
        ]),
        CafeText('${rows.length} matching tables · ${scoped.length} in this card'),
        if (rows.isEmpty) const Padding(padding: EdgeInsets.all(16), child: CafeText('No matching tables.')),
        for (final table in rows) Card(child: ExpansionTile(
          key: ValueKey('dashboard-table-row-${table['id']}'),
          title: Text('${table['name']}'),
          subtitle: CafeText('${table['area']} · ${dashboardTableStatus(table)} · ${table['pricing_mode']}'),
          childrenPadding: const EdgeInsets.all(16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CafeText('Seats: ${table['seats'] ?? 'Unknown'}'),
            if (table['visit_id'] != null) ...[
              CafeText('Guests: ${table['guest_count'] ?? 'Unknown'}'),
              CafeText('Visit started: ${cafeFinanceTimestamp(table['started_at'])} · Baghdad'),
              CafeText('Payment status: ${table['payment_status'] ?? 'Unknown'}'),
              CafeText('Orders: ${table['order_count'] ?? 'Unknown'} · Pending: ${table['pending_orders'] ?? 'Unknown'}'),
              if ('${table['customer_name'] ?? ''}'.isNotEmpty) Text('${table['customer_name']}'),
            ],
            if (dashboardTableStatus(table) == 'Cleaning')
              CafeText('Cleaning since: ${cafeFinanceTimestamp(table['cleaning_started_at'])} · Baghdad'),
            if (table['reservation'] is Map) ...[
              CafeText('Next reservation: ${cafeFinanceTimestamp(table['reservation']['starts_at'])} · Baghdad'),
              CafeText('Reservation guests: ${table['reservation']['party_size'] ?? 'Unknown'}'),
            ],
            CafeText('${dashboardOpenRequests(table).length} open service requests'),
            for (final request in dashboardOpenRequests(table)) ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${request['kind'] ?? ''}'.replaceAll('_', ' ')),
              subtitle: Text('${request['message'] ?? ''}\n${request['status'] ?? 'Unknown'} · ${cafeFinanceTimestamp(request['created_at'])}'),
            ),
          ],
        )),
      ],
    ]));
  });
}
