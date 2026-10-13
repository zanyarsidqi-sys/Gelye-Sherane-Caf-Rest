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
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _openingHours = TextEditingController();
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
      final data = await _db.from('cafe_website_settings')
          .select('title,description,phone,email,address,opening_hours,menu_enabled,ordering_requested,reservations_requested')
          .eq('id', 1).single();
      if (!mounted) return;
      setState(() {
        _canEdit = p?.canEdit == true;
        _title.text = (data['title'] as String?) ?? '';
        _description.text = (data['description'] as String?) ?? '';
        _phone.text = (data['phone'] as String?) ?? '';
        _email.text = (data['email'] as String?) ?? '';
        _address.text = (data['address'] as String?) ?? '';
        _openingHours.text = (data['opening_hours'] as String?) ?? '';
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
    final email = _email.text.trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid public contact email.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await _db.from('cafe_website_settings').update({
        'title': _title.text.trim(), 'description': _description.text.trim(),
        'phone': _phone.text.trim(), 'email': email,
        'address': _address.text.trim(),
        'opening_hours': _openingHours.text.trim(),
        'menu_enabled': _menu, 'ordering_requested': _ordering,
        'reservations_requested': _reservations,
      }).eq('id', 1).select('id').single();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Website and public contact details saved. Refresh the public page to see changes.')));
    } catch (e) { if (mounted) setState(() => _error = 'Save failed: $e'); }
    finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _openingHours.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _title.text.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), TextButton(onPressed: () {setState(() => _loading = true); _load();}, child: const Text('Retry'))]));
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Websites Management', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('Private cloud settings. Ordering and reservations are requests only; public services are not activated here.'),
      const SizedBox(height: 8),
      const Text('Public contact details appear in the landing page and can be changed here.'),
      const SizedBox(height: 16),
      TextField(controller: _title, enabled: _canEdit, maxLength: 100, decoration: const InputDecoration(labelText: 'Website title', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: _description, enabled: _canEdit, maxLength: 300, maxLines: 3, decoration: const InputDecoration(labelText: 'Introduction', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: _phone, enabled: _canEdit, maxLength: 50, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Public phone', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: _email, enabled: _canEdit, maxLength: 254, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Public email', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: _address, enabled: _canEdit, maxLength: 300, maxLines: 2, decoration: const InputDecoration(labelText: 'Public address', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: _openingHours, enabled: _canEdit, maxLength: 300, maxLines: 2, decoration: const InputDecoration(labelText: 'Opening hours', border: OutlineInputBorder())),
      const SizedBox(height: 12),
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
