import 'public_event_request_screen.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'public_reservation_screen.dart';
import 'public_online_order_screen.dart';
import 'public_order_tracking_screen.dart';

/// Public read-only menu. Never exposes internal cost or tourism pricing.
class PublicMenuScreen extends StatefulWidget {
  const PublicMenuScreen({super.key});
  @override
  State<PublicMenuScreen> createState() => _PublicMenuScreenState();
}

class _PublicMenuScreenState extends State<PublicMenuScreen> {
  late Future<List<Map<String, dynamic>>> _items = _fetch();
  String _query = '';
  Timer? _qrHeartbeat;
  String? _qrToken;
  late final String _qrSessionId = _newSessionId();

  String _newSessionId() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  void initState() {
    super.initState();
    // Only the public menu route with a valid table QR token is tracked.
    _qrToken = Uri.base.queryParameters['token'];
    if (_qrToken != null && _qrToken!.isNotEmpty) {
      _reportQrSession();
      _qrHeartbeat = Timer.periodic(const Duration(seconds: 45), (_) => _reportQrSession());
    }
  }

  Future<void> _reportQrSession() async {
    final token = _qrToken;
    if (!mounted || token == null) return;
    try {
      await Supabase.instance.client.rpc('gs_touch_public_table_qr_session', params: {
        'p_token': token, 'p_session_key': _qrSessionId,
      });
    } catch (_) {
      // Public menu must remain usable even if presence tracking fails.
    }
  }

  @override
  void dispose() {
    _qrHeartbeat?.cancel();
    super.dispose();
  }


  Future<List<Map<String, dynamic>>> _fetch() async {
    final result = await Supabase.instance.client.rpc('gs_public_menu');
    return (result as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  void _refresh() => setState(() => _items = _fetch());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Our Menu')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Menu is unavailable right now.'),
            TextButton(onPressed: _refresh, child: const Text('Try again')),
          ]));
        }
        final rows = snapshot.data ?? [];
        final filtered = rows.where((row) =>
          (row['name']?.toString().toLowerCase() ?? '').contains(_query.toLowerCase())).toList();
        return RefreshIndicator(
          onRefresh: () async { _refresh(); await _items; },
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextField(onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search menu', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            if (filtered.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No menu items available.'))),
            ...filtered.map((item) => Card(child: ListTile(
              title: Text(item['name']?.toString() ?? ''),
              trailing: Text('${item['price_iqd']} IQD'),
            ))),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PublicOnlineOrderScreen())), icon: const Icon(Icons.shopping_cart_checkout), label: const Text('Order online')),
            FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PublicReservationScreen())), icon: const Icon(Icons.event_available), label: const Text('Request a table')),
            OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PublicEventRequestScreen())), icon: const Icon(Icons.celebration), label: const Text('Plan an event')),
            OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PublicOrderTrackingScreen())), icon: const Icon(Icons.local_shipping_outlined), label: const Text('Track an order')),
            const Text('Orders and reservations are requests until accepted by staff.', textAlign: TextAlign.center),
          ]),
        );
      },
    ),
  );
}
