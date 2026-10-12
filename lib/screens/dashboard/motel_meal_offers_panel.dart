import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only motel meal delivery queue. The server must validate reservation
/// access, barcode identity, package entitlements and verified payment status.
class MotelMealOffersPanel extends StatefulWidget {
  const MotelMealOffersPanel({super.key});
  @override
  State<MotelMealOffersPanel> createState() => _MotelMealOffersPanelState();
}

class _MotelMealOffersPanelState extends State<MotelMealOffersPanel> {
  late Future<List<Map<String, dynamic>>> _rows = _load();
  String _filter = 'upcoming';

  Future<List<Map<String, dynamic>>> _load() async {
    final result = await Supabase.instance.client.rpc(
      'gs_dashboard_motel_meal_offers',
      params: {'p_filter': _filter},
    );
    return (result as List)
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _refresh() => setState(() => _rows = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Motel Meal Offers'), actions: [
      IconButton(tooltip: 'Refresh', onPressed: _refresh,
        icon: const Icon(Icons.refresh)),
    ]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'upcoming', label: Text('Upcoming')),
          ButtonSegment(value: 'all', label: Text('All')),
        ],
        selected: {_filter},
        onSelectionChanged: (selected) {
          setState(() { _filter = selected.first; _rows = _load(); });
        },
      )),
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _rows,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('Motel meal offers unavailable. Backend migration or access may not be ready.')));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snapshot.data!;
          if (rows.isEmpty) return const Center(child: Text('No scheduled motel meals.'));
          return ListView.builder(itemCount: rows.length, itemBuilder: (context, index) {
            final r = rows[index];
            return Card(child: ListTile(
              leading: const Icon(Icons.room_service_outlined),
              title: Text('Room ${r['room_label'] ?? '—'} · ${r['delivery_status'] ?? 'Scheduled'}'),
              subtitle: Text(
                'Delivery: ${r['scheduled_delivery_at'] ?? '—'}\n'
                'Payment: ${r['payment_status'] ?? 'Unverified'} · '
                '${r['payment_mode'] ?? 'Unknown'}'),
              isThreeLine: true,
              onTap: () => showDialog<void>(context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Motel meal details'),
                  content: SingleChildScrollView(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reservation: ${r['reservation_reference'] ?? '—'}'),
                      Text('Room: ${r['room_label'] ?? '—'}'),
                      Text('Requested arrival: ${r['scheduled_delivery_at'] ?? '—'}'),
                      Text('Payment arrangement: ${r['payment_mode'] ?? '—'}'),
                      Text('Verified payment: ${r['payment_status'] ?? '—'}'),
                      Text('Order: ${r['meal_summary'] ?? '—'}'),
                    ],
                  )),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'))],
                )),
            ));
          });
        },
      )),
    ]),
  );
}
