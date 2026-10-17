import 'package:flutter/material.dart';
import 'cafe_finance_surface.dart';
import 'cafe_language.dart';
import 'cafe_operations_workspace.dart';
import 'cafe_people_workspace.dart';
import 'workspace_reporting.dart';

List<Map<String, dynamic>> cafeAttendanceSummary(dynamic raw) {
  final data = cafePeopleData(raw, 'attendance');
  final rows = cafeRows(data['rows']);
  if (data['total_count'] < rows.length || data['total_count'] < 0 ||
      data['truncated'] != (data['total_count'] > rows.length)) {
    throw const FormatException('Invalid attendance coverage');
  }
  final staff = <String, Map<String, dynamic>>{}, seen = <String>{};
  for (final row in rows) {
    final id = row['staff_id'];
    if (id is! String || id.isEmpty || !seen.add(row['id'] as String) ||
        row['period_seconds'] > 31 * 86400) {
      throw const FormatException('Invalid attendance identity or duration');
    }
    final start = DateTime.parse(row['clocked_in_at']);
    final end = row['clocked_out_at'] == null ? null : DateTime.parse(row['clocked_out_at']);
    if (end != null && end.isBefore(start)) throw const FormatException('Invalid attendance times');
    final entry = staff.putIfAbsent(id, () => {
      'id': id,
      'name': row['employee_name'] is String && (row['employee_name'] as String).trim().isNotEmpty
          ? row['employee_name'] : 'Name not recorded',
      'seconds': 0, 'open': 0, 'closed': 0, 'sessions': <Map<String, dynamic>>[],
    });
    entry['seconds'] = (entry['seconds'] as int) + (row['period_seconds'] as int);
    final state = end == null ? 'open' : 'closed';
    entry[state] = (entry[state] as int) + 1;
    (entry['sessions'] as List<Map<String, dynamic>>).add(row);
  }
  final result = staff.values.toList();
  result.sort((a, b) {
    final byName = '${a['name']}'.toLowerCase().compareTo('${b['name']}'.toLowerCase());
    return byName != 0 ? byName : '${a['id']}'.compareTo('${b['id']}');
  });
  return result;
}
String cafeRecordedDuration(int seconds) => '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m ${seconds % 60}s';

class CafeStaffPerformance extends StatefulWidget {
  const CafeStaffPerformance({super.key, required this.account, this.rpc});
  final String account;
  final CafeRpc? rpc;
  @override
  State<CafeStaffPerformance> createState() => _CafeStaffPerformanceState();
}
class _CafeStaffPerformanceState extends State<CafeStaffPerformance> {
  final _search = TextEditingController();
  int _days = 1, _request = 0;
  bool _loading = true;
  String? _error;
  String _query = '';
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _staff = [];
  late DateTime _from, _to;
  @override
  void initState() { super.initState(); _load(); }
  @override
  void didUpdateWidget(CafeStaffPerformance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account || oldWidget.rpc != widget.rpc) {
      _search.clear(); _query = ''; _days = 1; _load();
    }
  }
  @override
  void dispose() { _request++; _search.dispose(); super.dispose(); }
  String _date(DateTime value) => value.toIso8601String().substring(0, 10);
  Future<void> _load() async {
    final request = ++_request;
    _to = baghdadCalendarDate(DateTime.now());
    _from = _to.subtract(Duration(days: _days - 1));
    setState(() { _loading = true; _error = null; _data = null; _staff = []; });
    try {
      if (widget.rpc == null) throw StateError('Unavailable');
      final raw = await widget.rpc!('get_cafe_people_workspace', {
        'p_kind': 'attendance', 'p_from': _date(_from), 'p_to': _date(_to),
      });
      final summary = cafeAttendanceSummary(raw);
      if (!mounted || request != _request) return;
      setState(() { _data = Map<String, dynamic>.from(raw); _staff = summary; });
    } catch (_) {
      if (mounted && request == _request) setState(() => _error = 'Could not load attendance measures. Check connection and assigned attendance access, then refresh.');
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }
  @override
  Widget build(BuildContext context) => CafeFinanceSurface(builder: (context) {
    final staff = _staff.where((s) => '${s['name']} ${s['id']}'.toLowerCase().contains(_query.trim().toLowerCase())).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const CafeText('Staff Performance', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const CafeText('Attendance measures only. Recorded time is not productivity, lateness, absence, breaks or payroll. Staff see their own records; administrators see authorized staff records.'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final days in [1, 7, 31]) ChoiceChip(
          label: CafeText(days == 1 ? 'Today' : 'Last $days days'), selected: _days == days,
          onSelected: _loading ? null : (_) { setState(() => _days = days); _load(); },
        ),
        OutlinedButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), label: const CafeText('Refresh')),
      ]),
      CafeText('${_date(_from)} to ${_date(_to)} · Baghdad dates'),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) CafeText(_error!),
      if (_data != null && !_loading) ...[
        CafeText('Loaded ${(_data!['rows'] as List).length} of ${_data!['total_count']} sessions · Snapshot ${cafeFinanceTimestamp(_data!['server_time'])} Baghdad'),
        if (_data!['truncated'] == true) const CafeText('Incomplete period: only the latest 500 sessions were returned. Employee totals below cover loaded sessions only; narrow the period.'),
        const CafeText('Time is clipped by the server to the selected period. Open sessions are measured only through the snapshot. Employees with no returned records are not listed and are not classified as absent.'),
        const SizedBox(height: 12),
        TextField(controller: _search, decoration: const InputDecoration(label: CafeText('Search employee'), prefixIcon: Icon(Icons.search)),
          onChanged: (value) => setState(() => _query = value)),
        CafeText('${staff.length} employees in matching loaded sessions'),
        if (staff.isEmpty) const CafeText('No matching recorded attendance.'),
        for (final employee in staff) Card(child: ExpansionTile(
          key: ValueKey('attendance-summary-${employee['id']}'),
          title: Text('${employee['name']}'),
          subtitle: Text('Recorded: ${cafeRecordedDuration(employee['seconds'] as int)}\nClosed sessions: ${employee['closed']} · Open sessions: ${employee['open']}'),
          children: [
            for (final session in employee['sessions'] as List<Map<String, dynamic>>) Padding(
              padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CafeText('In: ${cafeFinanceTimestamp(session['clocked_in_at'])} Baghdad'),
                CafeText(session['clocked_out_at'] == null ? 'Still open at snapshot' : 'Out: ${cafeFinanceTimestamp(session['clocked_out_at'])} Baghdad'),
                CafeText('Selected-period time: ${cafeRecordedDuration(session['period_seconds'] as int)}'),
              ]),
            ),
          ],
        )),
      ],
    ]);
  });
}
