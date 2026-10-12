import 'package:flutter/material.dart';
import '../shared/section_shell.dart';
import '../shared/payments_management_panel.dart';

/// Reconciliation review only; no unverified financial transactions are posted.
class PaymentsManagementScreen extends StatelessWidget {
  const PaymentsManagementScreen({super.key, this.initialFocus});
  final String? initialFocus;

  @override
  Widget build(BuildContext context) => SectionShell(
    title: 'Payments Management',
    description: 'Authorized Standing Cash collection and read-only Pending Payment reconciliation; source totals may be capped',
    sectionId: 'payments_management',
    authorizedContent: _PaymentsManagementScreenContent(initialFocus: initialFocus),
  );
}

class _PaymentsManagementScreenContent extends StatelessWidget {
  const _PaymentsManagementScreenContent({this.initialFocus});
  final String? initialFocus;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Payments Management')),
    body: SafeArea(child: PaymentsManagementPanel(initialFocus: initialFocus)),
  );
}
