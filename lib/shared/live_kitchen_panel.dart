import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live kitchen queue. All changes are authorized and validated by the SQL RPC.
/// Requires optional gs_ migrations 001 and 002.
/// Display-only guest identity. Never changes the combined table invoice.
String gsKitchenGuestDisplay(Object? guestLabel, {Object? guestNumber}) {
  final label = guestLabel?.toString().trim() ?? '';
  if (label.isNotEmpty) return label;
  final number = int.tryParse(guestNumber?.toString() ?? '');
  if (number != null && number > 0) return 'Guest $number';
  return 'Table Order';
}

class LiveKitchenPanel extends StatefulWidget {
  const LiveKitchenPanel({super.key});

  @override
  State<LiveKitchenPanel> createState() => _LiveKitchenPanelState();
}

class _LiveKitchenPanelState extends State<LiveKitchenPanel> with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSubscription;
  String? _sessionEmployeeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionEmployeeId = Supabase.instance.client.auth.currentUser?.id;
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      final currentId = Supabase.instance.client.auth.currentUser?.id;
      if (!mounted || currentId == _sessionEmployeeId) return;
      _sessionEmployeeId = currentId;
      setState(() {
        _busyId = null;
        _busyOperationToken++;
        _confirmingId = null;
        _confirmationToken++;
        _busyEmployeeId = null;
        _loadGeneration++;
        _loadedUserId = null;
        _queueMayBeTruncated = false;
        _itemRequests.clear();
        _orders = _load();
      });
    });
  }

  String _query = '';
  String _statusFilter = 'active';
  String _historyPeriod = 'today';
  bool _oldestFirst = true;
  late Future<List<Map<String, dynamic>>> _orders = _load();
  int? _busyId;
  int? _confirmingId;
  int _confirmationToken = 0;
  String? _busyEmployeeId;
  int _busyOperationToken = 0;
  bool _queueMayBeTruncated = false;
  int _loadGeneration = 0;
  String? _loadedUserId;
  bool _isCurrentEmployee(String? userId) =>
      userId != null && Supabase.instance.client.auth.currentUser?.id == userId;

  final Map<int, Future<List<Map<String, dynamic>>>> _itemRequests = {};

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Revalidate orders after the device returns from the background: another
    // employee may have advanced or served an order while this app was idle.
    if (state == AppLifecycleState.resumed && mounted) {
      _refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _loadGeneration++;
    _itemRequests.clear();
    _confirmingId = null;
    _confirmationToken++;
    _busyOperationToken++;
    super.dispose();
  }

  // Money is stored as integral IQD. Never silently convert invalid values to
  // zero or truncate fractional amounts in the kitchen handover preview.
  int? _validIqd(dynamic value) {
    if (value is int) return value >= 0 ? value : null;
    if (value is String && RegExp(r'^\d+$').hasMatch(value)) {
      return int.tryParse(value);
    }
    return null;
  }

  // PostgREST may encode bigint IDs as strings. Reject invalid values rather
  // than crashing the queue while sorting or rendering an individual order.
  int? _validOrderId(dynamic value) {
    if (value is int) return value > 0 ? value : null;
    if (value is String && RegExp(r'^\d+$').hasMatch(value)) {
      final parsed = int.tryParse(value);
      return parsed != null && parsed > 0 ? parsed : null;
    }
    return null;
  }

  // Use the same financial integrity rules in the item preview and the
  // final handover guard. A mathematically inconsistent line must never
  // contribute to a seemingly valid displayed order total.
  bool _validKitchenItem(Map<String, dynamic> item) {
    final productId = _validOrderId(item['product_id']);
    final quantity = _validOrderId(item['quantity']);
    final unitPrice = _validIqd(item['unit_price_iqd']);
    final lineTotal = _validIqd(item['line_total_iqd']);
    return productId != null && quantity != null &&
        unitPrice != null && lineTotal != null &&
        BigInt.from(quantity) * BigInt.from(unitPrice) == BigInt.from(lineTotal);
  }

  // Read only the server-authorized order-item projection. Do not fetch
  // customer profiles or expose private contact information in the kitchen.
  Widget _orderIdentitySummary(int orderId) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _itemRequests.putIfAbsent(orderId,
        () => _loadItems(orderId, expectedGeneration: _loadGeneration)),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text('Customer / station: unavailable',
            style: TextStyle(fontSize: 12));
      }
      if (!snapshot.hasData) {
        return const Text('Loading customer and station…',
            style: TextStyle(fontSize: 12));
      }
      final items = snapshot.data!;
      if (items.isEmpty) return const Text('Customer / station: not assigned');
      final guests = <String>{};
      final stations = <String>{};
      for (final item in items) {
        guests.add(gsKitchenGuestDisplay(item['guest_label'],
            guestNumber: item['guest_number']));
        final station = item['station_name']?.toString().trim() ?? '';
        stations.add(station.isEmpty ? 'Unassigned station' : station);
      }
      final guestText = guests.toList()..sort();
      final stationText = stations.toList()..sort();
      return Text('Customer: ${guestText.join(', ')}  ·  Station: ${stationText.join(', ')}',
          maxLines: 3, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600));
    },
  );

  Future<List<Map<String, dynamic>>> _loadItems(int orderId, {
    required int expectedGeneration,
  }) async {
    final employeeId = Supabase.instance.client.auth.currentUser?.id;
    if (employeeId == null) {
      throw StateError('Employee login required.');
    }
    // Server-side Kitchen permission check; station routing is read-only.
    // Do not expose unrestricted menu/device configuration to employees.
    final rows = await Supabase.instance.client
        .rpc('gs_kitchen_order_item_details', params: {'p_order_id': orderId});
    if (!_isCurrentEmployee(employeeId) ||
        expectedGeneration != _loadGeneration ||
        employeeId != _loadedUserId) {
      throw StateError('Kitchen session or queue changed while loading items.');
    }
    return List<Map<String, dynamic>>.from(rows);
  }

// Use café business dates (Asia/Baghdad, UTC+03:00), not the device timezone.
// Iraq currently does not observe daylight saving time.
DateTime _historyStartUtc(String period) {
  final baghdadNow = DateTime.now().toUtc().add(const Duration(hours: 3));
  final midnightUtc = DateTime.utc(
    baghdadNow.year, baghdadNow.month, baghdadNow.day,
  ).subtract(const Duration(hours: 3));
  switch (period) {
    case 'yesterday': return midnightUtc.subtract(const Duration(days: 1));
    case 'week': return midnightUtc.subtract(const Duration(days: 6));
    case 'month': return midnightUtc.subtract(const Duration(days: 29));
    default: return midnightUtc;
  }
}

DateTime _historyEndUtc(String period) {
  final today = _historyStartUtc('today');
  return period == 'yesterday' ? today : today.add(const Duration(days: 1));
}

  Future<List<Map<String, dynamic>>> _load() async {
    final employeeId = Supabase.instance.client.auth.currentUser?.id;
    if (employeeId == null) {
      throw StateError('Employee login required.');
    }
    final generation = ++_loadGeneration;
    // Do not silently hide active kitchen orders after the first 100 rows.
    // Supabase/PostgREST limits result pages, so request bounded pages and
    // expose a warning if the safety cap is reached.
    // Filter on the server BEFORE pagination: old completed orders must not
    // consume the window reserved for active kitchen work.
    final requestedStatus = _statusFilter;
    const pageSize = 500;
    const maxPages = 10;
    final result = <Map<String, dynamic>>[];
    for (var page = 0; page < maxPages; page++) {
      var query = Supabase.instance.client
          .from('gs_orders')
          .select('id,destination,is_motel,tourism_mode,status,created_at,kitchen_accepted_at,kitchen_estimated_minutes,kitchen_estimated_ready_at,kitchen_completed_at,kitchen_picked_up_at,kitchen_delivered_at');
      if (requestedStatus == 'history') {
        query = query.eq('status', 'served')
            .gte('kitchen_completed_at', _historyStartUtc(_historyPeriod).toIso8601String())
            .lt('kitchen_completed_at', _historyEndUtc(_historyPeriod).toIso8601String());
      } else if (requestedStatus == 'active') {
        query = query.inFilter('status', ['new', 'preparing', 'ready']);
      } else if (requestedStatus == 'today_completed') {
        query = query.eq('status', 'served')
            .gte('kitchen_completed_at', _historyStartUtc('today').toIso8601String())
            .lt('kitchen_completed_at', _historyEndUtc('today').toIso8601String());
      } else if (requestedStatus != 'all') {
        query = query.eq('status', requestedStatus);
      }
      final rows = await query
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);
      if (!_isCurrentEmployee(employeeId) || generation != _loadGeneration) {
        throw StateError('Kitchen session or filter changed; refresh the queue.');
      }
      result.addAll(List<Map<String, dynamic>>.from(rows));
      if (rows.length < pageSize) {
        _queueMayBeTruncated = false;
        _loadedUserId = employeeId;
        return result;
      }
    }
    if (!_isCurrentEmployee(employeeId) || generation != _loadGeneration) {
      throw StateError('Kitchen session changed while loading the last page.');
    }
    _queueMayBeTruncated = true;
    _loadedUserId = employeeId;
    return result;
  }

  void _refresh() => setState(() {
    // A manual or automatic refresh invalidates any open confirmation.
    // Do not let a dialog from an older queue submit after the refresh.
    _confirmationToken++;
    _confirmingId = null;
    _loadGeneration++;
    _loadedUserId = null;
    _queueMayBeTruncated = false;
    _itemRequests.clear();
    _orders = _load();
  });

  /// Prevent accidental completion of an order before it has been handed over.
  Future<void> _confirmAndAdvance(int id, String next) async {
    // Capture the employee and queue version BEFORE any asynchronous dialog.
    // A different employee may sign in or refresh the queue while it is open.
    final employeeId = Supabase.instance.client.auth.currentUser?.id;
    final queueGeneration = _loadGeneration;
    if (!_isCurrentEmployee(employeeId) || employeeId != _loadedUserId) return;
    // A rapid double tap must not open two handover confirmations or issue
    // overlapping status RPCs for the same queue.
    if (_confirmingId != null || _busyId != null) return;
    // Immediately rebuild so action buttons show that a confirmation is open.
    setState(() { _confirmingId = id; });
    final confirmationToken = ++_confirmationToken;
    try {
    if (next == 'served') {
      // A successful queue fetch does not prove that order items are present
      // or financially valid. Re-fetch immediately before handover rather than
      // trusting a cached/unfinished ExpansionTile item request.
      List<Map<String, dynamic>> handoverItems;
      try {
        handoverItems = await _loadItems(id, expectedGeneration: queueGeneration);
      } catch (_) {
        if (mounted && _isCurrentEmployee(employeeId) &&
            employeeId == _loadedUserId &&
            queueGeneration == _loadGeneration) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Cannot verify order items. Refresh and retry before handover.'),
          ));
        }
        return;
      }
      if (!mounted || !_isCurrentEmployee(employeeId) ||
          employeeId != _loadedUserId || queueGeneration != _loadGeneration ||
          confirmationToken != _confirmationToken || _confirmingId != id) return;
      final validItems = handoverItems.isNotEmpty &&
          handoverItems.every(_validKitchenItem);
      if (!validItems) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Handover blocked: order items are missing or contain invalid quantities or amounts.'),
        ));
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm order handover'),
          content: Text('Has order #$id actually been served to the customer? '
              'This action also updates linked public-order fulfillment.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not yet'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm served'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    if (!mounted) return;
    if (!_isCurrentEmployee(employeeId) ||
        employeeId != _loadedUserId ||
        queueGeneration != _loadGeneration ||
        confirmationToken != _confirmationToken) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Employee or kitchen queue changed. Refresh and confirm again.'),
      ));
      return;
    }
    int? estimatedMinutes;
    if (next == 'preparing') {
      final controller = TextEditingController(text: '20');
      try {
        estimatedMinutes = await showDialog<int>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Accept order — preparation estimate'),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Estimated preparation time (minutes)',
                helperText: 'Required. Customer will see estimated ready time.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = int.tryParse(controller.text.trim());
                  if (value == null || value < 1 || value > 480) return;
                  Navigator.pop(dialogContext, value);
                },
                child: const Text('Accept with estimate'),
              ),
            ],
          ),
        );
      } finally {
        controller.dispose();
      }
      if (estimatedMinutes == null || !mounted ||
          !_isCurrentEmployee(employeeId) ||
          queueGeneration != _loadGeneration ||
          confirmationToken != _confirmationToken) return;
    }
    await _advance(id, next, estimatedMinutes: estimatedMinutes,
        expectedEmployeeId: employeeId,
        expectedQueueGeneration: queueGeneration);
    } finally {
      // A prior employee/dialog must never unlock a newer confirmation
      // for the same order after an account switch.
      if (mounted && _confirmingId == id &&
          _confirmationToken == confirmationToken) {
        setState(() { _confirmingId = null; });
      }
    }
  }

  Future<void> _advance(int id, String next, {
    int? estimatedMinutes,
    required String? expectedEmployeeId,
    required int expectedQueueGeneration,
  }) async {
    if (_busyId != null || id <= 0) return;
    final employeeId = Supabase.instance.client.auth.currentUser?.id;
    if (next != 'preparing' && next != 'ready' && next != 'served') return;
    if (!_isCurrentEmployee(employeeId) ||
        employeeId != expectedEmployeeId ||
        employeeId != _loadedUserId ||
        expectedQueueGeneration != _loadGeneration) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee session changed. Refresh before editing kitchen orders.')));
      return;
    }
    final operationToken = ++_busyOperationToken;
    setState(() { _busyId = id; _busyEmployeeId = employeeId; });
    try {
      if (next == 'preparing') {
        if (estimatedMinutes == null) return;
        await Supabase.instance.client.rpc('gs_accept_kitchen_order', params: {
          'p_order_id': id,
          'p_estimated_minutes': estimatedMinutes,
        });
      } else {
        await Supabase.instance.client.rpc('gs_update_kitchen_status', params: {
          'p_order_id': id,
          'p_next_status': next,
        });
      }
      // A manual refresh may finish before this RPC commits. Always fetch
      // the final server state for the same employee/operation, even when the
      // queue generation changed while the request was in flight.
      if (mounted && _isCurrentEmployee(employeeId) &&
          _busyOperationToken == operationToken) _refresh();
    } catch (error) {
      if (mounted && _isCurrentEmployee(employeeId) &&
          _busyOperationToken == operationToken) {
        // A concurrent employee may have advanced this order. Never leave
        // stale action buttons and item previews visible after RPC rejection.
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Kitchen update rejected or order changed. Queue refreshed; review the latest status.'),
        ));
      }
    } finally {
      if (mounted && _busyId == id && _busyEmployeeId == employeeId &&
          _busyOperationToken == operationToken) {
        setState(() { _busyId = null; _busyEmployeeId = null; });
      }
    }
  }

  Future<void> _recordPickup(int id) async {
    if (_busyId != null || _confirmingId != null) return;
    final employeeId = Supabase.instance.client.auth.currentUser?.id;
    if (!_isCurrentEmployee(employeeId) || employeeId != _loadedUserId) return;
    final token = ++_busyOperationToken;
    setState(() { _busyId = id; _busyEmployeeId = employeeId; });
    try {
      await Supabase.instance.client.rpc('gs_pickup_kitchen_order',
          params: {'p_order_id': id});
      if (mounted && _isCurrentEmployee(employeeId) &&
          _busyOperationToken == token) _refresh();
    } catch (_) {
      if (mounted && _isCurrentEmployee(employeeId) &&
          _busyOperationToken == token) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pickup could not be recorded. Refresh and check order status.')));
      }
    } finally {
      if (mounted && _busyId == id && _busyOperationToken == token) {
        setState(() { _busyId = null; _busyEmployeeId = null; });
      }
    }
  }

  Future<void> _acceptStationTicket(int ticketId) async {
    final employeeId = Supabase.instance.client.auth.currentUser?.id;
    if (!_isCurrentEmployee(employeeId) || _busyId != null || _confirmingId != null) return;
    final controller = TextEditingController(text: '20');
    int? minutes;
    try {
      minutes = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Accept station ticket'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Estimated preparation time (minutes)',
              helperText: 'Required: 1–480 minutes',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
            FilledButton(onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 1 || value > 480) return;
              Navigator.pop(dialogContext, value);
            }, child: const Text('Accept')),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
    if (!mounted || minutes == null || !_isCurrentEmployee(employeeId)) return;
    try {
      await Supabase.instance.client.rpc('gs_accept_station_preparation',
        params: {'p_ticket_id': ticketId, 'p_minutes': minutes});
      if (mounted && _isCurrentEmployee(employeeId)) _refresh();
    } catch (_) {
      if (mounted && _isCurrentEmployee(employeeId)) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Station acceptance failed. Refresh to see current status.'),
        ));
      }
    }
  }

  Future<void> _completeStationTicket(int ticketId) async {
    final employeeId = Supabase.instance.client.auth.currentUser?.id;
    if (!_isCurrentEmployee(employeeId) || _busyId != null || _confirmingId != null) return;
    try {
      await Supabase.instance.client.rpc('gs_complete_station_preparation',
          params: {'p_ticket_id': ticketId});
      if (mounted && _isCurrentEmployee(employeeId)) _refresh();
    } catch (_) {
      if (mounted && _isCurrentEmployee(employeeId)) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Station completion failed. Refresh to check current status.'),
        ));
      }
    }
  }

  Future<void> _stationHandover(int ticketId, String action) async {
    final employeeId = Supabase.instance.client.auth.currentUser?.id;
    if (!_isCurrentEmployee(employeeId) || _busyId != null || _confirmingId != null) return;
    try {
      await Supabase.instance.client.rpc('gs_record_station_handover',
        params: {'p_ticket_id': ticketId, 'p_action': action});
      if (mounted && _isCurrentEmployee(employeeId)) _refresh();
    } catch (_) {
      if (mounted && _isCurrentEmployee(employeeId)) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Station handover failed. Refresh and check ticket status.'),
        ));
      }
    }
  }

  Widget _stationHandoverPanel(int ticketId) => FutureBuilder<dynamic>(
    future: Supabase.instance.client.rpc('gs_station_handover_details',
      params: {'p_ticket_id': ticketId}),
    builder: (context, snapshot) {
      if (snapshot.hasError) return const ListTile(title: Text('Handover details unavailable'));
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final rows = snapshot.data as List;
      if (rows.isEmpty) return const SizedBox.shrink();
      final info = Map<String, dynamic>.from(rows.first as Map);
      if (info['picked_up_at'] == null) {
        return ListTile(
          title: const Text('Ready for station pickup'),
          trailing: FilledButton(
            onPressed: () => _stationHandover(ticketId, 'picked_up'),
            child: const Text('Record pickup'),
          ),
        );
      }
      if (info['delivered_at'] == null) {
        return ListTile(
          title: Text('Picked up at ${info['picked_up_at']}'),
          subtitle: Text('Employee: ${info['picked_up_by']}'),
          trailing: FilledButton(
            onPressed: () => _stationHandover(ticketId, 'delivered'),
            child: const Text('Record delivery'),
          ),
        );
      }
      return ListTile(
        leading: const Icon(Icons.done_all),
        title: Text('Delivered at ${info['delivered_at']}'),
        subtitle: Text('Picked up by: ${info['picked_up_by']} · Delivered by: ${info['delivered_by']}'),
      );
    },
  );

  Widget _overdueStationAlerts() => FutureBuilder<dynamic>(
    future: Supabase.instance.client.rpc('gs_kitchen_overdue_station_alerts'),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const ListTile(
          leading: Icon(Icons.warning_amber_outlined),
          title: Text('Overdue alerts unavailable'),
          subtitle: Text('Check permissions, migration, or connection.'),
        );
      }
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final alerts = List<Map<String, dynamic>>.from(
        (snapshot.data as List).map((v) => Map<String, dynamic>.from(v as Map)),
      );
      if (alerts.isEmpty) return const SizedBox.shrink();
      return ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.notification_important_outlined),
        title: Text('Overdue preparation alerts (${alerts.length})'),
        subtitle: const Text('Responsible employees and authorized supervisors'),
        children: [
          for (final alert in alerts)
            ListTile(
              leading: const Icon(Icons.timer_off_outlined),
              title: Text('Order #${alert['order_id']} · ${alert['station_name']}'),
              subtitle: Text(
                '${alert['overdue_minutes']} min overdue · '
                '${alert['audience'] == 'responsible' ? 'Your ticket' : 'Supervisor attention'}'
                ' · Accepted by: ${alert['accepted_by']}',
              ),
            ),
        ],
      );
    },
  );

  Widget _stationTicketQueue() => FutureBuilder<dynamic>(
    future: Supabase.instance.client.rpc('gs_kitchen_station_preparation_queue'),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const ListTile(
          title: Text('Station tickets unavailable'),
          subtitle: Text('Check kitchen permission, migration, and connection.'),
        );
      }
      if (!snapshot.hasData) {
        return const LinearProgressIndicator();
      }
      final rows = List<Map<String, dynamic>>.from(
        (snapshot.data as List).map((v) => Map<String, dynamic>.from(v as Map)),
      );
      if (rows.isEmpty) return const ListTile(title: Text('No pending station tickets'));
      final stations = rows.map((r) => r['station_name']?.toString() ?? 'Unknown')
          .toSet().toList()..sort();
      return ExpansionTile(
        title: Text('Preparation stations — ${rows.length} pending tickets'),
        subtitle: const Text('Station preparation status; independent of device dispatch and order delivery'),
        children: [
          for (final station in stations)
            ExpansionTile(
              title: Text(station),
              subtitle: Text('${rows.where((r) => r['station_name'] == station).length} tickets'),
              children: [
                for (final ticket in rows.where((r) => r['station_name'] == station))
                  ExpansionTile(
                    title: Text('Order #${ticket['order_id']} · ${ticket['item_count']} items · Station: $station'),
                    subtitle: Text('Ticket: ${ticket['preparation_state']} · '
                        'Quantity: ${ticket['item_quantity']}'
                        '${ticket['estimated_minutes'] == null ? '' : ' · ETA ${ticket['estimated_minutes']} min'}'),
                    children: [
                      if (ticket['preparation_state'] == 'pending')
                        ListTile(
                          title: const Text('Station preparation not accepted'),
                          trailing: FilledButton(
                            onPressed: () => _acceptStationTicket(ticket['ticket_id'] as int),
                            child: const Text('Accept with ETA'),
                          ),
                        ),
                      if (ticket['preparation_state'] == 'preparing')
                        ListTile(
                          title: const Text('Preparation in progress'),
                          trailing: FilledButton(
                            onPressed: () => _completeStationTicket(ticket['ticket_id'] as int),
                            child: const Text('Mark station ready'),
                          ),
                        ),
                      if (ticket['preparation_state'] == 'ready')
                        ListTile(
                          leading: const Icon(Icons.check_circle_outline),
                          title: const Text('Station preparation complete'),
                          subtitle: Text('Ready at: ${ticket['ready_at'] ?? 'Unknown'}'),
                        ),
                      if (ticket['preparation_state'] == 'ready')
                        _stationHandoverPanel(ticket['ticket_id'] as int),
                      if (ticket['estimated_ready_at'] != null)
                        ListTile(
                          title: const Text('Expected ready time'),
                          subtitle: Text('${ticket['estimated_ready_at']}'),
                        ),
                      FutureBuilder<dynamic>(
                        future: Supabase.instance.client.rpc(
                          'gs_kitchen_station_ticket_details',
                          params: {'p_ticket_id': ticket['ticket_id']},
                        ),
                        builder: (context, details) {
                          if (details.hasError) {
                            return const ListTile(title: Text('Ticket details unavailable'));
                          }
                          if (!details.hasData) return const LinearProgressIndicator();
                          final items = List<Map<String, dynamic>>.from(
                            (details.data as List).map((v) => Map<String, dynamic>.from(v as Map)),
                          );
                          if (items.isEmpty) {
                            return const ListTile(title: Text('No ticket items'));
                          }
                          return Column(children: [
                            for (final item in items)
                              ListTile(
                                dense: true,
                                title: Text('${item['quantity']} × ${item['product_name']}'),
                                subtitle: Text(
                                  'Customer: ${gsKitchenGuestDisplay(item['guest_label'], guestNumber: item['guest_number'])}'
                                   ' · Station: $station'
                                  '${item['preparation_notes'] == null ? '' : ' · Instructions: ${item['preparation_notes']}'}',
                                ),
                              ),
                          ]);
                        },
                      ),
                    ],
                  ),
              ],
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => Column(children: [
    ListTile(
      title: const Text('LIVE Supabase kitchen queue'),
      subtitle: const Text('Requires reviewed database migrations. Only employees with kitchen edit permission can advance an order.'),
      trailing: IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Search order number or table / room',
          border: OutlineInputBorder(),
        ),
        onChanged: (value) {
          final nextQuery = value.trim().toLowerCase();
          if (nextQuery == _query) return;
          setState(() {
            // A confirmation opened under a different search view must not
            // remain actionable after the visible queue changes.
            _query = nextQuery;
            _confirmationToken++;
            _confirmingId = null;
          });
        },
      ),
    ),
    const SizedBox(height: 8),
    _overdueStationAlerts(),
    _stationTicketQueue(),
    SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        for (final filter in const ['active', 'today_completed', 'history', 'all', 'new', 'preparing', 'ready', 'served', 'cancelled']) ...[
          ChoiceChip(
            label: Text(filter == 'active' ? 'Active' : filter == 'today_completed' ? "Today's Completed" : filter == 'history' ? 'History' : filter[0].toUpperCase() + filter.substring(1)),
            selected: _statusFilter == filter,
            onSelected: (_) {
              if (_statusFilter == filter) return;
              setState(() {
                // Changing the queue view invalidates any pending handover
                // confirmation just like a manual refresh. The dialog's
                // token check must reject a confirmation from the old view.
                _confirmationToken++;
                _confirmingId = null;
                _loadGeneration++;
                _loadedUserId = null;
                _queueMayBeTruncated = false;
                _statusFilter = filter;
                _itemRequests.clear();
                _orders = _load();
              });
            },
          ),
          const SizedBox(width: 6),
        ],
      ]),
    ),
    if (_statusFilter == 'history')
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButton<String>(
          value: _historyPeriod,
          items: const [
            DropdownMenuItem(value: 'today', child: Text('Today')),
            DropdownMenuItem(value: 'yesterday', child: Text('Yesterday')),
            DropdownMenuItem(value: 'week', child: Text('Last 7 calendar days')),
            DropdownMenuItem(value: 'month', child: Text('Last 30 calendar days')),
          ],
          onChanged: (period) {
            if (period == null || period == _historyPeriod) return;
            setState(() {
              _historyPeriod = period;
              _confirmationToken++;
              _confirmingId = null;
              _itemRequests.clear();
              _orders = _load();
            });
          },
        ),
      ),
    if (_statusFilter == 'history' || _statusFilter == 'today_completed')
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text('Only orders completed after the completion-timestamp migration are dated. Older served orders remain available under Served/All.'),
      ),
    SwitchListTile.adaptive(
      dense: true,
      title: const Text('Oldest orders first'),
      subtitle: const Text('Prioritize waiting orders; does not change database status'),
      value: _oldestFirst,
      onChanged: (value) => setState(() {
        _oldestFirst = value;
        _confirmationToken++;
        _confirmingId = null;
      }),
    ),
    Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _orders,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ListView(children: [
            const ListTile(title: Text('Kitchen data unavailable'),
              subtitle: Text('Check the optional migrations, Supabase connection and employee permissions.')),
            const Padding(padding: EdgeInsets.all(16), child: Text('Please sign in again or contact a manager if the problem continues.')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry loading kitchen orders'),
                ),
              ),
            ),
          ]);
        }
        if (_loadedUserId == null || !_isCurrentEmployee(_loadedUserId)) {
          return const Center(child: Text('Sign in to view the kitchen queue.'));
        }
        final orders = snapshot.data ?? const <Map<String, dynamic>>[];
        // Do not describe a capped result set as the entire kitchen queue.
        final counts = <String, int>{};
        for (final order in orders) {
          final status = '${order['status'] ?? 'unknown'}';
          counts[status] = (counts[status] ?? 0) + 1;
        }
        final visible = orders.where((order) {
          final status = '${order['status'] ?? ''}';
          final matchesStatus = _statusFilter == 'all' ||
              ((_statusFilter == 'history' || _statusFilter == 'today_completed') && status == 'served') ||
              (_statusFilter == 'active' &&
                  (status == 'new' || status == 'preparing' || status == 'ready')) ||
              status == _statusFilter;
          final searchText = '${order['id']} ${order['destination'] ?? ''}'.toLowerCase();
          return matchesStatus && searchText.contains(_query);
        }).toList();
        visible.sort((a, b) {
          final left = DateTime.tryParse('${a['created_at'] ?? ''}');
          final right = DateTime.tryParse('${b['created_at'] ?? ''}');
          if (left == null || right == null) {
        final leftId = _validOrderId(a['id']) ?? 0;
        final rightId = _validOrderId(b['id']) ?? 0;
        return _oldestFirst ? leftId.compareTo(rightId) : rightId.compareTo(leftId);
      }
          final timeComparison =
              _oldestFirst ? left.compareTo(right) : right.compareTo(left);
          if (timeComparison != 0) return timeComparison;
          // Stable tie-breaker when multiple orders share a timestamp.
          final leftId = _validOrderId(a['id']) ?? 0;
          final rightId = _validOrderId(b['id']) ?? 0;
          return _oldestFirst
              ? leftId.compareTo(rightId)
              : rightId.compareTo(leftId);
        });
        if (visible.isEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_queueMayBeTruncated
                ? 'No matching orders in the first 5,000 ${_statusFilter == 'all' ? 'orders' : '$_statusFilter orders'}. The queue may be incomplete; review older orders in Supabase.'
                : 'No kitchen orders match your filters.'),
          ));
        }
        return ListView.builder(
          itemCount: visible.length + 1 + (_queueMayBeTruncated ? 1 : 0),
          itemBuilder: (context, index) {
            if (_queueMayBeTruncated && index == 1) {
              return const ListTile(
                leading: Icon(Icons.warning_amber_outlined),
                title: Text('Kitchen queue may be incomplete'),
                subtitle: Text('The 5,000-order safety limit was reached for this status filter. Review older orders in Supabase.'),
              );
            }
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Wrap(spacing: 12, runSpacing: 4, children: [
                  Text('Showing ${visible.length} / ${orders.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  for (final status in const ['new', 'preparing', 'ready', 'cancelled'])
                    Text('$status: ${counts[status] ?? 0}'),
                ]),
              );
            }
            final order = visible[index - 1 - (_queueMayBeTruncated ? 1 : 0)];
            final id = _validOrderId(order['id']);
            if (id == null || id <= 0) return const ListTile(title: Text('Invalid order identifier; contact an administrator.'));
            final status = '${order['status'] ?? ''}';
            final next = switch (status) {
              'new' => 'preparing',
              'preparing' => 'ready',
              'ready' => order['kitchen_picked_up_at'] != null ? 'served' : null,
              _ => null,
            };
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: ExpansionTile(
                key: PageStorageKey('kitchen-order-$id'),
                leading: Icon(order['is_motel'] == true
                    ? Icons.hotel_outlined : Icons.table_restaurant_outlined),
                title: Text('Order #$id — ${order['destination'] ?? ''}'),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                     Text('${order['is_motel'] == true ? 'Motel' : 'Table'} · '
                    '${order['tourism_mode'] == true ? 'Tourism' : 'Normal'} · $status'),
                     _orderIdentitySummary(id),
                   ]),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                // The same persisted ETA can be shown in customer views.

                children: [
                  if (order['kitchen_estimated_ready_at'] != null)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.schedule),
                      title: Text('Estimated preparation: ${order['kitchen_estimated_minutes']} min'),
                      subtitle: Text('Estimated ready at: ${DateTime.tryParse('${order['kitchen_estimated_ready_at']}')?.toLocal().toString().substring(0, 16) ?? 'Unavailable'}'),
                    ),
                  if (status == 'ready' && order['kitchen_picked_up_at'] == null)
                    ListTile(
                      leading: const Icon(Icons.shopping_bag_outlined),
                      title: const Text('Ready for pickup'),
                      trailing: FilledButton(
                        onPressed: (_busyId != null || _confirmingId != null)
                            ? null : () => _recordPickup(id),
                        child: const Text('Record pickup'),
                      ),
                    ),
                  if (order['kitchen_picked_up_at'] != null)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.shopping_bag),
                      title: const Text('Picked up'),
                      subtitle: Text('${order['kitchen_picked_up_at']}'),
                    ),
                  if (order['kitchen_delivered_at'] != null)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.check_circle_outline),
                      title: const Text('Delivered'),
                      subtitle: Text('${order['kitchen_delivered_at']}'),
                    ),
                  FutureBuilder<Map<String, dynamic>?>(
                    future: Supabase.instance.client.rpc(
                      'gs_get_kitchen_delivery_history',
                      params: {'p_order_id': id},
                    ).then((v) {
                      final rows = List<dynamic>.from(v as List);
                      return rows.isEmpty ? null :
                        Map<String, dynamic>.from(rows.first as Map);
                    }),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      final data = snapshot.data!;
                      return ListTile(
                        dense: true,
                        title: const Text('Pickup and delivery employees'),
                        subtitle: Text(
                          'Picked up by: ${data['picked_up_by'] ?? 'Not yet'}'
                          ' · Delivered by: ${data['delivered_by'] ?? 'Not yet'}'),
                      );
                    },
                  ),
                  FutureBuilder<List<dynamic>>(
                    future: Supabase.instance.client.rpc(
                      'gs_get_kitchen_status_history',
                      params: {'p_order_id': id},
                    ).then((value) => List<dynamic>.from(value as List)),
                    builder: (context, historySnapshot) {
                      if (historySnapshot.hasError) {
                        return const ListTile(
                          leading: Icon(Icons.history),
                          title: Text('Activity history unavailable'),
                          subtitle: Text('Check access or database migrations.'),
                        );
                      }
                      if (!historySnapshot.hasData) {
                        return const LinearProgressIndicator();
                      }
                      final events = historySnapshot.data!;
                      return ExpansionTile(
                        leading: const Icon(Icons.history),
                        title: Text('Status activity history (${events.length})'),
                        children: events.isEmpty
                          ? [const ListTile(title: Text('No recorded transitions since history was enabled'))]
                          : events.map((event) {
                              final row = Map<String, dynamic>.from(event as Map);
                              final time = DateTime.tryParse('${row['changed_at'] ?? ''}');
                              final when = time == null ? 'Time unavailable' :
                                  time.toLocal().toString().substring(0, 16);
                              return ListTile(
                                dense: true,
                                title: Text('${row['previous_status']} → ${row['new_status']}'),
                                subtitle: Text('$when · Employee ID: ${row['changed_by'] ?? 'Unavailable'}'),
                              );
                            }).toList(),
                      );
                    },
                  ),
                  // Refresh the authoritative order and its item list together.
                  // Item previews are cached for this queue generation, so a
                  // separate employee's edit may not otherwise be visible.
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: (_busyId != null || _confirmingId != null)
                          ? null : _refresh,
                      icon: const Icon(Icons.sync),
                      label: const Text('Recheck order and items'),
                    ),
                  ),
                  if (order['is_motel'] == true)
                    const ListTile(
                      dense: true,
                      leading: Icon(Icons.verified_outlined),
                      title: Text('Motel order — Tourism pricing required'),
                    ),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _itemRequests.putIfAbsent(id,
                        () => _loadItems(id, expectedGeneration: _loadGeneration)),
                    builder: (context, itemSnapshot) {
                      if (itemSnapshot.hasError) {
                        return const ListTile(
                          title: Text('Items unavailable'),
                          subtitle: Text('Check order-item access and connection.'),
                        );
                      }
                      if (!itemSnapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: LinearProgressIndicator(),
                        );
                      }
                      final items = itemSnapshot.data!;
                      if (items.isEmpty) {
                        return const ListTile(title: Text('No visible order items'));
                      }
                      if (!items.every(_validKitchenItem)) {
                        return const ListTile(
                          leading: Icon(Icons.error_outline),
                          title: Text('Order total unavailable'),
                          subtitle: Text('An item has an invalid product, quantity, price, or line total. Contact a manager before handover.'),
                        );
                      }
                      final total = items.fold<BigInt>(BigInt.zero,
                          (sum, item) => sum +
                              BigInt.from(_validIqd(item['line_total_iqd'])!));
                      return Column(children: [
                        for (final item in items)
                          ListTile(
                            dense: true,
                            title: Text('${item['product_name'] ?? 'Product #${item['product_id']}'} × ${item['quantity']}'),
                            subtitle: Text(
                              'Customer: ${gsKitchenGuestDisplay(item['guest_label'], guestNumber: item['guest_number'])}'
                              ' · ${item['station_name'] ?? 'Unassigned station'}'
                              ' · Unit: ${item['unit_price_iqd']} IQD'
                              '${(item['preparation_notes']?.toString().trim().isNotEmpty ?? false) ? '\\nInstructions: ${item['preparation_notes']}' : ''}',
                            ),
                            trailing: Text('${item['line_total_iqd']} IQD'),
                          ),
                        const Divider(),
                        ListTile(
                          dense: true,
                          title: const Text('Order total'),
                          trailing: Text('$total IQD',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ]);
                    },
                  ),
                  if (next != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _busyId == null && _confirmingId == null
                            ? () => _confirmAndAdvance(id, next) : null,
                        child: Text(_busyId == id ? 'Updating...'
                            : _confirmingId == id ? 'Confirming...'
                            : 'Mark $next'),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    )),
  ]);
}
