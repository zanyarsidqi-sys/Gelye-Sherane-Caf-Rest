import 'package:flutter/material.dart';
import '../shared/section_shell.dart';

class InvoiceDesignCustomizationScreen extends StatelessWidget {
  const InvoiceDesignCustomizationScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: "Invoice Design & Customization",
    description: "Receipt and invoice templates",
    sectionId: "invoice_design_customization",
  );
}
