import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Staff event intake. All writes use permission-enforcing RPCs.
class StaffEventRequestScreen extends StatefulWidget {
  const StaffEventRequestScreen({super.key});
  @override
  State<StaffEventRequestScreen> createState() => _StaffEventRequestScreenState();
}

class _StaffEventRequestScreenState extends State<StaffEventRequestScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), phone = TextEditingController();
  final eventType = TextEditingController(), services = TextEditingController();
  final product = TextEditingController(), instructions = TextEditingController();
  final quantity = TextEditingController(text: '1');
  DateTime? start, end;
  int guests = 2;
  String model = 'both';
  String venueScope = 'selected_tables';
  final Set<String> selectedTableIds = <String>{};
  List<Map<String, dynamic>> availableTables = [];
  bool loadingTables = false;
  bool busy = false;
  String? error;
  final List<Map<String, dynamic>> products = [];
  @override
  void dispose() {
    for (final c in [name,phone,eventType,services,product,instructions,quantity]) { c.dispose(); }
    super.dispose();
  }
  Future<DateTime?> pick(DateTime? initial) async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, firstDate: now,
      lastDate: now.add(const Duration(days: 365)), initialDate: initial ?? now);
    if (d == null || !mounted) return null;
    final t = await showTimePicker(context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now));
    if (t == null) return null;
    return DateTime(d.year,d.month,d.day,t.hour,t.minute);
  }
  Future<void> loadTables() async {
    if (start == null || end == null || guests < 1 || guests > 1000 ||
        !end!.isAfter(start!)) return;
    setState(() { loadingTables = true; selectedTableIds.clear(); availableTables = []; });
    try {
      final result = await Supabase.instance.client.rpc('gs_staff_event_scope_options', params: {
        'p_start': start!.toUtc().toIso8601String(),
        'p_end': end!.toUtc().toIso8601String(),
      });
      if (!mounted) return;
      setState(() => availableTables = (result as List)
          .map((row) => Map<String, dynamic>.from(row as Map)).toList());
    } catch (e) {
      if (mounted) setState(() => error = 'Could not check table availability: $e');
    } finally {
      if (mounted) setState(() => loadingTables = false);
    }
  }
  void addProduct() {
    final q = int.tryParse(quantity.text);
    if (product.text.trim().length < 2 || q == null || q < 1 || q > 10000) {
      setState(() => error = 'Enter a product name and quantity from 1 to 10,000.'); return;
    }
    setState(() { products.add({'name': product.text.trim(), 'quantity': q,
      'instructions': instructions.text.trim()}); product.clear(); instructions.clear();
      quantity.text='1'; error=null; });
  }
  Future<void> submit() async {
    if (!(form.currentState?.validate() ?? false) || start == null || end == null ||
        !start!.isAfter(DateTime.now()) || !end!.isAfter(start!) ||
        end!.difference(start!) > const Duration(hours: 24)) {
      setState(() => error = 'Provide valid details and an event lasting no more than 24 hours.'); return;
    }
    if ((model != 'rental' && products.isEmpty) || (model == 'rental' && products.isNotEmpty)) {
      setState(() => error = 'Product sales require products; rental-only must not include products.'); return;
    }
    if (venueScope == 'selected_tables' && selectedTableIds.isEmpty) {
      setState(() => error = 'Select at least one table.'); return;
    }
    final seats = availableTables.where((t) => selectedTableIds.contains(t['table_id'].toString()))
        .fold<int>(0, (total, t) => total + ((t['seats'] as num?)?.toInt() ?? 0));
    if (venueScope == 'selected_tables' && seats < guests) {
      setState(() => error = 'Selected tables cannot seat all guests.'); return;
    }
    setState(() { busy=true; error=null; });
    try {
      final db = Supabase.instance.client;
      await db.rpc('gs_staff_submit_scoped_event', params: {
        'p_customer_name': name.text.trim(), 'p_customer_phone': phone.text.trim(),
        'p_event_type': eventType.text.trim(), 'p_start': start!.toUtc().toIso8601String(),
        'p_end': end!.toUtc().toIso8601String(), 'p_guest_count': guests,
        'p_business_model': model, 'p_services': services.text.trim(),
        'p_venue_scope': venueScope, 'p_table_ids': venueScope == 'whole_venue' ? <String>[] : selectedTableIds.toList(),
        'p_products': products.map((item) => {
          'product_name': item['name'], 'quantity': item['quantity'],
          'instructions': item['instructions'],
        }).toList(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Event request submitted for Admin approval.')));
      Navigator.pop(context,true);
    } catch (e) {
      if (mounted) setState(() => error = 'Submission failed; the event and products were rolled back together. $e');
    } finally { if (mounted) setState(() => busy=false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Request café event')),
    body: Form(key: form, child: ListView(padding: const EdgeInsets.all(16), children: [
      for (final field in [(name,'Customer name'),(phone,'Phone'),(eventType,'Event type')])
        Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(
          controller: field.$1, decoration: InputDecoration(labelText: field.$2),
          validator: (v) => (v?.trim().length ?? 0)<2 ? 'Required' : null)),
      TextFormField(controller: services, maxLength: 2000,
        decoration: const InputDecoration(labelText: 'Services and event requirements')),
      DropdownButtonFormField<String>(initialValue: model,
        decoration: const InputDecoration(labelText: 'Business model'),
        items: const [DropdownMenuItem(value:'products',child:Text('Product sales only')),
          DropdownMenuItem(value:'rental',child:Text('Rental only')),
          DropdownMenuItem(value:'both',child:Text('Rental + products'))],
        onChanged: busy ? null : (v) => setState(() => model=v ?? 'both')),
      TextFormField(initialValue:'2', keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Number of guests'),
        validator: (v) { final n=int.tryParse(v ?? ''); return n==null || n<1 || n>1000 ? '1–1000 guests' : null; },
        onChanged: (v) { guests=int.tryParse(v) ?? 0; setState(() { selectedTableIds.clear(); availableTables=[]; }); }),
      ListTile(title: Text('Start: ${start ?? 'Select'}'), trailing: const Icon(Icons.event),
        onTap: busy ? null : () async { final d=await pick(start); if(d!=null) { setState(() { start=d; selectedTableIds.clear(); availableTables=[]; }); await loadTables(); } }),
      ListTile(title: Text('End: ${end ?? 'Select'}'), trailing: const Icon(Icons.schedule),
        onTap: busy ? null : () async { final d=await pick(end ?? start); if(d!=null) { setState(() { end=d; selectedTableIds.clear(); availableTables=[]; }); await loadTables(); } }),
      const SizedBox(height:12),
      OutlinedButton.icon(onPressed: busy || loadingTables ? null : loadTables,
        icon: const Icon(Icons.refresh), label: Text(loadingTables ? 'Checking tables...' : 'Check available tables')),
      const SizedBox(height: 12),
      const Text('Event space', style: TextStyle(fontWeight: FontWeight.bold)),
      RadioListTile<String>(title: const Text('Entire café'),
        value: 'whole_venue', groupValue: venueScope,
        onChanged: busy ? null : (v) => setState(() { venueScope=v!; selectedTableIds.clear(); })),
      RadioListTile<String>(title: const Text('Selected tables'),
        value: 'selected_tables', groupValue: venueScope,
        onChanged: busy ? null : (v) => setState(() => venueScope=v!)),
      if (venueScope == 'selected_tables') ...[
        Text('Selected capacity: ${availableTables.where((t) => selectedTableIds.contains(t['table_id'].toString())).fold<int>(0,(sum,t) => sum + ((t['seats'] as num?)?.toInt() ?? 0))} / $guests guests'),
        for (final t in availableTables)
          CheckboxListTile(title: Text('${t['table_label']} — ${t['seats']} seats'),
            value: selectedTableIds.contains(t['table_id'].toString()),
            onChanged: busy ? null : (value) => setState(() {
              if (value == true) { selectedTableIds.add(t['table_id'].toString()); }
              else { selectedTableIds.remove(t['table_id'].toString()); }
            })),
      ],
      const Text('Availability is a preview; Admin approval checks conflicts again.'),
      const SizedBox(height:12),
      const Text('Advance product quantities', style: TextStyle(fontWeight: FontWeight.bold)),
      TextField(controller: product, decoration: const InputDecoration(labelText:'Product name')),
      TextField(controller: quantity, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText:'Quantity')),
      TextField(controller: instructions, decoration: const InputDecoration(labelText:'Preparation instructions')),
      TextButton.icon(onPressed: busy ? null : addProduct,
        icon: const Icon(Icons.add), label: const Text('Add product')),
      for (var i=0;i<products.length;i++) ListTile(
        title: Text('${products[i]['name']} × ${products[i]['quantity']}'),
        subtitle: Text('${products[i]['instructions']}'),
        trailing: IconButton(icon: const Icon(Icons.delete_outline),
          onPressed: busy ? null : () => setState(() => products.removeAt(i)))),
      if (error!=null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      const SizedBox(height:12),
      FilledButton(onPressed: busy ? null : submit,
        child: Text(busy ? 'Submitting...' : 'Submit for Admin approval')),
      const Text('No reservation, kitchen ticket or payment is confirmed by this request.'),
    ])),
  );
}
