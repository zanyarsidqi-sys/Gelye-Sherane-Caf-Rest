import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cafe_finance_surface.dart';
import 'cafe_language.dart';
import 'cafe_operations_workspace.dart';

typedef CustomerReservationLoader = Future<List<Map<String, dynamic>>> Function(DateTime from, DateTime to);

String customerDay(DateTime date) => date.toIso8601String().substring(0, 10);
DateTime customerBaghdadDay(DateTime date) {
  final local = date.toUtc().add(const Duration(hours: 3));
  return DateTime.utc(local.year, local.month, local.day);
}

/// Fetch every matching reservation; no names/contact details are requested.
Future<List<Map<String, dynamic>>> loadCustomerReservations(
  SupabaseClient client, DateTime from, DateTime to,
) async {
  final rows = <Map<String, dynamic>>[];
  for (var offset = 0; ; offset += 500) {
    final page = await client.from('cafe_table_reservations')
      .select('id,table_id,party_size,starts_at,ends_at,status,arrived_at')
      .gte('starts_at', from.subtract(const Duration(hours: 3)).toIso8601String())
      .lt('starts_at', to.add(const Duration(days: 1)).subtract(const Duration(hours: 3)).toIso8601String())
      .order('starts_at').order('id').range(offset, offset + 499);
    rows.addAll(page.map((r) => Map<String, dynamic>.from(r)));
    if (page.length < 500) return rows;
  }
}

class CustomerGuestRow {
  const CustomerGuestRow(this.id, this.table, this.guests, this.time);
  final String id, table, time;
  final int? guests;
}

class CustomerGuestSummary {
  const CustomerGuestSummary(this.seated, this.expected, this.finished);
  final List<CustomerGuestRow> seated, expected, finished;
  static int knownCount(List<CustomerGuestRow> rows) =>
    rows.fold(0, (total, row) => total + (row.guests ?? 0));
  static int missingCount(List<CustomerGuestRow> rows) =>
    rows.where((row) => row.guests == null).length;
}

int? _guestCount(dynamic value) => value is int && value > 0 ? value : null;

/// Seated is always the current snapshot. Expected and finished use selected dates.
CustomerGuestSummary summarizeCustomers({
  required List<Map<String, dynamic>> tables,
  required List<Map<String, dynamic>> reservations,
  required Map<String, dynamic> report,
  required DateTime from,
  required DateTime to,
  required DateTime now,
}) {
  final seated = <CustomerGuestRow>[], expected = <CustomerGuestRow>[], finished = <CustomerGuestRow>[];
  final names = <String, String>{};
  final seen = <String>{};
  final start = customerDay(from), end = customerDay(to);
  bool selected(String day) => day.compareTo(start) >= 0 && day.compareTo(end) <= 0;
  for (final table in tables) {
    names[table['id'] as String] = table['name'] as String;
    final id = table['visit_id'];
    if (id != null && seen.add('visit:$id')) {
      seated.add(CustomerGuestRow(id as String, table['name'] as String,
        _guestCount(table['guest_count']), cafeFinanceTimestamp(table['started_at'])));
    }
  }
  for (final r in reservations) {
    final id = r['id'] as String;
    final starts = DateTime.parse(r['starts_at'] as String);
    final ends = DateTime.parse(r['ends_at'] as String);
    if (r['status'] == 'confirmed' && r['arrived_at'] == null &&
        ends.isAfter(now) && selected(customerDay(customerBaghdadDay(starts))) &&
        seen.add('reservation:$id')) {
      expected.add(CustomerGuestRow(id, names[r['table_id']] ?? 'Table not available',
        _guestCount(r['party_size']), cafeFinanceTimestamp(r['starts_at'])));
    }
  }
  final columns = List<String>.from(report['columns'] as List);
  final indexes = ['Table', 'Visit', 'Guests', 'Started (Baghdad)', 'Closed (Baghdad)']
    .map(columns.indexOf).toList();
  if (indexes.any((i) => i < 0)) throw const FormatException('Guest history fields missing');
  for (final raw in report['rows'] as List) {
    final row = raw as List;
    if (row.length != columns.length) throw const FormatException('Guest history record invalid');
    final closed = row[indexes[4]];
    if (closed == null) continue;
    if (closed is! String || DateTime.tryParse(closed) == null) {
      throw const FormatException('Guest departure time invalid');
    }
    final id = row[indexes[1]] as String;
    if (selected(closed.substring(0, 10)) && seen.add('closed:$id')) {
      finished.add(CustomerGuestRow(id, row[indexes[0]] as String,
        _guestCount(row[indexes[2]]), closed));
    }
  }
  return CustomerGuestSummary(seated, expected, finished);
}

class CafeCustomerNumber extends StatefulWidget {
  const CafeCustomerNumber({super.key, this.rpc, this.reservations});
  final CafeRpc? rpc;
  final CustomerReservationLoader? reservations;
  @override
  State<CafeCustomerNumber> createState() => _CafeCustomerNumberState();
}

class _CafeCustomerNumberState extends State<CafeCustomerNumber> {
  late DateTime _from = customerBaghdadDay(DateTime.now()), _to = _from;
  CustomerGuestSummary? _summary;
  String? _error;
  DateTime? _loadedAt;
  bool _loading = false;
  int _request = 0;
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _request++; super.dispose(); }

  Future<void> _load() async {
    final request = ++_request;
    setState(() { _loading = true; _error = null; _summary = null; _loadedAt = null; });
    try {
      if (widget.rpc == null || widget.reservations == null) throw StateError('Unavailable');
      final results = await Future.wait<dynamic>([
        widget.rpc!('get_cafe_table_overview', {}),
        widget.rpc!('get_cafe_operational_report', {
          'p_section': 'dashboard', 'p_card': 'guests_today',
          'p_from': customerDay(_from), 'p_to': customerDay(_to),
        }),
        widget.reservations!(_from, _to),
      ]);
      final overview = Map<String, dynamic>.from(results[0] as Map);
      final now = DateTime.parse(overview['server_time'] as String);
      final summary = summarizeCustomers(tables: cafeRows(overview['tables']),
        reservations: cafeRows(results[2]), report: Map<String, dynamic>.from(results[1] as Map),
        from: _from, to: _to, now: now);
      if (!mounted || request != _request) return;
      setState(() { _summary = summary; _loadedAt = now; });
    } catch (_) {
      if (mounted && request == _request) setState(() =>
        _error = 'Could not load customer counts. Check Table Overview, Table Reservations and Guests Today access, then retry.');
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _dates() async {
    final range = await showDateRangePicker(context: context,
      firstDate: DateTime(2020), lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _from, end: _to));
    if (range == null || !mounted) return;
    if (range.end.difference(range.start).inDays > 366) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: CafeText('Choose a date range up to one year.')));
      return;
    }
    setState(() {
      _from = DateTime.utc(range.start.year, range.start.month, range.start.day);
      _to = DateTime.utc(range.end.year, range.end.month, range.end.day);
    });
    await _load();
  }

  Widget _group(String label, String scope, List<CustomerGuestRow> rows) {
    final missing = CustomerGuestSummary.missingCount(rows);
    final count = CustomerGuestSummary.knownCount(rows);
    return Card(child: ExpansionTile(
      key: ValueKey('customer-count-$label'),
      title: CafeText(label),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(missing == 0 ? '$count guests' : '$count recorded guests · $missing parties: Not recorded',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        CafeText(scope),
      ]),
      children: [
        if (rows.isEmpty) const ListTile(title: CafeText('No matching guests.')),
        for (final row in rows) ListTile(title: Text(row.table),
          subtitle: Text('${row.guests ?? 'Not recorded'} guests · ${row.time} · Baghdad')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) => CafeFinanceSurface(builder: (context) =>
    Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const CafeText('Customer Number', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const CafeText('People, not tables or orders. Paid guests remain seated until their visit is closed.'),
        Wrap(spacing: 8, children: [
          OutlinedButton(onPressed: _loading ? null : _dates, child: const CafeText('Date range')),
          TextButton(onPressed: _loading ? null : () {
            setState(() { _from = customerBaghdadDay(DateTime.now()); _to = _from; });
            _load();
          }, child: const CafeText('Today')),
          OutlinedButton(onPressed: _loading ? null : _load, child: const CafeText('Refresh')),
        ]),
        Text('${customerDay(_from)} — ${customerDay(_to)} · Baghdad'),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) CafeText(_error!),
        if (_summary != null) ...[
          CafeText('Snapshot: ${cafeFinanceTimestamp(_loadedAt?.toIso8601String())} · Baghdad'),
          _group('At tables now', 'Current visits, including earlier arrivals', _summary!.seated),
          _group('Reserved · Not arrived', 'Selected reservation dates; expired bookings excluded', _summary!.expected),
          _group('Left · Visit finished', 'Visits closed during selected dates', _summary!.finished),
          const CafeText('Refresh after arrivals or departures. Counts are guest visits, not unique people.'),
        ],
      ])));
}
