import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Customer-facing event planning preview. Public submissions require a
/// separately deployed, rate-limited and CAPTCHA-verified server endpoint.
class PublicEventRequestScreen extends StatefulWidget {
  const PublicEventRequestScreen({super.key});
  @override
  State<PublicEventRequestScreen> createState() => _PublicEventRequestScreenState();
}

class _PublicEventRequestScreenState extends State<PublicEventRequestScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final eventType = TextEditingController();
  final product = TextEditingController();
  final quantity = TextEditingController(text: '1');
  DateTime? start;
  int guests = 2;
  int durationMinutes = 120;
  final notes = TextEditingController();
  String model = 'both';
  String venueScope = 'selected_tables';
  final List<Map<String, dynamic>> products = [];
  bool get selectedTablesFit => venueScope == 'whole_venue' ||
      (selectedTableIds.isNotEmpty && selectedCapacity >= guests);

  Map<String, dynamic> buildRequestPreview() => {
    'customer_name': name.text.trim(),
    'customer_phone': phone.text.trim(),
    'event_type': eventType.text.trim(),
    'event_start': start?.toUtc().toIso8601String(),
    'event_end': start?.add(Duration(minutes: durationMinutes)).toUtc().toIso8601String(),
    'guest_count': guests,
    'business_model': model,
    'requested_services': notes.text.trim(),
    'venue_scope': venueScope,
    'table_ids': venueScope == 'selected_tables' ? selectedTableIds.toList() : <String>[],
    'products': model == 'rental' ? <Map<String, dynamic>>[] : products,
  };
  List<Map<String, dynamic>> availableTables = [];
  final Set<String> selectedTableIds = {};
  bool loadingTables = false;
  String? availabilityError;
  bool? wholeVenueAvailable;
  int availabilityRequestId = 0;

  int get selectedCapacity => availableTables.where(
    (table) => selectedTableIds.contains(table['table_id'].toString()),
  ).fold<int>(0, (sum, table) => sum + ((table['seats'] as num?)?.toInt() ?? 0));

  Future<void> loadAvailability() async {
    if (start == null) return;
    final requestId = ++availabilityRequestId;
    setState(() { loadingTables = true; availabilityError = null;
      availableTables = []; selectedTableIds.clear(); wholeVenueAvailable = null; });
    try {
      final result = await Supabase.instance.client.rpc('gs_public_event_available_tables',
        params: {
          'p_start': start!.toUtc().toIso8601String(),
          'p_end': start!.add(Duration(minutes: durationMinutes)).toUtc().toIso8601String(),
        });
      final venueResult = await Supabase.instance.client.rpc(
        'gs_public_event_whole_venue_available',
        params: {
          'p_start': start!.toUtc().toIso8601String(),
          'p_end': start!.add(Duration(minutes: durationMinutes)).toUtc().toIso8601String(),
        },
      );
      if (!mounted || requestId != availabilityRequestId) return;
      setState(() {
        availableTables = (result as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();
        wholeVenueAvailable = venueResult == true;
      });
    } catch (_) {
      if (!mounted || requestId != availabilityRequestId) return;
      setState(() => availabilityError = 'Availability could not be loaded. Please try again.');
    } finally {
      if (mounted && requestId == availabilityRequestId) setState(() => loadingTables = false);
    }
  }

  @override
  void dispose() {
    availabilityRequestId++;
    for (final c in [name, phone, eventType, product, quantity, notes]) { c.dispose(); }
    super.dispose();
  }

  Future<void> chooseDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, firstDate: now,
      lastDate: now.add(const Duration(days: 365)), initialDate: now);
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0));
    if (time == null || !mounted) return;
    setState(() => start = DateTime(date.year, date.month, date.day, time.hour, time.minute));
    await loadAvailability();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Plan a café event')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Preview only — public submissions are not enabled until secure verification and rate limiting are deployed.'),
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Customer name')),
      TextField(controller: phone, keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'Phone number')),
      TextField(controller: eventType, decoration: const InputDecoration(labelText: 'Event type')),
      ListTile(title: Text(start == null ? 'Select event date and start time' : start.toString()),
        trailing: const Icon(Icons.event), onTap: chooseDate),
      DropdownButtonFormField<int>(value: durationMinutes,
        decoration: const InputDecoration(labelText: 'Event duration'),
        items: const [60, 90, 120, 180, 240, 360, 480]
          .map((minutes) => DropdownMenuItem(value: minutes,
            child: Text('$minutes minutes'))).toList(),
        onChanged: (value) { setState(() => durationMinutes = value ?? 120); loadAvailability(); }),
      ListTile(title: Text('Guests: $guests'), trailing: SizedBox(width: 160,
        child: Slider(value: guests.toDouble(), min: 1, max: 200, divisions: 199,
          onChanged: (v) => setState(() => guests = v.round())))),
      const Text('Event space', style: TextStyle(fontWeight: FontWeight.bold)),
      RadioListTile<String>(title: const Text('Entire café'),
        subtitle: const Text('Subject to Admin approval and full venue availability'),
        value: 'whole_venue', groupValue: venueScope,
        onChanged: (v) => setState(() => venueScope = v ?? 'whole_venue')),
      RadioListTile<String>(title: const Text('Selected tables'),
        subtitle: const Text('Select available tables for your event'),
        value: 'selected_tables', groupValue: venueScope,
        onChanged: (v) => setState(() => venueScope = v ?? 'selected_tables')),
      if (start != null) ...[
        Row(children: [
          const Expanded(child: Text('Table availability')),
          TextButton.icon(onPressed: loadingTables ? null : loadAvailability,
            icon: const Icon(Icons.refresh), label: const Text('Refresh')),
        ]),
        if (loadingTables) const LinearProgressIndicator(),
        if (availabilityError != null) Text(availabilityError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (venueScope == 'selected_tables') ...[
          ...availableTables.map((table) {
            final id = table['table_id'].toString();
            final seats = (table['seats'] as num?)?.toInt() ?? 0;
            return CheckboxListTile(
              title: Text(table['table_label']?.toString() ?? 'Table'),
              subtitle: Text('$seats seats'),
              value: selectedTableIds.contains(id),
              onChanged: (checked) => setState(() {
                if (checked == true && selectedTableIds.length < 30) {
                  selectedTableIds.add(id);
                } else if (checked == false) {
                  selectedTableIds.remove(id);
                }
              }),
            );
          }),
          Text('Selected: ${selectedTableIds.length} tables · '
            '$selectedCapacity seats · $guests guests'),
          if (selectedTableIds.isNotEmpty && selectedCapacity < guests)
            Text('Select more tables to fit all guests.',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ] else ...[
          if (wholeVenueAvailable == true)
            const Text('Entire café is currently available for the selected time.'),
          if (wholeVenueAvailable == false)
            Text('The entire café is unavailable for this time.',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (wholeVenueAvailable == null)
            const Text('Check whole-café availability before requesting.'),
          const Text('Availability is provisional until Admin approval.'),
        ],
      ],
      DropdownButtonFormField<String>(value: model,
        decoration: const InputDecoration(labelText: 'Payment model'),
        items: const [
          DropdownMenuItem(value: 'products', child: Text('Products only')),
          DropdownMenuItem(value: 'rental', child: Text('Rental only')),
          DropdownMenuItem(value: 'both', child: Text('Rental + products')),
        ], onChanged: (v) => setState(() => model = v ?? 'both')),
      if (model != 'rental') ...[
        TextField(controller: product, decoration: const InputDecoration(labelText: 'Requested product')),
        TextField(controller: quantity, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity')),
        TextButton(onPressed: () {
          final n = int.tryParse(quantity.text);
          if (product.text.trim().isNotEmpty && n != null && n > 0 && n <= 10000) {
            setState(() => products.add({'product_name': product.text.trim(), 'quantity': n, 'instructions': ''}));
            product.clear();
          }
        }, child: const Text('Add product quantity')),
        ...products.asMap().entries.map((entry) => ListTile(
          title: Text("${entry.value['product_name']} × ${entry.value['quantity']}"),
          trailing: IconButton(icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Remove product',
            onPressed: () => setState(() => products.removeAt(entry.key))))),
      ],
      TextField(controller: notes, maxLines: 3, maxLength: 2000,
        decoration: const InputDecoration(labelText: 'Event arrangements and special requests')),
      if (start != null) ListTile(title: const Text('Event ends'),
        subtitle: Text(start!.add(Duration(minutes: durationMinutes)).toString())),
      const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Request review', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Space: ${venueScope == 'whole_venue' ? 'Entire café' : '${selectedTableIds.length} selected tables'}'),
          Text('Guests: $guests'),
          Text('Service: ${model == 'both' ? 'Rental + products' : model}'),
          Text('Advance products: ${model == 'rental' ? 0 : products.length}'),
          if (venueScope == 'selected_tables' && !selectedTablesFit)
            Text('Selected seating does not cover all guests.',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const Text('This request does not reserve a table until Admin approval.'),
        ],
      ))),
      const FilledButton(onPressed: null, child: Text('Submission available after security deployment')),
    ]),
  );
}
