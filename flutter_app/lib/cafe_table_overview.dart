import 'cafe_language.dart';
import 'cafe_finance_surface.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'cafe_operations_workspace.dart';
import 'cafe_request_id.dart';

/// Table state comes from the server; filters never change operational state.
class CafeTableOverview extends StatefulWidget {
  const CafeTableOverview({super.key, this.rpc, required this.onQr, this.initialStatus = 'All', this.requestsOnly = false, this.executiveStyle = false, this.title = 'Table Overview'});
  final String initialStatus;
  final String title;
  final bool executiveStyle;
  final bool requestsOnly;
  final CafeRpc? rpc;
  final Future<void> Function(String id) onQr;
  @override
  State<CafeTableOverview> createState() => _CafeTableOverviewState();
}

class _CafeTableOverviewState extends State<CafeTableOverview> {
  List<Map<String, dynamic>> _tables = [];
  Map<String, dynamic> _caps = {};
  String _query = '', _area = 'All', _mode = 'All', _status = 'All';
  String _sort = 'Table name';
  String _waiter = 'All';
  bool _loading = true, _busy = false, _list = false;
  String? _error;
  Map<String, dynamic>? _pending;
  int _page = 0;
  Duration _offset = Duration.zero;
  Timer? _clock, _refresh;
  DateTime get _now => DateTime.now().toUtc().add(_offset);
  Future<dynamic> _rpc(String name, Map<String, dynamic> params) async {
    if (widget.rpc == null) throw StateError('Connection not configured');
    return widget.rpc!(name, params);
  }
  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _load();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
    _refresh = Timer.periodic(const Duration(seconds: 20), (_) { if (!_busy && !_loading) _load(); });
  }
  @override
  void dispose() { _clock?.cancel(); _refresh?.cancel(); super.dispose(); }
  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final data = Map<String, dynamic>.from(await _rpc('get_cafe_table_overview', {}));
      if (!mounted) return;
      setState(() {
        _tables = cafeRows(data['tables']);
        _caps = Map<String, dynamic>.from(data['capabilities']);
        _offset = DateTime.parse(data['server_time']).difference(DateTime.now().toUtc());
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not refresh tables. Check your connection and permissions.');
    } finally { if (mounted) setState(() => _loading = false); }
  }
  String _state(Map<String, dynamic> t) {
    if (t['visit_id'] != null) return 'Occupied';
    if (t['status'] == 'cleaning') return 'Cleaning';
    if (t['status'] == 'reserved') return (t['reservation'] as Map?)?['arrived_at'] == null ? 'Reserved' : 'Arrived';
    return 'Available';
  }
  String _elapsed(dynamic value) {
    final start = DateTime.tryParse('$value');
    if (start == null) return '';
    final seconds = _now.difference(start).inSeconds.clamp(0, 99999999);
    return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m ${seconds % 60}s';
  }
  Future<void> _action(Map<String, dynamic> t, String action, Map<String, dynamic> data) async {
    _pending = {'p_request_id': newCafeRequestId(), 'p_table_id': t['id'], 'p_action': action, 'p_data': data};
    await _send();
  }
  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await _rpc('perform_cafe_table_action', _pending!);
      _pending = null;
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'The action was not confirmed. Retry safely with the same request, or refresh to check the table.');
    } finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _edit(Map<String, dynamic> t, String action) async {
    final guests = TextEditingController(text: '1');
    final name = TextEditingController();
    final contact = TextEditingController();
    final reason = TextEditingController();
    var mode = '${t['pricing_mode']}';
    final form = GlobalKey<FormState>();
    final data = await showDialog<Map<String, dynamic>>(context: context, builder: (context) => StatefulBuilder(builder: (context, change) => AlertDialog(
      title: CafeText('${action == 'take' ? 'Take' : 'Activate mode'} · ${t['name']}'),
      content: SizedBox(width: 400, child: Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (action == 'take') ...[
          TextFormField(controller: guests, decoration: const InputDecoration(label: CafeText('Guests')), keyboardType: TextInputType.number, validator: (v) { final n = int.tryParse(v ?? ''); return n == null || n < 1 || n > (t['seats'] as num) ? 'Enter 1–${t['seats']} guests' : null; }),
          TextFormField(controller: name, maxLength: 120, decoration: const InputDecoration(label: CafeText('Customer name (optional)'))),
          TextFormField(controller: contact, maxLength: 80, decoration: const InputDecoration(label: CafeText('Phone (optional)'))),
        ] else ...[
          DropdownButtonFormField<String>(initialValue: mode, items: ['normal', 'tourism', 'owner'].map((m) => DropdownMenuItem(value: m, child: Text(m.toUpperCase()))).toList(), onChanged: (v) => change(() => mode = v!), decoration: const InputDecoration(label: CafeText('Pricing mode'))),
          const CafeText('Applies to new orders. Existing charges keep their accepted prices. Owner mode requires an administrator.'),
          TextFormField(controller: reason, maxLength: 200, decoration: const InputDecoration(label: CafeText('Reason')), validator: (v) => (v?.trim().length ?? 0) < 3 ? 'Enter a reason' : null),
        ],
      ])))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const CafeText('Cancel')), FilledButton(onPressed: () {
        if (form.currentState!.validate()) Navigator.pop(context, action == 'take' ? {'guests': int.parse(guests.text), 'name': name.text.trim(), 'contact': contact.text.trim()} : {'mode': mode, 'reason': reason.text.trim()});
      }, child: const CafeText('Confirm'))],
    )));
    if (data != null && mounted) await _action(t, action, data);
  }
  Future<void> _confirm(Map<String, dynamic> t, String action, String prompt, [Map<String, dynamic> data = const {}]) async {
    final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text(t['name']), content: Text(prompt), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const CafeText('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const CafeText('Confirm'))]));
    if (yes == true && mounted) await _action(t, action, data);
  }
  Future<void> _bill(Map<String, dynamic> t) async {
    setState(() => _busy = true);
    try {
      final bill = Map<String, dynamic>.from(await _rpc('get_cafe_visit_bill', {'p_table_id': t['id']}));
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (context) => AlertDialog(title: CafeText('${t['name']} · Current visit bill'), content: SizedBox(width: 540, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final order in cafeRows(bill['orders'] ?? [])) ...[
          CafeText('Order ${order['order_number'] ?? order['id']} · ${order['status']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          for (final item in cafeRows(order['items'] ?? [])) CafeText('${item['quantity']} × ${item['name']} · ${(item['quantity'] as num) * (item['unit_price_iqd'] as num)} IQD'),
          const Divider(),
        ],
        CafeText('Total: ${bill['total_iqd']} IQD'), CafeText('Paid: ${bill['paid_iqd']} IQD'), CafeText('Balance: ${bill['balance_iqd']} IQD', style: const TextStyle(fontWeight: FontWeight.bold)),
      ]))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const CafeText('Close'))]));
    } catch (_) { if (mounted) setState(() => _error = 'Could not load the current visit bill.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _choose(Map<String, dynamic> table, String action) async {
    setState(() => _busy = true);
    try {
      final choices = action == 'assign_waiter' ? cafeRows(await _rpc('get_cafe_table_staff', {})) : _tables.where((t) => t['id'] != table['id'] && _state(t) == 'Available').toList();
      if (!mounted) return;
      String? selected;
      final picked = await showDialog<String>(context: context, builder: (context) => StatefulBuilder(builder: (context, change) => AlertDialog(
        title: Text(action == 'assign_waiter' ? 'Assign waiter · ${table['name']}' : 'Transfer · ${table['name']}'),
        content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (choices.isEmpty) const CafeText('No available choices.'),
          DropdownButtonFormField<String>(isExpanded: true, items: choices.map((t) => DropdownMenuItem(value: '${t['id']}', child: CafeText('${t['name']}'))).toList(), onChanged: (v) => change(() => selected = v), decoration: InputDecoration(labelText: action == 'assign_waiter' ? 'Waiter' : 'Destination table')),
          if (action == 'transfer') const CafeText('Move the active visit and its orders. Existing charges remain unchanged. New orders use the destination table’s mode. The original table will need cleaning.'),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const CafeText('Cancel')), FilledButton(onPressed: selected == null ? null : () => Navigator.pop(context, selected), child: const CafeText('Confirm'))],
      )));
      if (picked != null && mounted) await _action(table, action, {action == 'assign_waiter' ? 'waiter_id' : 'target_id': picked});
    } catch (_) { if (mounted) setState(() => _error = 'Could not load available choices.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _history(Map<String,dynamic> table) async {
    setState(() => _busy = true);
    try {
      final rows = cafeRows(await _rpc('get_cafe_table_history', {'p_table_id': table['id']}));
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (context) => AlertDialog(title: CafeText('${table['name']} · Activity history'), content: SizedBox(width: 600, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (rows.isEmpty) const CafeText('No recorded activity.'),
        for (final r in rows) ListTile(title: CafeText('${r['action']}'.replaceAll('_', ' ')), subtitle: CafeText('${DateTime.parse(r['created_at']).toUtc().add(const Duration(hours: 3)).toString().substring(0,19)} · ${r['actor'] ?? 'System'}\n${r['reason'] ?? ''}')),
      ]))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const CafeText('Close'))]));
    } catch (_) { if (mounted) setState(() => _error = 'Could not load activity history.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Widget _filter(String label, String value, Iterable<String> choices, void Function(String) change) => SizedBox(width: 175, child: DropdownButtonFormField<String>(key: ValueKey('$label-$value'), initialValue: value, isExpanded: true, decoration: InputDecoration(labelText: label), items: choices.toSet().map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() { change(v!); _page = 0; })));
  Future<void> _orders(Map<String, dynamic> table, {bool payments = false}) async {
    await showDialog<void>(context: context, builder: (context) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(18), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [Expanded(child: CafeText('${table['name']} · ${payments ? 'Payments' : 'Orders'}', style: Theme.of(context).textTheme.titleLarge)), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), tooltip: 'Close')]),
      CafeOperationsWorkspace(source: 'table', canCreate: _caps[payments ? 'payments' : 'orders'] == true, payments: payments, tableId: '${table['id']}', visitId: '${table['visit_id']}', rpc: widget.rpc),
    ]))))));
    if (mounted) await _load();
  }
  Widget _card(Map<String, dynamic> t) {
    final state = _state(t);
    final color = switch (state) { 'Occupied' => Colors.deepOrange, 'Cleaning' => Colors.purple, 'Reserved' => Colors.orange, 'Arrived' => Colors.blue, _ => Colors.green };
    final border = switch (t['pricing_mode']) { 'tourism' => const Color(0xFFF59E0B), 'owner' => const Color(0xFF8B5CF6), _ => const Color(0xFF2563EB) };
    final enabled = !_busy && !_loading && _error == null && _pending == null;
    Widget button(String label, VoidCallback action, String cap) => OutlinedButton(onPressed: enabled && _caps[cap] == true ? action : null, child: Text(label));
    final reservation = t['reservation'] as Map?;
    return Card(color: color.withValues(alpha: .06), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: border, width: 2)), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: CafeText('${t['name']}', style: Theme.of(context).textTheme.titleLarge)), Chip(label: Text(state))]),
      CafeText('${t['area']} · ${t['seats']} seats'),
      CafeText('${t['pricing_mode']}'.toUpperCase(), style: TextStyle(color: border, fontWeight: FontWeight.bold)),
      if (t['visit_id'] != null) ...[CafeText('${t['guest_count']} guests · ${_elapsed(t['started_at'])}'), CafeText('Waiter: ${t['waiter_name'] ?? 'Unassigned'}'), if ('${t['customer_name'] ?? ''}'.isNotEmpty) CafeText('${t['customer_name']} · ${t['contact']}'), CafeText('${t['order_count']} orders · ${t['pending_orders']} pending'), CafeText('${t['payment_status']}')],
      if (state == 'Cleaning') CafeText('Cleaning · ${_elapsed(t['cleaning_started_at'])}'),
      if (reservation != null) CafeText('Reservation: ${DateTime.parse(reservation['starts_at']).toUtc().add(const Duration(hours: 3)).toString().substring(0, 16)} · ${reservation['party_size']} guests'),
      const SizedBox(height: 12),
      Wrap(spacing: 6, runSpacing: 6, children: [
        if (state == 'Available' || state == 'Arrived') button('Take', () => _edit(t, 'take'), 'take'),
        if (state == 'Reserved' && reservation != null) button('Arrived', () => _confirm(t, 'arrived', 'Confirm these reserved guests have arrived?', {'reservation_id': reservation['id']}), 'arrived'),
        if (state == 'Reserved' && reservation != null) button('No-show', () => _confirm(t, 'no_show', 'Mark this reservation as no-show and release it? This is only allowed after its start time.', {'reservation_id': reservation['id']}), 'arrived'),
        if (t['visit_id'] != null) ...[button('Add Order / Orders', () => _orders(t), 'orders'), button('Combined Bill', () => _bill(t), 'bills'), button('Payment', () => _orders(t, payments: true), 'payments'), button('Close visit', () => _confirm(t, 'close', 'End this visit and mark the table for cleaning? All charges must be settled and orders finished.'), 'close')],
        if (state == 'Cleaning') button('Ready', () => _confirm(t, 'ready', 'Confirm cleaning is finished and the table is ready?'), 'ready'),
        button('Mode', () => _edit(t, 'mode'), 'mode'),
        if (t['visit_id'] != null) ...[button('Assign waiter', () => _choose(t, 'assign_waiter'), 'assign_waiter'), button('Transfer', () => _choose(t, 'transfer'), 'transfer')],
        button('Call staff', () => _confirm(t, 'call_staff', 'Create a staff service request for this table?'), 'service'),
        button('History', () => _history(t), 'history'),
        OutlinedButton(onPressed: enabled ? () => widget.onQr('${t['id']}') : null, child: const CafeText('Show QR')),
      ]),
      for (final r in cafeRows(t['requests'] ?? [])) ListTile(contentPadding: EdgeInsets.zero, title: CafeText('${r['kind']}'.replaceAll('_', ' ')), subtitle: CafeText('${r['message']} · ${r['status']}'), trailing: _caps['service'] == true ? TextButton(onPressed: enabled ? () => _action(t, r['status'] == 'open' ? 'acknowledge' : 'complete_request', {'request_id': r['id']}) : null, child: Text(r['status'] == 'open' ? 'Acknowledge' : 'Complete')) : null),
    ])));
  }
  @override
  Widget build(BuildContext context) => widget.executiveStyle
      ? CafeFinanceSurface(builder: _content) : _content(context);

  Widget _content(BuildContext context) {
    final rows = _tables.where((t) => (_waiter == 'All' || t['waiter_name'] == _waiter) && (!widget.requestsOnly || (t['requests'] as List).isNotEmpty) && (_area == 'All' || t['area'] == _area) && (_mode == 'All' || t['pricing_mode'] == _mode) && (_status == 'All' || _state(t) == _status) && '${t['name']} ${t['id']} ${t['customer_name']} ${t['contact']}'.toLowerCase().contains(_query.toLowerCase())).toList();
    rows.sort((a,b) => _sort == 'Longest visit' ? '${a['started_at'] ?? 'z'}'.compareTo('${b['started_at'] ?? 'z'}') : _sort == 'Requests' ? (b['requests'] as List).length.compareTo((a['requests'] as List).length) : '${a['name']}'.compareTo('${b['name']}'));
    final page = _page.clamp(0, rows.isEmpty ? 0 : (rows.length - 1) ~/ 12);
    final shown = rows.skip(page * 12).take(12).toList();
    final baghdad = _now.add(const Duration(hours: 3));
    return Container(color: widget.executiveStyle ? const Color(0xFF14243A) : Colors.white, padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CafeText(widget.title, style: Theme.of(context).textTheme.headlineMedium),
      CafeText('${baghdad.toString().substring(0, 19)} · Baghdad'),
      const SizedBox(height: 16),
      TextField(decoration: const InputDecoration(label: CafeText('Search table, customer or phone'), prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() { _query = v; _page = 0; })),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 12, children: [
        _filter('Area', _area, ['All', ..._tables.map((t) => '${t['area']}')], (v) => _area = v),
        _filter('Status', _status, ['All', 'Available', 'Reserved', 'Arrived', 'Occupied', 'Cleaning'], (v) => _status = v),
        _filter('Mode', _mode, ['All', 'normal', 'tourism', 'owner'], (v) => _mode = v),
        _filter('Waiter', _waiter, ['All', _waiter, ..._tables.where((t) => t['waiter_name'] != null).map((t) => '${t['waiter_name']}')], (v) => _waiter = v),
        _filter('Sort', _sort, ['Table name', 'Longest visit', 'Requests'], (v) => _sort = v),
        TextButton(onPressed: () => setState(() { _area = _mode = _status = _waiter = 'All'; _page = 0; }), child: const CafeText('Reset filters')),
        IconButton(onPressed: _busy || _loading ? null : _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
        IconButton(onPressed: () => setState(() => _list = !_list), tooltip: _list ? 'Grid view' : 'List view', icon: Icon(_list ? Icons.grid_view : Icons.view_list)),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [for (final state in ['Available', 'Reserved', 'Arrived', 'Occupied', 'Cleaning']) Chip(label: CafeText('$state ${rows.where((t) => _state(t) == state).length}')), Chip(label: CafeText('Paid, still seated ${rows.where((t) => t['payment_status'] == 'Paid — Still Seated').length}'))]),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      if (_pending != null) TextButton(onPressed: _busy ? null : _send, child: const CafeText('Retry action')),
      CafeText('${rows.length} matching tables'),
      if (!_loading && rows.isEmpty) const Padding(padding: EdgeInsets.all(24), child: CafeText('No matching tables.')),
      LayoutBuilder(builder: (context, box) { final columns = _list ? 1 : (box.maxWidth / 360).floor().clamp(1, 4); final width = (box.maxWidth - 12 * (columns - 1)) / columns; return Wrap(spacing: 12, runSpacing: 12, children: [for (final t in shown) SizedBox(width: width, child: _card(t))]); }),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton(onPressed: page > 0 ? () => setState(() => _page = page - 1) : null, child: const CafeText('Previous')), CafeText('Page ${page + 1}'), TextButton(onPressed: (page + 1) * 12 < rows.length ? () => setState(() => _page = page + 1) : null, child: const CafeText('Next'))]),
    ]));
  }
}
