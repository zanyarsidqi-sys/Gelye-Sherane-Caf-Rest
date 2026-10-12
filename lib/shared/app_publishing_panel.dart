import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_release_version.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_release.dart';
import '../services/app_release_service.dart';
import '../services/employee_permission_service.dart';

class AppPublishingPanel extends StatefulWidget {
  const AppPublishingPanel({super.key});
  @override
  State<AppPublishingPanel> createState() => _AppPublishingPanelState();
}

class _AppPublishingPanelState extends State<AppPublishingPanel> {
  final _service = AppReleaseService();
  List<AppRelease> _releases = [];
  SectionPermission? _permission;
  bool _loading = true, _busy = false;
  String? _error;
  String _installed = 'Checking…', _platform = 'all', _channel = 'all', _search = '';
  DateTime? _checkedAt;
  int _epoch = 0;
  StreamSubscription<AuthState>? _authSubscription;
  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (!mounted) return;
      _epoch++;
      setState(() { _releases = []; _permission = null; _loading = true; });
      _load();
    });
    _load();
    _installed = AppReleaseVersion.label;
  }
  @override
  void dispose() { _epoch++; _authSubscription?.cancel(); super.dispose(); }
  String _message(Object error) {
    if (error is TimeoutException) return 'The request timed out. Refresh before retrying; a submitted action may have completed.';
    if (error is PostgrestException) {
      if (['42P01', 'PGRST202', 'PGRST205'].contains(error.code)) {
        return 'Release database setup is required. Apply migration 20261012_1493_app_release_management.sql, then refresh.';
      }
      if (error.code == '42501') return 'Your current account cannot perform this action. Check MFA and section permissions.';
      if (error.code == '23505') return 'This platform, channel and version already exists. Refresh the list.';
      if (error.code == '40001') return 'This release changed on another device. Refresh and review the latest state.';
      if (error.code == 'P0001') return error.message;
    }
    return 'The request could not be verified. Refresh and check your connection or session.';
  }
  Future<void> _load() async {
    final epoch = ++_epoch;
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final permissions = await EmployeePermissionService().getSectionPermissions();
      final permission = permissions['app_publishing_updates'];
      if (permission?.canView != true) throw StateError('Access denied');
      final releases = await _service.list();
      if (!mounted || epoch != _epoch) return;
      setState(() { _permission = permission; _releases = releases; _checkedAt = DateTime.now(); });
    } catch (e) {
      if (!mounted || epoch != _epoch) return;
      setState(() { _releases = []; _permission = null; _error = _message(e); });
    } finally {
      if (mounted && epoch == _epoch) setState(() => _loading = false);
    }
  }
  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Release record saved. No binary deployment was performed.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_message(e))));
    } finally {
      if (mounted) { setState(() => _busy = false); await _load(); }
    }
  }
  Future<void> _create() async {
    final version = TextEditingController(), notes = TextEditingController();
    final url = TextEditingController(), checksum = TextEditingController();
    final form = GlobalKey<FormState>();
    var platform = 'web', channel = 'test';
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
      title: const Text('New release draft'),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: platform, decoration: const InputDecoration(labelText: 'Platform'), items: AppRelease.platforms.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => update(() => platform = v!)),
        DropdownButtonFormField<String>(initialValue: channel, decoration: const InputDecoration(labelText: 'Channel'), items: AppRelease.channels.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => update(() => channel = v!)),
        TextFormField(controller: version, decoration: const InputDecoration(labelText: 'Version', hintText: '1.0.0.30'), validator: (_) => AppRelease.validateDraft(version: version.text.trim(), notes: notes.text.trim(), url: url.text.trim(), sha256: checksum.text.trim())),
        TextFormField(controller: notes, maxLines: 4, maxLength: 4000, decoration: const InputDecoration(labelText: 'Release notes')),
        TextFormField(controller: url, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'HTTPS release URL')),
        const Text('Use the café domain, this project’s GitHub Releases, or an official Apple, Google or Microsoft store URL. No query strings.'),
        TextFormField(controller: checksum, decoration: const InputDecoration(labelText: 'Build SHA-256 (64 characters)')),
      ])))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () {
        if (form.currentState!.validate()) Navigator.pop(ctx, <String, dynamic>{'platform': platform, 'channel': channel, 'version': version.text.trim(), 'notes': notes.text.trim(), 'artifact_url': url.text.trim(), 'sha256': checksum.text.trim().toLowerCase()});
      }, child: const Text('Save draft'))],
    )));
    version.dispose(); notes.dispose(); url.dispose(); checksum.dispose();
    if (result != null && mounted) {
      final request = _service.newRequestId();
      await _perform(() => _service.create(result, request));
    }
  }
  Future<void> _transition(AppRelease release, String action) async {
    final reason = TextEditingController();
    final checks = {for (final key in AppRelease.reviewChecks.keys) key: false};
    String? error;
    final accepted = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
      title: Text('${_actionLabel(action)} ${release.version}'),
      content: SizedBox(width: 540, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(action == 'rollback' ? 'Restores the previous available release RECORD. You must separately restore the hosted web build or distribute the earlier app. No database restore is performed.' : 'This changes the release catalog only. It does not upload, install, deploy, or certify a build.'),
        if (action == 'ready') ...AppRelease.reviewChecks.entries.map((e) => CheckboxListTile(contentPadding: EdgeInsets.zero, title: Text(e.value), value: checks[e.key], onChanged: (v) => update(() => checks[e.key] = v ?? false))),
        TextField(controller: reason, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(labelText: 'Reason / review evidence (10+ characters)')),
        if (error != null) Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () {
        if (reason.text.trim().length < 10 || (action == 'ready' && checks.values.any((v) => !v))) {
          update(() => error = 'Enter a reason and complete every required review check.'); return;
        }
        Navigator.pop(ctx, true);
      }, child: const Text('Confirm'))],
    )));
    final note = reason.text.trim(); reason.dispose();
    if (accepted == true && mounted) {
      final request = _service.newRequestId();
      await _perform(() => _service.transition(release, action, note, checks, request));
    }
  }
  String _actionLabel(String action) => switch (action) {
    'ready' => 'Review', 'publish' => 'Make available', 'rollback' => 'Restore previous record', _ => 'Withdraw',
  };
  Future<void> _history(AppRelease release) async {
    final epoch = _epoch;
    try {
      final events = await _service.history(release.id);
      if (!mounted || epoch != _epoch) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: Text('History · ${release.version}'), content: SizedBox(width: 540, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: events.map((e) => ListTile(title: Text('${e['action']} · ${e['created_at']}'), subtitle: Text(e['reason'].toString()))).toList()))), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))]));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_message(e)))); }
  }
  @override
  Widget build(BuildContext context) {
    final rows = _releases.where((r) => (_platform == 'all' || r.platform == _platform) && (_channel == 'all' || r.channel == _channel) && '${r.version} ${r.notes} ${r.status}'.toLowerCase().contains(_search.toLowerCase())).toList();
    return RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Installed app: $_installed', style: Theme.of(context).textTheme.titleMedium),
        const SelectableText('Web: https://cafe.gelyesheranecompany.com'),
        const Text('Release catalog and review controls. Hosting, app-store submission and device installation are separate operations.'),
        if (_checkedAt != null) Text('Last successful server check: ${_checkedAt!.toLocal()}'),
      ]))),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(onPressed: _loading || _busy ? null : _load, icon: const Icon(Icons.refresh), label: const Text('Refresh releases')),
        FilledButton.icon(onPressed: _loading || _busy || _permission?.canCreate != true ? null : _create, icon: const Icon(Icons.add), label: const Text('New draft')),
      ]),
      if (_loading || _busy) const LinearProgressIndicator(),
      if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!))),
      const SizedBox(height: 12),
      TextField(decoration: const InputDecoration(labelText: 'Search versions, notes or status', prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => _search = v)),
      Wrap(spacing: 16, children: [
        DropdownButton<String>(value: _platform, items: ['all', ...AppRelease.platforms].map((s) => DropdownMenuItem(value: s, child: Text(s == 'all' ? 'All platforms' : s))).toList(), onChanged: (v) => setState(() => _platform = v!)),
        DropdownButton<String>(value: _channel, items: ['all', ...AppRelease.channels].map((s) => DropdownMenuItem(value: s, child: Text(s == 'all' ? 'All channels' : s))).toList(), onChanged: (v) => setState(() => _channel = v!)),
      ]),
      if (!_loading && _error == null && rows.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('No matching release records. No release is inferred from the installed version.')),
      ...rows.map((r) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${r.version} · ${r.platform} · ${r.channel}', style: Theme.of(context).textTheme.titleMedium),
        Text('Status: ${r.status} · Revision ${r.revision}'),
        Text(r.notes), const SizedBox(height: 8),
        SelectableText(r.artifactUrl), SelectableText('SHA-256: ${r.sha256}'),
        Wrap(spacing: 8, children: [
          TextButton(onPressed: _busy ? null : () => Clipboard.setData(ClipboardData(text: r.artifactUrl)), child: const Text('Copy release link')),
          TextButton(onPressed: _busy ? null : () => _history(r), child: const Text('Audit history')),
          TextButton(onPressed: _busy ? null : () => Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert({'version': r.version, 'platform': r.platform, 'channel': r.channel, 'status': r.status, 'notes': r.notes, 'url': r.artifactUrl, 'sha256': r.sha256}))), child: const Text('Copy release details')),
          if (_permission?.canEdit == true) ...[
            if (r.status == 'draft') TextButton(onPressed: _busy ? null : () => _transition(r, 'ready'), child: const Text('Review')),
            if (r.status == 'ready') TextButton(onPressed: _busy ? null : () => _transition(r, 'publish'), child: const Text('Make available')),
            if (['draft', 'ready'].contains(r.status)) TextButton(onPressed: _busy ? null : () => _transition(r, 'withdraw'), child: const Text('Withdraw')),
            if (r.status == 'published' && r.data['previous_release_id'] != null) TextButton(onPressed: _busy ? null : () => _transition(r, 'rollback'), child: const Text('Restore previous record')),
          ],
        ]),
      ])))),
      const Text('Showing up to the latest 100 release records. Review confirmations are staff assertions, not automated certification.'),
    ]));
  }
}
