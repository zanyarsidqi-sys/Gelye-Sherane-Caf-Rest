import 'package:flutter/material.dart';
import '../shared/section_shell.dart';

class SettingsRulesScreen extends StatelessWidget {
  const SettingsRulesScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: "Settings & Rules",
    description: "Operational rules and defaults",
    sectionId: "settings_rules",
  );
}
