import 'package:flutter/material.dart';
import '../shared/section_shell.dart';

class NargileManagementScreen extends StatelessWidget {
  const NargileManagementScreen({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => SectionShell(
    title: "Nargile Management",
    description: "Shisha orders, supplies and safety",
    sectionId: "nargile_management",
    compact: compact,
    authorizedContent: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Card(
          child: ListTile(
            leading: Icon(Icons.smoking_rooms_outlined),
            title: Text('Nargile workspace'),
            subtitle: Text(
              'Nargile is grouped under Kitchen. Live order, stock and service controls '
              'will appear here when their verified backend workflows are available.',
            ),
          ),
        ),
      ),
    ),
  );
}
