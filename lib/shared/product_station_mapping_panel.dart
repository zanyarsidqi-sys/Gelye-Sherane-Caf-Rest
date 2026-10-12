import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Kitchen-only product preparation routing. The database RPC enforces
/// supervisor, station scope and Menu edit permissions; UI checks are additive.
class ProductStationMappingPanel extends StatefulWidget {
  const ProductStationMappingPanel({super.key});
  @override
  State<ProductStationMappingPanel> createState() => _ProductStationMappingPanelState();
}

class _ProductStationMappingPanelState extends State<ProductStationMappingPanel> {
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> stations = [];
  String filter = '';
  String? error;
  bool loading = true;
  bool saving = false;
  String? activeProduct;
  int generation = 0;
  String? loadedUserId;

  @override
  void initState() { super.initState(); reload(); }

  bool sessionMatches(String? uid) => uid != null &&
      Supabase.instance.client.auth.currentUser?.id == uid;

  Future<void> reload() async {
    final request = ++generation;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    setState(() { loading = true; error = null; products = []; stations = []; loadedUserId = null; });
    if (uid == null) {
      if (mounted) setState(() { loading = false; error = 'Employee sign-in required.'; });
      return;
    }
    try {
      final results = await Future.wait([
        Supabase.instance.client.rpc('gs_1217_product_station_directory'),
        Supabase.instance.client.rpc('gs_1217_station_directory'),
      ]);
      if (!mounted || request != generation || !sessionMatches(uid)) return;
      final rows = (results[0] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final allowed = (results[1] as List).map((e) => Map<String, dynamic>.from(e as Map))
          .where((s) => s['enabled'] == true && (s['station_key']?.toString().trim().isNotEmpty ?? false)).toList();
      setState(() { products = rows; stations = allowed; loadedUserId = uid; });
    } catch (_) {
      if (mounted && request == generation) setState(() => error = 'Unable to load authorized product routing.');
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> assign(Map<String, dynamic> product, String key) async {
    final uid = loadedUserId;
    final productId = product['product_id'];
    if (saving || !sessionMatches(uid) || productId == null ||
        !stations.any((s) => s['station_key']?.toString() == key)) return;
    final old = product['station_key']?.toString();
    if (old == key) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm station routing'),
        content: Text('Route ${product['product_name'] ?? 'this product'} to '
            '${stations.firstWhere((s) => s['station_key']?.toString() == key)['display_name'] ?? key}? '
            'Existing preparation tickets will not be changed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (approved != true || !mounted || !sessionMatches(uid) || saving) return;
    setState(() { saving = true; activeProduct = productId.toString(); });
    try {
      await Supabase.instance.client.rpc('gs_set_product_preparation_station',
          params: {'p_product_id': productId, 'p_station_key': key});
      if (!mounted || !sessionMatches(uid)) return;
      await reload();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Routing failed. Check station scope and Menu edit permission.'),
      ));
    } finally {
      if (mounted) setState(() { saving = false; activeProduct = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loadedUserId != null && !sessionMatches(loadedUserId)) {
      return Center(child: FilledButton(onPressed: reload, child: const Text('Session changed — reload')));
    }
    final shown = products.where((p) =>
        (p['product_name']?.toString() ?? '').toLowerCase().contains(filter.toLowerCase())).toList();
    return Column(children: [
      ListTile(title: const Text('Product preparation routing'),
        subtitle: const Text('Kitchen stations only. Existing order tickets keep their original routing.'),
        trailing: IconButton(onPressed: saving ? null : reload, icon: const Icon(Icons.refresh))),
      Padding(padding: const EdgeInsets.all(8), child: TextField(
        decoration: const InputDecoration(labelText: 'Find product', prefixIcon: Icon(Icons.search)),
        onChanged: (v) => setState(() => filter = v))),
      if (error != null) Padding(padding: const EdgeInsets.all(8), child: Text(error!)),
      if (loading || saving) const LinearProgressIndicator(),
      if (!loading && stations.isEmpty) const ListTile(title: Text('No authorized active stations'),
        subtitle: Text('Create or request access to a station in Kitchen → Stations.')),
      Expanded(child: ListView.builder(itemCount: shown.length, itemBuilder: (context, i) {
        final p = shown[i];
        final current = p['station_key']?.toString();
        final busy = saving || loading || stations.isEmpty;
        return ListTile(
          title: Text(p['product_name']?.toString() ?? 'Unnamed product'),
          subtitle: Text(current == null || current.isEmpty
              ? 'No station assigned' : 'Current: ${p['station_name'] ?? current}'),
          trailing: activeProduct == p['product_id']?.toString()
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator())
              : PopupMenuButton<String>(enabled: !busy, tooltip: 'Assign preparation station',
                  onSelected: (v) => assign(p, v),
                  itemBuilder: (context) => stations.map((s) => PopupMenuItem<String>(
                    value: s['station_key'].toString(),
                    child: Text(s['display_name']?.toString() ?? s['station_key'].toString()),
                  )).toList()),
        );
      })),
    ]);
  }
}
