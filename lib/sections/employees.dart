import 'package:flutter/material.dart';
import '../shared/section_shell.dart';
import '../shared/employee_access_panel.dart';

class EmployeesScreen extends StatelessWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: "Employees",
    description: "Staff, attendance and roles",
    sectionId: "employees",
    authorizedContent: EmployeeAccessPanel(),
  );
}
