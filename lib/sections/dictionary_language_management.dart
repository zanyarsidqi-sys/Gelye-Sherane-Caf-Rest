import 'package:flutter/material.dart';
import '../shared/section_shell.dart';

class DictionaryLanguageManagementScreen extends StatelessWidget {
  const DictionaryLanguageManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: "Dictionary & Language Management",
    description: "Translations and terminology",
    sectionId: "dictionary_language_management",
  );
}
