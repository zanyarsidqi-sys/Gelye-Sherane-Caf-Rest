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

  void _refresh() => setState(() {
    _instructions.clear();
    _quantities.clear(); // Prevent stale prices after a mode change.
    _menu = _load();
    _sessionValid = _validateVisitSession();
  });

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
                      ? 'Current table visit verified. Bill preview and assistance requests are available. Direct ordering is not enabled yet.'
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
              IconButton(tooltip: 'Remove one', onPressed: (_quantities[item['product_id'].toString()] ?? 0) == 0 ? null : () => setState(() {
                final key = item['product_id'].toString();
                _quantities[key] = (_quantities[key] ?? 0) - 1;
              }), icon: const Icon(Icons.remove_circle_outline)),
              Text('${_quantities[item['product_id'].toString()] ?? 0}'),
              IconButton(tooltip: 'Add one', onPressed: () => setState(() {
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
                  onPressed: () => _editInstructions(
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
          const Text('Preview only. Ordering is disabled until secure customer session and server-side price confirmation are implemented.'),
          FilledButton(onPressed: null, child: const Text('Submit order — coming soon')),
        ]);
      },
    ),
  );
}
