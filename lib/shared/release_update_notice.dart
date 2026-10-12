import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_release_version.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Non-disruptive update notifications. Never reloads, installs, signs out,
/// clears storage, runs migrations, or changes the current working screen.
class ReleaseUpdateNotice extends StatefulWidget {
  const ReleaseUpdateNotice({super.key, required this.child});
  final Widget child;
  @override
  State<ReleaseUpdateNotice> createState() => _ReleaseUpdateNoticeState();
  static bool isNewer(String candidate, String installed) {
    List<int>? parse(String s) {
      if (!RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(s)) return null;
      return s.split('.').map(int.parse).toList();
    }
    final a = parse(candidate), b = parse(installed);
    if (a == null || b == null) return false;
    for (var i = 0; i < 4; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }
}
class _ReleaseUpdateNoticeState extends State<ReleaseUpdateNotice> with WidgetsBindingObserver {
  Timer? _timer;
  StreamSubscription<AuthState>? _auth;
  Map<String, dynamic>? _notice;
  String? _installed, _dismissed;
  bool _checking = false, _foreground = true, _showDetails = false;
  int _epoch = 0;
  String get _platform => kIsWeb ? 'web' : switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android', TargetPlatform.iOS => 'ios',
    TargetPlatform.windows => 'windows', _ => 'unsupported',
  };
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _auth = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _epoch++;
      if (mounted) setState(() { _notice = null; _dismissed = null; });
      _check();
    });
    _installed = AppReleaseVersion.label;
    _check();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _check());
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _epoch++;
    if (!_foreground && mounted) setState(() => _notice = null);
    if (_foreground) _check();
  }
  @override
  void dispose() {
    _epoch++; _timer?.cancel(); _auth?.cancel();
    WidgetsBinding.instance.removeObserver(this); super.dispose();
  }
  Future<void> _check() async {
    if (_checking || !_foreground || _installed == null || _platform == 'unsupported') return;
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null || client.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel != AuthenticatorAssuranceLevels.aal2) return;
    _checking = true;
    final epoch = _epoch;
    try {
      final result = await client.rpc('gs_app_available_update', params: {'p_platform': _platform}).timeout(const Duration(seconds: 10));
      if (!mounted || epoch != _epoch || !_foreground ||
          client.auth.currentSession?.accessToken != session.accessToken) return;
      final notice = result == null ? null : Map<String, dynamic>.from(result as Map);
      final newer = notice != null && ReleaseUpdateNotice.isNewer(notice['version'].toString(), _installed!);
      setState(() => _notice = newer && '${notice['id']}:${notice['revision']}' != _dismissed ? notice : null);
    } catch (_) {
      // An unavailable update service must never interrupt the user's work.
      if (mounted && epoch == _epoch) setState(() => _notice = null);
    } finally { _checking = false; }
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    if (_notice != null) Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: SafeArea(bottom: false, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Row(children: [
        const Icon(Icons.system_update_outlined), const SizedBox(width: 8),
        Expanded(child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 160), child: SingleChildScrollView(child: Semantics(liveRegion: true, child: Text('Update ${_notice!['version']} is available. Save your work before updating.${_showDetails ? '\n${_notice!['notes']}' : ''}'))))),
        TextButton(onPressed: () {
          setState(() => _showDetails = !_showDetails);
        }, child: Text(_showDetails ? 'Hide' : 'Details')),
        IconButton(tooltip: 'Remind me next session', onPressed: () => setState(() {
          _dismissed = '${_notice!['id']}:${_notice!['revision']}'; _notice = null;
        }), icon: const Icon(Icons.close)),
      ]))),
    ),
    Expanded(child: widget.child),
  ]);
}
