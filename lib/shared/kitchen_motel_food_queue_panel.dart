import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Kitchen preparation controls for accepted motel requests; not billing tickets.
class KitchenMotelFoodQueuePanel extends StatefulWidget {
  const KitchenMotelFoodQueuePanel({super.key});
  @override
  State<KitchenMotelFoodQueuePanel> createState() => _KitchenMotelFoodQueuePanelState();
}

class _KitchenMotelFoodQueuePanelState extends State<KitchenMotelFoodQueuePanel> {
  late Future<List<Map<String, dynamic>>> _requests;
  late final StreamSubscription<AuthState> _authSubscription;
  String? _employeeId;
  int _sessionRevision = 0;

  @override
  void initState() {
    super.initState();
    _employeeId = Supabase.instance.client.auth.currentUser?.id;
    _requests = _employeeId == null
        ? Future.value(<Map<String, dynamic>>[]) : _load();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      final currentId = Supabase.instance.client.auth.currentUser?.id;
      if (!mounted || currentId == _employeeId) return;
      setState(() {
        _employeeId = currentId;
        _sessionRevision++;
        _saving = false;
        _requests = currentId == null
            ? Future.value(<Map<String, dynamic>>[]) : _load();
      });
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final data = await Supabase.instance.client.rpc('gs_kitchen_list_accepted_motel_food');
    return (data as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  bool _saving = false;
  void _refresh() {
    if (!mounted) return;
    setState(() => _requests = _employeeId == null
        ? Future.value(<Map<String, dynamic>>[]) : _load());
  }

  Future<void> _advance(String id, String action) async {
    if (_saving || _employeeId == null) return;
    final employeeAtStart = _employeeId;
    final revisionAtStart = _sessionRevision;
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.rpc('gs_kitchen_advance_motel_food', params: {
        'p_request_id': id, 'p_action': action,
      });
      if (mounted && _employeeId == employeeAtStart && _sessionRevision == revisionAtStart) _refresh();
    } catch (_) {
      if (mounted && _employeeId == employeeAtStart && _sessionRevision == revisionAtStart) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update order. Check permission and status.')),
      );
    } finally {
      if (mounted && _employeeId == employeeAtStart && _sessionRevision == revisionAtStart) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _employeeId == null
      ? const Center(child: Text('Sign in to view motel food requests.'))
      : Column(children: [
    ListTile(
      title: const Text('Accepted motel food requests'),
      subtitle: const Text('Start preparing and mark ready here. Delivery and billing are separate.'),
      trailing: IconButton(onPressed: _refresh, tooltip: 'Refresh requests', icon: const Icon(Icons.refresh)),
    ),
    Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _requests,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Unable to load motel food requests. Check permissions and migrations.'),
            TextButton(onPressed: _refresh, child: const Text('Retry')),
          ]));
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) return const Center(child: Text('No accepted motel food requests.'));
        return ListView.builder(itemCount: requests.length, itemBuilder: (context, index) {
          final order = requests[index];
          final rawItems = order['items'];
          final items = rawItems is List ? rawItems : <dynamic>[];
          final description = items.map((item) {
            final line = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
            return '${line['quantity'] ?? 0} × ${line['name'] ?? 'Product'}';
          }).join('\n');
          final status = order['status']?.toString() ?? '';
          final action = status == 'accepted' ? 'start_preparing' : status == 'preparing' ? 'mark_ready' : null;
          return Card(child: ListTile(
            title: Text('${order['room_label'] ?? ''} — ${order['room_name'] ?? ''}'),
            subtitle: Text(description),
            isThreeLine: items.length > 1,
            trailing: Column(mainAxisSize: MainAxisSize.min, children: [
              Chip(label: Text(status)),
              if (action != null) TextButton(
                onPressed: _saving || order['id'] == null ? null : () => _advance(order['id'].toString(), action),
                child: Text(status == 'accepted' ? 'Start Preparing' : 'Mark Ready'),
              ),
              Text('${order['total_iqd'] ?? 0} IQD'),
            ]),
          ));
        });
      },
    )),
  ]);
}
