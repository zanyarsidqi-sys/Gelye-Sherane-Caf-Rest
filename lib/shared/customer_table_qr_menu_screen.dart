import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'customer_table_feedback_screen.dart';
import 'customer_call_employee_screen.dart';
import 'customer_table_bill_screen.dart';

/// Customer-facing, read-only QR table menu and local cart preview.
/// QR possession is NOT authorization to submit orders or read bills.
/// The backend must create a separate verified visit-scoped ordering session.
class CustomerTableQrMenuScreen extends StatefulWidget {
  const CustomerTableQrMenuScreen({super.key, required this.token, this.visitSessionToken});
  final String token;
  /// Issued separately by authorized staff; never derived from the public QR token.
  final String? visitSessionToken;

  @override
  State<CustomerTableQrMenuScreen> createState() => _CustomerTableQrMenuScreenState();
}

class _CustomerTableQrMenuScreenState extends State<CustomerTableQrMenuScreen> {
  late Future<List<Map<String, dynamic>>> _menu = _load();
  final Map<String, int> _quantities = {};
  final Map<String, String> _instructions = {};
  String _search = '';
  late Future<bool> _sessionValid = _validateVisitSession();
  Timer? _requestPoll;
  bool _sendingOrder = false;
  bool _checkingRequest = false;
  String? _retryKey;
  String? _requestId;
  Map<String, dynamic>? _requestStatus;
  String? _requestError;

  Future<bool> _validateVisitSession() async {
    final token = widget.visitSessionToken;
    if (token == null || token.isEmpty) return false;
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_customer_visit_session_valid',
        params: {'p_token': token},
      );
      return response == true;
    } catch (_) {
      return false; // Fail closed if the session RPC is unavailable.
    }
  }


  Future<List<Map<String, dynamic>>> _load() async {
    final result = await Supabase.instance.client.rpc(
      'gs_public_table_menu', params: {'p_token': widget.token},
    );
    return (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _editInstructions(String productId, String productName) async {
    final controller = TextEditingController(text: _instructions[productId] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Instructions for $productName'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Preparation instructions (optional)',
            hintText: 'Example: no onions, less sugar',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (!mounted) return;
    if (result != null) setState(() {
      if (result.isEmpty) { _instructions.remove(productId); }
      else { _instructions[productId] = result; }
    });
    controller.dispose();
  }

  String _newIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _submitForStaffReview(List<Map<String, dynamic>> items) async {
    final session = widget.visitSessionToken;
    if (_sendingOrder || _requestId != null || session == null) return;
    final sessionIsValid = await _sessionValid;
    if (!mounted) return;
    if (!sessionIsValid) {
      setState(() => _requestError =
          'This visit session is no longer valid. Ask staff to issue a new one.');
      return;
    }

    final cart = <Map<String, dynamic>>[];
    for (final item in items) {
      final productId = int.tryParse(item['product_id']?.toString() ?? '');
      final key = item['product_id'].toString();
      final quantity = _quantities[key] ?? 0;
      if (quantity <= 0) continue;
      if (productId == null || productId <= 0) {
        setState(() => _requestError =
            'A menu item could not be verified. Refresh the menu and try again.');
        return;
      }
      cart.add({
        'product_id': productId,
        'quantity': quantity,
        'instructions': _instructions[key],
      });
    }
    if (cart.isEmpty) return;

    _retryKey ??= _newIdempotencyKey();
    setState(() { _sendingOrder = true; _requestError = null; });
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_public_submit_table_order_request',
        params: {
          'p_table_qr_token': widget.token,
          'p_session_token': session,
          'p_idempotency_key': _retryKey,
          'p_items': cart,
        },
      );
      final requestId = response.toString();
      if (requestId.isEmpty || requestId == 'null') {
        throw StateError('The server did not return a request reference');
      }
      if (!mounted) return;
      setState(() {
        _requestId = requestId;
        _requestStatus = {'status': 'pending'};
        _requestError = null;
        _retryKey = null;
      });
      _startRequestPolling();
    } catch (_) {
      if (mounted) {
        setState(() => _requestError =
            'The request was not confirmed. Your cart is kept; retry will reuse the same reference.');
      }
    } finally {
      if (mounted) setState(() => _sendingOrder = false);
    }
  }

  void _startRequestPolling() {
    _requestPoll?.cancel();
    unawaited(_refreshRequestStatus());
    _requestPoll = Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(_refreshRequestStatus());
    });
  }

  Future<void> _refreshRequestStatus() async {
    final requestId = _requestId;
    final session = widget.visitSessionToken;
    if (requestId == null || session == null || _checkingRequest || !mounted) return;
    _checkingRequest = true;
    try {
      final response = await Supabase.instance.client.rpc(
        'gs_customer_table_order_request_status',
        params: {'p_session_token': session, 'p_request_id': requestId},
      );
      final rows = (response as List).cast<Map>();
      if (rows.isEmpty) throw StateError('Request status is unavailable');
      final next = Map<String, dynamic>.from(rows.first);
      if (!mounted) return;
      setState(() { _requestStatus = next; _requestError = null; });
      if (next['status'] == 'accepted' || next['status'] == 'rejected') {
        _requestPoll?.cancel();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _requestError =
            'Request status is temporarily unavailable. Use Refresh status before retrying.');
      }
    } finally {
      _checkingRequest = false;
    }
  }

  void _startAnotherRequest({required bool clearCart}) {
    _requestPoll?.cancel();
    setState(() {
      _requestId = null;
      _requestStatus = null;
      _requestError = null;
      _retryKey = null;
      if (clearCart) {
        _quantities.clear();
        _instructions.clear();
      }
    });
  }

  Future<void> _refresh() async {
    if (_retryKey != null && _requestId == null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Start a new order attempt?'),
          content: const Text(
            'The earlier request may have reached staff even though this screen '
            'did not receive a response. Retry with the same reference first. '
            'Clear only if staff confirms no request was received.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep current cart'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Clear and refresh'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _retryKey = null;
      _requestError = null;
      _instructions.clear();
      _quantities.clear();
      _menu = _load();
      _sessionValid = _validateVisitSession();
    });
  }

  String _instructionSummary(String productId) {
    final note = _instructions[productId];
    return note == null || note.isEmpty ? '' : '\nInstructions: $note';
  }

  int _price(Map<String, dynamic> item) =>
      (item['unit_price_iqd'] as num?)?.toInt() ?? 0;

  String _money(int amount) => '${amount.toString()} IQD';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Table Menu'), actions: [
      IconButton(onPressed: _refresh, tooltip: 'Refresh table prices', icon: const Icon(Icons.refresh)),
    ]),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _menu,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('This table menu is unavailable. Please ask an employee.'),
              TextButton(onPressed: _refresh, child: const Text('Try again')),
            ]));
          }
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        final table = items.isEmpty ? null : items.first['table_number'];
        final visible = items.where((e) =>
          (e['product_name']?.toString().toLowerCase() ?? '').contains(_search.toLowerCase())).toList();
        var total = 0;
        var count = 0;
        for (final item in items) {
          final qty = _quantities[item['product_id'].toString()] ?? 0;
          total += qty * _price(item);
          count += qty;
        }
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text(table == null ? 'Table menu' : 'Table $table', style: Theme.of(context).textTheme.headlineSmall),
          const Text('Prices shown are for this table’s current mode. Refresh before reviewing your cart.'),
          const SizedBox(height: 8),
          FutureBuilder<bool>(
            future: _sessionValid,
            builder: (context, sessionSnapshot) {
              final valid = sessionSnapshot.data == true;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Icon(valid ? Icons.verified_user_outlined : Icons.lock_outline),
                    const SizedBox(width: 10),
                    Expanded(child: Text(valid
                      ? 'Current table visit verified. Customer order requests go to staff review before becoming live orders.'
                      : 'Read-only menu. Ask an employee to authorize this table visit. Orders and bills remain private.')),
                  ]),
                ),
              );
            },
          ),
          Card(child: Column(children: [
            ListTile(leading: const Icon(Icons.restaurant_menu),
              title: const Text('Menu & order preview'),
              subtitle: const Text('Browse items and prepare your cart below.')),
            FutureBuilder<bool>(
              future: _sessionValid,
              builder: (context, sessionSnapshot) {
                final authorized = sessionSnapshot.data == true &&
                    widget.visitSessionToken != null;
                return ListTile(
                  leading: Icon(authorized ? Icons.receipt_long_outlined : Icons.lock_outline),
                  title: const Text('Check table bill'),
                  subtitle: Text(authorized
                    ? 'View items and gross order amount for this visit (IQD).'
                    : 'Ask an employee to authorize this table visit.'),
                  trailing: Icon(authorized ? Icons.chevron_right : Icons.lock_outline),
                  onTap: authorized ? () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => CustomerTableBillScreen(
                      visitSessionToken: widget.visitSessionToken!))) : null,
                );
              },
            ),
            ListTile(leading: const Icon(Icons.event_seat_outlined),
              title: const Text('Extra chairs / specific order'),
              subtitle: const Text('Request more chairs or ask staff for a specific item'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => CustomerCallEmployeeScreen(visitSessionToken: widget.visitSessionToken))),
            ),
            ListTile(leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Call an employee'),
              subtitle: const Text('Waiter, cashier, shisha, supervisor, or any available staff'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => CustomerCallEmployeeScreen(visitSessionToken: widget.visitSessionToken))),
            ),
          ])),
          OutlinedButton.icon(
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('Survey, item ratings & product suggestions'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => CustomerTableFeedbackScreen(
                token: widget.token,
                visitSessionToken: widget.visitSessionToken,
                products: items.map((e) => Map<String, dynamic>.from(e)).toList(),
              ),
            )),
          ),
          const SizedBox(height: 12),
          TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search products', border: OutlineInputBorder()),
            onChanged: (value) => setState(() => _search = value)),
          const SizedBox(height: 12),
          for (final item in visible)
            Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(children: [
              Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['product_name']?.toString() ?? 'Product', style: Theme.of(context).textTheme.titleMedium),
                Text(_money(_price(item))),
              ])),
              IconButton(tooltip: 'Remove one', onPressed: _requestId != null || _retryKey != null || _sendingOrder || (_quantities[item['product_id'].toString()] ?? 0) == 0 ? null : () => setState(() {
                final key = item['product_id'].toString();
                _quantities[key] = (_quantities[key] ?? 0) - 1;
              }), icon: const Icon(Icons.remove_circle_outline)),
              Text('${_quantities[item['product_id'].toString()] ?? 0}'),
              IconButton(tooltip: 'Add one', onPressed: _requestId != null || _retryKey != null || _sendingOrder ? null : () => setState(() {
                final key = item['product_id'].toString();
                _quantities[key] = (_quantities[key] ?? 0) + 1;
              }), icon: const Icon(Icons.add_circle_outline)),
              ]),
              if ((_quantities[item['product_id'].toString()] ?? 0) > 0)
                Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                  icon: const Icon(Icons.edit_note),
                  label: Text((_instructions[item['product_id'].toString()] ?? '').isEmpty
                    ? 'Add preparation instructions'
                    : 'Edit: ${_instructions[item['product_id'].toString()]}',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  onPressed: _requestId != null || _retryKey != null || _sendingOrder ? null : () => _editInstructions(
                    item['product_id'].toString(), item['product_name']?.toString() ?? 'Product'),
                )),
            ]))),
          const Divider(),
          Text('Cart: $count items', style: Theme.of(context).textTheme.titleMedium),
          for (final item in items.where((e) => (_quantities[e['product_id'].toString()] ?? 0) > 0))
            ListTile(title: Text(item['product_name'].toString()),
              subtitle: Text('${_quantities[item['product_id'].toString()]} × ${_money(_price(item))}'
                '${_instructionSummary(item['product_id'].toString())}'),
              trailing: Text(_money((_quantities[item['product_id'].toString()] ?? 0) * _price(item)))),
          ListTile(title: const Text('Estimated total'), trailing: Text(_money(total))),
           if (_requestId != null)
             Card(
               child: Column(children: [
                 ListTile(
                   leading: Icon(_requestStatus?['status'] == 'accepted'
                       ? Icons.check_circle_outline
                       : _requestStatus?['status'] == 'rejected'
                           ? Icons.cancel_outlined
                           : Icons.hourglass_top),
                   title: Text('Order request: ${_requestStatus?['status'] ?? 'checking'}'),
                   subtitle: Text(
                     _requestStatus?['status'] == 'accepted'
                         ? 'Staff accepted your request. Order #${_requestStatus?['order_id'] ?? ''}.'
                         : _requestStatus?['status'] == 'rejected'
                             ? 'Staff could not accept it: ${_requestStatus?['rejection_reason'] ?? 'No reason provided.'}'
                             : 'Waiting for staff review. This request is not yet an order or kitchen ticket.'),
                 ),
                 if (_requestStatus?['request_id'] != null)
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 16),
                     child: SelectableText(
                       "Request reference: ${_requestStatus!['request_id']}",
                     ),
                   ),
                 if (_requestError != null)
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 16),
                     child: Text(_requestError!,
                         style: TextStyle(color: Theme.of(context).colorScheme.error)),
                   ),
                 Wrap(spacing: 8, children: [
                   TextButton.icon(
                     onPressed: _checkingRequest ? null : _refreshRequestStatus,
                     icon: const Icon(Icons.refresh),
                     label: const Text('Refresh status'),
                   ),
                   if (_requestStatus?['status'] == 'accepted' ||
                       _requestStatus?['status'] == 'rejected')
                     TextButton.icon(
                       onPressed: () => _startAnotherRequest(
                           clearCart: _requestStatus?['status'] == 'accepted'),
                       icon: const Icon(Icons.add_shopping_cart),
                       label: const Text('Start another request'),
                     ),
                 ]),
               ]),
             )
           else ...[
             const Text('Staff reviews each request before it becomes an order. Prices are recalculated by the server when staff accepts.'),
             if (_requestError != null)
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Padding(
                     padding: const EdgeInsets.symmetric(vertical: 8),
                     child: Text(_requestError!,
                         style: TextStyle(color: Theme.of(context).colorScheme.error)),
                   ),
                   if (_retryKey != null)
                     SelectableText('Retry reference: $_retryKey'),
                 ],
               ),
             FutureBuilder<bool>(
               future: _sessionValid,
               builder: (context, sessionSnapshot) {
                 final valid = sessionSnapshot.data == true &&
                     widget.visitSessionToken != null;
                 return FilledButton.icon(
                   onPressed: valid && count > 0 && !_sendingOrder
                       ? () => _submitForStaffReview(items)
                       : null,
                   icon: _sendingOrder
                       ? const SizedBox(width: 18, height: 18,
                           child: CircularProgressIndicator(strokeWidth: 2))
                       : const Icon(Icons.send_outlined),
                   label: Text(_sendingOrder
                       ? 'Sending request…'
                       : valid
                           ? 'Send to staff for review'
                           : 'Staff-authorized visit required'),
                 );
               },
             ),
           ],
        ]);
      },
    ),
  );

  @override
  void dispose() {
    _requestPoll?.cancel();
    super.dispose();
  }
}
