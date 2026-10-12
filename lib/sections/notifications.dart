import 'dart:async';
import 'package:flutter/material.dart';
import '../shared/section_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/staff_customer_calls_screen.dart';
import '../shared/notification_center_panel.dart';

/// Staff notification hub. Customer assistance is backed by the same
/// permission-checked queue used in Table Orders; no local-only duplicate.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionShell(
    title: 'Notifications',
    description: 'Staff notification hub',
    sectionId: 'notifications',
    authorizedContent: _NotificationsContent(),
  );
}

class _NotificationsContent extends StatefulWidget {
  const _NotificationsContent();
  @override
  State<_NotificationsContent> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<_NotificationsContent> {
  StreamSubscription<AuthState>? _authSubscription;
  int _permissionRequest = 0;
  bool _checking = true;
  bool _canViewCalls = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (!mounted) return;
      setState(() { _canViewCalls = false; _checking = true; });
      _checkPermission();
    });
    _checkPermission();
  }

  @override
  void dispose() {
    _permissionRequest++;
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final request = ++_permissionRequest;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() { _canViewCalls = false; _checking = false; });
      return;
    }
    try {
      // The server-side queue RPC is authoritative and checks Table Orders
      // view permission. Never expose the queue based on a client flag alone.
      await Supabase.instance.client.rpc('gs_staff_customer_call_queue');
      if (mounted && request == _permissionRequest &&
          Supabase.instance.client.auth.currentUser?.id == userId) {
        setState(() { _canViewCalls = true; _checking = false; });
      }
    } catch (_) {
      if (mounted && request == _permissionRequest) {
        setState(() { _canViewCalls = false; _checking = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: Column(children: [
      // Push enrollment is available to every authenticated staff member;
      // Table Orders permissions apply only to the customer-call queue.
      const NotificationCenterPanel(),
      Expanded(child: _checking
        ? const Center(child: CircularProgressIndicator())
        : !_canViewCalls
          ? Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock_outline, size: 40),
                const SizedBox(height: 12),
                const Text('Customer assistance alerts require Table Orders view permission.', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () { setState(() => _checking = true); _checkPermission(); }, child: const Text('Retry')),
              ]),
            ))
          : const Column(children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Customer assistance requests refresh every 8 seconds while this screen is open. Browser push alerts require activation and a successful delivery test.'),
              ),
              Expanded(child: StaffCustomerCallsScreen()),
            ])),
    ]),
  );
}
