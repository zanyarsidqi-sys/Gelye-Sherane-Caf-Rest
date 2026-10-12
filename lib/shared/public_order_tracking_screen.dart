import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PublicOrderTrackingScreen extends StatefulWidget {
  const PublicOrderTrackingScreen({super.key, this.initialToken});
  final String? initialToken;
  @override
  State<PublicOrderTrackingScreen> createState() => _PublicOrderTrackingScreenState();
}
class _PublicOrderTrackingScreenState extends State<PublicOrderTrackingScreen> {
  late final TextEditingController _token = TextEditingController(text: widget.initialToken ?? '');
  Map<String, dynamic>? _order;
  bool _loading = false;
  String? _message;
  @override
  void dispose() { _token.dispose(); super.dispose(); }
  Future<void> _check() async {
    final token = _token.text.trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(token)) {
      setState(() { _order = null; _message = 'Enter the 64-character tracking code.'; }); return;
    }
    setState(() { _loading = true; _message = null; });
    try {
      final result = await Supabase.instance.client.rpc('gs_track_public_order', params: {'p_token': token});
      if (!mounted) return;
      setState(() { _order = result == null ? null : Map<String, dynamic>.from(result as Map); _message = result == null ? 'Order not found.' : null; });
    } catch (_) {
      if (mounted) setState(() { _order = null; _message = 'Tracking unavailable. Try again later.'; });
    } finally { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Track your order')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Keep your tracking code private. Anyone with this code can see the order status.'),
      const SizedBox(height: 12),
      TextField(controller: _token, autocorrect: false, enableSuggestions: false,
        decoration: InputDecoration(labelText: 'Tracking code', border: const OutlineInputBorder(),
          suffixIcon: IconButton(tooltip: 'Paste', icon: const Icon(Icons.paste), onPressed: () async {
            final data = await Clipboard.getData('text/plain'); if (data?.text != null) _token.text = data!.text!;
          }))),
      const SizedBox(height: 12),
      FilledButton(onPressed: _loading ? null : _check, child: Text(_loading ? 'Checking...' : 'Check status')),
      if (_message != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_message!)),
      if (_order != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Status: ${_order!['status']}', style: Theme.of(context).textTheme.titleLarge),
          Text('Total: ${_order!['total_iqd']} IQD'),
          for (final item in (_order!['items'] as List? ?? []))
            Text('${item['name']} × ${item['quantity']}'),
          const SizedBox(height: 8),
          const Text('Pending orders require staff acceptance.'),
        ]))),
    ]),
  );
}
