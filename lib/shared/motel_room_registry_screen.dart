import 'app_language.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MotelRoomRegistryScreen extends StatefulWidget {
  const MotelRoomRegistryScreen({super.key});
  @override
  State<MotelRoomRegistryScreen> createState() => _MotelRoomRegistryScreenState();
}

class _MotelRoomRegistryScreenState extends State<MotelRoomRegistryScreen> {
  final _number = TextEditingController();
  final _name = TextEditingController();
  String _type = 'room';
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _rooms = [];

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _number.dispose(); _name.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final result = await Supabase.instance.client.rpc('gs_staff_list_motel_rooms');
      if (!mounted) return;
      setState(() { _rooms = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(); _error = null; });
    } catch (e) { if (mounted) setState(() => _error = 'Unable to load rooms: $e'); }
  }

  Future<void> _save() async {
    if (_busy) return;
    final number = _number.text.trim();
    final name = _name.text.trim();
    if (number.isEmpty || name.isEmpty || number.length > 100 || name.length > 100) {
      setState(() => _error = 'Enter a room number and name (1–100 characters each).');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.rpc('gs_staff_save_motel_room', params: {
        'p_room_label': number, 'p_room_name': name, 'p_accommodation_type': _type,
      });
      await _load();
      if (mounted) { _number.clear(); _name.clear(); }
    } catch (e) { if (mounted) setState(() => _error = 'Save failed: $e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _manageGuestAccess(Map<String, dynamic> room) async {
    final label = room['room_label'].toString();
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (dialogContext) {
      bool processing = false;
      String? issuedCode;
      String? error;
      int hours = 24;
      return StatefulBuilder(builder: (context, update) => AlertDialog(
        title: Text('Guest access · $label'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Verify the active check-in with reception before issuing a code. A QR scan alone is not proof of occupancy.'),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(initialValue: hours,
            decoration: const InputDecoration(labelText: 'Access duration'),
            items: const [1, 6, 12, 24, 48, 72, 168].map((h) => DropdownMenuItem(value: h, child: Text('$h hours'))).toList(),
            onChanged: processing ? null : (v) { if (v != null) update(() => hours = v); }),
          if (issuedCode != null) ...[
            const SizedBox(height: 12),
            const Text('Give this code privately to the verified guest. It is displayed only now.'),
            SelectableText(issuedCode!),
            TextButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: issuedCode!)),
              icon: const Icon(Icons.copy), label: const Text('Copy code')),
          ],
          if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
        ])),
        actions: [
          TextButton(onPressed: processing ? null : () => Navigator.pop(dialogContext), child: const Text('Close')),
          TextButton(onPressed: processing ? null : () async {
            update(() { processing = true; error = null; });
            try {
              await Supabase.instance.client.rpc('gs_staff_revoke_motel_guest_access', params: {'p_room_label': label});
              if (context.mounted) update(() { issuedCode = null; });
            } catch (_) { if (context.mounted) update(() => error = 'Unable to revoke guest access.'); }
            finally { if (context.mounted) update(() => processing = false); }
          }, child: const Text('Revoke')),
          FilledButton(onPressed: processing ? null : () async {
            update(() { processing = true; error = null; });
            try {
              final result = await Supabase.instance.client.rpc('gs_staff_issue_motel_guest_access',
                params: {'p_room_label': label, 'p_hours': hours});
              if (context.mounted) update(() => issuedCode = result.toString());
            } catch (_) { if (context.mounted) update(() => error = 'Unable to issue guest access. Check permissions and room status.'); }
            finally { if (context.mounted) update(() => processing = false); }
          }, child: const Text('Issue code')),
        ],
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    String t(String value) => AppLanguage.label(AppLanguage.of(context), value);
    return ListView(padding: const EdgeInsets.all(16), children: [
    Text(t('Rooms, Villas & Chalets'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const Text('Register a destination or update its name. Room QR identity stays unchanged.'),
    const SizedBox(height: 12),
    TextField(controller: _number, maxLength: 100, decoration: InputDecoration(labelText: t('Room number / unique label'))),
    TextField(controller: _name, maxLength: 100, decoration: InputDecoration(labelText: t('Room name'))),
    DropdownButtonFormField<String>(initialValue: _type, decoration: InputDecoration(labelText: t('Accommodation type')),
      items: const ['room','villa','chalet','cottage','suite','other'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
      onChanged: _busy ? null : (v) { if (v != null) setState(() => _type = v); }),
    const SizedBox(height: 12),
    FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? t('Saving…') : t('Add / Update Room'))),
    if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
    const Divider(),
    Row(children: [Expanded(child: Text(t('Registered accommodations'), style: TextStyle(fontWeight: FontWeight.bold))), IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
    for (final room in _rooms) ListTile(
      title: Text('${room['room_label']} — ${room['room_name']}'),
      subtitle: Text('${room['accommodation_type']} · ${room['is_active'] == true ? t('Active') : t('Disabled')}'),
      trailing: Wrap(children: [
        IconButton(tooltip: 'Manage guest access', icon: const Icon(Icons.key_outlined),
          onPressed: room['is_active'] == true ? () => _manageGuestAccess(room) : null),
        IconButton(tooltip: 'Edit room', icon: const Icon(Icons.edit_outlined), onPressed: () => setState(() {
          _number.text = '${room['room_label']}'; _name.text = '${room['room_name']}'; _type = '${room['accommodation_type']}';
        })),
      ]),
    ),
  ]);
  }
}
