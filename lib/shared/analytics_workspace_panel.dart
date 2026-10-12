import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only analysis of a bounded, RLS-filtered sample of orders.
/// Order values are not verified payments or recognized revenue.
class AnalyticsWorkspacePanel extends StatefulWidget {
  const AnalyticsWorkspacePanel({super.key});

  @override
  State<AnalyticsWorkspacePanel> createState() => _AnalyticsWorkspacePanelState();
}

class _AnalyticsWorkspacePanelState extends State<AnalyticsWorkspacePanel> {
  late Future<_AnalyticsData> _future = _load();
  String _mode = 'all';

  Future<_AnalyticsData> _load() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw StateError('Sign in to view analytics.');
    }
    final orders = List<Map<String, dynamic>>.from(await client
        .from('gs_orders')
        .select('id,created_at,status,tourism_mode,is_motel')
        .order('created_at', ascending: false)
        .limit(100));
    final values = <String, int>{};
    var truncatedItems = false;
    if (orders.isNotEmpty) {
      final items = List<Map<String, dynamic>>.from(await client
          .from('gs_order_items')
          .select('order_id,line_total_iqd')
          .inFilter('order_id', orders.map((e) => e['id']).toList())
          .limit(1000));
      truncatedItems = items.length == 1000;
      for (final item in items) {
        final key = '${item['order_id']}';
        values[key] = (values[key] ?? 0) +
            ((item['line_total_iqd'] as num?)?.toInt() ?? 0);
      }
    }
    return _AnalyticsData(orders, values, truncatedItems);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ListTile(
        leading: const Icon(Icons.insights_outlined),
        title: const Text('Order analytics'),
        subtitle: const Text('Recent accessible orders · values in IQD'),
        trailing: IconButton(
          tooltip: 'Refresh analytics',
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(() => _future = _load()),
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
            DropdownMenuItem(value: 'all', child: Text('All modes')),
            DropdownMenuItem(value: 'normal', child: Text('Normal')),
            DropdownMenuItem(value: 'tourism', child: Text('Tourism')),
          ],
          onChanged: (value) => setState(() => _mode = value ?? 'all'),
        ),
      ),
      Expanded(child: FutureBuilder<_AnalyticsData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText('Analytics unavailable: ${snapshot.error}'),
            ));
          }
          final data = snapshot.data!;
          final daily = <String, _AnalyticsBucket>{};
          final modes = <String, _AnalyticsBucket>{
            'Normal': _AnalyticsBucket(),
            'Tourism': _AnalyticsBucket(),
          };
          final statuses = <String, int>{};
          var excluded = 0;
          for (final order in data.orders) {
            final tourism = order['tourism_mode'] == true || order['is_motel'] == true;
            if (_mode == 'tourism' && !tourism) continue;
            if (_mode == 'normal' && tourism) continue;
            final status = '${order['status']}'.toLowerCase();
            statuses[status] = (statuses[status] ?? 0) + 1;
            if (status == 'cancelled' || status == 'canceled') {
              excluded++;
              continue;
            }
            final value = data.values['${order['id']}'] ?? 0;
            final mode = modes[tourism ? 'Tourism' : 'Normal']!;
            mode.count++;
            mode.value += value;
            final created = DateTime.tryParse('${order['created_at']}');
            if (created == null) continue;
            final local = created.toLocal();
            final day = '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
            final bucket = daily.putIfAbsent(day, _AnalyticsBucket.new);
            bucket.count++;
            bucket.value += value;
          }
          final days = daily.keys.toList()..sort((a, b) => b.compareTo(a));
          final totalCount = modes.values.fold<int>(0, (sum, b) => sum + b.count);
          final totalValue = modes.values.fold<int>(0, (sum, b) => sum + b.value);
          final sortedStatuses = statuses.keys.toList()..sort();
          return ListView(padding: const EdgeInsets.all(12), children: [
            Card(child: ListTile(
              title: Text('$totalValue IQD', style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text('$totalCount non-cancelled sampled orders'),
            )),
            Card(child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Sample only — not confirmed revenue'),
              subtitle: Text('Latest 100 accessible orders and up to 1,000 items. '
                  'RLS may restrict results. $excluded cancelled orders excluded. '
                  'Dates use device local time; order values are not payments.'),
            )),
            if (data.truncatedItems)
              const Card(child: ListTile(
                leading: Icon(Icons.warning_amber_outlined),
                title: Text('Item limit reached'),
                subtitle: Text('Order values may be incomplete.'),
              )),
            const ListTile(title: Text('Pricing mode comparison')),
            for (final entry in modes.entries)
              Card(child: ListTile(
                title: Text(entry.key),
                subtitle: Text('${entry.value.count} orders'),
                trailing: Text('${entry.value.value} IQD'),
              )),
            const ListTile(title: Text('Order status breakdown')),
            for (final status in sortedStatuses)
              ListTile(title: Text(status), trailing: Text('${statuses[status]}')),
            const ListTile(title: Text('Daily order trends')),
            if (days.isEmpty)
              const ListTile(title: Text('No matching orders')),
            for (final day in days)
              Card(child: ListTile(
                title: Text(day),
                subtitle: Text('${daily[day]!.count} orders'),
                trailing: Text('${daily[day]!.value} IQD'),
              )),
          ]);
        },
      )),
    ]);
  }
}

class _AnalyticsBucket {
  int count = 0;
  int value = 0;
}

class _AnalyticsData {
  final List<Map<String, dynamic>> orders;
  final Map<String, int> values;
  final bool truncatedItems;
  _AnalyticsData(this.orders, this.values, this.truncatedItems);
}
