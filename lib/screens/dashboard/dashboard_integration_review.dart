import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Non-mutating RPC smoke check. Success means read endpoint responded,
/// NOT that billing, authorization or real-time workflows passed tests.
class DashboardIntegrationReview extends StatefulWidget {
  const DashboardIntegrationReview({super.key});
  @override
  State<DashboardIntegrationReview> createState() => _DashboardIntegrationReviewState();
}

class _DashboardIntegrationReviewState extends State<DashboardIntegrationReview> {
  bool _running = false;
  Map<String, String> _results = const {};
  final _checks = const <String, String>{
    'Table service tasks': 'gs_dashboard_table_service_tasks',
    'Employee directory': 'gs_service_assignable_employees',
    'My notifications': 'gs_my_service_task_notifications',
    'Motel meal offers': 'gs_dashboard_motel_meal_offers',
    'Owner guest offers': 'gs_dashboard_owner_guest_offers',
  };

  Future<void> _runChecks() async {
    if (_running) return;
    setState(() { _running = true; _results = {}; });
    final results = <String, String>{};
    for (final entry in _checks.entries) {
      try {
        final params = switch (entry.value) {
          'gs_dashboard_table_service_tasks' => <String, dynamic>{'p_table_id': null},
          'gs_my_service_task_notifications' => <String, dynamic>{'p_limit': 1},
          'gs_dashboard_motel_meal_offers' => <String, dynamic>{'p_filter': 'upcoming'},
          _ => <String, dynamic>{},
        };
        await Supabase.instance.client.rpc(entry.value, params: params);
        results[entry.key] = 'Read endpoint responded (not a functional test)';
      } catch (_) {
        // Avoid showing raw server errors, SQL or access-control details.
        results[entry.key] = 'Unavailable or access denied';
      }
      if (!mounted) return;
      setState(() => _results = Map.of(results));
    }
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dashboard Integration Review')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Read-only backend connectivity check',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Results reflect your current employee permissions. A response does '
        'not confirm production readiness, payment integrity or workflow correctness.'),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: _running ? null : _runChecks,
        icon: const Icon(Icons.fact_check_outlined),
        label: Text(_running ? 'Checking…' : 'Run read-only checks')),
      const SizedBox(height: 12),
      for (final check in _checks.keys) ListTile(
        title: Text(check),
        subtitle: Text(_results[check] ?? 'Not checked'),
        leading: Icon(_results[check]?.startsWith('Read endpoint') == true
          ? Icons.check_circle_outline : Icons.info_outline),
      ),
      const Divider(),
      const Text('Blocking issues before deployment:',
        style: TextStyle(fontWeight: FontWeight.bold)),
      const Text('• Match every draft SQL migration to the actual schema and role names.\n'
        '• Link table orders and cleaning to a unique visit/session, not table number alone.\n'
        '• Verify cash, card, online, and credit settlements from authoritative ledgers.\n'
        '• Require authenticated owner approval before any complimentary adjustment.\n'
        '• Resolve motel reservation barcode server-side and verify meal entitlement.\n'
        '• Add audited actions, concurrency tests, and offline sync conflict handling.\n'
        '• Compile Flutter and test on iPhone and Windows.'),
    ]),
  );
}
