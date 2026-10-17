import 'package:flutter/material.dart';

import 'cafe_finance_surface.dart';
import 'cafe_language.dart';
import 'cafe_operations_workspace.dart';
import 'cafe_inventory_workspace.dart';

List<Map<String, dynamic>> tableAttentionRows(Map<String, dynamic> data) {
  final rows = <Map<String, dynamic>>[];
  for (final table in cafeRows(data['tables'])) {
    final id = table['id'] as String, name = table['name'] as String;
    if (table['maintenance_blocked'] == true) {
      rows.add({
        'id': 'repair:$id',
        'source': 'Tables',
        'kind': 'Maintenance',
        'title': '$name · Maintenance blocked',
        'detail': 'Review Table Maintenance before seating guests.',
        'time': null,
      });
    }
    if (table['status'] == 'cleaning') {
      rows.add({
        'id': 'cleaning:$id',
        'source': 'Tables',
        'kind': 'Cleaning',
        'title': '$name · Cleaning needed',
        'detail': 'Mark ready in Table Cleaning after the table is prepared.',
        'time': table['cleaning_started_at'],
      });
    }
    for (final request in cafeRows(table['requests'] ?? [])) {
      if (request['status'] == 'completed') continue;
      rows.add({
        'id': 'request:${request['id']}',
        'source': 'Tables',
        'kind': 'Service request',
        'title': '$name · ${request['kind']}'.replaceAll('_', ' '),
        'detail':
            '${request['message'] ?? ''}\n${request['status']} · Review Table Service Requests.',
        'time': request['created_at'],
      });
    }
  }
  return rows;
}

class CafeDashboardAlerts extends StatefulWidget {
  const CafeDashboardAlerts({
    super.key,
    required this.tables,
    required this.inventory,
    this.rpc,
  });
  final bool tables, inventory;
  final CafeRpc? rpc;
  @override
  State<CafeDashboardAlerts> createState() => _CafeDashboardAlertsState();
}

class _CafeDashboardAlertsState extends State<CafeDashboardAlerts> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  List<String> _failures = [], _coverage = [];
  bool _loading = true;
  String _query = '', _kind = 'All';
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CafeDashboardAlerts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tables != widget.tables ||
        oldWidget.inventory != widget.inventory ||
        oldWidget.rpc != widget.rpc) {
      _load();
    }
  }

  @override
  void dispose() {
    _request++;
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    final rpc = widget.rpc;
    final rows = <Map<String, dynamic>>[],
        failures = <String>[],
        coverage = <String>[];
    setState(() {
      _loading = true;
      _rows = [];
      _failures = [];
      _coverage = [];
    });
    Future<void> source(String label, Future<void> Function() action) async {
      try {
        if (rpc == null) throw StateError('Unavailable');
        await action();
      } catch (_) {
        failures.add(
          '$label unavailable. Results are incomplete; refresh or check access.',
        );
      }
    }

    await Future.wait([
      if (widget.tables)
        source('Tables', () async {
          final data = Map<String, dynamic>.from(
            await rpc!('get_cafe_table_overview', {}),
          );
          final found = tableAttentionRows(data);
          final stamp = DateTime.parse(data['server_time'] as String)
              .toIso8601String();
          rows.addAll(found);
          coverage.add(
            'Tables: ${found.length} current alerts · ${cafeFinanceTimestamp(stamp)} Baghdad',
          );
        }),
      if (widget.inventory)
        source('Inventory', () async {
          final data = cafeInventoryData(
            await rpc!('get_cafe_inventory_workspace', {
              'p_card': 'low_stock_alerts',
              'p_query': '',
            }),
          );
          final items = cafeRows(data['items']);
          final found = <Map<String, dynamic>>[];
          for (final item in items) {
            if (num.parse('${item['on_hand']}') >
                num.parse('${item['reorder_level']}')) {
              continue;
            }
            found.add({
              'id': 'stock:${item['id']}',
              'source': 'Inventory',
              'kind': 'Low stock',
              'title': '${item['name']} · Low stock',
              'detail':
                  '${inventoryAmount(item['on_hand'])} ${item['unit']} available · Reorder level ${inventoryAmount(item['reorder_level'])}. Review Low Stock Alerts.',
              'time': null,
            });
          }
          rows.addAll(found);
          final count = data['counts']['items'] as int;
          coverage.add(
            'Inventory: ${items.length} of $count matching items${count > items.length ? ' · Limited to 500; open Low Stock Alerts to search' : ''} · ${cafeFinanceTimestamp(data['server_time'])} Baghdad',
          );
        }),
    ]);
    if (!mounted || request != _request) return;
    rows.sort((a, b) {
      final left = DateTime.tryParse('${a['time']}'),
          right = DateTime.tryParse('${b['time']}');
      if (left != null && right != null) return left.compareTo(right);
      if (left != null) return -1;
      if (right != null) return 1;
      return '${a['title']}'.compareTo('${b['title']}');
    });
    setState(() {
      _rows = rows;
      _failures = failures;
      _coverage = coverage;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => CafeFinanceSurface(
    builder: (context) {
      final rows = _rows
          .where(
            (r) =>
                (_kind == 'All' || r['kind'] == _kind) &&
                '${r['title']} ${r['detail']}'.toLowerCase().contains(
                  _query.trim().toLowerCase(),
                ),
          )
          .toList();
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CafeText(
              'Notifications & Alerts',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const CafeText(
              'Current table and stock attention list. Resolve issues in their source workflow, then refresh. This is not a push-notification inbox.',
            ),
            if (!widget.tables)
              const CafeText('Table alerts are outside your assigned access.'),
            if (!widget.inventory)
              const CafeText('Stock alerts are outside your assigned access.'),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const CafeText('Refresh'),
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            for (final failure in _failures) CafeText(failure),
            for (final coverage in _coverage) CafeText(coverage),
            if (!_loading) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  label: CafeText('Search alerts'),
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in [
                    'All',
                    'Service request',
                    'Cleaning',
                    'Maintenance',
                    'Low stock',
                  ])
                    ChoiceChip(
                      label: CafeText(kind),
                      selected: _kind == kind,
                      onSelected: (_) => setState(() => _kind = kind),
                    ),
                ],
              ),
              CafeText(
                '${rows.length} matching alerts · ${_rows.length} loaded',
              ),
              if (rows.isEmpty)
                CafeText(
                  _failures.isNotEmpty
                      ? 'No matching alerts in the available results.'
                      : !widget.tables && !widget.inventory
                      ? 'Ask an administrator to assign Table Overview or Low Stock Alerts access.'
                      : 'No matching alerts in the loaded sources.',
                ),
              for (final row in rows)
                Card(
                  child: ListTile(
                    key: ValueKey('attention-${row['id']}'),
                    leading: const Icon(Icons.info_outline),
                    title: Text('${row['title']}'),
                    subtitle: Text(
                      '${row['detail']}\n${row['time'] == null ? 'Current condition · Onset not recorded' : '${cafeFinanceTimestamp(row['time'])} · Baghdad'}',
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}
