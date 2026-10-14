import 'package:flutter/material.dart';

import 'payments_management_panel.dart';
import 'section_shell.dart';

/// Guarded payment-reconciliation detail used by other finance areas.
/// Keeping this separate prevents nested links from reopening the full hub.
class PaymentsReconciliationScreen extends StatelessWidget {
  const PaymentsReconciliationScreen({
    super.key,
    this.initialFocus,
    this.compact = false,
  });

  final String? initialFocus;
  final bool compact;

  @override
  Widget build(BuildContext context) => SectionShell(
        title: 'Payment Management',
        description: 'Settlement and payment reconciliation',
        sectionId: 'payments_management',
        compact: compact,
        authorizedContent:
            PaymentsManagementPanel(initialFocus: initialFocus),
      );
}
