import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Staff-only specific-table booking. The RPC enforces authorization, capacity,
/// serialization and the audit record; this screen is not an access boundary.
class StaffSpecificReservationScreen extends StatefulWidget {
  const StaffSpecificReservationScreen({super.key});
  @override
  State<StaffSpecificReservationScreen> createState() => _StaffSpecificReservationScreenState();
}

class _StaffSpecificReservationScreenState extends State<StaffSpecificReservationScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  List<Map<String, dynamic>> _tables = [];
  String? _tableId;
  DateTime? _start;
  int _guests = 2;
  int _minutes = 120;
  bool _busy = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _name.dispose(); _phone.dispose(); _notes.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _busy = true; _error = null; _tableId = null; });
    try {
      final rows = await Supabase.instance.client.rpc(
        'gs_public_reservable_table_options', params: {'p_party_size': _guests});
      if (mounted) setState(() => _tables = (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map)).toList());
    } catch (e) { if (mounted) setState(() => _error = 'Cannot load tables: $e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _chooseTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, firstDate: now,
      lastDate: now.add(const Duration(days: 89)), initialDate: now);
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0));
    if (time == null || !mounted) return;
    setState(() => _start = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _book() async {
    if (!_form.currentState!.validate() || _tableId == null || _start == null ||
        !_start!.isAfter(DateTime.now())) {
      setState(() => _error = 'Select a future date, table, and valid customer details.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final available = await Supabase.instance.client.rpc('gs_public_table_available', params: {
        'p_table_id': _tableId, 'p_start': _start!.toUtc().toIso8601String(),
        'p_duration': _minutes, 'p_party_size': _guests,
      });
      if (available != true) throw StateError('Selected table is not available.');
      await Supabase.instance.client.rpc('gs_staff_book_specific_table', params: {
        'p_name': _name.text.trim(), 'p_phone': _phone.text.trim(),
        'p_table_id': _tableId, 'p_start': _start!.toUtc().toIso8601String(),
        'p_party_size': _guests, 'p_duration': _minutes,
        'p_notes': _notes.text.trim(), 'p_existing_request_id': null,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Reservation created and confirmed by the server.')));
      Navigator.of(context).pop(true);
    } catch (e) { if (mounted) setState(() => _error = 'Booking failed: $e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Staff · Reserve a table')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560),
      child: Form(key: _form, child: ListView(padding: const EdgeInsets.all(20), children: [
        TextFormField(controller: _name, maxLength: 100,
          decoration: const InputDecoration(labelText: 'Customer name'),
          validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Name required' : null),
        TextFormField(controller: _phone, maxLength: 30,
          decoration: const InputDecoration(labelText: 'Phone'),
          validator: (v) => (v?.trim().length ?? 0) < 6 ? 'Phone required' : null),
        DropdownButtonFormField<int>(value: _guests,
          decoration: const InputDecoration(labelText: 'Guests'),
          items: List.generate(30, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
          onChanged: _busy ? null : (v) { if (v != null) { setState(() => _guests = v); _load(); } }),
        DropdownButtonFormField<String>(value: _tableId,
          decoration: const InputDecoration(labelText: 'Specific table'),
          items: _tables.map((t) => DropdownMenuItem<String>(value: '${t['table_id']}',
            child: Text('${t['table_label']} · ${t['seats']} seats'))).toList(),
          onChanged: _busy ? null : (v) => setState(() => _tableId = v)),
        ListTile(title: Text(_start == null ? 'Select date and time' : 'Selected: $_start'),
          trailing: const Icon(Icons.calendar_month), onTap: _busy ? null : _chooseTime),
        DropdownButtonFormField<int>(value: _minutes,
          decoration: const InputDecoration(labelText: 'Duration'),
          items: const [30,60,90,120,180,240,300,360].map((n) =>
            DropdownMenuItem(value: n, child: Text('$n minutes'))).toList(),
          onChanged: _busy ? null : (v) => setState(() => _minutes = v ?? 120)),
        TextFormField(controller: _notes, maxLength: 500, maxLines: 3,
          decoration: const InputDecoration(labelText: 'Notes (optional)')),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 12),
        FilledButton(onPressed: _busy ? null : _book,
          child: Text(_busy ? 'Please wait...' : 'Confirm staff reservation')),
      ])))));
}
