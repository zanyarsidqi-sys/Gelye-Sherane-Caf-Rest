import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only sample of authorized order values, not settled revenue.
class ReportsWorkspacePanel extends StatefulWidget {
  const ReportsWorkspacePanel({super.key});
  @override
  State<ReportsWorkspacePanel> createState() => _ReportsWorkspacePanelState();
}

class _ReportsWorkspacePanelState extends State<ReportsWorkspacePanel> {
  late Future<_ReportData> _report = _load();
  String _mode = 'all';

  Future<_ReportData> _load() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw StateError('Sign in before opening reports.');
    }
    final orders = List<Map<String, dynamic>>.from(await client
        .from('gs_orders')
        .select('id,created_at,status,tourism_mode,is_motel')
        .order('created_at', ascending: false)
        .limit(100));
    final totals = <String, int>{};
    var itemLimitReached = false;
    if (orders.isNotEmpty) {
      final items = List<Map<String, dynamic>>.from(await client
          .from('gs_order_items')
          .select('order_id,line_total_iqd')
          .inFilter('order_id', orders.map((e) => e['id']).toList())
          .limit(1000));
      itemLimitReached = items.length == 1000;
      for (final item in items) {
        final id = '${item['order_id']}';
        totals[id] = (totals[id] ?? 0) +
            ((item['line_total_iqd'] as num?)?.toInt() ?? 0);
      }
    }
    return _ReportData(orders, totals, itemLimitReached);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ListTile(
        leading: const Icon(Icons.assessment_outlined),
        title: const Text('Order activity report'),
        subtitle: const Text('Read-only, recent authorized records · IQD'),
        trailing: IconButton(
          tooltip: 'Refresh report',
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(() => _report = _load()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DropdownButtonFormField<String>(
          initialValue: _mode,
          decoration: const InputDecoration(
            labelText: 'Pricing mode', border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All orders')),
            DropdownMenuItem(value: 'normal', child: Text('Normal')),
            DropdownMenuItem(value: 'tourism', child: Text('Tourism')),
          ],
          onChanged: (value) => setState(() => _mode = value ?? 'all'),
        ),
      ),
      Expanded(child: FutureBuilder<_ReportData>(
        future: _report,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText('Report unavailable: ${snapshot.error}'),
            ));
          }
          final data = snapshot.data!;
          final days = <String, _DaySummary>{};
          var excluded = 0;
          for (final order in data.orders) {
            final tourism = order['tourism_mode'] == true || order['is_motel'] == true;
            if (_mode != 'all' && (_mode == 'tourism') != tourism) continue;
            final status = '${order['status']}'.toLowerCase();
            if (status == 'cancelled' || status == 'canceled') {
              excluded++;
              continue;
            }
            final created = DateTime.tryParse('${order['created_at']}');
            if (created == null) continue;
            final local = created.toLocal();
            final day = '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
            final summary = days.putIfAbsent(day, () => _DaySummary());
            summary.count++;
            summary.value += data.totals['${order['id']}'] ?? 0;
          }
          final keys = days.keys.toList()..sort((a, b) => b.compareTo(a));
          final total = days.values.fold<int>(0, (sum, day) => sum + day.value);
          return ListView(padding: const EdgeInsets.all(12), children: [
            Card(child: ListTile(
              title: Text('$total IQD', style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text('Non-cancelled order value · ${days.values.fold<int>(0, (sum, day) => sum + day.count)} sampled orders'),
            )),
            Card(child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Not a financial statement'),
              subtitle: Text('Only the latest 100 accessible orders and up to 1,000 line items are queried. '
                  'RLS may hide records. $excluded cancelled orders excluded. '
                  'Order value is not confirmed payment or revenue.'),
            )),
            if (data.itemLimitReached)
              const Card(child: ListTile(
                leading: Icon(Icons.warning_amber_outlined),
                title: Text('Item query limit reached'),
                subtitle: Text('Displayed values may be incomplete.'),
              )),
            if (keys.isEmpty) const Center(child: Padding(
              padding: EdgeInsets.all(24), child: Text('No matching orders'),
            )),
            for (final day in keys)
              Card(child: ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(day),
                subtitle: Text('${days[day]!.count} orders'),
                trailing: Text('${days[day]!.value} IQD'),
              )),
          ]);
        },
      )),
    ]);
  }
}

class _DaySummary {
  int count = 0;
  int value = 0;
}

class _ReportData {
  final List<Map<String, dynamic>> orders;
  final Map<String, int> totals;
  final bool itemLimitReached;
  _ReportData(this.orders, this.totals, this.itemLimitReached);
}
