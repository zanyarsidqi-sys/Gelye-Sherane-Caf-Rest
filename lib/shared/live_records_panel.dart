import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only view of the optional Phase 3 gs_ tables.
/// It never writes data or bypasses database RLS.
class LiveRecordsPanel extends StatefulWidget {
  const LiveRecordsPanel({super.key, required this.kind});
  final String kind; // menu, table, motel, kitchen

  @override
  State<LiveRecordsPanel> createState() => _LiveRecordsPanelState();
}

class _LiveRecordsPanelState extends State<LiveRecordsPanel> {
  late Future<List<Map<String, dynamic>>> _records = _load();
  String _search = "";
  String _status = "all";
  String _menuStatus = "all";
  String _menuSort = "name";
  bool _resultsMayBeTruncated = false;
  int _loadGeneration = 0;

  @override
  void dispose() {
    _loadGeneration++;
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final employeeId = client.auth.currentUser?.id;
    if (employeeId == null) throw StateError('Sign in before viewing live records.');
    final generation = ++_loadGeneration;
    const pageSize = 250;
    const maxPages = 20;
    final all = <Map<String, dynamic>>[];
    for (var page = 0; page < maxPages; page++) {
      List<Map<String, dynamic>> rows;
      if (widget.kind == 'menu') {
        final response = await client.from('gs_menu_products')
            .select('id,name,barcode,normal_price_iqd,tourism_price_iqd,is_active')
            .order('id').range(page * pageSize, (page + 1) * pageSize - 1);
        rows = List<Map<String, dynamic>>.from(response);
      } else {
        var query = client.from('gs_orders')
            .select('id,destination,is_motel,tourism_mode,status,created_at');
        if (widget.kind == 'table' || widget.kind == 'motel') {
          query = query.eq('is_motel', widget.kind == 'motel');
        }
        final response = await query.order('id', ascending: false)
            .range(page * pageSize, (page + 1) * pageSize - 1);
        rows = List<Map<String, dynamic>>.from(response);
      }
      if (client.auth.currentUser?.id != employeeId || generation != _loadGeneration) {
        throw StateError('Employee session changed while loading records; refresh.');
      }
      all.addAll(rows);
      if (rows.length < pageSize) {
        _resultsMayBeTruncated = false;
        return all;
      }
    }
    if (client.auth.currentUser?.id != employeeId || generation != _loadGeneration) {
      throw StateError('Employee changed while finishing record pagination.');
    }
    _resultsMayBeTruncated = true;
    return all;
  }

  Future<void> _showPaymentSummary(Object? orderId) async {
    if (orderId is! int || orderId <= 0) return;
    final employeeId = Supabase.instance.client.auth.currentUser?.id;
    if (employeeId == null) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Cash payment summary — order #$orderId'),
        content: SizedBox(
          width: 400,
          child: FutureBuilder<dynamic>(
            future: Supabase.instance.client.rpc(
              'gs_order_cash_payment_summary',
              params: {'p_order_id': orderId},
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData && !snapshot.hasError) {
                return const SizedBox(height: 90, child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return SelectableText('Unable to retrieve authorized payment summary: ${snapshot.error}');
              }
              if (Supabase.instance.client.auth.currentUser?.id != employeeId) {
                return const Text('Employee session changed. Close and reopen this summary.');
              }
              final result = snapshot.data;
              final Map<String, dynamic>? data = result is List && result.isNotEmpty
                  ? Map<String, dynamic>.from(result.first as Map)
                  : result is Map ? Map<String, dynamic>.from(result) : null;
              if (data == null) return const Text('No payment summary was returned.');
              String amount(String key) => '${data[key] ?? 0} IQD';
              return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Order total: ${amount('order_total_iqd')}'),
                Text('Cash received: ${amount('cash_paid_iqd')}'),
                Text('Remaining cash balance: ${amount('cash_balance_iqd')}'),
                Text('Cash status: ${data['cash_status'] ?? 'unknown'}'),
                Text('Cash payment entries: ${data['cash_payment_count'] ?? 0}'),
                const SizedBox(height: 12),
                const Text('Cash ledger only. Card and credit settlements are not included.',
                  style: TextStyle(fontSize: 12)),
              ]);
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ),
    );
  }

  void _reload() => setState(() {
    _loadGeneration++;
    _resultsMayBeTruncated = false;
    _records = _load();
  });

  @override
  Widget build(BuildContext context) => Column(children: [
    ListTile(
      leading: const Icon(Icons.cloud_outlined),
      title: const Text('Supabase records — read only'),
      subtitle: const Text('Requires reviewed gs_ migrations and employee access. Paginated, with a 5,000-record safety limit.'),
      trailing: IconButton(onPressed: _reload, tooltip: 'Refresh',
        icon: const Icon(Icons.refresh)),
    ),
    if (widget.kind == 'motel')
      const ListTile(
        leading: Icon(Icons.hotel_outlined),
        title: Text('Motel orders — Tourism Mode required'),
        subtitle: Text('This view is read-only. Verify charged prices in order items; mode alone does not prove server enforcement.'),
      ),
    if (widget.kind == 'menu') ...[
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Normal and Tourism prices use the same product and barcode.'),
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search product name or barcode',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _search = value.trim().toLowerCase()),
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          SizedBox(
            width: 165,
            child: DropdownButtonFormField<String>(
              initialValue: _menuStatus,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Products', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All products')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              ],
              onChanged: (value) => setState(() => _menuStatus = value ?? 'all'),
            ),
          ),
          SizedBox(
            width: 185,
            child: DropdownButtonFormField<String>(
              initialValue: _menuSort,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Sort by', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'name', child: Text('Product name')),
                DropdownMenuItem(value: 'normal', child: Text('Normal price')),
                DropdownMenuItem(value: 'tourism', child: Text('Tourism price')),
                DropdownMenuItem(value: 'difference', child: Text('Price difference')),
              ],
              onChanged: (value) => setState(() => _menuSort = value ?? 'name'),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 8),
    ],
    if (widget.kind == 'motel' || widget.kind == 'table') ...[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search room / table or order ID',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _search = value.trim().toLowerCase()),
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All statuses')),
            DropdownMenuItem(value: 'new', child: Text('New')),
            DropdownMenuItem(value: 'preparing', child: Text('Preparing')),
            DropdownMenuItem(value: 'ready', child: Text('Ready')),
            DropdownMenuItem(value: 'served', child: Text('Served')),
            DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
          ],
          onChanged: (value) => setState(() => _status = value ?? 'all'),
        ),
      ),
      const SizedBox(height: 8),
    ],
    Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _records,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ListView(children: [
            const ListTile(leading: Icon(Icons.warning_amber_outlined),
              title: Text('Unable to load live records'),
              subtitle: Text('Check the optional database migration, employee permissions and connection. Local previews remain available.')),
            Padding(padding: const EdgeInsets.all(16),
              child: SelectableText('${snapshot.error}')),
          ]);
        }
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        final filtered = rows.where((row) {
          if (widget.kind != 'motel' && widget.kind != 'table') return true;
          final searchText = '${row['id']} ${row['destination'] ?? ''}'.toLowerCase();
          final status = '${row['status'] ?? ''}'.toLowerCase();
          return (_search.isEmpty || searchText.contains(_search)) &&
              (_status == 'all' || status == _status);
        }).toList();
        if (widget.kind == 'menu') {
          filtered.retainWhere((row) {
            final searchText = '${row['name'] ?? ''} ${row['barcode'] ?? ''}'.toLowerCase();
            final active = row['is_active'] == true;
            return (_search.isEmpty || searchText.contains(_search)) &&
                (_menuStatus == 'all' || (_menuStatus == 'active' ? active : !active));
          });
          int price(Map<String, dynamic> row, String key) =>
              (row[key] as num?)?.toInt() ?? 0;
          filtered.sort((a, b) {
            switch (_menuSort) {
              case 'normal':
                return price(a, 'normal_price_iqd').compareTo(price(b, 'normal_price_iqd'));
              case 'tourism':
                return price(a, 'tourism_price_iqd').compareTo(price(b, 'tourism_price_iqd'));
              case 'difference':
                final deltaA = price(a, 'tourism_price_iqd') - price(a, 'normal_price_iqd');
                final deltaB = price(b, 'tourism_price_iqd') - price(b, 'normal_price_iqd');
                return deltaB.compareTo(deltaA);
              default:
                return '${a['name'] ?? ''}'.toLowerCase().compareTo('${b['name'] ?? ''}'.toLowerCase());
            }
          });
        }
        if (filtered.isEmpty) return Center(child: Text(_resultsMayBeTruncated
            ? 'No match among the first 5,000 accessible records; narrow the search in Supabase.'
            : 'No matching accessible records.'));
        return ListView.builder(
          itemCount: filtered.length + (_resultsMayBeTruncated ? 1 : 0),
          itemBuilder: (context, index) {
            if (_resultsMayBeTruncated && index == 0) {
              return const ListTile(
                leading: Icon(Icons.warning_amber_outlined),
                title: Text('Record list may be incomplete'),
                subtitle: Text('The 5,000-record safety limit was reached. Use a narrower query in Supabase.'),
              );
            }
            final row = filtered[index - (_resultsMayBeTruncated ? 1 : 0)];
            if (widget.kind == 'menu') {
              return Card(child: ListTile(
                title: Text('${row['name'] ?? ''}'),
                subtitle: Text('Barcode: ${row['barcode'] ?? ''}\nNormal: ${row['normal_price_iqd']} IQD  •  Tourism: ${row['tourism_price_iqd']} IQD\nDifference: ${((row['tourism_price_iqd'] as num?) ?? 0) - ((row['normal_price_iqd'] as num?) ?? 0)} IQD'),
                isThreeLine: true,
                trailing: row['is_active'] == true ? const Icon(Icons.check_circle_outline) : const Icon(Icons.pause_circle_outline),
              ));
            }
            return Card(child: ListTile(
              title: Text('Order #${row['id']} — ${row['destination'] ?? ''}'),
              subtitle: Text('${row['is_motel'] == true ? 'Motel' : 'Table'} • ${row['tourism_mode'] == true ? 'Tourism' : 'Normal'} • ${row['created_at'] ?? ''}'),
              trailing: Text('${row['status'] ?? ''}'),
              onTap: () => _showPaymentSummary(row['id']),
            ));
          },
        );
      },
    )),
  ]);
}
