import 'package:flutter/material.dart';

/// Explainable, read-only operational suggestions derived exclusively from
/// permission-filtered server metrics. This is NOT a generative AI service.
/// No automatic financial, inventory, or employee action is performed.
class DashboardInsight {
  const DashboardInsight(this.title, this.explanation, this.metricKey,
      this.metricValue, this.priority);
  final String title;
  final String explanation;
  final String metricKey;
  final num metricValue;
  final int priority;
}

class DashboardInsights {
  static num? _number(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is num && value.isFinite && value >= 0) return value;
    return null;
  }

  /// A rule fires only when its corresponding source metric is present.
  /// These thresholds are provisional UI prompts, not operational SLAs.
  static List<DashboardInsight> fromMetrics(Map<String, dynamic> data) {
    final items = <DashboardInsight>[];
    void addIfPositive(String key, String title, String message, int priority) {
      final count = _number(data, key);
      if (count != null && count > 0) {
        items.add(DashboardInsight(title, message, key, count, priority));
      }
    }
    addIfPositive('urgent_guest_requests', 'Urgent guest requests',
        'Review outstanding urgent guest requests and assign an authorized employee.', 0);
    addIfPositive('overdue_service_orders', 'Overdue service orders',
        'Inspect waiting orders and investigate service delays.', 0);
    addIfPositive('out_of_stock_count', 'Out-of-stock products',
        'Review unavailable products before accepting affected orders.', 1);
    addIfPositive('low_stock_count', 'Low-stock products',
        'Review inventory and purchase requirements.', 2);
    addIfPositive('cash_reconciliation_discrepancies', 'Cash differences',
        'Investigate differences with authorized finance staff; do not adjust receipts automatically.', 0);
    addIfPositive('open_maintenance_issues', 'Open maintenance issues',
        'Review unresolved equipment or facility issues.', 1);
    addIfPositive('pending_offline_sync', 'Unsynchronized records',
        'Check offline synchronization before relying on cross-device totals.', 0);
    items.sort((a, b) => a.priority.compareTo(b.priority));
    return items;
  }
}

class DashboardInsightsPanel extends StatelessWidget {
  const DashboardInsightsPanel({super.key, required this.metrics});
  final Map<String, dynamic> metrics;

  @override
  Widget build(BuildContext context) {
    final insights = DashboardInsights.fromMetrics(metrics);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.tips_and_updates_outlined),
            const SizedBox(width: 8),
            Expanded(child: Text('Smart operational insights',
                style: Theme.of(context).textTheme.titleLarge)),
          ]),
          const SizedBox(height: 6),
          const Text('Explainable suggestions from available server metrics. '
              'No AI service is connected and no action is taken automatically.'),
          const SizedBox(height: 12),
          if (insights.isEmpty)
            const Text('No triggered suggestions from available metrics. '
                'This does not mean all operational areas are clear.'),
          for (final insight in insights)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(insight.priority == 0
                  ? Icons.priority_high : Icons.info_outline),
              title: Text(insight.title),
              subtitle: Text('${insight.explanation}\n'
                  'Source: ${insight.metricKey} = ${insight.metricValue}'),
              isThreeLine: true,
            ),
        ]),
      ),
    );
  }
}
