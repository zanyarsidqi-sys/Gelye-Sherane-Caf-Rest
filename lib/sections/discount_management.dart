import 'package:flutter/material.dart';
import '../shared/section_shell.dart';
import '../shared/discount_planner_panel.dart';

class DiscountManagementScreen extends StatelessWidget {
  const DiscountManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: "Discount Management",
    description: "Discount rules and approvals",
    sectionId: "discount_management",
    authorizedContent: DiscountPlannerPanel(),
  );
}
