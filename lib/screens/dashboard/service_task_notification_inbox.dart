import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'table_service_tasks_panel.dart';

/// Recipient-scoped in-app notifications. Backend enforces recipient isolation.
class ServiceTaskNotificationInbox extends StatefulWidget {
  const ServiceTaskNotificationInbox({super.key});
  @override
  State<ServiceTaskNotificationInbox> createState() => _ServiceTaskNotificationInboxState();
}

class _ServiceTaskNotificationInboxState extends State<ServiceTaskNotificationInbox> {
  late Future<List<Map<String, dynamic>>> _items = _load();
  bool _unreadOnly = false;
  bool _updating = false;


  Future<List<Map<String, dynamic>>> _load() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      throw StateError('Employee login required');
    }
    final result = await Supabase.instance.client.rpc(
      'gs_my_service_task_notifications', params: {'p_limit': 100});
    return (result as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  void _refresh() => setState(() => _items = _load());

  Future<void> _openNotification(Map<String, dynamic> item) async {
    if (_updating) return;
    final id = item['id'];
    if (item['read_at'] == null && id is int) {
      setState(() => _updating = true);
      try {
        await Supabase.instance.client.rpc(
          'gs_mark_service_notification_read', params: {'p_notification_id': id});
        if (!mounted) return;
        _refresh();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not mark notification as read. Server may not be deployed.')));
      } finally {
        if (mounted) setState(() => _updating = false);
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const TableServiceTasksPanel()));
    if (mounted) _refresh();
  }


  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Service Notifications'), actions: [
      IconButton(tooltip: 'Refresh', onPressed: _refresh,
        icon: const Icon(Icons.refresh)),
    ]),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Padding(
          padding: EdgeInsets.all(20), child: Text(
          'Notifications unavailable. Server permissions or migration may not be ready.')));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!;
        if (items.isEmpty) return const Center(child: Text('No service notifications.'));
        final unread = items.where((item) => item['read_at'] == null).length;
        final visible = _unreadOnly
          ? items.where((item) => item['read_at'] == null).toList()
          : items;

        return Column(children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Expanded(child: Text('$unread unread · ${items.length} recent notifications')),
              FilterChip(label: const Text('Unread only'), selected: _unreadOnly,
                onSelected: (value) => setState(() => _unreadOnly = value)),
            ])),
          Expanded(child: RefreshIndicator(onRefresh: () async { _refresh(); await _items; },
          child: visible.isEmpty
            ? ListView(children: const [SizedBox(height: 100),
                Center(child: Text('No unread notifications.'))])
            : ListView.builder(itemCount: visible.length, itemBuilder: (context, index) {
            final item = visible[index];
            final event = '${item['event_type'] ?? 'updated'}';
            final task = '${item['task_id'] ?? '—'}';
            final date = '${item['created_at'] ?? '—'}';
            return ListTile(
              leading: Icon(item['read_at'] == null
                ? Icons.notifications_active_outlined : Icons.notifications_none),
              title: Text('Service task #$task · ${event.replaceAll('_', ' ')}'),
              subtitle: Text(date),
              trailing: const Icon(Icons.chevron_right),
              onTap: _updating ? null : () => _openNotification(item),
            );
          }))),
        ]);
      },
    ),
  );
}
