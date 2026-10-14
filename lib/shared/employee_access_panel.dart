import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/employee_permission_service.dart';

/// Read-only view of the signed-in employee's own profile and section grants.
/// Database RLS remains responsible for protecting the underlying records.
class EmployeeAccessPanel extends StatefulWidget {
  const EmployeeAccessPanel({super.key});

  @override
  State<EmployeeAccessPanel> createState() => _EmployeeAccessPanelState();
}

class _EmployeeAccessPanelState extends State<EmployeeAccessPanel> {
  late Future<_EmployeeAccessData> _future = _load();

  Future<_EmployeeAccessData> _load() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw StateError('Sign in to view your employee access.');
    }
    final service = EmployeePermissionService();
    final profile = await service.getActiveEmployee();
    if (profile == null) {
      throw StateError('No active employee profile is available.');
    }
    final permissions = await service.getSectionPermissions();
    return _EmployeeAccessData(profile, permissions);
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_EmployeeAccessData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Unable to load employee access: ${snapshot.error}'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          );
        }
        final data = snapshot.data!;
        const financeAreaIds = <String>{
          'cost',
          'revenue',
          'invoices_payments',
          'discount_management',
          'credit_management',
          'payments_management',
        };
        const kitchenAreaIds = <String>{
          'kitchen',
          'nargile_management',
          'menu',
          'products_inventory',
        };
        final tableGrant = data.permissions['tables'];
        final orderGrant = data.permissions['table_orders'];
        final showTables = tableGrant?.canView == true ||
            orderGrant?.canView == true;
        final kitchenGrants = data.permissions.entries
            .where((entry) =>
                entry.value.canView && kitchenAreaIds.contains(entry.key))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        final financeGrants = data.permissions.entries
            .where((entry) =>
                entry.value.canView && financeAreaIds.contains(entry.key))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        final grants = data.permissions.entries
            .where((entry) =>
                entry.value.canView &&
                entry.key != 'tables' &&
                entry.key != 'table_orders' &&
                !kitchenAreaIds.contains(entry.key) &&
                !financeAreaIds.contains(entry.key))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        final sectionCount = grants.length +
            (showTables ? 1 : 0) +
            (kitchenGrants.isNotEmpty ? 1 : 0) +
            (financeGrants.isNotEmpty ? 1 : 0);
        String permissionSummary(SectionPermission? permission) {
          if (permission == null || !permission.canView) return 'No access';
          return [
            'View',
            if (permission.canCreate) 'Create',
            if (permission.canEdit) 'Edit',
            if (permission.canDelete) 'Delete',
          ].join(' · ');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My employee profile',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Name: ${data.profile['full_name'] ?? 'Not set'}'),
                    Text('Role: ${data.profile['role'] ?? 'Not set'}'),
                    const SizedBox(height: 4),
                    const Text('Access shown below is read-only.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('My authorized sections ($sectionCount)',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: 'Refresh permissions',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (grants.isEmpty &&
                !showTables &&
                kitchenGrants.isEmpty &&
                financeGrants.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No section permissions are assigned.'),
              ),
            for (final grant in grants)
              Card(
                child: ListTile(
                  title: Text(grant.key.replaceAll('_', ' ')),
                  subtitle: Text([
                    'View',
                    if (grant.value.canCreate) 'Create',
                    if (grant.value.canEdit) 'Edit',
                    if (grant.value.canDelete) 'Delete',
                  ].join(' · ')),
                  leading: const Icon(Icons.verified_user_outlined),
                ),
              ),
            if (kitchenGrants.isNotEmpty)
              Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.soup_kitchen_outlined),
                  title: const Text('Kitchen'),
                  subtitle:
                      Text('${kitchenGrants.length} authorized module(s)'),
                  children: [
                    for (final grant in kitchenGrants)
                      ListTile(
                        dense: true,
                        title: Text(grant.key.replaceAll('_', ' ')),
                        subtitle: Text(permissionSummary(grant.value)),
                        leading:
                            const Icon(Icons.verified_user_outlined, size: 20),
                      ),
                  ],
                ),
              ),
            if (financeGrants.isNotEmpty)
              Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Payment Management'),
                  subtitle: Text(
                      '${financeGrants.length} authorized finance area(s)'),
                  children: [
                    for (final grant in financeGrants)
                      ListTile(
                        dense: true,
                        title: Text(grant.key.replaceAll('_', ' ')),
                        subtitle: Text(permissionSummary(grant.value)),
                        leading:
                            const Icon(Icons.verified_user_outlined, size: 20),
                      ),
                  ],
                ),
              ),
            if (showTables)
              Card(
                child: ListTile(
                  title: const Text('Tables'),
                  subtitle: Text(
                    'Floor map & seating: ${permissionSummary(tableGrant)}\n'
                    'Live orders: ${permissionSummary(orderGrant)}',
                  ),
                  leading: const Icon(Icons.verified_user_outlined),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EmployeeAccessData {
  final Map<String, dynamic> profile;
  final Map<String, SectionPermission> permissions;
  const _EmployeeAccessData(this.profile, this.permissions);
}
