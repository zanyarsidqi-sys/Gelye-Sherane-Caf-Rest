import 'package:flutter/material.dart';
import '../shared/section_shell.dart';
import '../shared/app_publishing_panel.dart';

class AppPublishingUpdatesScreen extends StatelessWidget {
  const AppPublishingUpdatesScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: "App Publishing & Updates",
    description: "Release versions and updates",
    sectionId: "app_publishing_updates",
    authorizedContent: AppPublishingPanel(),
  );
}
