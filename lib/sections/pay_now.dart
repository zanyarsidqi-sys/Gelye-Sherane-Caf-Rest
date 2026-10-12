import 'package:flutter/material.dart';
import '../shared/section_shell.dart';
import '../shared/payment_preparation_panel.dart';

class PayNowScreen extends StatelessWidget {
  const PayNowScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: "Pay Now",
    description: "Payment collection workflow",
    sectionId: "pay_now",
    authorizedContent: PaymentPreparationPanel(),
  );
}
