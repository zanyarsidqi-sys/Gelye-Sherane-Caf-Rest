import 'package:flutter/material.dart';
import '../shared/section_shell.dart';
import '../shared/maintenance_workspace_panel.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: "Maintenance",
    description: "Equipment and service requests",
    sectionId: "maintenance",
    authorizedContent: MaintenanceWorkspacePanel(),
  );
}
