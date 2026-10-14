import 'public_event_request_screen.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'public_reservation_screen.dart';
import 'public_online_order_screen.dart';
import 'public_order_tracking_screen.dart';
import '../services/menu_management_service.dart';

/// Public, read-only view of approved menu data.
class PublicMenuScreen extends StatefulWidget {
  const PublicMenuScreen({super.key});
  @override
  State<PublicMenuScreen> createState() => _PublicMenuScreenState();
}

class _PublicMenuScreenState extends State<PublicMenuScreen> {
  final MenuManagementService _menuService = MenuManagementService();
  late Future<List<Map<String, dynamic>>> _items = _fetch();
  String _query = '';
  String _category = 'All';
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
      // Public menu stays usable if optional table presence tracking is down.
    }
  }

  @override
  void dispose() {
    _qrHeartbeat?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final result = await Supabase.instance.client.rpc('gs_menu_public_catalog');
    return (result as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> _refresh() async {
    final next = _fetch();
    setState(() => _items = next);
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F0E8),
    appBar: AppBar(
      backgroundColor: const Color(0xFF071D31),
      foregroundColor: Colors.white,
      title: Row(children: [
        const Icon(Icons.local_cafe_rounded, color: Color(0xFFF1CD7B)),
        const SizedBox(width: 10),
        const Text('Gelye Sherane'),
      ]),
      actions: [
        IconButton(tooltip: 'Refresh approved menu', onPressed: _refresh, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
          return const _PublicMenuLoading();
        }
        if (snapshot.hasError) {
          return _PublicMenuError(onRetry: _refresh);
        }
        final rows = snapshot.data ?? <Map<String, dynamic>>[];
        final categories = <String>{
          'All',
          ...rows.map((row) => '${row['category'] ?? ''}').where((value) => value.trim().isNotEmpty),
        }.toList();
        final filtered = rows.where((row) {
          final text = '${row['name'] ?? ''} ${row['description'] ?? ''}'.toLowerCase();
          return text.contains(_query.trim().toLowerCase()) &&
              (_category == 'All' || '${row['category'] ?? ''}' == _category);
        }).toList();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: LayoutBuilder(builder: (context, constraints) {
            final narrow = constraints.maxWidth < 700;
            final columns = constraints.maxWidth >= 1120 ? 4 : constraints.maxWidth >= 760 ? 3 : constraints.maxWidth >= 520 ? 2 : 1;
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _PublicMenuHero(
                    count: rows.length,
                    narrow: narrow,
                    query: _query,
                    onQuery: (value) => setState(() => _query = value),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 56,
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: narrow ? 18 : 34),
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) => ChoiceChip(
                        label: Text(categories[index]),
                        selected: _category == categories[index],
                        onSelected: (_) => setState(() => _category = categories[index]),
                        showCheckmark: false,
                      ),
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.menu_book_outlined, size: 38, color: Color(0xFF88795F)),
                        const SizedBox(height: 12),
                        Text(rows.isEmpty ? 'The menu is being refreshed.' : 'No dishes match that search.',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 5),
                        Text(rows.isEmpty ? 'Please check back shortly.' : 'Try a different dish or category.',
                          style: const TextStyle(color: Color(0xFF6D6A63))),
                      ]),
                    )),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(narrow ? 16 : 34, 4, narrow ? 16 : 34, 20),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        mainAxisExtent: narrow && columns == 1 ? 327 : 300,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _PublicDishCard(
                          item: filtered[index],
                          service: _menuService,
                        ),
                        childCount: filtered.length,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _PublicActions(
                    onOrder: () => _navigate(const PublicOnlineOrderScreen()),
                    onReserve: () => _navigate(const PublicReservationScreen()),
                    onEvent: () => _navigate(const PublicEventRequestScreen()),
                    onTrack: () => _navigate(const PublicOrderTrackingScreen()),
                  ),
                ),
              ],
            );
          }),
        );
      },
    ),
  );

  void _navigate(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

class _PublicMenuHero extends StatelessWidget {
  const _PublicMenuHero({required this.count, required this.narrow, required this.query, required this.onQuery});
  final int count;
  final bool narrow;
  final String query;
  final ValueChanged<String> onQuery;
  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.fromLTRB(narrow ? 16 : 34, 20, narrow ? 16 : 34, 18),
    padding: EdgeInsets.all(narrow ? 20 : 30),
    decoration: BoxDecoration(
      color: const Color(0xFF102C44),
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [BoxShadow(color: Color(0x16071D31), blurRadius: 22, offset: Offset(0, 9))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(color: const Color(0xFFD9A744).withValues(alpha: .18), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.coffee_rounded, color: Color(0xFFF1CD7B), size: 24),
        ),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Gelye Sherane', style: TextStyle(color: const Color(0xFFF1CD7B), fontSize: narrow ? 17 : 19, fontWeight: FontWeight.w800)),
          const Text('CAFÉ & RESTAURANT', style: TextStyle(color: Color(0xFFCAD4DC), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
        ])),
        Text('$count dishes', style: const TextStyle(color: Color(0xFFD8E0E5), fontSize: 12)),
      ]),
      const SizedBox(height: 22),
      Text('A good table starts here.', style: TextStyle(color: Colors.white, fontSize: narrow ? 27 : 34, height: 1.08, fontWeight: FontWeight.w800, letterSpacing: -.7)),
      const SizedBox(height: 6),
      const Text('Made for slow mornings, long lunches and everything between.', style: TextStyle(color: Color(0xFFC5D0D8), fontSize: 14)),
      const SizedBox(height: 17),
      TextField(
        onChanged: onQuery,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: 'Find a dish or drink',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: query.isEmpty ? null : IconButton(onPressed: () => onQuery(''), icon: const Icon(Icons.close), tooltip: 'Clear search'),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
        ),
      ),
    ]),
  );
}

class _PublicDishCard extends StatelessWidget {
  const _PublicDishCard({required this.item, required this.service});
  final Map<String, dynamic> item;
  final MenuManagementService service;
  @override
  Widget build(BuildContext context) {
    final imageUrl = service.publicImageUrl('${item['image_path'] ?? ''}');
    final price = item['price_iqd'] ?? item['normal_price_iqd'];
    final category = '${item['category'] ?? 'Café favourites'}';
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19), side: const BorderSide(color: Color(0xFFE7E0D4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            if (imageUrl != null)
              Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const _DishPlaceholder())
            else
              const _DishPlaceholder(),
            Positioned(
              top: 11, left: 11,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF102C44).withValues(alpha: .91), borderRadius: BorderRadius.circular(20)),
                child: Text(category, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${item['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF102C44)))),
              const SizedBox(width: 8),
              Text(price == null ? 'Ask us' : '${_publicPrice(price)} IQD', style: const TextStyle(color: Color(0xFF775B23), fontWeight: FontWeight.w800, fontSize: 12)),
            ]),
            const SizedBox(height: 5),
            Text('${item['description'] ?? 'Prepared fresh at Gelye Sherane.'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6E6A62), fontSize: 12, height: 1.3)),
          ]),
        ),
      ]),
    );
  }
}

class _DishPlaceholder extends StatelessWidget {
  const _DishPlaceholder();
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFEAE2D4),
    child: const Center(child: Icon(Icons.local_dining_rounded, size: 46, color: Color(0xFF9B8760))),
  );
}

class _PublicActions extends StatelessWidget {
  const _PublicActions({required this.onOrder, required this.onReserve, required this.onEvent, required this.onTrack});
  final VoidCallback onOrder;
  final VoidCallback onReserve;
  final VoidCallback onEvent;
  final VoidCallback onTrack;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(18, 4, 18, 28),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: const Color(0xFF102C44), borderRadius: BorderRadius.circular(20)),
    child: Column(children: [
      const Text('Stay a little longer.', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      const Text('Order ahead, book your table or celebrate with us.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFC8D2DA))),
      const SizedBox(height: 15),
      Wrap(alignment: WrapAlignment.center, spacing: 9, runSpacing: 9, children: [
        FilledButton.icon(onPressed: onOrder, icon: const Icon(Icons.shopping_bag_outlined), label: const Text('Order online')),
        OutlinedButton.icon(onPressed: onReserve, icon: const Icon(Icons.event_seat_outlined), label: const Text('Request a table'), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0xFF708397)))),
        OutlinedButton.icon(onPressed: onEvent, icon: const Icon(Icons.celebration_outlined), label: const Text('Plan an event'), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0xFF708397)))),
        TextButton.icon(onPressed: onTrack, icon: const Icon(Icons.local_shipping_outlined, color: Color(0xFFF1CD7B)), label: const Text('Track order', style: TextStyle(color: Color(0xFFF1CD7B)))),
      ]),
      const SizedBox(height: 10),
      const Text('Orders and reservations are requests until accepted by staff.', style: TextStyle(color: Color(0xFFAEBCC7), fontSize: 11), textAlign: TextAlign.center),
    ]),
  );
}

class _PublicMenuLoading extends StatelessWidget {
  const _PublicMenuLoading();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      Container(height: 235, decoration: BoxDecoration(color: const Color(0xFFE1DED7), borderRadius: BorderRadius.circular(22))),
      const SizedBox(height: 20),
      Wrap(spacing: 12, runSpacing: 12, children: List.generate(4, (_) => Container(
        width: 220, height: 255, decoration: BoxDecoration(color: const Color(0xFFE6E2DA), borderRadius: BorderRadius.circular(18)),
      ))),
    ],
  );
}

class _PublicMenuError extends StatelessWidget {
  const _PublicMenuError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_off_outlined, size: 40, color: Color(0xFF8B7652)),
      const SizedBox(height: 12),
      const Text('Menu is unavailable right now.', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      const SizedBox(height: 6),
      const Text('Please check your connection and try again.', textAlign: TextAlign.center),
      const SizedBox(height: 13),
      FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
    ]),
  ));
}

String _publicPrice(Object value) {
  final number = value is num ? value.toInt() : int.tryParse('$value');
  if (number == null) return '$value';
  return number.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}
