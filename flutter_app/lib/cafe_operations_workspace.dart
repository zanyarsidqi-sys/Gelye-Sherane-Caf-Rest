import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cafe_request_id.dart';
import 'workspace_reporting.dart';

typedef CafeRpc = Future<dynamic> Function(
  String name,
  Map<String, dynamic> params,
);
Future<dynamic> cafeOperationsRpc(String name, Map<String, dynamic> params) =>
    Supabase.instance.client.rpc(name, params: params);
List<Map<String, dynamic>> cafeRows(dynamic data) =>
    (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

class CafeOperationsWorkspace extends StatefulWidget {
  const CafeOperationsWorkspace({
    super.key,
    required this.source,
    required this.canCreate,
    this.rpc,
    this.payments = false,
    this.canRefund = false,
  });
  final String source;
  final bool canCreate, payments, canRefund;
  final CafeRpc? rpc;
  @override
  State<CafeOperationsWorkspace> createState() =>
      _CafeOperationsWorkspaceState();
}

class _CafeOperationsWorkspaceState extends State<CafeOperationsWorkspace> {
  List<Map<String, dynamic>> _rows = [];
  String _query = '', _filter = 'Active';
  bool _loading = true, _busy = false;
  String? _error;
  Future<dynamic> _rpc(String name, Map<String, dynamic> params) async {
    if (widget.rpc == null) throw StateError('Connection not configured');
    return widget.rpc!(name, params);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = cafeRows(
        await _rpc(
          widget.payments
              ? 'list_cafe_payment_balances'
              : 'list_cafe_staff_orders',
          widget.payments ? {} : {'p_source': widget.source, 'p_history': _filter == 'All'},
        ),
      );
      if (mounted) setState(() => _rows = rows);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not load records. Check your connection and assigned permissions, then refresh.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final catalog = Map<String, dynamic>.from(
        await _rpc('get_cafe_order_catalog', {'p_source': widget.source})
            as Map,
      );
      if (!mounted) return;
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _OrderEditor(source: widget.source, catalog: catalog, rpc: _rpc),
      );
      if (saved == true && mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not open the order catalog. Refresh and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transition(Map<String, dynamic> row, String status) async {
    if (status == 'cancelled') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancel order?'),
          content: const Text(
            'Recorded payments must be refunded first. This keeps the order in history.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep order'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel order'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await _rpc('transition_cafe_order', {
        'p_order_id': row['id'],
        'p_status': status,
      });
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Change could not be confirmed. Refresh before retrying. Paid orders must be refunded before cancellation.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payment(
    Map<String, dynamic> order, [
    Map<String, dynamic>? original,
  ]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _PaymentEditor(order: order, original: original, rpc: _rpc),
    );
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _rows.where((r) {
      final active = widget.payments
          ? (r['total_iqd'] as num) > (r['paid_iqd'] as num) &&
                r['status'] != 'cancelled'
          : !['served', 'cancelled'].contains(r['status']);
      return (_filter == 'All' || active) &&
          '${r['id']} ${r['table_name']} ${r['status']}'.toLowerCase().contains(
            _query.toLowerCase(),
          );
    }).toList();
    final range = WorkspaceReportRange.forSelection(
      baghdadCalendarDate(DateTime.now()),
      'Today',
    );
    var collected = 0, refunded = 0;
    if (widget.payments) {
      for (final row in _rows) {
        for (final p in cafeRows(row['payments'])) {
          if (range.contains(DateTime.parse(p['created_at'] as String))) {
            if (p['kind'] == 'payment') {
              collected += (p['amount_iqd'] as num).toInt();
            } else {
              refunded += (p['amount_iqd'] as num).toInt();
            }
          }
        }
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.payments
                  ? 'Order payments'
                  : '${widget.source.replaceAll('_', ' ')} orders',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.payments
                  ? 'Cash and manually recorded card payments in IQD. Card payments must already be completed on your terminal.'
                  : 'Received → Preparing → Ready → Served. Refresh to load the latest changes. History shows up to 500 recent orders.',
            ),
            if (widget.payments && !_loading && _error == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Today · Baghdad time\nCollected: $collected IQD · Refunds: $refunded IQD · Net: ${collected - refunded} IQD',
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy || _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                if (!widget.payments && widget.canCreate)
                  FilledButton.icon(
                    onPressed: _busy || _loading || _error != null
                        ? null
                        : _create,
                    icon: const Icon(Icons.add),
                    label: const Text('New order'),
                  ),
                for (final f in ['Active', 'All'])
                  ChoiceChip(
                    label: Text(
                      widget.payments && f == 'Active' ? 'Unpaid' : f,
                    ),
                    selected: _filter == f,
                    onSelected: _loading || _busy ? null : (_) {
                      setState(() => _filter = f);
                      if (!widget.payments) _load();
                    },
                  ),
              ],
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search order, table or reference',
              ),
              onChanged: (s) => setState(() => _query = s),
            ),
            if (_error != null)
              Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
            if (_loading)
              const LinearProgressIndicator()
            else if (_error == null && visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No matching orders.'),
              ),
            if (!_loading)
              for (final row in visible)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${row['table_name']} · ${row['status']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SelectableText('Order ${row['id']}'),
                        Text('Total: ${row['total_iqd']} IQD'),
                        if (widget.payments) ...[
                          Text(
                            'Net paid: ${row['paid_iqd']} IQD · Outstanding: ${(row['total_iqd'] as num) - (row['paid_iqd'] as num)} IQD',
                          ),
                          if (widget.canCreate &&
                              row['status'] != 'cancelled' &&
                              (row['total_iqd'] as num) >
                                  (row['paid_iqd'] as num))
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton(
                                onPressed: _busy || _error != null
                                    ? null
                                    : () => _payment(row),
                                child: const Text('Record payment'),
                              ),
                            ),
                          for (final p in cafeRows(row['payments']))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${p['kind']} · ${p['amount_iqd']} IQD · ${p['method']}',
                              ),
                              subtitle: Text(
                                '${p['reference']}\nReceipt ${p['id']}',
                              ),
                              trailing:
                                  widget.canRefund && p['kind'] == 'payment'
                                  ? TextButton(
                                      onPressed: _busy || _error != null
                                          ? null
                                          : () => _payment(row, p),
                                      child: const Text('Refund'),
                                    )
                                  : null,
                            ),
                        ] else ...[
                          for (final item in cafeRows(row['items']))
                            Text(
                              '${item['quantity']} × ${item['name']} · ${item['unit_price_iqd']} IQD',
                            ),
                          if ('${row['notes']}'.isNotEmpty)
                            Text('Notes: ${row['notes']}'),
                          Wrap(
                            spacing: 8,
                            children: [
                              if ([
                                'received',
                                'preparing',
                                'ready',
                              ].contains(row['status']))
                                FilledButton(
                                  onPressed: _busy || _error != null
                                      ? null
                                      : () => _transition(
                                          row,
                                          {
                                            'received': 'preparing',
                                            'preparing': 'ready',
                                            'ready': 'served',
                                          }[row['status']]!,
                                        ),
                                  child: Text(
                                    {
                                      'received': 'Start preparing',
                                      'preparing': 'Mark ready',
                                      'ready': 'Mark served',
                                    }[row['status']]!,
                                  ),
                                ),
                              if ([
                                'received',
                                'preparing',
                              ].contains(row['status']))
                                TextButton(
                                  onPressed: _busy || _error != null
                                      ? null
                                      : () => _transition(row, 'cancelled'),
                                  child: const Text('Cancel order'),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _OrderEditor extends StatefulWidget {
  const _OrderEditor({
    required this.source,
    required this.catalog,
    required this.rpc,
  });
  final String source;
  final Map<String, dynamic> catalog;
  final CafeRpc rpc;
  @override
  State<_OrderEditor> createState() => _OrderEditorState();
}

class _OrderEditorState extends State<_OrderEditor> {
  final _destination = TextEditingController(),
      _notes = TextEditingController();
  final _quantities = <String, int>{};
  final _request = newCafeRequestId();
  String? _table, _error;
  bool _busy = false;
  Map<String, dynamic>? _submitted;
  @override
  void dispose() {
    _destination.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_submitted == null) {
      if (_quantities.isEmpty ||
          (widget.source == 'table' && _table == null) ||
          (['motel', 'online'].contains(widget.source) &&
              _destination.text.trim().isEmpty)) {
        setState(
          () => _error = 'Choose products and enter the table, room or delivery reference.',
        );
        return;
      }
      _submitted = {
        'p_request_id': _request,
        'p_source': widget.source,
        'p_table_id': _table,
        'p_destination': _destination.text.trim(),
        'p_notes': _notes.text.trim(),
        'p_items': _quantities.entries
            .map((e) => {'item_id': e.key, 'quantity': e.value})
            .toList(),
      };
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.rpc('submit_cafe_staff_order', _submitted!);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Save could not be confirmed. Retry sends the same order safely. Close and check order history before starting a different order.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = cafeRows(widget.catalog['products']);
    final locked = _busy || _submitted != null;
    final total = products.fold<int>(
      0,
      (v, p) =>
          v + (_quantities[p['id']] ?? 0) * (p['price_iqd'] as num).toInt(),
    );
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('New order'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.source == 'table')
                  DropdownButtonFormField<String>(
                    initialValue: _table,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Table'),
                    items: [
                      for (final t in cafeRows(widget.catalog['tables']))
                        DropdownMenuItem(
                          value: t['id'] as String,
                          child: Text(t['name'] as String),
                        ),
                    ],
                    onChanged: locked
                        ? null
                        : (v) => setState(() => _table = v),
                  )
                else
                  TextField(
                    controller: _destination,
                    enabled: !locked,
                    maxLength: 200,
                    decoration: InputDecoration(
                      labelText: widget.source == 'motel'
                          ? 'Room reference'
                          : widget.source == 'online'
                          ? 'Delivery / pickup reference'
                          : 'Customer reference (optional)',
                    ),
                  ),
                if (products.isEmpty)
                  const Text(
                    'No available products. Add products in Menu Management first.',
                  ),
                for (final p in products)
                  Row(
                    children: [
                      Expanded(
                        child: Text('${p['name']} · ${p['price_iqd']} IQD'),
                      ),
                      IconButton(
                        tooltip: 'Remove ${p['name']}',
                        onPressed: locked
                            ? null
                            : () => setState(() {
                                final q = (_quantities[p['id']] ?? 0) - 1;
                                if (q <= 0) {
                                  _quantities.remove(p['id']);
                                } else {
                                  _quantities[p['id']] = q;
                                }
                              }),
                        icon: const Icon(Icons.remove),
                      ),
                      Text('${_quantities[p['id']] ?? 0}'),
                      IconButton(
                        tooltip: 'Add ${p['name']}',
                        onPressed:
                            locked ||
                                (_quantities[p['id']] ?? 0) >= 20 ||
                                (!_quantities.containsKey(p['id']) &&
                                    _quantities.length >= 20)
                            ? null
                            : () => setState(
                                () => _quantities[p['id']] =
                                    (_quantities[p['id']] ?? 0) + 1,
                              ),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                TextField(
                  controller: _notes,
                  enabled: !locked,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Preparation notes',
                  ),
                ),
                Text('Total: $total IQD'),
                if (_error != null) Text(_error!),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: _busy || products.isEmpty ? null : _save,
            child: Text(
              _busy
                  ? 'Saving…'
                  : _submitted == null
                  ? 'Place order'
                  : 'Retry same order',
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentEditor extends StatefulWidget {
  const _PaymentEditor({
    required this.order,
    required this.original,
    required this.rpc,
  });
  final Map<String, dynamic> order;
  final Map<String, dynamic>? original;
  final CafeRpc rpc;
  @override
  State<_PaymentEditor> createState() => _PaymentEditorState();
}

class _PaymentEditorState extends State<_PaymentEditor> {
  final _amount = TextEditingController(), _reference = TextEditingController();
  final _request = newCafeRequestId();
  String _method = 'cash';
  String? _error;
  bool _busy = false;
  Map<String, dynamic>? _submitted;
  int get maximum {
    if (widget.original == null) {
      return ((widget.order['total_iqd'] as num) -
              (widget.order['paid_iqd'] as num))
          .toInt();
    }
    final refunded = cafeRows(widget.order['payments'])
        .where((p) => p['original_payment_id'] == widget.original!['id'])
        .fold<int>(0, (n, p) => n + (p['amount_iqd'] as num).toInt());
    return (widget.original!['amount_iqd'] as num).toInt() - refunded;
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final refund = widget.original != null;
    if (_submitted == null) {
      final amount = int.tryParse(_amount.text.trim());
      if (amount == null ||
          amount <= 0 ||
          amount > maximum ||
          ((refund || _method == 'manual_card') &&
              _reference.text.trim().length < 3)) {
        setState(
          () => _error =
              'Enter a whole IQD amount from 1 to $maximum and the required reference or refund reason.',
        );
        return;
      }
      _submitted = {
        'p_request_id': _request,
        'p_amount_iqd': amount,
        if (refund) ...{
          'p_payment_id': widget.original!['id'],
          'p_reason': _reference.text.trim(),
        } else ...{
          'p_order_id': widget.order['id'],
          'p_method': _method,
          'p_reference': _reference.text.trim(),
        },
      };
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.rpc(
        refund ? 'refund_cafe_payment' : 'capture_cafe_payment',
        _submitted!,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Save could not be confirmed. Retry uses the same receipt request. Close and refresh payments before making a different entry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final refund = widget.original != null;
    final locked = _busy || _submitted != null;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(refund ? 'Record refund' : 'Record payment'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Maximum: $maximum IQD'),
                if (!refund)
                  DropdownButtonFormField<String>(
                    initialValue: _method,
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(
                        value: 'manual_card',
                        child: Text('Card — already paid on terminal'),
                      ),
                    ],
                    onChanged: locked
                        ? null
                        : (v) => setState(() => _method = v!),
                    isExpanded: true,
                  ),
                TextField(
                  controller: _amount,
                  enabled: !locked,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (IQD)'),
                ),
                TextField(
                  controller: _reference,
                  enabled: !locked,
                  maxLength: 120,
                  decoration: InputDecoration(
                    labelText: refund
                        ? 'Refund reason'
                        : _method == 'manual_card'
                        ? 'Terminal reference'
                        : 'Reference (optional)',
                  ),
                ),
                Text(
                  refund
                      ? 'This records a refund already made. It does not transfer money.'
                      : 'Only record money you have received. This does not charge a card.',
                ),
                if (_error != null) Text(_error!),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: _busy || maximum <= 0 ? null : _save,
            child: Text(
              _busy
                  ? 'Saving…'
                  : _submitted == null
                  ? 'Save record'
                  : 'Retry same record',
            ),
          ),
        ],
      ),
    );
  }
}
