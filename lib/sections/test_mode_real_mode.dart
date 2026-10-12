import 'package:flutter/material.dart';
import '../shared/section_shell.dart';

class TestModeRealModeScreen extends StatelessWidget {
  const TestModeRealModeScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: "Test Mode / Real Mode",
    description: "Environment isolation",
    sectionId: "test_mode_real_mode",
  );
}
