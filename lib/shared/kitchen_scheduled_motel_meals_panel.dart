import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Kitchen preparation controls for scheduled motel meals. These are not
/// gs_orders tickets and cannot be billed or dispatched for delivery here.
class KitchenScheduledMotelMealsPanel extends StatefulWidget {
  const KitchenScheduledMotelMealsPanel({super.key});
  @override
  State<KitchenScheduledMotelMealsPanel> createState() => _KitchenScheduledMotelMealsPanelState();
}

class _KitchenScheduledMotelMealsPanelState extends State<KitchenScheduledMotelMealsPanel> {
  late Future<List<Map<String, dynamic>>> _future = _load();
  late final StreamSubscription<AuthState> _authSubscription;
  String? _employeeId;
  int _sessionRevision = 0;

  @override
  void initState() {
    super.initState();
    _employeeId = Supabase.instance.client.auth.currentUser?.id;
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      final currentId = Supabase.instance.client.auth.currentUser?.id;
      if (!mounted || currentId == _employeeId) return;
      setState(() {
        _employeeId = currentId;
        _sessionRevision++;
        _busy.clear();
        _future = currentId == null ? Future.value(<Map<String, dynamic>>[]) : _load();
      });
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final result = await Supabase.instance.client.rpc('gs_kitchen_list_motel_scheduled_meals');
    return (result as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  final Set<String> _busy = {};
  void _refresh() {
    if (!mounted) return;
    setState(() => _future = _employeeId == null
        ? Future.value(<Map<String, dynamic>>[]) : _load());
  }

  Future<void> _advance(String id, String nextStatus) async {
    if (_busy.contains(id) || _employeeId == null) return;
    final employeeAtStart = _employeeId;
    final revisionAtStart = _sessionRevision;
    setState(() => _busy.add(id));
    try {
      await Supabase.instance.client.rpc(
        'gs_kitchen_progress_motel_scheduled_meal',
        params: {'p_meal_id': id, 'p_next_status': nextStatus},
      );
      if (mounted && _employeeId == employeeAtStart && _sessionRevision == revisionAtStart) _refresh();
    } catch (_) {
      if (mounted && _employeeId == employeeAtStart && _sessionRevision == revisionAtStart) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update meal. Check permission and current status.')),
        );
      }
    } finally {
      if (mounted && _employeeId == employeeAtStart && _sessionRevision == revisionAtStart) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => _employeeId == null
      ? const Center(child: Text('Sign in to view scheduled motel meals.'))
      : Column(children: [
    ListTile(
      title: const Text('Scheduled motel meals'),
      subtitle: const Text('Kitchen can mark meals Preparing or Ready. No room charges or delivery dispatch.'),
      trailing: IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh scheduled meals'),
    ),
    Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Unable to load scheduled meals. Check Kitchen permissions and migrations.'),
            TextButton(onPressed: _refresh, child: const Text('Retry')),
          ]));
        }
        final meals = snapshot.data ?? [];
        if (meals.isEmpty) return const Center(child: Text('No confirmed scheduled motel meals.'));
        return ListView.builder(itemCount: meals.length, itemBuilder: (context, index) {
          final meal = meals[index];
          final due = DateTime.tryParse(meal['requested_for']?.toString() ?? '')?.toLocal();
          final status = (meal['status'] ?? '').toString();
          final id = (meal['id'] ?? '').toString();
          final nextStatus = (status == 'confirmed' || status == 'scheduled')
              ? 'preparing' : (status == 'preparing' ? 'ready' : null);
          return Card(child: ListTile(minVerticalPadding: 16,
            title: Text('${meal['room_label'] ?? ''} — ${meal['room_name'] ?? ''}'),
            subtitle: Text('${meal['meal_description'] ?? ''}\nRequested: ${due ?? 'Unknown'}'),
            isThreeLine: true,
            trailing: Column(mainAxisSize: MainAxisSize.min, children: [
              Chip(label: Text(status.replaceAll('_', ' '))),
              if (nextStatus != null)
                TextButton(
                  onPressed: id.isEmpty || _busy.contains(id)
                      ? null : () => _advance(id, nextStatus),
                  child: Text(nextStatus == 'preparing' ? 'Start preparing' : 'Mark ready'),
                ),
            ]),
          ));
        });
      },
    )),
  ]);
}
