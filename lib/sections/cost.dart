import 'package:flutter/material.dart';
import '../shared/cost_planning_panel.dart';
import '../shared/section_shell.dart';

class CostScreen extends StatelessWidget {
  const CostScreen({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => SectionShell(
        title: "Cost",
        description: "Expense and purchase records",
        sectionId: "cost",
        compact: compact,
        authorizedContent: compact ? const CostPlanningPanel() : null,
      );
}
