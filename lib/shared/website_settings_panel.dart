import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/employee_permission_service.dart';

/// Private management settings. Public website publication is a separate feature.
class WebsiteSettingsPanel extends StatefulWidget {
  const WebsiteSettingsPanel({super.key});
  @override
  State<WebsiteSettingsPanel> createState() => _WebsiteSettingsPanelState();
}
class _WebsiteSettingsPanelState extends State<WebsiteSettingsPanel> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _menu = true, _ordering = false, _reservations = false;
  bool _loading = true, _saving = false, _canEdit = false;
  String? _error;
  SupabaseClient get _db => Supabase.instance.client;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final permissions = await EmployeePermissionService().getSectionPermissions();
      final p = permissions['websites_management'];
      if (p?.canView != true) throw Exception('Website management access denied');
      final data = await _db.from('cafe_website_settings').select('title,description,menu_enabled,ordering_requested,reservations_requested').eq('id', 1).single();
      if (!mounted) return;
      setState(() {
        _canEdit = p?.canEdit == true;
        _title.text = (data['title'] as String?) ?? '';
        _description.text = (data['description'] as String?) ?? '';
        _menu = data['menu_enabled'] == true;
        _ordering = data['ordering_requested'] == true;
        _reservations = data['reservations_requested'] == true;
        _error = null;
      });
    } catch (e) { if (mounted) setState(() => _error = 'Could not load website settings: $e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _save() async {
    if (!_canEdit || _saving) return;
    if (_title.text.trim().isEmpty) { setState(() => _error = 'Website title is required'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      await _db.from('cafe_website_settings').update({
        'title': _title.text.trim(), 'description': _description.text.trim(),
        'menu_enabled': _menu, 'ordering_requested': _ordering,
        'reservations_requested': _reservations,
      }).eq('id', 1).select('id').single();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Website settings saved to Supabase. Public site unchanged.')));
    } catch (e) { if (mounted) setState(() => _error = 'Save failed: $e'); }
    finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  void dispose() { _title.dispose(); _description.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _title.text.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), TextButton(onPressed: () {setState(() => _loading = true); _load();}, child: const Text('Retry'))]));
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Websites Management', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('Private cloud settings. Ordering and reservations are requests only; public services are not activated here.'),
      const SizedBox(height: 16),
      TextField(controller: _title, enabled: _canEdit, maxLength: 100, decoration: const InputDecoration(labelText: 'Website title', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: _description, enabled: _canEdit, maxLength: 300, maxLines: 3, decoration: const InputDecoration(labelText: 'Introduction', border: OutlineInputBorder())),
      SwitchListTile(title: const Text('Show menu (configuration only)'), value: _menu, onChanged: _canEdit ? (v) => setState(() => _menu = v) : null),
      SwitchListTile(title: const Text('Request online ordering (not live)'), value: _ordering, onChanged: _canEdit ? (v) => setState(() => _ordering = v) : null),
      SwitchListTile(title: const Text('Request reservations (not live)'), value: _reservations, onChanged: _canEdit ? (v) => setState(() => _reservations = v) : null),
      if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _canEdit && !_saving ? _save : null, icon: const Icon(Icons.cloud_upload_outlined), label: Text(_saving ? 'Saving...' : 'Save to Supabase')),
      if (!_canEdit) const Text('Read-only: website edit permission is required.'),
    ]);
  }
}
