import 'package:flutter/material.dart';

import '../shared/section_shell.dart';
import 'cost.dart';
import 'credit_management.dart';
import 'discount_management.dart';
import 'invoices_payments.dart';
import 'revenue.dart';
import '../shared/payments_reconciliation_screen.dart';

/// One visible finance workspace. Each area below still checks its own
/// employee permission before rendering its existing content.
class PaymentsManagementScreen extends StatelessWidget {
  const PaymentsManagementScreen({
    super.key,
    this.initialTabIndex = 0,
    this.initialFocus,
  });

  final int initialTabIndex;
  final String? initialFocus;

  static const financeAreaSectionIds = <String>{
    'cost',
    'revenue',
    'invoices_payments',
    'discount_management',
    'credit_management',
  };

  static int tabIndexForSectionId(String sectionId) => switch (sectionId) {
        'cost' => 1,
        'revenue' => 2,
        'invoices_payments' => 3,
        'discount_management' => 4,
        'credit_management' => 5,
        'payments_management' => 6,
        _ => 0,
      };

  @override
  Widget build(BuildContext context) => SectionShell(
        title: 'Payment Management',
        description:
            'Cost, revenue, invoices, discounts, customer credit and payment reconciliation',
        sectionId: 'payments_management',
        additionalAccessSectionIds: const [
          'cost',
          'revenue',
          'invoices_payments',
          'discount_management',
          'credit_management',
        ],
        authorizedContent: _PaymentManagementWorkspace(
          initialTabIndex: initialFocus == null
              ? initialTabIndex
              : tabIndexForSectionId('payments_management'),
          initialFocus: initialFocus,
        ),
      );
}

class _PaymentManagementWorkspace extends StatelessWidget {
  const _PaymentManagementWorkspace({
    required this.initialTabIndex,
    this.initialFocus,
  });

  final int initialTabIndex;
  final String? initialFocus;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 7,
        initialIndex: initialTabIndex.clamp(0, 6).toInt(),
        child: Builder(
          builder: (context) {
            final controller = DefaultTabController.of(context);
            return Column(
              children: [
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: const [
                      Tab(text: 'Overview', icon: Icon(Icons.grid_view_rounded)),
                      Tab(text: 'Cost', icon: Icon(Icons.request_quote_outlined)),
                      Tab(text: 'Revenue', icon: Icon(Icons.trending_up_rounded)),
                      Tab(text: 'Invoices', icon: Icon(Icons.receipt_long_outlined)),
                      Tab(text: 'Discounts', icon: Icon(Icons.local_offer_outlined)),
                      Tab(text: 'Credit', icon: Icon(Icons.credit_card_outlined)),
                      Tab(text: 'Payments', icon: Icon(Icons.payments_outlined)),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _FinanceOverview(
                        onOpenArea: (index) => controller.animateTo(index),
                      ),
                      const CostScreen(compact: true),
                      const RevenueScreen(compact: true),
                      const InvoicesPaymentsScreen(compact: true),
                      const DiscountManagementScreen(compact: true),
                      const CreditManagementScreen(compact: true),
                      PaymentsReconciliationScreen(
                        compact: true,
                        initialFocus: initialFocus,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class _FinanceOverview extends StatelessWidget {
  const _FinanceOverview({required this.onOpenArea});

  final ValueChanged<int> onOpenArea;

  static const _areas = <_FinanceArea>[
    _FinanceArea(
      'Cost management',
      'Plan operating costs and review expense workflows.',
      Icons.request_quote_outlined,
      1,
    ),
    _FinanceArea(
      'Revenue management',
      'Review verified order-value and revenue sources.',
      Icons.trending_up_rounded,
      2,
    ),
    _FinanceArea(
      'Invoices & payments',
      'Review invoices, payment preparation and handoffs.',
      Icons.receipt_long_outlined,
      3,
    ),
    _FinanceArea(
      'Discount management',
      'Preview discount rules without changing order totals.',
      Icons.local_offer_outlined,
      4,
    ),
    _FinanceArea(
      'Credit management',
      'Review customer credit identity and account workflows.',
      Icons.credit_card_outlined,
      5,
    ),
    _FinanceArea(
      'Payment management',
      'Inspect authorized settlement and reconciliation records.',
      Icons.payments_outlined,
      6,
    ),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900
              ? 3
              : constraints.maxWidth >= 520
                  ? 2
                  : 1;
          const spacing = 12.0;
          final cardWidth =
              (constraints.maxWidth - (spacing * (columns - 1))) / columns;
          final colors = Theme.of(context).colorScheme;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: colors.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 34,
                          color: colors.onPrimaryContainer,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'All financial areas in one place',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Open a module below. Its original employee permission remains in force.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final area in _areas)
                      SizedBox(
                        width: cardWidth,
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => onOpenArea(area.tabIndex),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: colors.secondaryContainer,
                                    foregroundColor:
                                        colors.onSecondaryContainer,
                                    child: Icon(area.icon),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          area.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          area.description,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded,
                                      size: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.verified_outlined),
                    title: const Text('Verified financial data only'),
                    subtitle: const Text(
                      'The sample amounts and charts in the design reference are not used. Totals appear only when an authorized, verified source provides them.',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _FinanceArea {
  const _FinanceArea(this.title, this.description, this.icon, this.tabIndex);

  final String title;
  final String description;
  final IconData icon;
  final int tabIndex;
}
