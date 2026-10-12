import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_language.dart';

/// Public QR entry: identifies a physical room, never a guest or active stay.
/// Protected ordering, status and billing must be enabled only after a separate
/// server-verified, stay-scoped guest session is implemented.
class CustomerMotelRoomQrScreen extends StatefulWidget {
  const CustomerMotelRoomQrScreen({super.key, required this.token});
  final String token;

  @override
  State<CustomerMotelRoomQrScreen> createState() => _CustomerMotelRoomQrScreenState();
}

class _CustomerMotelRoomQrScreenState extends State<CustomerMotelRoomQrScreen> {
  late Future<Map<String, dynamic>?> _room = _identify();
  final _access = TextEditingController();
  final _mealDetails = TextEditingController();
  DateTime? _mealTime;
  bool _sendingMeal = false;
  String? _mealFeedback;
  bool _loadingMealStatus = false;
  List<Map<String, dynamic>> _mealStatuses = [];
  String? _mealStatusError;
  Future<void> _loadMealStatus() async {
    if (!_verified || _loadingMealStatus) return;
    final accessAtStart = _access.text.trim();
    final roomAtStart = widget.token;
    setState(() { _loadingMealStatus = true; _mealStatusError = null; });
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_public_motel_meal_status', params: {
          'p_room_token': roomAtStart, 'p_access_token': accessAtStart,
        });
      if (!mounted || !_verified || widget.token != roomAtStart ||
          _access.text.trim() != accessAtStart) return;
      setState(() => _mealStatuses = (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList());
    } catch (_) {
      if (mounted && widget.token == roomAtStart && _access.text.trim() == accessAtStart) {
        setState(() { _mealStatuses = []; _mealStatusError = 'Unable to load meal requests. Verify your access again.'; });
      }
    } finally {
      if (mounted) setState(() => _loadingMealStatus = false);
    }
  }
  bool _loadingFoodStatus = false;
  List<Map<String, dynamic>> _foodStatuses = [];
  String? _foodStatusError;

  Future<void> _loadFoodStatus() async {
    if (!_verified || _loadingFoodStatus) return;
    final accessAtStart = _access.text.trim();
    final roomAtStart = widget.token;
    setState(() { _loadingFoodStatus = true; _foodStatusError = null; });
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_public_motel_food_order_status', params: {
          'p_room_token': roomAtStart, 'p_access_token': accessAtStart,
        });
      if (!mounted || !_verified || widget.token != roomAtStart ||
          _access.text.trim() != accessAtStart) return;
      setState(() => _foodStatuses = (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList());
    } catch (_) {
      if (mounted && widget.token == roomAtStart &&
          _access.text.trim() == accessAtStart) {
        setState(() { _foodStatuses = [];
          _foodStatusError = 'Unable to load food orders. Verify your access again.'; });
      }
    } finally {
      if (mounted) setState(() => _loadingFoodStatus = false);
    }
  }

  final Map<int, int> _cart = {};
  bool _sendingOrder = false;
  String? _orderFeedback;
  String? _orderRequestId;
  int get _cartCount => _cart.values.fold(0, (sum, qty) => sum + qty);
  int get _cartTotal => (_menuItems ?? []).fold<int>(0, (sum, item) =>
    sum + ((item['unit_price_iqd'] as num?)?.toInt() ?? 0) *
      (_cart[(item['product_id'] as num).toInt()] ?? 0));

  Future<void> _submitFoodOrder() async {
    if (!_verified || _sendingOrder || _cartCount == 0) return;
    _orderRequestId ??= UniqueKey().toString();
    final requestId = _orderRequestId!;
    setState(() { _sendingOrder = true; _orderFeedback = null; _foodStatuses = []; _foodStatusError = null; });
    try {
      final result = await Supabase.instance.client.rpc('gs_public_submit_motel_food_order', params: {
        'p_room_token': widget.token,
        'p_access_token': _access.text.trim(),
        'p_request_key': requestId,
        'p_items': _cart.entries.map((e) => {'product_id': e.key, 'quantity': e.value}).toList(),
      });
      if (!mounted) return;
      setState(() { _cart.clear(); _orderRequestId = null;
        _orderFeedback = 'Order submitted for staff review. Reference: $result. No room charge has been made.'; });
      await _loadFoodStatus();
    } catch (_) {
      if (mounted) setState(() => _orderFeedback =
        'Could not submit order. Please retry without changing your cart to avoid duplicates.');
    } finally { if (mounted) setState(() => _sendingOrder = false); }
  }

  bool _loadingMenu = false;
  List<Map<String, dynamic>>? _menuItems;
  String? _menuError;

  Future<void> _showMotelMenu() async {
    if (!_verified || _loadingMenu) return;
    final accessAtStart = _access.text.trim();
    setState(() { _loadingMenu = true; _menuError = null; });
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_public_motel_guest_menu', params: {
          'p_room_token': widget.token, 'p_access_token': accessAtStart,
        });
      if (!mounted || !_verified || _access.text.trim() != accessAtStart) return;
      setState(() => _menuItems = (result as List)
          .map((row) => Map<String, dynamic>.from(row as Map)).toList());
    } catch (_) {
      if (mounted) setState(() { _menuItems = null;
        _menuError = 'Menu unavailable. Check your guest access and try again.'; });
    } finally {
      if (mounted) setState(() => _loadingMenu = false);
    }
  }

  bool _verifying = false;
  bool _loadingBillPreview = false;
  Map<String, dynamic>? _billPreview;
  String? _billPreviewError;
  Future<void> _loadBillPreview() async {
    if (!_verified || _loadingBillPreview) return;
    final accessAtStart = _access.text.trim();
    final roomAtStart = widget.token;
    setState(() { _loadingBillPreview = true; _billPreviewError = null; });
    try {
      final data = await Supabase.instance.client.rpc('gs_public_motel_food_bill_preview',
        params: {'p_room_token': roomAtStart, 'p_access_token': accessAtStart});
      if (!mounted || !_verified || widget.token != roomAtStart ||
          _access.text.trim() != accessAtStart) return;
      setState(() { _billPreview = Map<String, dynamic>.from(data as Map); });
    } catch (e) {
      if (mounted && widget.token == roomAtStart && _access.text.trim() == accessAtStart) {
        setState(() { _billPreviewError = 'Unable to load food bill preview: $e'; });
      }
    } finally {
      if (mounted) setState(() { _loadingBillPreview = false; });
    }
  }
  bool _verified = false;
  String? _verificationError;

  @override
  void dispose() { _access.dispose(); _mealDetails.dispose(); super.dispose(); }

  Future<void> _verifyAccess() async {
    if (_verifying || _access.text.trim().isEmpty) return;
    setState(() { _verifying = true; _verified = false; _verificationError = null; });
    try {
      final valid = await Supabase.instance.client.rpc(
        'gs_public_verify_motel_guest_access', params: {
          'p_room_token': widget.token, 'p_access_token': _access.text.trim(),
        });
      if (!mounted) return;
      setState(() { _verified = valid == true;
        if (!_verified) _verificationError = 'Invalid or expired guest access code';
        _mealStatuses = []; _mealStatusError = null; _menuItems = null; _menuError = null; _cart.clear(); _orderRequestId = null; _orderFeedback = null; _foodStatuses = []; _foodStatusError = null; });
    } catch (_) {
      if (mounted) setState(() => _verificationError = 'Unable to verify guest access');
    } finally { if (mounted) setState(() => _verifying = false); }
  }


  Future<void> _pickMealTime() async {
    final now = DateTime.now();
    final day = await showDatePicker(context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
      initialDate: now.add(const Duration(days: 1)));
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0));
    if (time == null || !mounted) return;
    setState(() => _mealTime = DateTime(day.year,day.month,day.day,time.hour,time.minute));
  }

  Future<void> _submitMeal() async {
    if (!_verified || _sendingMeal) return;
    if (_mealDetails.text.trim().length < 3 || _mealTime == null ||
        !_mealTime!.isAfter(DateTime.now().add(const Duration(minutes: 15)))) {
      setState(() => _mealFeedback = 'Enter meal details and a future delivery time.');
      return;
    }
    setState(() { _sendingMeal = true; _mealFeedback = null; });
    try {
      await Supabase.instance.client.rpc('gs_public_request_motel_scheduled_meal', params: {
        'p_room_token': widget.token,
        'p_access_token': _access.text.trim(),
        'p_description': _mealDetails.text.trim(),
        'p_requested_for': _mealTime!.toUtc().toIso8601String(),
      });
      if (!mounted) return;
      _mealDetails.clear();
      setState(() { _mealTime = null; _mealFeedback =
        'Request sent to staff. The meal is not confirmed until approved.'; });
      await _loadMealStatus();
    } catch (_) {
      if (mounted) setState(() => _mealFeedback =
        'Could not send request. Check access code, meal details and delivery time.');
    } finally {
      if (mounted) setState(() => _sendingMeal = false);
    }
  }

  Future<Map<String, dynamic>?> _identify() async {
    final rows = await Supabase.instance.client.rpc(
      'gs_public_motel_room_details', params: {'p_token': widget.token});
    if (rows is! List || rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  @override
  void didUpdateWidget(covariant CustomerMotelRoomQrScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _room = _identify(); _access.clear(); _verified = false; _mealTime = null; _mealDetails.clear(); _mealFeedback = null;
      _verificationError = null; _mealStatuses = []; _mealStatusError = null; _menuItems = null; _menuError = null; _cart.clear(); _orderRequestId = null; _orderFeedback = null; _foodStatuses = []; _foodStatusError = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(String value) => AppLanguage.label(AppLanguage.of(context), value);
    return Scaffold(
      appBar: AppBar(title: Text(t('Motel Guest Services'))),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _room,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(t('Room QR unavailable')),
              TextButton(onPressed: () => setState(() => _room = _identify()),
                child: Text(t('Try again'))),
            ]));
          }
          final room = snapshot.data!;
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Icon(Icons.hotel_outlined, size: 52),
            const SizedBox(height: 12),
            Text(room['room_name']?.toString() ?? '',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
            Text('${room['accommodation_type']} · ${room['room_label']}', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Card(child: Padding(padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.lock_outline), const SizedBox(width: 12),
                Expanded(child: Text(t('Room identified. Guest stay verification is required before ordering or viewing private information.'))),
              ]))),
            const SizedBox(height: 12),
            TextField(controller: _access, obscureText: true,
              onChanged: (_) { if (_verified) setState(() { _verified = false; _mealFeedback = null; _mealStatuses = []; _mealStatusError = null; _menuItems = null; _menuError = null; _cart.clear(); _orderRequestId = null; _orderFeedback = null; _foodStatuses = []; _foodStatusError = null; _billPreview = null; _billPreviewError = null; }); },
              decoration: InputDecoration(labelText: t('Guest access code'),
                helperText: t('Ask reception for your temporary access code'))),
            const SizedBox(height: 8),
            FilledButton(onPressed: _verifying ? null : _verifyAccess,
              child: Text(_verifying ? 'Verifying...' : t('Verify guest stay'))),
            if (_verificationError != null) Text(_verificationError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (_verified) const ListTile(leading: Icon(Icons.verified_user),
              title: Text('Guest access verified'),
              subtitle: Text('Food-order requests are available. Private bills are not yet connected.')),
            if (_verified) Card(child: Padding(padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Expanded(child: Text('Motel Menu · Tourism Prices',
                    style: TextStyle(fontWeight: FontWeight.bold))),
                  TextButton.icon(onPressed: _loadingMenu ? null : _showMotelMenu,
                    icon: const Icon(Icons.restaurant_menu),
                    label: Text(_loadingMenu ? 'Loading...' : 'View Menu')),
                ]),
                const Text('Choose quantities and submit for staff review. Prices are rechecked by the server; no room charge is made.'),
                if (_menuError != null) Text(_menuError!),
                if (_menuItems != null && _menuItems!.isEmpty)
                  const Text('No available menu items.'),
                if (_menuItems != null)
                  for (final product in _menuItems!)
                    ListTile(dense: true,
                      title: Text(product['product_name']?.toString() ?? ''),
                      subtitle: Text('${product['unit_price_iqd'] ?? 0} IQD · Tourism price'),
                      trailing: SizedBox(width: 132, child: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _sendingOrder ? null : () => setState(() {
                            final id = (product['product_id'] as num).toInt();
                            final next = (_cart[id] ?? 0) - 1;
                            if (next <= 0) { _cart.remove(id); } else { _cart[id] = next; }
                            _orderRequestId = null;
                          })),
                        Text('${_cart[(product['product_id'] as num).toInt()] ?? 0}'),
                        IconButton(icon: const Icon(Icons.add_circle_outline),
                          onPressed: _sendingOrder ? null : () => setState(() {
                            final id = (product['product_id'] as num).toInt();
                            if ((_cart[id] ?? 0) < 20) _cart[id] = (_cart[id] ?? 0) + 1;
                            _orderRequestId = null;
                          })),
                      ]))),
                  if (_menuItems != null && _cartCount > 0) ...[
                    Text('$_cartCount items · Estimated total: $_cartTotal IQD',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                    FilledButton.icon(onPressed: _sendingOrder ? null : _submitFoodOrder,
                      icon: const Icon(Icons.send),
                      label: Text(_sendingOrder ? 'Submitting...' : 'Submit food order')),
                  ],
                  if (_orderFeedback != null) Text(_orderFeedback!),
              ]))),
            if (_verified) Card(child: Padding(padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Expanded(child: Text('My Food Orders',
                    style: TextStyle(fontWeight: FontWeight.bold))),
                  IconButton(icon: const Icon(Icons.refresh),
                    onPressed: _loadingFoodStatus ? null : _loadFoodStatus,
                    tooltip: 'Refresh food order statuses'),
                ]),
                if (_loadingFoodStatus) const LinearProgressIndicator(),
                if (_foodStatusError != null) Text(_foodStatusError!),
                if (!_loadingFoodStatus && _foodStatuses.isEmpty)
                  const Text('Tap refresh to check your submitted food orders.'),
                for (final order in _foodStatuses)
                  ExpansionTile(
                    title: Text('Order · ${order['status'] ?? 'Unknown'}'),
                    subtitle: Text('${order['total_iqd'] ?? 0} IQD · ${order['created_at'] ?? ''}'),
                    children: [
                      for (final item in (order['items'] is List ? order['items'] as List : []))
                        ListTile(dense: true,
                          title: Text((item as Map)['name']?.toString() ?? ''),
                          trailing: Text('${item['quantity'] ?? 0} × ${item['unit_price_iqd'] ?? 0} IQD')),
                    ],
                  ),
              ]))),
            if (_verified) Card(child: Padding(padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Expanded(child: Text('Room Food Bill Preview',
                    style: TextStyle(fontWeight: FontWeight.bold))),
                  IconButton(icon: const Icon(Icons.refresh),
                    onPressed: _loadingBillPreview ? null : _loadBillPreview,
                    tooltip: 'Refresh delivered food total'),
                ]),
                const Text('Delivered food from this guest access session only. Not an official room invoice or payment balance.'),
                if (_loadingBillPreview) const LinearProgressIndicator(),
                if (_billPreviewError != null) Text(_billPreviewError!),
                if (_billPreview == null) const Text('Tap refresh to preview delivered food charges.'),
                if (_billPreview != null) ...[
                  Text('Delivered food total: ${_billPreview!['delivered_food_total_iqd'] ?? 0} IQD',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  for (final entry in (_billPreview!['orders'] is List ? _billPreview!['orders'] as List : []))
                    ListTile(dense: true,
                      title: Text('Delivered food · ${entry['total_iqd'] ?? 0} IQD'),
                      subtitle: Text('${entry['delivered_at'] ?? ''}')),
                ],
              ]))),
            if (_verified) Card(child: Padding(padding: const EdgeInsets.all(12), child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(t('Schedule Special Meal'), style: Theme.of(context).textTheme.titleMedium),
                const Text('Request only — staff must confirm availability and price.'),
                TextField(controller: _mealDetails, maxLength: 500, maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Meal and special instructions')),
                OutlinedButton.icon(onPressed: _pickMealTime, icon: const Icon(Icons.event),
                  label: Text(_mealTime == null ? 'Choose delivery time' : 'Delivery: ${_mealTime!.toLocal()}')),
                FilledButton(onPressed: _sendingMeal ? null : _submitMeal,
                  child: Text(_sendingMeal ? 'Sending...' : 'Send meal request')),
                if (_mealFeedback != null) Text(_mealFeedback!),
              ]))),
            if (_verified) Card(child: Padding(padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Expanded(child: Text('My Scheduled Meal Requests',
                    style: TextStyle(fontWeight: FontWeight.bold))),
                  IconButton(icon: const Icon(Icons.refresh),
                    onPressed: _loadingMealStatus ? null : _loadMealStatus,
                    tooltip: 'Refresh request statuses'),
                ]),
                if (_loadingMealStatus) const LinearProgressIndicator(),
                if (_mealStatusError != null) Text(_mealStatusError!),
                if (!_loadingMealStatus && _mealStatuses.isEmpty)
                  const Text('Tap refresh to check your meal request statuses.'),
                for (final meal in _mealStatuses)
                  ListTile(
                    title: Text(meal['meal_description']?.toString() ?? ''),
                    subtitle: Text('Requested delivery: ${meal['requested_for'] ?? ''}'),
                    trailing: Text(meal['status']?.toString() ?? 'Unknown'),
                  ),
              ]))),
            const SizedBox(height: 12),
            for (final entry in <(IconData, String)>[
              (Icons.room_service_outlined, 'Order Food & Drinks'),
              (Icons.delivery_dining, 'Check Order Status'),
              (Icons.event, 'Schedule Special Meal'),
              (Icons.receipt_long, 'Check Room Bill'),
              (Icons.support_agent, 'Call Employee'),
            ])
              Card(child: ListTile(
                leading: Icon(entry.$1), title: Text(t(entry.$2)),
                subtitle: Text(t('Requires verified guest stay')),
                trailing: const Icon(Icons.lock_outline),
                enabled: false,
              )),
          ]);
        },
      ),
    );
  }
}
