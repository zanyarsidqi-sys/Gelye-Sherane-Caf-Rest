import 'package:flutter/material.dart';
import 'payments_management.dart';
import '../shared/credit_barcode_panel.dart';
import '../shared/credit_account_registration_panel.dart';
import '../shared/credit_identity_review_panel.dart';
import '../shared/credit_identity_onboarding_panel.dart';
import '../shared/section_shell.dart';

class CreditManagementScreen extends StatelessWidget {
  const CreditManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => SectionShell(
    title: 'Credit Management',
    description: 'Customer credit and settlements',
    sectionId: 'credit_management',
    authorizedContent: ListView(children: [
      const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Credit account identity and debit requests do not prove a collected payment. Confirmed credit allocation must be reconciled to its original order and must not be added to cash receipt totals. Review the originating order and confirmed allocation before treating credit as settled. Standing Cash is cash-only; Pending Payment remains read-only until all-method settlement is verified.'),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(spacing: 8, children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Review Standing Cash'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const PaymentsManagementScreen(initialFocus: 'standing'),
            )),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Inspect Pending Payment'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const PaymentsManagementScreen(initialFocus: 'pending'),
            )),
          ),
        ]),
      ),
      CreditAccountRegistrationPanel(),
      CreditIdentityReviewPanel(),
      CreditIdentityOnboardingPanel(),
      CreditBarcodePanel(),
    ]),
  );
}
