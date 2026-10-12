import 'package:flutter/material.dart';
import '../shared/section_shell.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: "Reports",
    description: "Operational and financial reports",
    sectionId: "reports",
  );
}
