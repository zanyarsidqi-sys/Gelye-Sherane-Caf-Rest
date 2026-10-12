import 'package:flutter/material.dart';
import '../shared/section_shell.dart';

class SecurityAccessControlScreen extends StatelessWidget {
  const SecurityAccessControlScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: "Security & Access Control",
    description: "Role permissions and security policies",
    sectionId: "security_access_control",
  );
}
