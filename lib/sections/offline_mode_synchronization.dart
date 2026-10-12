import 'dart:async';
import 'package:flutter/material.dart';
import '../shared/section_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-confirmed synchronization status. Never queues financial mutations.
class OfflineModeSynchronizationScreen extends StatelessWidget {
  const OfflineModeSynchronizationScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: 'Offline Mode & Synchronization',
    description: 'Server-confirmed synchronization status',
    sectionId: 'offline_mode_synchronization',
    authorizedContent: _OfflineModeSynchronizationContent(),
  );
}

class _OfflineModeSynchronizationContent extends StatefulWidget {
  const _OfflineModeSynchronizationContent();
  @override
  State<_OfflineModeSynchronizationContent> createState() =>
      _OfflineModeSynchronizationScreenState();
}

class _OfflineModeSynchronizationScreenState
    extends State<_OfflineModeSynchronizationContent> {
  StreamSubscription<AuthState>? _authSubscription;
  int _cursorRequest = 0;
  Future<_SyncStatus>? _status;
  DateTime? _cursorTime;
  int _cursorId = 0;
  int _receivedThisSession = 0;
  String? _cursorError;
  bool _cursorLoading = false;
  String? _cursorUserId;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (!mounted) return;
      _cursorRequest++;
      _cursorLoading = false;
      _refresh();
    });
    _refresh();
  }

  @override
  void dispose() {
    _cursorRequest++;
    _authSubscription?.cancel();
    super.dispose();
  }

  void _refresh() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (_cursorUserId != userId) {
      _cursorUserId = userId;
      _cursorTime = null;
      _cursorId = 0;
      _receivedThisSession = 0;
      _cursorError = null;
    }
    setState(() => _status = _fetch());
  }

  /// Fetch only new notifications. Cursor advances only after a valid batch.
  /// Kept in memory: nothing is cached on a shared device or queued offline.
  Future<void> _syncNotificationCursor() async {
    if (_cursorLoading) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final request = ++_cursorRequest;
    if (userId == null) {
      setState(() => _cursorError = 'Employee login required');
      return;
    }
    if (_cursorUserId != userId) {
      _cursorUserId = userId;
      _cursorTime = null;
      _cursorId = 0;
      _receivedThisSession = 0;
    }
    setState(() { _cursorLoading = true; _cursorError = null; });
    try {
      final args = <String, dynamic>{'p_limit': 100};
      if (_cursorTime != null) {
        args['p_after_created_at'] = _cursorTime!.toUtc().toIso8601String();
        args['p_after_id'] = _cursorId;
      }
      final response = await Supabase.instance.client.rpc(
        'gs_my_service_notifications_since', params: args);
      final rows = response as List;
      DateTime? nextTime = _cursorTime;
      int nextId = _cursorId;
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw as Map);
        final time = DateTime.parse(row['created_at'] as String).toUtc();
        final id = (row['id'] as num).toInt();
        if (nextTime != null &&
            (time.isBefore(nextTime) ||
             (time.isAtSameMomentAs(nextTime) && id <= nextId))) {
          throw StateError('Server returned an out-of-order cursor');
        }
        nextTime = time;
        nextId = id;
      }
      if (!mounted || request != _cursorRequest ||
          Supabase.instance.client.auth.currentUser?.id != userId) return;
      setState(() {
        _cursorTime = nextTime;
        _cursorId = nextId;
        _receivedThisSession += rows.length;
      });
      _refresh();
    } catch (_) {
      if (mounted && request == _cursorRequest &&
          Supabase.instance.client.auth.currentUser?.id == userId) {
        setState(() => _cursorError = 'Unable to fetch notifications. Check connection and access.');
      }
    } finally {
      if (mounted && request == _cursorRequest) {
        setState(() => _cursorLoading = false);
      }
    }
  }

  Future<_SyncStatus> _fetch() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Employee login required');
    final response = await client.rpc('gs_my_service_notification_summary');
    if (client.auth.currentUser?.id != user.id) {
      throw StateError('Employee session changed');
    }
    final rows = response as List;
    if (rows.isEmpty) throw StateError('Notification summary unavailable');
    final summary = Map<String, dynamic>.from(rows.first as Map);
    // The backend scopes the summary to auth.uid(), not a client-provided ID.
    return _SyncStatus(
      userId: user.id,
      unread: (summary['unread_count'] as num?)?.toInt() ?? 0,
      lastNotification: summary['latest_notification_at']?.toString(),
      checkedAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Offline Mode & Synchronization'),
          actions: [
            IconButton(
              tooltip: 'Check server again',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<_SyncStatus>(
          future: _status,
          builder: (context, snapshot) {
            final currentUserId = Supabase.instance.client.auth.currentUser?.id;
            final fetched = snapshot.data;
            final data = fetched?.userId == currentUserId ? fetched : null;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(
                      data != null ? Icons.cloud_done_outlined :
                      snapshot.hasError ? Icons.cloud_off_outlined :
                      Icons.cloud_sync_outlined,
                    ),
                    title: Text(data != null
                        ? 'Server check successful'
                        : snapshot.hasError
                            ? 'Server check unavailable'
                            : 'Checking server…'),
                    subtitle: Text(data != null
                        ? 'Checked ${data.checkedAt.toLocal()}'
                        : snapshot.hasError
                            ? 'Check connection, login and deployed permissions.'
                            : 'Contacting the authorized employee endpoint.'),
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(),
                if (data != null) ...[
                  ListTile(
                    title: const Text('Signed-in employee'),
                    subtitle: Text(data.userId),
                  ),
                  ListTile(
                    title: const Text('Unread service notifications'),
                    trailing: Text('${data.unread}'),
                  ),
                  ListTile(
                    title: const Text('Latest notification'),
                    subtitle: Text(data.lastNotification ?? 'None recorded'),
                  ),
                ],
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Notification cursor sync',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Fetched this session: $_receivedThisSession'),
                        Text('Last cursor ID: $_cursorId'),
                        Text('Last cursor time: ${_cursorTime?.toLocal() ?? 'Not started'}'),
                        if (_cursorError != null)
                          Text(_cursorError!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _cursorLoading ? null : _syncNotificationCursor,
                          icon: const Icon(Icons.sync),
                          label: Text(_cursorLoading ? 'Checking…' : 'Fetch new notifications'),
                        ),
                        const Text('Manual online-only sync. Read-state changes '
                          'are not included in this creation cursor. The cursor '
                          'is not persisted after the app closes.'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Offline transaction sync is not enabled. This screen '
                      'checks the live server only; it does not persist a '
                      'customer cache or queue writes. Payments, bill transfers, '
                      'owner approvals, cleaning signoff and table release '
                      'must be verified online. Never treat this screen as '
                      'proof that an offline action was synchronized.',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class _SyncStatus {
  const _SyncStatus({
    required this.userId,
    required this.unread,
    required this.lastNotification,
    required this.checkedAt,
  });

  final String userId;
  final int unread;
  final String? lastNotification;
  final DateTime checkedAt;
}
