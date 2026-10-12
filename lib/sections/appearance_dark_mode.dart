import 'package:flutter/material.dart';
import '../shared/section_shell.dart';

class AppearanceDarkModeScreen extends StatelessWidget {
  const AppearanceDarkModeScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: "Appearance & Dark Mode",
    description: "Visual themes and accessibility",
    sectionId: "appearance_dark_mode",
  );
}
