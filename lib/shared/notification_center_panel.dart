import '../services/browser_push.dart';
import '../services/device_session_preference.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Device-local notification notes. Not a server notification delivery system.
class NotificationCenterPanel extends StatefulWidget {
  const NotificationCenterPanel({super.key});

  @override
  State<NotificationCenterPanel> createState() => _NotificationCenterPanelState();
}

class _NotificationCenterPanelState extends State<NotificationCenterPanel> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  final List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _filter = 'All';
  String _priority = 'Normal';
  bool _pushBusy = false;
  String? _pushMessage;

  String _pushConfig() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) throw StateError('Sign in first');
    final expiry = DeviceSessionPreference.expiresAtMilliseconds;
    return jsonEncode({
      'url': const String.fromEnvironment('SUPABASE_URL'),
      'key': const String.fromEnvironment('SUPABASE_ANON_KEY'),
      'vapid': const String.fromEnvironment('WEB_PUSH_PUBLIC_KEY'),
      'token': session.accessToken,
      'expires': expiry == null ? null : DateTime.fromMillisecondsSinceEpoch(expiry, isUtc: true).toIso8601String(),
    });
  }

  Future<void> _pushAction(String action) async {
    if (_pushBusy) return;
    setState(() => _pushBusy = true);
    try {
      // Invoke enable immediately inside the tap to preserve browser permission gesture.
      final result = action == 'enable' ? await enableBrowserPush(_pushConfig()) :
          action == 'test' ? await testBrowserPush(_pushConfig()) : await disableBrowserPush(_pushConfig());
      if (mounted) setState(() => _pushMessage = result);
    } catch (_) {
      if (mounted) setState(() => _pushMessage =
          'Could not complete notification setup. Check Home Screen installation, notification permission, and push service configuration.');
    } finally {
      if (mounted) setState(() => _pushBusy = false);
    }
  }

  Widget _pushCard() {
    final state = browserPushStatus();
    const configured = String.fromEnvironment('WEB_PUSH_PUBLIC_KEY') != '';
    final available = configured && (state == 'default' || state == 'granted');
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Browser notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('On iPhone: open this website in Safari → Share → Add to Home Screen. Open its new icon, then tap Enable notifications and Allow.'),
        const SizedBox(height: 8),
        Text(!configured ? 'Push service setup is pending.' : state == 'install_required'
            ? 'Install this website on your Home Screen first.' : state == 'denied'
            ? 'Notifications are blocked. Change permission in your device/browser settings.'
            : 'Browser permission: $state'),
        if (_pushMessage != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_pushMessage!)),
        Wrap(spacing: 8, children: [
          FilledButton(onPressed: _pushBusy || !available ? null : () => _pushAction('enable'), child: const Text('Enable notifications')),
          OutlinedButton(onPressed: _pushBusy || !configured || state != 'granted' ? null : () => _pushAction('test'), child: const Text('Send test')),
          TextButton(onPressed: _pushBusy ? null : () => _pushAction('disable'), child: const Text('Turn off')),
        ]),
      ],
    )));
  }

  /// Published release events are server-backed; local reminders are separate.
  Future<List<Map<String, dynamic>>> _releaseHistory() async {
    final rows = await Supabase.instance.client.rpc(
      'gs_my_published_release_history', params: {'p_limit': 10});
    return (rows as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Widget _releaseHistoryCard() => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Published release history', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _releaseHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          }
          if (snapshot.hasError) {
            return const Text('Release history unavailable. Check connection and access.');
          }
          final releases = snapshot.data ?? [];
          if (releases.isEmpty) return const Text('No published releases yet.');
          return Column(children: releases.map((release) => ListTile(
            leading: const Icon(Icons.system_update_alt),
            title: Text('Version ${release['version'] ?? ''}'),
            subtitle: Text('${release['notes'] ?? ''}\nPublished: ${release['published_at'] ?? ''}'),
            isThreeLine: true,
          )).toList());
        },
      ),
    ]),
  ));

  String? get _key {
    final user = Supabase.instance.client.auth.currentUser;
    return user == null ? null : 'cafe_notification_notes_v1_${user.id}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final key = _key;
      if (key != null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(key);
        final data = raw == null ? <dynamic>[] : jsonDecode(raw) as List<dynamic>;
        if (mounted) {
          setState(() {
            _items
              ..clear()
              ..addAll(data.map((e) => Map<String, dynamic>.from(e as Map)));
          });
        }
      }
    } catch (_) {
      // Malformed local data should not prevent the section from opening.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final key = _key;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(_items));
  }

  void _addNote() {
    if (_title.text.trim().isEmpty) return;
    setState(() {
      _items.insert(0, {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'title': _title.text.trim(),
        'message': _message.text.trim(),
        'priority': _priority,
        'read': false,
        'created': DateTime.now().toLocal().toIso8601String(),
      });
    });
    _title.clear();
    _message.clear();
    _save();
    Navigator.of(context).pop();
  }

  void _createDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('New personal reminder'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: _message, maxLines: 3, decoration: const InputDecoration(labelText: 'Details')),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: ['Low', 'Normal', 'High'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (value) => updateDialog(() => _priority = value ?? 'Normal'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: _addNote, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _items.where((item) {
      if (_filter == 'Unread') return item['read'] != true;
      if (_filter == 'Read') return item['read'] == true;
      if (_filter == 'High') return item['priority'] == 'High';
      return true;
    }).toList();
    final unread = _items.where((item) => item['read'] != true).length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      _pushCard(),
      _releaseHistoryCard(),
      const Card(child: ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('Personal notification notes'),
        subtitle: Text('Saved only on this device. Not live Supabase alerts, push notifications, or employee messages.'),
      )),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Chip(label: Text('$unread unread')),
        FilledButton.icon(onPressed: _createDialog, icon: const Icon(Icons.add), label: const Text('New reminder')),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 6, children: ['All', 'Unread', 'Read', 'High'].map((filter) => ChoiceChip(
        label: Text(filter), selected: _filter == filter,
        onSelected: (_) => setState(() => _filter = filter),
      )).toList()),
      if (_loading) const Center(child: CircularProgressIndicator())
      else if (visible.isEmpty) const Padding(
        padding: EdgeInsets.all(24), child: Center(child: Text('No reminders in this view.')),
      )
      else ...visible.map((item) => Card(child: ListTile(
        leading: Icon(item['read'] == true ? Icons.drafts_outlined : Icons.markunread_outlined),
        title: Text(item['title']?.toString() ?? ''),
        subtitle: Text('${item['message'] ?? ''}\nPriority: ${item['priority'] ?? 'Normal'}'),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            setState(() {
              if (action == 'delete') {
                _items.remove(item);
              } else {
                item['read'] = action == 'read';
              }
            });
            _save();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'read', child: Text('Mark read')),
            PopupMenuItem(value: 'unread', child: Text('Mark unread')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ))),
    ]);
  }
}
