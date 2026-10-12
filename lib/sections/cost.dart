import 'package:flutter/material.dart';
import '../shared/section_shell.dart';

class CostScreen extends StatelessWidget {
  const CostScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: "Cost",
    description: "Expense and purchase records",
    sectionId: "cost",
  );
}
