import 'package:flutter/material.dart';
import '../shared/section_shell.dart';

class ActionCenterScreen extends StatelessWidget {
  const ActionCenterScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: "Action Center",
    description: "Approvals and outstanding tasks",
    sectionId: "action_center",
  );
}
