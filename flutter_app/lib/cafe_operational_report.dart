import 'cafe_language.dart';
import 'cafe_report_selection.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'cafe_operations_workspace.dart';
import 'workspace_reporting.dart';

const operationalReportCards = <String, Set<String>>{
  'dashboard': {'Today Revenue', 'Cash Received', 'Daily Financial Summary', 'Cash & Payment Methods', 'Sales Performance', 'Pending Payment', 'Refunds & Adjustments', 'Today’s Orders', 'Today Orders', 'Kitchen Orders', 'Motel Orders', 'Online & Walk-In Orders', 'Orders Preparing', 'Ready for Delivery', 'Delayed Orders', 'Table Orders', 'Motel Orders Tracking', 'Online Orders Tracking', 'Walk-In Orders Tracking', 'Online Orders', 'Kitchen Queue', 'Today’s Customers', 'Guests Today', 'Table Occupancy Reports', 'Table Occupancy', 'Product Performance', 'Audit & Activity History', 'Audit & Activity'},
  'payment_management': {'Today Revenue', 'Revenue', 'Payment Overview', 'Collected Cash', 'Table Income', 'Pending Payments', 'Pending Payment', 'Refunds', 'Audit'},
  'motel_online_orders': {'Motel & Online Orders Overview', 'Order Tracking', 'Order History', 'Order Details', 'Room Orders', 'Ready for Pickup', 'Walk-In Order History'},
  'customer_management': {'Kitchen Overview', 'Kitchen Reports', 'Kitchen Performance & Timing', 'Kitchen Priority & Delays'},
  'tables_orders': {'Table Reports'},
  'kitchen_management': {'Product Sales & Performance', 'Menu Reports', 'Price Change History', 'Menu Audit History', 'Revisions'},
};


class CafeOperationalReport extends StatefulWidget {
  const CafeOperationalReport({
    super.key, required this.section, required this.card, required this.title,
    this.rpc, this.initialRange,
  });
  final String section, card, title;
  final CafeRpc? rpc;
  /// UTC instants with an exclusive end, as used by the Dashboard.
  final WorkspaceReportRange? initialRange;
  @override
  State<CafeOperationalReport> createState() => _CafeOperationalReportState();
}

class _CafeOperationalReportState extends State<CafeOperationalReport> {
  late DateTime _from, _to;
  Map<String, dynamic>? _report;
  DateTime? _loadedAt;
  bool _loading = true;
  String? _error;
  String _query = '';
  final _filters = <String, String>{};
  int? _sortColumn;
  bool _ascending = true;
  int _request = 0;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setInitialRange();
    _load();
  }

  void _setInitialRange() {
    final range = widget.initialRange;
    _from = range == null ? baghdadCalendarDate(DateTime.now())
        : baghdadCalendarDate(range.start);
    _to = range == null ? _from
        : baghdadCalendarDate(range.end.subtract(const Duration(microseconds: 1)));
  }

  @override
  void didUpdateWidget(CafeOperationalReport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section || oldWidget.card != widget.card ||
        oldWidget.initialRange?.start != widget.initialRange?.start ||
        oldWidget.initialRange?.end != widget.initialRange?.end) {
      _query = '';
      _filters.clear();
      _sortColumn = null;
      _ascending = true;
      _search.clear();
      _setInitialRange();
      _load();
    }
  }

  @override
  void dispose() {
    _request++;
    _search.dispose();
    super.dispose();
  }

  String _date(DateTime value) => value.toIso8601String().substring(0, 10);
  List<String> get _columns => (_report?['columns'] as List? ?? []).map((e) => '$e').toList();
  List<List<dynamic>> get _allRows => (_report?['rows'] as List? ?? [])
      .map((row) => List<dynamic>.from(row as List)).toList();
  List<List<dynamic>> get _rows => selectCafeReportRows(
    columns: _columns, rows: _allRows, query: _query,
    filters: _filters, sortColumn: _sortColumn, ascending: _ascending,
  );
  void _clearSelection() => setState(() {
    _query = '';
    _search.clear();
    _filters.clear();
    _sortColumn = null;
    _ascending = true;
  });

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
      _loadedAt = null;
    });
    try {
      if (widget.rpc == null) throw StateError('Connection unavailable');
      final result = await widget.rpc!('get_cafe_operational_report', {
        'p_section': widget.section, 'p_card': widget.card,
        'p_from': _date(_from), 'p_to': _date(_to),
      });
      final report = Map<String, dynamic>.from(result);
      final columns = report['columns'];
      final rows = report['rows'];
      if (columns is! List || columns.isEmpty || rows is! List ||
          rows.any((row) => row is! List || row.length != columns.length)) {
        throw const FormatException('Invalid report shape');
      }
      if (mounted && request == _request) {
        setState(() {
          _report = report;
          _loadedAt = DateTime.now().toUtc();
          _filters.removeWhere((column, value) => !cafeReportOptions(_columns, _allRows, column).contains(value));
          if (_sortColumn != null && _sortColumn! >= _columns.length) _sortColumn = null;
        });
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _error =
            'Could not load the report. Check connection, date range and assigned permission.');
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _range() async {
    final picked = await showDateRangePicker(
      context: context, firstDate: DateTime(2020), lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: DateTime(_from.year, _from.month, _from.day),
        end: DateTime(_to.year, _to.month, _to.day),
      ),
    );
    if (picked == null || !mounted) return;
    if (picked.end.difference(picked.start).inDays > 366) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: CafeText('Choose a date range up to one year.')),
      );
      return;
    }
    setState(() { _from = picked.start; _to = picked.end; });
    await _load();
  }

  Future<void> _print() async {
    final report = _report;
    if (report == null || _error != null || _loading) return;
    final rows = _rows;
    try {
      final document = pw.Document();
      document.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4.landscape, build: (_) => [
        pw.Header(level: 0, text: widget.title),
        pw.Text('${_date(_from)} to ${_date(_to)} · Baghdad'),
        if (_query.trim().isNotEmpty) pw.Text('Search: ${_query.trim()}'),
        for (final filter in _filters.entries) pw.Text('${filter.key}: ${filter.value}'),
        if (_sortColumn != null) pw.Text('Sort: ${_columns[_sortColumn!]} · ${_ascending ? 'Ascending' : 'Descending'}'),
        pw.Text('${rows.length} matching records'),
        pw.SizedBox(height: 10),
        pw.Text('${report['note'] ?? ''}'),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: (report['columns'] as List).map((e) => '$e').toList(),
          data: rows.map((row) => row.map((e) => e == null ? '—' : '$e').toList()).toList(),
          cellStyle: const pw.TextStyle(fontSize: 8),
        ),
      ]));
      await Printing.layoutPdf(
        name: '${widget.card}-${_date(_from)}.pdf', onLayout: (_) => document.save(),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: CafeText('Could not prepare the report for printing. Refresh and try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFF14243A);
    const border = Color(0xFF30435A);
    const ink = Color(0xFFF6F2E9);
    const muted = Color(0xFFB7C2D1);
    const gold = Color(0xFFD6AA57);
    final theme = ThemeData(
      useMaterial3: true, brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(primary: gold, surface: surface, onSurface: ink),
      scaffoldBackgroundColor: surface,
      textTheme: Theme.of(context).textTheme.apply(bodyColor: ink, displayColor: ink),
    );
    final columns = (_report?['columns'] as List? ?? []).map((e) => '$e').toList();
    final rows = _rows;
    final refreshed = _loadedAt?.add(const Duration(hours: 3));
    return Theme(data: theme, child: Container(
      key: const ValueKey('operational-report-workspace'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CafeText(widget.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        CafeText('${_date(_from)} to ${_date(_to)} · Baghdad time',
          style: const TextStyle(color: muted)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: _loading ? null : _range,
            icon: const Icon(Icons.date_range), label: const CafeText('Dates')),
          OutlinedButton.icon(onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh), label: const CafeText('Refresh')),
          FilledButton.icon(onPressed: _loading || _error != null || _report == null ? null : _print,
            icon: const Icon(Icons.print_outlined), label: const CafeText('Print / save PDF')),
        ]),
        if (_loading) const Padding(padding: EdgeInsets.symmetric(vertical: 16),
          child: LinearProgressIndicator()),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 16),
          child: CafeText(_error!, style: const TextStyle(color: Color(0xFFFFB4AB)))),
        if (_report != null && !_loading && _error == null) ...[
          const SizedBox(height: 12),
          CafeText('${_report!['note'] ?? ''}', style: const TextStyle(color: muted)),
          const SizedBox(height: 12),
          TextField(controller: _search,
            decoration: const InputDecoration(
              label: CafeText('Search report'), prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final column in const ['Source', 'Status', 'Mode'])
              if (columns.contains(column)) SizedBox(width: 240,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('report-filter-$column-${_filters[column]}'),
                  initialValue: _filters[column] ?? '',
                  isExpanded: true,
                  decoration: InputDecoration(label: CafeText(column)),
                  items: [
                    const DropdownMenuItem(value: '', child: CafeText('All')),
                    for (final value in cafeReportOptions(columns, _allRows, column))
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) => setState(() {
                    if (value == null || value.isEmpty) { _filters.remove(column); }
                    else { _filters[column] = value; }
                  }),
                )),
            SizedBox(width: 240, child: DropdownButtonFormField<int>(
              key: ValueKey('report-sort-$_sortColumn'),
              initialValue: _sortColumn ?? -1, isExpanded: true,
              decoration: const InputDecoration(label: CafeText('Sort by')),
              items: [
                const DropdownMenuItem(value: -1, child: CafeText('Original order')),
                for (var i = 0; i < columns.length; i++)
                  DropdownMenuItem(value: i, child: CafeText(columns[i])),
              ],
              onChanged: (value) => setState(() => _sortColumn = value == -1 ? null : value),
            )),
            if (_sortColumn != null) OutlinedButton.icon(
              onPressed: () => setState(() => _ascending = !_ascending),
              icon: Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward),
              label: CafeText(_ascending ? 'Ascending' : 'Descending'),
            ),
            TextButton(onPressed: _clearSelection, child: const CafeText('Clear filters')),
          ]),
          const SizedBox(height: 8),
          CafeText('${_allRows.length} loaded records · filters apply to these records only',
            style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 12),
          Wrap(spacing: 16, runSpacing: 6, children: [
            CafeText('${rows.length} matching records'),
            if (refreshed != null) CafeText(
              'Last updated: ${_date(refreshed)} ${refreshed.toIso8601String().substring(11, 19)} · Baghdad',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ]),
          const SizedBox(height: 12),
          if (rows.isEmpty) Padding(padding: const EdgeInsets.all(20),
            child: CafeText(_allRows.isEmpty ? 'No recorded activity for this report.' : 'No records match these filters. Clear filters to see loaded records.')),
          if (rows.isNotEmpty) LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth < 640) {
              return Column(key: const ValueKey('report-mobile-records'), children: [
                for (var i = 0; i < rows.length; i++) Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (var j = 0; j < columns.length; j++) Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        CafeText(columns[j], style: const TextStyle(color: muted, fontSize: 12)),
                        SelectableText(rows[i][j] == null ? '—' : '${rows[i][j]}'),
                      ]),
                    ),
                  ]),
                ),
              ]);
            }
            return SingleChildScrollView(scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [for (final c in columns) DataColumn(label: CafeText(c))],
                rows: [for (final row in rows) DataRow(cells: [
                  for (final value in row) DataCell(SelectableText(value == null ? '—' : '$value')),
                ])],
              ),
            );
          }),
        ],
      ]),
    ));
  }
}
