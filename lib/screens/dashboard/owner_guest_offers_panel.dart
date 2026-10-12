import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only owner guest approvals. Only server-side verified approvals count.
class OwnerGuestOffersPanel extends StatefulWidget {
  const OwnerGuestOffersPanel({super.key});
  @override
  State<OwnerGuestOffersPanel> createState() => _OwnerGuestOffersPanelState();
}
class _OwnerGuestOffersPanelState extends State<OwnerGuestOffersPanel> {
  late Future<List<Map<String,dynamic>>> _offers = _load();
  Future<List<Map<String,dynamic>>> _load() async {
    final result = await Supabase.instance.client.rpc('gs_dashboard_owner_guest_offers');
    return (result as List).map((e) => Map<String,dynamic>.from(e as Map)).toList();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Owner Guest Offers'), actions: [
      IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh',
        onPressed: () => setState(() => _offers = _load())),
    ]),
    body: FutureBuilder<List<Map<String,dynamic>>>(
      future: _offers,
      builder: (context,snapshot) {
        if (snapshot.hasError) return const Center(child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Owner offers unavailable. Verify access and deploy the backend first.')));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty) return const Center(child: Text('No owner offers recorded.'));
        return ListView(children: [
          for (final r in snapshot.data!) Card(child: ListTile(
            leading: Icon(r['status']=='verified' ? Icons.verified_user : Icons.pending_actions),
            title: Text('Table ${r['table_reference'] ?? '—'} · ${r['status'] ?? '—'}'),
            subtitle: Text('Complimentary: ${r['complimentary_amount_iqd'] ?? 0} IQD\n'
              'Owner approval: ${r['verified_at'] ?? 'Not verified'}'),
            isThreeLine: true,
          )),
        ]);
      },
    ),
  );
}
