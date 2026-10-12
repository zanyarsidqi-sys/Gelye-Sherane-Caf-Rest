import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Public reservation requests are pending until an authorized employee confirms.
/// Public users never receive access to private orders, bills, or guest records.
class PublicReservationScreen extends StatefulWidget {
  const PublicReservationScreen({super.key});
  @override
  State<PublicReservationScreen> createState() => _PublicReservationScreenState();
}

class _PublicReservationScreenState extends State<PublicReservationScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _when;
  int _party = 2;
  int _duration = 120;
  bool _saving = false;
  bool _loading = false;
  List<Map<String, dynamic>> _tables = [];
  String? _tableId;
  bool? _available;

  @override
  void initState() { super.initState(); _loadTables(); }
  @override
  void dispose() { _name.dispose(); _phone.dispose(); _notes.dispose(); super.dispose(); }

  Future<void> _loadTables() async {
    setState(() { _loading = true; _tableId = null; _available = null; });
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_public_reservable_table_options', params: {'p_party_size': _party});
      if (!mounted) return;
      setState(() => _tables = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load tables. Please retry.')));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _checkAvailability() async {
    if (_tableId == null || _when == null) return;
    setState(() { _loading = true; _available = null; });
    try {
      final result = await Supabase.instance.client.rpc('gs_public_table_available', params: {
        'p_table_id': _tableId, 'p_start': _when!.toUtc().toIso8601String(),
        'p_duration': _duration, 'p_party_size': _party,
      });
      if (mounted) setState(() => _available = result == true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not check availability.')));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final day = await showDatePicker(context: context, firstDate: now,
      lastDate: now.add(const Duration(days: 89)), initialDate: now);
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0));
    if (time == null || !mounted) return;
    setState(() { _when = DateTime(day.year, day.month, day.day, time.hour, time.minute); _available = null; });
    await _checkAvailability();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _when == null || _tableId == null ||
        !_when!.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Complete all required fields and select a future table and time.')));
      return;
    }
    if (_available != true) { await _checkAvailability(); if (_available != true) return; }
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.rpc('gs_customer_request_specific_table', params: {
        'p_name': _name.text.trim(), 'p_phone': _phone.text.trim(),
        'p_table_id': _tableId, 'p_start': _when!.toUtc().toIso8601String(),
        'p_party_size': _party, 'p_duration': _duration, 'p_notes': _notes.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Request received. Your table is NOT confirmed until staff approve it.')));
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not submit request. Table availability may have changed.')));
      if (mounted) setState(() => _available = null);
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reserve a Table')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 540),
      child: Form(key: _form, child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Choose a table and time. Requests are subject to staff approval.'),
        const SizedBox(height: 16),
        TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Your name'),
          validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Enter your name' : null),
        TextFormField(controller: _phone, keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone number'),
          validator: (v) => (v?.trim().length ?? 0) < 6 ? 'Enter a valid phone number' : null),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(initialValue: _party,
          decoration: const InputDecoration(labelText: 'Guests'),
          items: List.generate(30, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
          onChanged: _saving ? null : (v) { setState(() => _party = v ?? 2); _loadTables(); }),
        DropdownButtonFormField<int>(initialValue: _duration,
          decoration: const InputDecoration(labelText: 'Duration'),
          items: const [60, 90, 120, 180, 240].map((m) => DropdownMenuItem(
            value: m, child: Text('$m minutes'))).toList(),
          onChanged: _saving ? null : (v) { setState(() { _duration = v ?? 120; _available = null; }); _checkAvailability(); }),
        OutlinedButton.icon(onPressed: _saving ? null : _pickDate,
          icon: const Icon(Icons.calendar_month),
          label: Text(_when == null ? 'Choose date and time' : _when.toString().substring(0, 16))),
        if (_loading) const LinearProgressIndicator(),
        DropdownButtonFormField<String>(key: ValueKey('$_party-$_tableId'),
          initialValue: _tableId,
          decoration: const InputDecoration(labelText: 'Specific table'),
          items: _tables.map((t) => DropdownMenuItem<String>(
            value: t['table_id'].toString(),
            child: Text('${t['table_label']} · ${t['seats']} seats'))).toList(),
          onChanged: _saving || _loading ? null : (v) {
            setState(() { _tableId = v; _available = null; }); _checkAvailability();
          }),
        if (_available != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(_available! ? 'Table appears available (not guaranteed until confirmed)' :
            'Table unavailable at this time. Choose another table or time.',
            style: TextStyle(color: _available! ? Colors.green : Theme.of(context).colorScheme.error))),
        TextFormField(controller: _notes, maxLength: 500, maxLines: 3,
          decoration: const InputDecoration(labelText: 'Notes (optional)')),
        const SizedBox(height: 12),
        FilledButton(onPressed: _saving || _loading ? null : _submit,
          child: Text(_saving ? 'Sending...' : 'Send reservation request')),
      ])))),
  );
}
