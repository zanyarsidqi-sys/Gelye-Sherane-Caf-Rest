import '../shared/professional_mobile_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/section_shell.dart';
import 'tables.dart';
import 'table_orders.dart';
import 'motel_orders.dart';
import 'kitchen.dart';

/// Operational dashboard; server-side aggregates enforce dashboard permission.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => const SectionShell(
    title: 'Dashboard',
    description: 'Live operational overview',
    sectionId: 'dashboard',
    authorizedContent: _DashboardOverview(),
  );
}

class _DashboardOverview extends StatefulWidget {
  const _DashboardOverview();
  @override
  State<_DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<_DashboardOverview> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _refresh();
  }

  late Future<Map<String, dynamic>> _summary = _load();
  late Future<List<dynamic>> _week = _loadWeek();
  late Future<Map<String, dynamic>> _cash = _loadCash();
  late Future<Map<String, dynamic>> _cashWeek = _loadCashWeek();
  Future<Map<String, dynamic>> _loadCashWeek() async {
    final response = await Supabase.instance.client.rpc('gs_dashboard_cash_collections_week');
    if (response is! Map) throw StateError('Invalid cash trend response');
    final data = Map<String, dynamic>.from(response);
    if (data['scope'] != 'cash_collections_only' || data['reconciled'] != false ||
        data['timezone'] != 'Asia/Baghdad' || data['days'] is! List ||
        (data['days'] as List).length != 7) {
      throw StateError('Cash trend metadata invalid');
    }
    final dates = <String>{};
    for (final item in data['days'] as List) {
      if (item is! Map || item['business_date'] is! String ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(item['business_date'] as String) ||
          !dates.add(item['business_date'] as String)) {
        throw StateError('Invalid cash trend date');
      }
      for (final prefix in const ['table', 'motel_food']) {
        final amount = item['${prefix}_cash_iqd'];
        final receipts = item['${prefix}_cash_receipts'];
        if ((amount == null) != (receipts == null) ||
            (amount != null && (amount is! num || !amount.isFinite || amount < 0 || amount != amount.roundToDouble())) ||
            (receipts != null && (receipts is! num || !receipts.isFinite || receipts < 0 || receipts != receipts.roundToDouble())) ||
            (amount is num && receipts is num && receipts == 0 && amount != 0)) {
          throw StateError('Invalid cash trend ledger');
        }
      }
    }
    // Require exactly seven consecutive dates, ending on the current Iraq
    // business day. Never display partial or duplicated ledger history as a
    // complete weekly report.
    final ordered = dates.toList()..sort();
    final first = DateTime.tryParse(ordered.first);
    if (first == null || List.generate(7, (i) =>
        first.add(Duration(days: i)).toIso8601String().substring(0, 10))
        .asMap().entries.any((e) => ordered[e.key] != e.value)) {
      throw StateError('Cash trend dates are not consecutive');
    }
    // The server snapshot, not the device clock, defines the reporting day.
    // A stale or implausibly future-dated snapshot must not be presented as
    // current; this also avoids midnight clock-boundary disagreements.
    final capturedAt = DateTime.tryParse(data['as_of']?.toString() ?? '');
    if (capturedAt == null || !capturedAt.isUtc && !data['as_of'].toString().contains(RegExp(r'(Z|[+-]\d\d:?\d\d)$'))) {
      throw StateError('Cash trend server timestamp is invalid');
    }
    final snapshotAge = DateTime.now().toUtc().difference(capturedAt.toUtc());
    if (snapshotAge > const Duration(minutes: 5) ||
        snapshotAge < const Duration(minutes: -2)) {
      throw StateError('Cash trend server snapshot is stale or future dated');
    }
    final iraqToday = capturedAt.toUtc().add(const Duration(hours: 3))
        .toIso8601String().substring(0, 10);
    if (ordered.last != iraqToday) {
      throw StateError('Cash trend does not end on the server Iraq business day');
    }
    return data;
  }

  /// Export the seven-day report without converting restricted values to zero.
  /// The export is intentionally labelled unreconciled, not revenue.
  Future<void> _copyWeeklyCashReport(Map<String, dynamic> report) async {
    if (report['scope'] != 'cash_collections_only' ||
        report['reconciled'] != false || report['timezone'] != 'Asia/Baghdad' ||
        report['days'] is! List || (report['days'] as List).length != 7) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weekly cash report is incomplete or invalid')));
      return;
    }
    final rows = (report['days'] as List).whereType<Map>().toList()
      ..sort((a, b) => a['business_date'].toString().compareTo(b['business_date'].toString()));
    final dates = rows.map((row) => row['business_date']?.toString() ?? '').toList();
    final start = dates.isEmpty ? null : DateTime.tryParse(dates.first);
    final capturedAt = DateTime.tryParse(report['as_of']?.toString() ?? '');
    final snapshotAge = capturedAt == null ? null :
        DateTime.now().toUtc().difference(capturedAt.toUtc());
    final iraqToday = capturedAt?.toUtc().add(const Duration(hours: 3))
        .toIso8601String().substring(0, 10);
    if (capturedAt == null || snapshotAge == null ||
        snapshotAge > const Duration(minutes: 5) ||
        snapshotAge < const Duration(minutes: -2) ||
        rows.length != 7 || start == null || dates.last != iraqToday ||
        dates.asMap().entries.any((entry) =>
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(entry.value) ||
          start.add(Duration(days: entry.key)).toIso8601String().substring(0, 10) != entry.value)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Weekly cash export blocked: missing or stale business dates')));
      return;
    }
    final lines = <String>[
      'Gelye Sherane — seven-day cash collections (unreconciled)',
      'Business timezone: Asia/Baghdad',
      'Date | Table cash IQD | Table receipts | Motel food cash IQD | Motel receipts',
    ];
    bool valid(dynamic n) => n is num && n.isFinite && n >= 0 && n == n.roundToDouble();
    final totals = <String, int>{'table': 0, 'motel_food': 0};
    final accessible = <String, bool>{'table': true, 'motel_food': true};
    for (final row in rows) {
      final cells = <String>[row['business_date'].toString()];
      for (final prefix in const ['table', 'motel_food']) {
        final amount = row['${prefix}_cash_iqd'];
        final receipts = row['${prefix}_cash_receipts'];
        if (valid(amount) && valid(receipts) && (receipts != 0 || amount == 0)) {
          cells.add((amount as num).toInt().toString());
          cells.add((receipts as num).toInt().toString());
          totals[prefix] = totals[prefix]! + amount.toInt();
        } else {
          accessible[prefix] = false;
          cells.add('Restricted / unavailable');
          cells.add('Restricted / unavailable');
        }
      }
      lines.add(cells.join(' | '));
    }
    for (final prefix in const ['table', 'motel_food']) {
      lines.add('$prefix seven-day cash: ${accessible[prefix]! ? '${totals[prefix]} IQD' : 'Restricted / unavailable'}');
    }
    if (accessible.values.every((value) => value)) {
      lines.add('Combined seven-day cash: ${totals['table']! + totals['motel_food']!} IQD');
    }
    lines.add('Cash collections only. Not reconciled accounting, total revenue, or profit. Credit excluded.');
    try {
      await Clipboard.setData(ClipboardData(text: lines.join('\n')));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seven-day cash report copied')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not copy seven-day cash report')));
    }
  }

  Future<Map<String, dynamic>> _loadCash() async {
    final response = await Supabase.instance.client.rpc('gs_dashboard_cash_collections_today');
    if (response is! Map) throw StateError('Invalid cash reporting response');
    final result = Map<String, dynamic>.from(response);
    if (result['scope'] != 'cash_collections_only' || result['reconciled'] != false || result['timezone'] != 'Asia/Baghdad') {
      throw StateError('Cash reporting metadata invalid');
    }
    final asOf = DateTime.tryParse(result['as_of']?.toString() ?? '');
    if (asOf == null || asOf.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      throw StateError('Cash reporting timestamp invalid');
    }
    for (final key in const ['table_cash_iqd', 'motel_food_cash_iqd', 'table_cash_receipts', 'motel_food_cash_receipts']) {
      final value = result[key];
      if (value != null && (value is! num || !value.isFinite || value < 0 || value != value.roundToDouble())) {
        throw StateError('Invalid cash ledger amount or receipt count');
      }
    }
    // Do not display a ledger as trustworthy if its receipt count contradicts
    // the collected amount. These checks do not establish reconciliation.
    for (final prefix in const ['table', 'motel_food']) {
      final amount = result['${prefix}_cash_iqd'];
      final receipts = result['${prefix}_cash_receipts'];
      if ((amount == null) != (receipts == null)) {
        throw StateError('Incomplete cash ledger response: $prefix');
      }
      if (amount is num && receipts is num && receipts == 0 && amount != 0) {
        throw StateError('Cash ledger amount without receipts: $prefix');
      }
    }
    return result;
  }
  /// Export only authorized, valid cash receipts. Never substitute missing
  /// permission-scoped ledger fields with zero or call collections revenue.
  Future<void> _copyCashSnapshot(Map<String, dynamic> cash) async {
    bool validMoney(dynamic v) => v is num && v.isFinite && v >= 0 && v == v.roundToDouble();
    final asOf = DateTime.tryParse(cash['as_of']?.toString() ?? '');
    if (cash['scope'] != 'cash_collections_only' || cash['reconciled'] != false ||
        cash['timezone'] != 'Asia/Baghdad' || asOf == null ||
        asOf.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cash report cannot be exported: invalid server metadata')));
      return;
    }
    final lines = <String>[
      'Gelye Sherane — cash collections (not revenue)',
      'As of: ${cash['as_of']}',
      'Business timezone: Asia/Baghdad',
    ];
    const sources = <(String, String, String)>[
      ('Table orders', 'table_cash_iqd', 'table_cash_receipts'),
      ('Motel food', 'motel_food_cash_iqd', 'motel_food_cash_receipts'),
    ];
    var allAccessible = true;
    var combined = 0;
    for (final source in sources) {
      final amount = cash[source.$2];
      final receipts = cash[source.$3];
      if (validMoney(amount) && validMoney(receipts)) {
        lines.add('${source.$1}: ${(amount as num).toInt()} IQD; ${(receipts as num).toInt()} receipts');
        combined += amount.toInt();
      } else {
        allAccessible = false;
        lines.add('${source.$1}: Restricted / unavailable');
      }
    }
    if (allAccessible) lines.add('Combined recorded cash collections: $combined IQD (unreconciled)');
    lines.add('Cash collections only; separate ledgers, unreconciled. Not total revenue, profit, or credit payments.');
    try {
      await Clipboard.setData(ClipboardData(text: lines.join('\n')));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cash collections snapshot copied')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not copy cash collections snapshot')));
    }
  }

  Future<List<dynamic>> _loadWeek() async {
    final result = await Supabase.instance.client.rpc('gs_dashboard_order_week');
    if (result is! List) throw StateError('Invalid dashboard week response');
    return result;
  }
  Future<Map<String, dynamic>> _load() async {
    final response = await Supabase.instance.client.rpc('gs_dashboard_operational_summary');
    if (response is! Map) throw StateError('Unexpected dashboard response');
    final result = Map<String, dynamic>.from(response);
    if (!result.containsKey('as_of') || result['timezone'] != 'Asia/Baghdad') {
      throw StateError('Dashboard response missing required server metadata');
    }
    final asOf = DateTime.tryParse(result['as_of']?.toString() ?? '');
    if (asOf == null || asOf.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      throw StateError('Invalid dashboard server timestamp');
    }
    return result;
  }
  /// Copy only numeric values already returned by the permission-scoped RPC.
  /// Restricted/missing metrics are never represented as zero.
  Future<void> _copyOperationalSnapshot(Map<String, dynamic> data) async {
    const labels = <String, String>{
      'today_orders': 'Today orders',
      'today_table_orders': 'Table orders',
      'today_motel_orders': 'Motel orders',
      'pending_kitchen': 'Kitchen pending',
      'ready_orders': 'Ready orders',
      'total_tables': 'Total tables',
      'occupied_tables': 'Occupied tables',
      'tourism_tables': 'Tourism tables',
    };
    final lines = <String>[
      'Gelye Sherane — operational snapshot',
      'Updated: ${data['as_of']}',
      'Timezone: Asia/Baghdad',
    ];
    for (final entry in labels.entries) {
      final value = data[entry.key];
      if (value is num && value.isFinite && value >= 0 &&
          value == value.roundToDouble()) {
        lines.add('${entry.value}: ${value.toInt()}');
      } else {
        lines.add('${entry.value}: Restricted / unavailable');
      }
    }
    lines.add('Read-only operational counts; not a financial report.');
    try {
      await Clipboard.setData(ClipboardData(text: lines.join('\n')));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Operational snapshot copied')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to copy snapshot on this device')),
      );
    }
  }

  // Dashboard shortcuts open the real section screen, not a permission-bypassing
  // embedded widget. SectionShell independently rechecks employee access.
  void _openSection(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Widget _sectionShortcuts() {
    final actions = <({String title, String subtitle, IconData icon, Widget screen})>[
      (title: 'Tables', subtitle: 'Floor & availability', icon: Icons.table_restaurant_outlined, screen: const TablesScreen()),
      (title: 'Table Orders', subtitle: 'Orders & payments', icon: Icons.receipt_long_outlined, screen: const TableOrdersScreen()),
      (title: 'Motel Orders', subtitle: 'Guest food orders', icon: Icons.hotel_outlined, screen: const MotelOrdersScreen()),
      (title: 'Kitchen', subtitle: 'Preparation queue', icon: Icons.soup_kitchen_outlined, screen: const KitchenScreen()),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ProfessionalMobileWidgets.sectionLabel('Quick access', caption: 'Permission checked'),
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 740 ? 4 : 2;
        final gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final action in actions)
            SizedBox(width: width, child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openSection(action.screen),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 118),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE1E7EC)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: ProfessionalMobileWidgets.gold.withOpacity(.18), borderRadius: BorderRadius.circular(11)),
                      child: Icon(action.icon, color: ProfessionalMobileWidgets.navy)),
                    const SizedBox(height: 9),
                    Text(action.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ProfessionalMobileWidgets.navy)),
                    Text(action.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF687A89))),
                  ]),
                ),
              ),
            )),
        ]);
      }),
    ]);
  }

  bool _validCount(dynamic value) => value is num && value.isFinite && value >= 0 && value == value.roundToDouble();

  // All four data sources participate in the same refresh. In earlier builds
  // pull-to-refresh waited only for the operational summary, so the indicator
  // could disappear while the weekly and cash reports were still loading.
  // FutureBuilder handles each individual failure without concealing the other
  // successfully loaded sections.
  Future<void> _refreshAll() async {
    if (!mounted) return;
    final summary = _load();
    final week = _loadWeek();
    final cash = _loadCash();
    final cashWeek = _loadCashWeek();
    setState(() {
      _summary = summary;
      _week = week;
      _cash = cash;
      _cashWeek = cashWeek;
    });
    await Future.wait<void>([
      summary.then<void>((_) {}, onError: (Object _) {}),
      week.then<void>((_) {}, onError: (Object _) {}),
      cash.then<void>((_) {}, onError: (Object _) {}),
      cashWeek.then<void>((_) {}, onError: (Object _) {}),
    ]);
  }

  void _refresh() { _refreshAll(); }
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refreshAll,
    child: FutureBuilder<Map<String, dynamic>>(
      future: _summary,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return ListView(padding: EdgeInsets.symmetric(horizontal: MediaQuery.sizeOf(context).width < 700 ? 12 : 20, vertical: 12), children: [
          ProfessionalMobileWidgets.heading(context, title: 'Gelye Sherane', subtitle: 'Café & Rest  •  Live operations', icon: Icons.coffee, trailing: IconButton(tooltip: 'Refresh dashboard', onPressed: _refresh, icon: const Icon(Icons.refresh, color: ProfessionalMobileWidgets.gold))),
          ProfessionalMobileWidgets.workspaceIntro(context, eyebrow: 'Management overview', title: 'Today at Café & Rest', description: 'Live figures appear only when authorized server data is available. Pull down to refresh.', icon: Icons.insights_outlined),
          ProfessionalMobileWidgets.operationalNotice(context, message: 'Metrics are displayed from authorized data sources; use Refresh to request the latest values.', icon: Icons.shield_outlined),
          ProfessionalMobileWidgets.mobileActions(context, actions: [
            ('Refresh live metrics', Icons.refresh, _refresh),
          ]),
          Row(children: [
            const Expanded(child: Text('Operations today (Iraq time)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            IconButton(tooltip: 'Refresh dashboard', onPressed: _refresh, icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 8),
          _sectionShortcuts(),
          const SizedBox(height: 8),
          _DashboardSourceHealth(
            operational: _summary,
            orders: _week,
            dailyCash: _cash,
            weeklyCash: _cashWeek,
            onRetry: _refresh,
          ),
          const SizedBox(height: 8),
          if (snapshot.connectionState != ConnectionState.done)
            const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
          else if (snapshot.hasError)
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Dashboard metrics unavailable', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Check your dashboard permission, network, and Supabase migrations 471–472. No numbers are shown until the server responds.'),
                const SizedBox(height: 8),
                Text('${snapshot.error}', style: const TextStyle(fontSize: 12)),
              ],
            )))
          else if (data != null) ...[
            LayoutBuilder(builder: (context, constraints) {
              final cols = constraints.maxWidth >= 1000 ? 4 : constraints.maxWidth >= 620 ? 3 : constraints.maxWidth >= 360 ? 2 : 1;
              const metrics = <(String, String, IconData)>[
                ('Today orders','today_orders',Icons.receipt_long),
                ('Table orders','today_table_orders',Icons.table_restaurant),
                ('Motel orders','today_motel_orders',Icons.hotel),
                ('Kitchen pending','pending_kitchen',Icons.soup_kitchen),
                ('Ready orders','ready_orders',Icons.check_circle_outline),
                ('Total tables','total_tables',Icons.grid_view),
                ('Occupied tables','occupied_tables',Icons.event_seat),
                ('Tourism tables','tourism_tables',Icons.travel_explore),
              ];
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisExtent: MediaQuery.textScalerOf(context).scale(16) > 23 ? 168 : 150,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: metrics.length,
                itemBuilder: (context, index) {
                  final metric = metrics[index];
                  final available = _validCount(data[metric.$2]);
                  final value = available ? '${(data[metric.$2] as num).toInt()}' : '—';
                  return Semantics(
                    container: true,
                    label: '${metric.$1}: ${available ? value : 'restricted or unavailable'}',
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF102C43),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF34516A)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF24445B),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(metric.$3, color: const Color(0xFFE1B75E), size: 21),
                        ),
                        const Spacer(),
                        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(metric.$1, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFFCBD9E5), fontSize: 12)),
                      ]),
                    ),
                  );
                },
              );
            }),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _copyOperationalSnapshot(data),
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('Copy operational snapshot'),
              ),
            ),
            const SizedBox(height: 12),
            Text('Cash collections — today', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            FutureBuilder<Map<String, dynamic>>(
              future: _cash,
              builder: (context, cashSnapshot) {
                if (cashSnapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (cashSnapshot.hasError) {
                  return const Card(child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Cash collection figures unavailable'),
                    subtitle: Text('Check finance permissions and migration 484. No financial values are assumed.'),
                  ));
                }
                final cash = cashSnapshot.data ?? const <String, dynamic>{};
                bool validCash(dynamic value) => value is num && value.isFinite &&
                    value >= 0 && value == value.roundToDouble();
                bool validLedger(String prefix) =>
                    validCash(cash['${prefix}_cash_iqd']) &&
                    validCash(cash['${prefix}_cash_receipts']) &&
                    ((cash['${prefix}_cash_receipts'] as num) > 0 ||
                     (cash['${prefix}_cash_iqd'] as num) == 0);
                String amount(String key) {
                  final prefix = key.startsWith('motel_food') ? 'motel_food' : 'table';
                  return validLedger(prefix)
                      ? '${(cash[key] as num).toInt()} IQD'
                      : 'Restricted / unavailable';
                }
                return Card(child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ListTile(title: const Text('Table-order cash received'), subtitle: Text(amount('table_cash_iqd'))),
                    ListTile(title: const Text('Motel-food cash settled'), subtitle: Text(amount('motel_food_cash_iqd'))),
                    if (validLedger('table'))
                      ListTile(title: const Text('Table cash receipts'), subtitle: Text('${(cash['table_cash_receipts'] as num).toInt()}')),
                    if (validLedger('motel_food'))
                      ListTile(title: const Text('Motel-food cash receipts'), subtitle: Text('${(cash['motel_food_cash_receipts'] as num).toInt()}')),
                    if (validLedger('table') && validLedger('motel_food'))
                      ListTile(
                        leading: const Icon(Icons.account_balance_wallet_outlined),
                        title: const Text('Combined recorded cash collections'),
                        subtitle: Text('${((cash['table_cash_iqd'] as num) + (cash['motel_food_cash_iqd'] as num)).toInt()} IQD · Unreconciled'),
                      )
                    else
                      const ListTile(
                        leading: Icon(Icons.lock_outline),
                        title: Text('Combined cash collections unavailable'),
                        subtitle: Text('Both ledgers and receipt counts must be accessible. Restricted values are never assumed to be zero.'),
                      ),
                    Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(
                      onPressed: () => _copyCashSnapshot(cash),
                      icon: const Icon(Icons.copy_outlined), label: const Text('Copy cash collections report'),
                    )),
                    const Text('Separate ledgers. Cash collections only; not revenue, profit, total payments, or reconciled accounting. Credit is excluded.',
                      style: TextStyle(fontSize: 12)),
                  ]),
                ));
              },
            ),
            const SizedBox(height: 12),
            _CashSourceAgreement(daily: _cash, weekly: _cashWeek),
            const SizedBox(height: 12),
            Text('Cash collections — last 7 days', style: Theme.of(context).textTheme.titleMedium),
            FutureBuilder<Map<String, dynamic>>(
              future: _cashWeek,
              builder: (context, trendSnapshot) {
                if (trendSnapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (trendSnapshot.hasError) {
                  return const Text('Cash trend unavailable. Check financial permissions and migration 488.');
                }
                final days = (trendSnapshot.data?['days'] as List?) ?? const [];
                final sortedDays = days.whereType<Map>().toList()
                  ..sort((a, b) => a['business_date'].toString()
                      .compareTo(b['business_date'].toString()));
                // A subtotal is meaningful only if the employee has access
                // to all seven daily values for that specific ledger.
                int? weeklyTotal(String prefix) {
                  if (sortedDays.length != 7) return null;
                  var total = 0;
                  for (final day in sortedDays) {
                    final amount = day['${prefix}_cash_iqd'];
                    final receipts = day['${prefix}_cash_receipts'];
                    if (amount is! num || receipts is! num ||
                        !amount.isFinite || !receipts.isFinite ||
                        amount < 0 || receipts < 0 ||
                        amount != amount.roundToDouble() ||
                        receipts != receipts.roundToDouble() ||
                        (receipts == 0 && amount != 0)) return null;
                    total += amount.toInt();
                  }
                  return total;
                }
                final tableTotal = weeklyTotal('table');
                final motelTotal = weeklyTotal('motel_food');
                // Validate each pair before showing a daily amount. Previously
                // the list rendered any non-null value, even a negative,
                // fractional, or receipt-inconsistent cash amount.
                String safeDailyCash(Map row, String prefix) {
                  final amount = row['${prefix}_cash_iqd'];
                  final receipts = row['${prefix}_cash_receipts'];
                  if (amount is! num || receipts is! num ||
                      !amount.isFinite || !receipts.isFinite ||
                      amount < 0 || receipts < 0 ||
                      amount != amount.roundToDouble() ||
                      receipts != receipts.roundToDouble() ||
                      (receipts == 0 && amount != 0)) {
                    return 'Restricted / invalid';
                  }
                  return '${amount.toInt()} IQD (${receipts.toInt()} receipts)';
                }
                return Card(child: Column(children: [
                  if (tableTotal != null || motelTotal != null)
                    Padding(padding: const EdgeInsets.all(12), child: Wrap(
                      spacing: 8, runSpacing: 8, children: [
                        if (tableTotal != null) Chip(label: Text('7-day table cash: $tableTotal IQD')),
                        if (motelTotal != null) Chip(label: Text('7-day motel cash: $motelTotal IQD')),
                        if (tableTotal != null && motelTotal != null)
                          Chip(label: Text('Combined 7-day cash: ${tableTotal + motelTotal} IQD')),
                      ],
                    )),
                  if (tableTotal == null || motelTotal == null)
                    const Padding(padding: EdgeInsets.all(12), child: Text(
                      'Some weekly totals are restricted or unavailable. Missing amounts are never treated as zero.')),
                  for (final row in sortedDays)
                    ListTile(
                      dense: true,
                      title: Text(row['business_date'].toString()),
                      subtitle: Text('Table: ${safeDailyCash(row, 'table')}  •  Motel: ${safeDailyCash(row, 'motel_food')}'),
                    ),
                  Align(alignment: Alignment.centerRight, child: TextButton.icon(
                    onPressed: () => _copyWeeklyCashReport(trendSnapshot.data!),
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copy seven-day cash report'),
                  )),
                  const Padding(padding: EdgeInsets.all(12), child: Text('Unreconciled cash collections only. Not total revenue or profit.', style: TextStyle(fontSize: 12))),
                ]));
              },
            ),
            _CashCrossReportCheck(today: _cash, week: _cashWeek),
            _DashboardDataReadiness(summary: data),
            _DashboardConsistency(summary: data),
            const SizedBox(height: 16),
            Text('Operational ratios', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _DashboardRatios(summary: data),
            const SizedBox(height: 16),
            Text('Operational attention', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _OperationalAttention(summary: data),
            const SizedBox(height: 12),
            Text('Order activity — last 7 days', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder<List<dynamic>>(
              future: _week,
              builder: (context, weekSnapshot) {
                if (weekSnapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (weekSnapshot.hasError) {
                  return Row(children: [
                    const Expanded(child: Text('Weekly order activity unavailable. Check permissions and migration 474.')),
                    TextButton(onPressed: _refresh, child: const Text('Retry')),
                  ]);
                }
                final rows = weekSnapshot.data ?? const <dynamic>[];
                if (rows.isEmpty) return const Text('No accessible order activity.');
                final validRows = rows.whereType<Map>().where((row) =>
                  row['order_count'] is num && (row['order_count'] as num).isFinite && (row['order_count'] as num) >= 0 && (row['order_count'] as num) == (row['order_count'] as num).roundToDouble() &&
                  row['business_date'] != null).toList();
                if (validRows.isEmpty) return const Text('No valid weekly activity data available.');
                if (validRows.length != rows.length || validRows.length != 7) {
                  return const Text('Incomplete or invalid seven-day report. The server must return exactly seven valid daily records.');
                }
                // Reject duplicate business dates instead of double-counting totals.
                // The SQL endpoint must return exactly one count per date.
                final seenDates = <String>{};
                final uniqueRows = <Map>[];
                for (final row in validRows) {
                  final date = row['business_date'].toString();
                  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
                      !seenDates.add(date)) {
                    return const Text('Weekly activity response is inconsistent. Refresh or contact an administrator.');
                  }
                  uniqueRows.add(row);
                }
                uniqueRows.sort((a, b) =>
                  a['business_date'].toString().compareTo(b['business_date'].toString()));
                final firstDay = DateTime.tryParse(uniqueRows.first['business_date'].toString());
                if (firstDay == null || List.generate(7, (i) => firstDay.add(Duration(days: i)).toIso8601String().substring(0, 10))
                    .asMap().entries.any((e) => uniqueRows[e.key]['business_date'].toString() != e.value)) {
                  return const Text('Weekly report contains missing or non-consecutive dates.');
                }
                final firstThreeDays = uniqueRows.take(3).fold<int>(0, (sum, row) => sum + (row['order_count'] as num).toInt());
                final lastThreeDays = uniqueRows.skip(4).fold<int>(0, (sum, row) => sum + (row['order_count'] as num).toInt());
                final comparison = lastThreeDays > firstThreeDays ? 'Higher' : lastThreeDays < firstThreeDays ? 'Lower' : 'Unchanged';
                final weekTotal = uniqueRows.fold<int>(0, (sum, row) =>
                  sum + (row['order_count'] as num).toInt());
                final peak = uniqueRows.reduce((a, b) =>
                  (a['order_count'] as num) >= (b['order_count'] as num) ? a : b);
                final maxCount = uniqueRows.fold<int>(1, (max, row) {
                  final count = (row['order_count'] as num).toInt();
                  return count > max ? count : max;
                });
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    Chip(label: Text('7-day orders: $weekTotal')),
                    Chip(label: Text('Average per reported day: ${(weekTotal / uniqueRows.length).toStringAsFixed(1)}')),
                    Chip(label: Text('Busiest day: ${peak['business_date']} (${peak['order_count']})')),
                    Chip(label: Text('Recent 3 days vs first 3: $comparison ($lastThreeDays vs $firstThreeDays orders)')),
                  ]),
                  const SizedBox(height: 8),
                  for (final item in uniqueRows)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
                    SizedBox(width: 88, child: Text('${item['business_date']}', style: const TextStyle(fontSize: 11))),
                    Expanded(child: LinearProgressIndicator(
                      value: (((item['order_count'] as num?)?.toInt() ?? 0) / maxCount).clamp(0.0, 1.0),
                      minHeight: 12,
                    )),
                    SizedBox(width: 42, child: Text('${item['order_count'] ?? 0}', textAlign: TextAlign.end)),
                  ])),
                ]);
              },
            ),
            const SizedBox(height: 12),
            const Text('Read-only counts. Restricted means your account lacks permission for that section; it does not mean zero. Revenue, profit, credit balances and reconciled accounting remain excluded pending verification. Cash collections are shown separately above when authorized.'),
            Text('Updated: ${data['as_of'] ?? 'unknown'}', style: Theme.of(context).textTheme.bodySmall),
          ],
        ]);
      },
    ),
  );
}

/// Alerts are derived only from permission-scoped server fields.
/// No access to a metric is never interpreted as a healthy zero.
class _OperationalAttention extends StatelessWidget {
  const _OperationalAttention({required this.summary});
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final notices = <(IconData, String, String)>[];
    int? count(String key) {
      if (!summary.containsKey(key)) return null;
      final value = summary[key];
      return value is num && value >= 0 ? value.toInt() : null;
    }
    final pending = count('pending_kitchen');
    final ready = count('ready_orders');
    final occupied = count('occupied_tables');
    final total = count('total_tables');
    if (pending != null && pending > 0) {
      notices.add((Icons.restaurant, '$pending kitchen orders pending',
        'Review preparation queue. This is a workload indicator, not an overdue-time claim.'));
    }
    if (ready != null && ready > 0) {
      notices.add((Icons.room_service, '$ready orders ready',
        'Check the fulfillment queue for orders awaiting service.'));
    }
    if (occupied != null && total != null && total > 0 && occupied >= total) {
      notices.add((Icons.event_busy, 'All $total tables occupied',
        'Check table availability before accepting new walk-in seating.'));
    }
    final hasOperationalAccess = pending != null || ready != null ||
      (occupied != null && total != null);
    if (notices.isEmpty) {
      return Card(child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(hasOperationalAccess
          ? 'No attention indicators from the accessible operational metrics. This does not confirm there are no other alerts.'
          : 'Operational attention is unavailable because the related section metrics are restricted.'),
      ));
    }
    return Column(children: [for (final notice in notices)
      Card(child: ListTile(
        leading: Icon(notice.$1),
        title: Text(notice.$2),
        subtitle: Text(notice.$3),
      )),
    ]);
  }
}

/// Ratios are computed exclusively from server-authorized fields. A missing
/// metric is not zero, and the widget does not infer revenue or profit.
class _DashboardRatios extends StatelessWidget {
  const _DashboardRatios({required this.summary});
  final Map<String, dynamic> summary;

  int? _nonNegative(String key) {
    final value = summary[key];
    if (value is! num || !value.isFinite || value < 0 || value != value.roundToDouble()) {
      return null;
    }
    return value.toInt();
  }

  @override
  Widget build(BuildContext context) {
    final occupied = _nonNegative('occupied_tables');
    final tables = _nonNegative('total_tables');
    final tourism = _nonNegative('tourism_tables');
    final tableOrders = _nonNegative('today_table_orders');
    final motelOrders = _nonNegative('today_motel_orders');
    final chips = <Widget>[];
    if (tables != null && occupied != null && tables > 0 && occupied <= tables) {
      chips.add(Chip(label: Text('Table occupancy: ${(occupied * 100 / tables).toStringAsFixed(1)}%')));
      chips.add(Chip(label: Text('Available tables: ${tables - occupied}')));
    }
    if (occupied != null && tourism != null && occupied > 0 && tourism <= occupied) {
      chips.add(Chip(label: Text('Tourism share of occupied tables: ${(tourism * 100 / occupied).toStringAsFixed(1)}%')));
    }
    if (tableOrders != null && motelOrders != null && tableOrders + motelOrders > 0) {
      final total = tableOrders + motelOrders;
      chips.add(Chip(label: Text('Table order share today: ${(tableOrders * 100 / total).toStringAsFixed(1)}%')));
      chips.add(Chip(label: Text('Motel order share today: ${(motelOrders * 100 / total).toStringAsFixed(1)}%')));
    }
    if (chips.isEmpty) {
      return const Text('Ratios unavailable: required metrics are restricted, missing, or there is no valid denominator.');
    }
    return Wrap(spacing: 8, runSpacing: 6, children: chips);
  }
}

/// Distinguishes section access, valid operational counts, and missing data.
/// This is not a production-health or financial-reconciliation certification.
class _DashboardDataReadiness extends StatelessWidget {
  const _DashboardDataReadiness({required this.summary});
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    const groups = <(String, List<String>)>[
      ('Table Orders', ['today_table_orders']),
      ('Motel Orders', ['today_motel_orders']),
      ('Kitchen', ['pending_kitchen', 'ready_orders']),
      ('Tables', ['total_tables', 'occupied_tables', 'tourism_tables']),
    ];
    bool valid(String key) {
      final value = summary[key];
      return value is num && value.isFinite && value >= 0 &&
          value == value.roundToDouble();
    }
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Data availability by section',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('Shows whether this account received valid operational counts. '
            'Restricted or unavailable is not zero and does not imply a system failure.'),
        const SizedBox(height: 8),
        for (final group in groups)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(group.$2.every(valid)
                ? Icons.check_circle_outline : Icons.lock_outline),
            title: Text(group.$1),
            subtitle: Text(group.$2.every(valid)
                ? 'Operational counts available'
                : 'Restricted, unavailable, or invalid'),
          ),
        const Text('Financial reconciliation and live Supabase verification '
            'are not covered by this status.'),
      ]),
    ));
  }
}


/// Cross-checks only metrics the employee is authorized to receive.
/// Does not treat missing or restricted metrics as zero.
class _DashboardConsistency extends StatelessWidget {
  const _DashboardConsistency({required this.summary});
  final Map<String, dynamic> summary;

  int? _count(String key) {
    final value = summary[key];
    if (value is! num || !value.isFinite || value < 0 ||
        value != value.roundToDouble()) return null;
    return value.toInt();
  }

  @override
  Widget build(BuildContext context) {
    final total = _count('today_orders');
    final table = _count('today_table_orders');
    final motel = _count('today_motel_orders');
    final capacity = _count('total_tables');
    final occupied = _count('occupied_tables');
    final tourism = _count('tourism_tables');
    final issues = <String>[];
    if (total != null && table != null && motel != null &&
        total != table + motel) {
      issues.add('Today order total does not match table and motel subtotals.');
    }
    if (capacity != null && occupied != null && occupied > capacity) {
      issues.add('Occupied table count exceeds table capacity.');
    }
    if (tourism != null && occupied != null && tourism > occupied) {
      issues.add('Tourism occupied tables exceed all occupied tables.');
    }
    final checked = (total != null && table != null && motel != null) ||
        (capacity != null && occupied != null) ||
        (tourism != null && occupied != null);
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Cross-section consistency', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (issues.isNotEmpty)
          for (final issue in issues) ListTile(
            dense: true, leading: const Icon(Icons.warning_amber_outlined),
            title: Text(issue),
          )
        else Text(checked
            ? 'Available operational totals are internally consistent. This is not financial reconciliation.'
            : 'Insufficient authorized data to check consistency; no pass is claimed.'),
      ]),
    ));
  }
}

/// Diagnostic comparison, NOT a settlement or accounting reconciliation.
/// Both RPCs are independently permission-scoped. Never infer a zero from
/// missing data or claim a mismatch when snapshots are far apart in time.
class _CashCrossReportCheck extends StatelessWidget {
  const _CashCrossReportCheck({required this.today, required this.week});
  final Future<Map<String, dynamic>> today;
  final Future<Map<String, dynamic>> week;

  static int? _whole(dynamic value) {
    if (value is! num || !value.isFinite || value < 0 ||
        value != value.roundToDouble()) return null;
    return value.toInt();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Future.wait([today, week]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ListTile(title: Text('Daily / weekly cash consistency'),
              subtitle: Text('Checking report snapshots…'));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const ListTile(leading: Icon(Icons.info_outline),
            title: Text('Daily / weekly cash consistency unavailable'),
            subtitle: Text('At least one permission-scoped report could not load.'));
        }
        final daily = snapshot.data![0];
        final weekly = snapshot.data![1];
        final dayTime = DateTime.tryParse(daily['as_of']?.toString() ?? '');
        final weekTime = DateTime.tryParse(weekly['as_of']?.toString() ?? '');
        final records = weekly['days'];
        if (dayTime == null || weekTime == null || records is! List ||
            records.length != 7 ||
            daily['scope'] != 'cash_collections_only' ||
            weekly['scope'] != 'cash_collections_only' ||
            daily['reconciled'] != false || weekly['reconciled'] != false ||
            daily['timezone'] != 'Asia/Baghdad' ||
            weekly['timezone'] != 'Asia/Baghdad' ||
            dayTime.difference(weekTime).inSeconds.abs() > 30) {
          return const ListTile(leading: Icon(Icons.schedule),
            title: Text('Cash reports captured at different times'),
            subtitle: Text('Refresh to compare recent snapshots. No reconciliation is implied.'));
        }
        // Iraq has used UTC+03 without DST since 2008. Derive the business
        // date from the server's timestamp, never from the device timezone.
        final iraqDate = dayTime.toUtc().add(const Duration(hours: 3));
        final expectedDate = '${iraqDate.year.toString().padLeft(4, '0')}-'
            '${iraqDate.month.toString().padLeft(2, '0')}-'
            '${iraqDate.day.toString().padLeft(2, '0')}';
        // The RPC is allowed to return days in any order. Identify today's
        // record by its business date, and refuse duplicate or malformed days.
        // Never compare against records.last without validating the date.
        final matches = records.where((record) =>
            record is Map && record['business_date'] == expectedDate).toList();
        final distinctDates = <String>{};
        final validDates = records.every((record) =>
            record is Map && record['business_date'] is String &&
            RegExp(r'^\d{4}-\d{2}-\d{2}$')
                .hasMatch(record['business_date'] as String) &&
            distinctDates.add(record['business_date'] as String));
        if (!validDates || matches.length != 1 || distinctDates.length != 7) {
          return const ListTile(leading: Icon(Icons.info_outline),
            title: Text('Cash report dates do not match'),
            subtitle: Text('Missing or duplicated business dates prevent comparison.'));
        }
        final last = matches.single as Map;
        final issues = <String>[];
        var compared = 0;
        for (final prefix in const ['table', 'motel_food']) {
          final dailyAmount = _whole(daily['${prefix}_cash_iqd']);
          final weeklyAmount = _whole(last['${prefix}_cash_iqd']);
          final dailyReceipts = _whole(daily['${prefix}_cash_receipts']);
          final weeklyReceipts = _whole(last['${prefix}_cash_receipts']);
          if (dailyAmount == null || weeklyAmount == null ||
              dailyReceipts == null || weeklyReceipts == null) continue;
          compared++;
          if (dailyAmount != weeklyAmount || dailyReceipts != weeklyReceipts) {
            issues.add(prefix == 'table' ? 'Table Orders' : 'Motel Orders');
          }
        }
        return ListTile(
          leading: Icon(issues.isNotEmpty ? Icons.warning_amber_outlined :
              compared == 0 ? Icons.lock_outline : Icons.fact_check_outlined),
          title: const Text('Daily / weekly cash consistency'),
          subtitle: Text(issues.isNotEmpty
              ? 'Different totals or receipt counts: ${issues.join(', ')}. Check report timing and source ledgers.'
              : compared == 0
                ? 'No common authorized cash ledger is available for comparison.'
                : '$compared authorized cash ledger(s) match across both reports. This is not accounting reconciliation.'),
        );
      },
    );
  }
}


/// Independently reports source loading/failure without exposing restricted
/// figures or mistaking a permission denial for a zero-valued result.
class _DashboardSourceHealth extends StatelessWidget {
  const _DashboardSourceHealth({
    required this.operational,
    required this.orders,
    required this.dailyCash,
    required this.weeklyCash,
    required this.onRetry,
  });
  final Future<Map<String, dynamic>> operational;
  final Future<List<dynamic>> orders;
  final Future<Map<String, dynamic>> dailyCash;
  final Future<Map<String, dynamic>> weeklyCash;
  final VoidCallback onRetry;

  Widget _source<T>(String label, Future<T> future) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      final waiting = snapshot.connectionState != ConnectionState.done;
      final failed = snapshot.hasError ||
          (!waiting && !snapshot.hasData);
      final icon = waiting ? Icons.hourglass_top :
          failed ? Icons.warning_amber_outlined : Icons.check_circle_outline;
      final status = waiting ? 'Loading' :
          failed ? 'Unavailable' : 'Response received';
      return Semantics(
        label: '$label: $status',
        child: Chip(
          avatar: Icon(icon, size: 17),
          label: Text('$label: $status'),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Reporting source health',
              style: TextStyle(fontWeight: FontWeight.bold))),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry all'),
          ),
        ]),
        Wrap(spacing: 6, runSpacing: 4, children: [
          _source('Operations', operational),
          _source('Order activity', orders),
          _source('Daily cash', dailyCash),
          _source('Weekly cash', weeklyCash),
        ]),
        const SizedBox(height: 6),
        const Text('Response received means the request completed; it does not '
            'mean accounting was reconciled or that restricted metrics are accessible.',
            style: TextStyle(fontSize: 12)),
      ]),
    ),
  );
}

/// Compares independently fetched daily and weekly cash ledgers for the same
/// Iraq business day. This is a source-consistency check, NOT accounting
/// reconciliation. Never expose a value when either RPC restricted it.
class _CashSourceAgreement extends StatelessWidget {
  const _CashSourceAgreement({required this.daily, required this.weekly});
  final Future<Map<String, dynamic>> daily;
  final Future<Map<String, dynamic>> weekly;

  static int? _whole(dynamic value) {
    if (value is! num || !value.isFinite || value < 0 ||
        value != value.roundToDouble()) return null;
    return value.toInt();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: Future.wait([daily, weekly]),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Card(child: ListTile(
          leading: Icon(Icons.sync), title: Text('Cash source consistency'),
          subtitle: Text('Comparing daily and seven-day cash sources…')));
      }
      if (snapshot.hasError || snapshot.data == null) {
        return const Card(child: ListTile(
          leading: Icon(Icons.lock_outline), title: Text('Cash source consistency unavailable'),
          subtitle: Text('One or both cash sources could not be accessed. No amounts are inferred.')));
      }
      final today = snapshot.data![0];
      final trend = snapshot.data![1];
      final dailyTime = DateTime.tryParse(today['as_of']?.toString() ?? '');
      final weeklyTime = DateTime.tryParse(trend['as_of']?.toString() ?? '');
      if (dailyTime == null || weeklyTime == null ||
          today['timezone'] != 'Asia/Baghdad' || trend['timezone'] != 'Asia/Baghdad' ||
          today['scope'] != 'cash_collections_only' || trend['scope'] != 'cash_collections_only') {
        return const Card(child: ListTile(
          title: Text('Cash source consistency unavailable'),
          subtitle: Text('Reporting metadata could not be verified.')));
      }
      final dailyDate = dailyTime.toUtc().add(const Duration(hours: 3))
          .toIso8601String().substring(0, 10);
      final weeklyDate = weeklyTime.toUtc().add(const Duration(hours: 3))
          .toIso8601String().substring(0, 10);
      final days = trend['days'];
      if (dailyDate != weeklyDate || days is! List) {
        return const Card(child: ListTile(
          leading: Icon(Icons.info_outline), title: Text('Cash snapshots cover different dates'),
          subtitle: Text('Refresh both sources after the Iraq business-day rollover.')));
      }
      final matching = days.whereType<Map>().where((row) => row['business_date'] == dailyDate).toList();
      if (matching.length != 1) {
        return const Card(child: ListTile(
          title: Text('Cash source consistency unavailable'),
          subtitle: Text('The seven-day source has no unique row for today.')));
      }
      final row = matching.single;
      final labels = <String>[];
      var mismatch = false;
      for (final prefix in const ['table', 'motel_food']) {
        final a = _whole(today['${prefix}_cash_iqd']);
        final b = _whole(row['${prefix}_cash_iqd']);
        final ac = _whole(today['${prefix}_cash_receipts']);
        final bc = _whole(row['${prefix}_cash_receipts']);
        final label = prefix == 'table' ? 'Table orders' : 'Motel food';
        if (a == null || b == null || ac == null || bc == null ||
            (ac == 0 && a != 0) || (bc == 0 && b != 0)) {
          labels.add('$label: restricted / unavailable');
        } else if (a != b || ac != bc) {
          mismatch = true;
          labels.add('$label: sources differ (refresh to confirm)');
        } else {
          labels.add('$label: amounts and receipt counts agree');
        }
      }
      final drift = dailyTime.difference(weeklyTime).abs();
      return Card(child: ListTile(
        leading: Icon(mismatch ? Icons.warning_amber_outlined : Icons.fact_check_outlined),
        title: Text(mismatch ? 'Cash sources need review' : 'Cash source consistency'),
        subtitle: Text('${labels.join('\n')}\n'
            'Snapshot gap: ${drift.inSeconds} seconds. This check is not accounting reconciliation.'),
        isThreeLine: true,
      ));
    },
  );
}
