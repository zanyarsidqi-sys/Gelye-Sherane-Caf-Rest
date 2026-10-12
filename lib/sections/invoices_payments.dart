import 'package:flutter/material.dart';
import '../shared/section_shell.dart';
import '../shared/payment_preparation_panel.dart';
import '../shared/motel_food_finance_handoff_panel.dart';
import 'payments_management.dart';

/// Shared finance review. Neither panel posts payment by simply being viewed.
class InvoicesPaymentsScreen extends StatelessWidget {
  const InvoicesPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: 'Invoices & Payments',
    description: 'Finance review',
    sectionId: 'invoices_payments',
    authorizedContent: _InvoicesPaymentsScreenContent(),
  );
}

class _InvoicesPaymentsScreenContent extends StatelessWidget {
  const _InvoicesPaymentsScreenContent();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Invoices & Payments')),
    body: const SafeArea(child: DefaultTabController(
      length: 4,
      child: Column(children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            'Cross-section review: Standing Cash reflects authorized active-table cash-only balances; Pending Payment lists posted motel invoice sources and read-only settlement evidence. These are not verified all-method outstanding totals. Review source orders, allocations and Cash Reconciliation before collecting payments.',
            style: TextStyle(fontSize: 12),
          ),
        ),
        TabBar(tabs: [Tab(text: 'Payment Review'), Tab(text: 'Motel Food Handoff'), Tab(text: 'Standing Cash'), Tab(text: 'Pending Payment')]),
        Expanded(child: TabBarView(children: [
          PaymentPreparationPanel(),
          SingleChildScrollView(child: MotelFoodFinanceHandoffPanel()),
          PaymentsManagementScreen(initialFocus: 'standing'),
          PaymentsManagementScreen(initialFocus: 'pending'),
        ])),
      ]),
    )),
  );
}
