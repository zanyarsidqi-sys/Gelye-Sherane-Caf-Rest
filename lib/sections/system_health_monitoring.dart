import 'package:flutter/material.dart';
import '../shared/section_shell.dart';
import '../shared/system_health_panel.dart';

class SystemHealthMonitoringScreen extends StatelessWidget {
  const SystemHealthMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: 'System Health & Monitoring',
    description: 'Read-only authentication and database diagnostics',
    sectionId: 'system_health_monitoring',
    authorizedContent: SystemHealthPanel(),
  );
}
