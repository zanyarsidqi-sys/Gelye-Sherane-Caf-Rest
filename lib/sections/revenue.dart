import 'package:flutter/material.dart';
import '../shared/section_shell.dart';
import '../services/local_order_preview.dart';
import '../shared/live_order_value_panel.dart';

class RevenueScreen extends StatelessWidget {
  const RevenueScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: "Revenue",
    description: "Income and revenue tracking",
    sectionId: "revenue",
    authorizedContent: _RevenueWorkspace(),
  );
}


class _RevenuePreview extends StatelessWidget {
  const _RevenuePreview();
  @override
  Widget build(BuildContext context) {
    final preview = LocalOrderPreview.instance;
    return AnimatedBuilder(
      animation: preview,
      builder: (context, _) {
        final orders = preview.orders;
        final valid = orders.where((o) => o.status != PreviewOrderStatus.cancelled);
        final cancelled = orders.where((o) => o.status == PreviewOrderStatus.cancelled);
        final normalValue = valid.where((o) => !o.tourism)
          .fold<int>(0, (sum, o) => sum + o.total);
        final tourismValue = valid.where((o) => o.tourism)
          .fold<int>(0, (sum, o) => sum + o.total);
        final cancelledValue = cancelled.fold<int>(0, (sum, o) => sum + o.total);
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('Revenue — local order preview',
            style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('NOT LIVE FINANCIAL DATA. Amounts represent preview order '
            'value only, not payments received or recognized revenue.'),
          const SizedBox(height: 16),
          Card(child: ListTile(title: const Text('Normal Mode order value'),
            trailing: Text('$normalValue IQD'))),
          Card(child: ListTile(title: const Text('Tourism Mode order value'),
            trailing: Text('$tourismValue IQD'))),
          Card(child: ListTile(title: const Text('Total non-cancelled order value'),
            trailing: Text('${normalValue + tourismValue} IQD'))),
          Card(child: ListTile(title: const Text('Cancelled order value (excluded)'),
            trailing: Text('$cancelledValue IQD'))),
          const SizedBox(height: 12),
          const Text('Payment settlement, refunds, discounts, taxes and '
            'Supabase reports are not implemented in this preview.'),
        ]);
      },
    );
  }
}

class _RevenueWorkspace extends StatelessWidget {
  const _RevenueWorkspace();
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(children: const [
      TabBar(tabs: [Tab(text: 'Live orders'), Tab(text: 'Local preview')]),
      Expanded(child: TabBarView(children: [
        LiveOrderValuePanel(),
        _RevenuePreview(),
      ])),
    ]),
  );
}
