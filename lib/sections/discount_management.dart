import 'package:flutter/material.dart';
import '../shared/section_shell.dart';
import '../shared/discount_planner_panel.dart';

class DiscountManagementScreen extends StatelessWidget {
  const DiscountManagementScreen({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => SectionShell(
        title: "Discount Management",
        description: "Discount rules and approvals",
        sectionId: "discount_management",
        compact: compact,
        authorizedContent: const DiscountPlannerPanel(),
      );
}
