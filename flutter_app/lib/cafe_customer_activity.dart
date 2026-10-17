import 'package:flutter/material.dart';

import 'cafe_finance_surface.dart';
import 'cafe_language.dart';
import 'cafe_operations_workspace.dart';

/// A party is a visit or reservation, never a deduplicated customer identity.
List<Map<String, dynamic>> customerActivityRows(Map<String, dynamic> overview) {
  final now = DateTime.parse(overview['server_time'] as String);
  final rows = <Map<String, dynamic>>[];
  final visits = <String>{}, reservations = <String>{};
  for (final table in cafeRows(overview['tables'])) {
    final name = table['name'] as String;
    final visit = table['visit_id'];
    if (visit != null && visits.add(visit as String)) {
      rows.add({
        'id': 'visit:$visit',
        'table': name,
        'area': table['area'],
        'name': table['customer_name'],
        'guests': table['guest_count'],
        'time': table['started_at'],
        'status': 'At table',
        'payment': table['payment_status'],
        'mode': table['pricing_mode'],
      });
    }
    final reservation = table['reservation'];
    if (reservation is Map &&
        reservation['id'] is String &&
        reservations.add(reservation['id'] as String)) {
      final end = DateTime.tryParse('${reservation['ends_at'] ?? ''}');
      // The overview supplies the next confirmed reservation for each table.
      // Missing expiry is retained and disclosed, never treated as a no-show.
      if (end != null && !end.isAfter(now)) continue;
      rows.add({
        'id': 'reservation:${reservation['id']}',
        'table': name,
        'area': table['area'],
        'name': reservation['customer_name'],
        'guests': reservation['party_size'],
        'time': reservation['starts_at'],
        'status': reservation['arrived_at'] == null ? 'Expected' : 'Arrived',
        'payment': null,
        'mode': null,
      });
    }
  }
  rows.sort((a, b) => '${a['time'] ?? ''}'.compareTo('${b['time'] ?? ''}'));
  return rows;
}

class CafeCustomerActivity extends StatefulWidget {
  const CafeCustomerActivity({super.key, this.rpc});
  final CafeRpc? rpc;
  @override
  State<CafeCustomerActivity> createState() => _CafeCustomerActivityState();
}

class _CafeCustomerActivityState extends State<CafeCustomerActivity> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  String _status = 'All', _query = '';
  String? _time, _error;
  int _request = 0;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CafeCustomerActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rpc != widget.rpc) _load();
  }

  @override
  void dispose() {
    _request++;
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _rows = [];
      _time = null;
      _error = null;
    });
    try {
      if (widget.rpc == null) throw StateError('Unavailable');
      final data = Map<String, dynamic>.from(
        await widget.rpc!('get_cafe_table_overview', {}),
      );
      final rows = customerActivityRows(data);
      if (!mounted || request != _request) return;
      setState(() {
        _rows = rows;
        _time = data['server_time'] as String;
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(
          () => _error = 'Could not load customer activity. Check Table Overview access and refresh.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => CafeFinanceSurface(
    builder: (context) {
      final rows = _rows
          .where(
            (r) =>
                (_status == 'All' || r['status'] == _status) &&
                '${r['name'] ?? ''} ${r['table']} ${r['area'] ?? ''}'
                    .toLowerCase()
                    .contains(_query.trim().toLowerCase()),
          )
          .toList();
      final known = rows.fold<int>(
        0,
        (sum, r) =>
            sum +
            (r['guests'] is int && r['guests'] > 0 ? r['guests'] as int : 0),
      );
      final missing = rows
          .where((r) => r['guests'] is! int || r['guests'] <= 0)
          .length;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CafeText(
              'Customers',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const CafeText(
              'Current table parties and the next reservation per table. These are visits, not unique customer profiles. Customer names are subject to Customer Details access; reservation names are not included in this snapshot.',
            ),
            const CafeText(
              'Use Customer Number for departure counts and Table History for completed sessions. Later reservations are outside this snapshot.',
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const CafeText('Refresh'),
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) CafeText(_error!),
            if (!_loading && _error == null) ...[
              CafeText('Snapshot: ${cafeFinanceTimestamp(_time)} · Baghdad'),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  label: CafeText('Search customer, table or area'),
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in [
                    'All',
                    'At table',
                    'Expected',
                    'Arrived',
                  ])
                    ChoiceChip(
                      label: CafeText(status),
                      selected: _status == status,
                      onSelected: (_) => setState(() => _status = status),
                    ),
                ],
              ),
              CafeText(
                '${rows.length} parties · $known recorded guests${missing > 0 ? ' · $missing party sizes not recorded' : ''}',
              ),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CafeText('No matching customer activity.'),
                ),
              for (final row in rows)
                Card(
                  child: ListTile(
                    key: ValueKey('customer-activity-${row['id']}'),
                    leading: Icon(
                      row['status'] == 'At table'
                          ? Icons.groups_outlined
                          : Icons.event_available_outlined,
                    ),
                    title: Text(
                      '${row['name'] ?? ''}'.trim().isEmpty
                          ? 'Name not recorded'
                          : '${row['name']}',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CafeText(
                          '${row['table']} · ${row['area'] ?? ''} · ${row['status']}',
                        ),
                        CafeText(
                          '${row['guests'] ?? 'Not recorded'} guests · ${cafeFinanceTimestamp(row['time'])} · Baghdad',
                        ),
                        if (row['status'] == 'At table')
                          CafeText(
                            'Payment: ${row['payment'] ?? 'Not recorded'} · Mode: ${row['mode'] ?? 'Not recorded'}',
                          ),
                      ],
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
