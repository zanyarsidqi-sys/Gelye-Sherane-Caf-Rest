import 'package:flutter/material.dart';
import '../shared/section_shell.dart';
import '../shared/backup_readiness_panel.dart';

class BackupRestoreScreen extends StatelessWidget {
  const BackupRestoreScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: 'Backup & Restore',
    description: 'Read-only recovery planning and backup verification checklist',
    sectionId: 'backup_restore',
    authorizedContent: BackupReadinessPanel(),
  );
}
