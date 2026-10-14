import 'package:flutter/material.dart';
import '../shared/section_shell.dart';
import '../shared/payment_preparation_panel.dart';
import '../shared/motel_food_finance_handoff_panel.dart';
import '../shared/payments_reconciliation_screen.dart';

/// Shared finance review. Neither panel posts payment by simply being viewed.
class InvoicesPaymentsScreen extends StatelessWidget {
  const InvoicesPaymentsScreen({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => SectionShell(
        title: 'Invoices & Payments',
        description: 'Finance review',
        sectionId: 'invoices_payments',
        compact: compact,
        authorizedContent:
            _InvoicesPaymentsScreenContent(compact: compact),
      );
}

class _InvoicesPaymentsScreenContent extends StatelessWidget {
  const _InvoicesPaymentsScreenContent({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Cross-section review: Standing Cash reflects authorized active-table cash-only balances; Pending Payment lists posted motel invoice sources and read-only settlement evidence. These are not verified all-method outstanding totals. Review source orders, allocations and Cash Reconciliation before collecting payments.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const TabBar(
              tabs: [
                Tab(text: 'Payment Review'),
                Tab(text: 'Motel Food Handoff'),
                Tab(text: 'Standing Cash'),
                Tab(text: 'Pending Payment'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  const PaymentPreparationPanel(),
                  const SingleChildScrollView(
                      child: MotelFoodFinanceHandoffPanel()),
                  const PaymentsReconciliationScreen(
                      compact: true, initialFocus: 'standing'),
                  const PaymentsReconciliationScreen(
                      compact: true, initialFocus: 'pending'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (compact) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Invoices & Payments')),
      body: body,
    );
  }
}
