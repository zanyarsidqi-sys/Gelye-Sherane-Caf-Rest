import 'package:flutter/material.dart';

/// Backup preparation only. Never claims that a backup exists or is restorable.
class BackupReadinessPanel extends StatefulWidget {
  const BackupReadinessPanel({super.key});

  @override
  State<BackupReadinessPanel> createState() => _BackupReadinessPanelState();
}

class _BackupReadinessPanelState extends State<BackupReadinessPanel> {
  final Set<int> _reviewed = <int>{};
  static const _items = <(String, String)>[
    ('Confirm provider backups', 'Check Supabase Dashboard backup availability and retention for your plan.'),
    ('Export database safely', 'Use an administrator-approved backup process outside this app.'),
    ('Protect backup files', 'Store encrypted copies with restricted access, separate from production.'),
    ('Record recovery information', 'Document backup time, schema version, and responsible administrator.'),
    ('Test recovery separately', 'Restore to an isolated test project, never directly over production.'),
    ('Verify recovered records', 'Check products, orders, order items, employee permissions, and RLS.'),
  ];

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Backup & recovery readiness',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Backup status: Not verified. This app does not create, download, or restore Supabase backups.'),
            const SizedBox(height: 8),
            Text('Review checklist: ${_reviewed.length}/${_items.length}',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (var i = 0; i < _items.length; i++)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _reviewed.contains(i),
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    _reviewed.add(i);
                  } else {
                    _reviewed.remove(i);
                  }
                }),
                title: Text(_items[i].$1),
                subtitle: Text(_items[i].$2),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => setState(_reviewed.clear),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset review checklist'),
            ),
            const SizedBox(height: 8),
            const Text('Checklist selections are temporary and do not certify a backup. Only a verified restore test can establish recoverability.'),
          ],
        ),
      );
}
