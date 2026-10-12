import 'package:flutter/material.dart';
import '../shared/section_shell.dart';

class GeneralInformationScreen extends StatelessWidget {
  const GeneralInformationScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: "General Information",
    description: "Business information and contacts",
    sectionId: "general_information",
  );
}
