import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/browser_push.dart';
import '../services/device_session_preference.dart';

class EmployeeDevicePresenceMonitor extends StatefulWidget {
  const EmployeeDevicePresenceMonitor({super.key, required this.child});

  final Widget child;

  @override
  State<EmployeeDevicePresenceMonitor> createState() =>
      _EmployeeDevicePresenceMonitorState();
}

class _EmployeeDevicePresenceMonitorState
    extends State<EmployeeDevicePresenceMonitor>
    with WidgetsBindingObserver {
  static const _heartbeatInterval = Duration(seconds: 30);
  Timer? _timer;
  StreamSubscription<AuthState>? _authSubscription;
  bool _foreground = true;
  bool _sending = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _generation++;
      _sendHeartbeat();
    });
    _timer = Timer.periodic(_heartbeatInterval, (_) => _sendHeartbeat());
    _sendHeartbeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _generation++;
    if (_foreground) _sendHeartbeat();
  }

  Future<void> _sendHeartbeat() async {
    if (_sending || !_foreground || !mounted) return;
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return;
    try {
      if (client.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel !=
          AuthenticatorAssuranceLevels.aal2) {
        return;
      }
    } catch (_) {
      return;
    }

    final sessionId = DeviceSessionPreference.sessionId(session);
    if (sessionId == null) return;
    _sending = true;
    final generation = _generation;
    try {
      final result = await client.rpc(
        'gs_employee_device_heartbeat',
        params: {
          'p_device_label': kIsWeb
              ? 'Web app'
              : '${defaultTargetPlatform.name} app',
          'p_user_agent': kIsWeb ? browserUserAgent() : '',
        },
      ).timeout(const Duration(seconds: 10));

      final current = client.auth.currentSession;
      if (!mounted ||
          generation != _generation ||
          current?.user.id != session.user.id ||
          DeviceSessionPreference.sessionId(current) != sessionId) {
        return;
      }
      if (result == false) {
        try {
          await DeviceSessionPreference.clear();
        } catch (_) {
          // Local sign-out still prevents this browser from reusing the session.
        }
        await client.auth.signOut(scope: SignOutScope.local);
      }
    } catch (_) {
      // A missing backend migration or temporary network failure does not sign
      // out a valid employee; only an explicit server revocation does.
    } finally {
      _sending = false;
    }
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    _authSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
