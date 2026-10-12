import 'package:flutter/material.dart';
import '../shared/section_shell.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: "Analytics",
    description: "Trends and performance",
    sectionId: "analytics",
  );
}
