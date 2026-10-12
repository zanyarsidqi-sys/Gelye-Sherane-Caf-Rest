import 'package:flutter/material.dart';
import '../shared/section_shell.dart';

class NargileManagementScreen extends StatelessWidget {
  const NargileManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: "Nargile Management",
    description: "Shisha orders, supplies and safety",
    sectionId: "nargile_management",
  );
}
