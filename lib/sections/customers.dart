import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/section_shell.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});
  @override
  Widget build(BuildContext context) => const SectionShell(
    title: 'Customers', description: 'Customer directory, visit history and rankings',
    sectionId: 'customers', authorizedContent: _CustomerWorkspace(),
  );
}

class _CustomerWorkspace extends StatefulWidget {
  const _CustomerWorkspace();
  @override
  State<_CustomerWorkspace> createState() => _CustomerWorkspaceState();
}

class _CustomerWorkspaceState extends State<_CustomerWorkspace> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _customers = [];
  String _search = '';
  String? _error;
  bool _busy = false;
  bool _monthlyLoaded = false;
  @override
  void initState() { super.initState(); _reload(); }

  Future<void> _reload() async {
    setState(() { _busy = true; _error = null; });
    try {
      final data = await _db.rpc('gs_list_cafe_customers');
      if (mounted) setState(() => _customers = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) {
      if (mounted) setState(() => _error = 'Unable to load customers: $e');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _addCustomer() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final notes = TextEditingController();
    try {
      final save = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Add customer'),
        content: SizedBox(width: 430, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Guest name *')),
          TextField(controller: phone, keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone (optional)')),
          TextField(controller: notes, maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes (optional)')),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))],
      ));
      if (save != true) return;
      await _db.rpc('gs_add_cafe_customer', params: {
        'p_name': name.text.trim(), 'p_phone': phone.text.trim(), 'p_notes': notes.text.trim(),
      });
      await _reload();
    } catch (e) { _message('Could not save customer: $e'); }
    finally { name.dispose(); phone.dispose(); notes.dispose(); }
  }

  void _message(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showHistory(Map<String, dynamic> customer) async {
    try {
      final data = await _db.rpc('gs_cafe_customer_visit_history',
        params: {'p_customer_id': customer['id']});
      if (!mounted) return;
      final visits = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text('Visit history · ${customer['full_name']}'),
        content: SizedBox(width: 520, height: 360, child: visits.isEmpty
          ? const Center(child: Text('No visits recorded yet.'))
          : ListView(children: [for (final v in visits) ListTile(
              leading: const Icon(Icons.history),
              title: Text(v['table_number'] == null ? 'Visit' : 'Table ${v['table_number']}'),
              subtitle: Text('${v['visited_at']}\n${v['notes'] ?? ''}'),
            )])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (e) { _message('Could not load history: $e'); }
  }

  Future<void> _showReservations(Map<String, dynamic> customer) async {
    try {
      final data = await _db.rpc('gs_cafe_customer_reservation_history',
        params: {'p_customer_id': customer['id']});
      if (!mounted) return;
      final rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text('Reservations · ${customer['full_name']}'),
        content: SizedBox(width: 520, height: 360, child: rows.isEmpty
          ? const Center(child: Text('No linked reservations yet.'))
          : ListView(children: [for (final r in rows) ListTile(
              leading: const Icon(Icons.event_note),
              title: Text('${r['status']} · ${r['party_size']} guests'),
              subtitle: Text('${r['requested_at']} · ${r['submission_channel']}'),
            )])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (e) { _message('Could not load reservations: $e'); }
  }

  // Combined customer profile: existing authorized RPCs remain the source of truth.
  // No financial values are inferred from orders or unverified payments.
  Future<void> _showCustomerProfile(Map<String, dynamic> customer) async {
    final id = customer['id'];
    try {
      final results = await Future.wait<dynamic>([
        _db.rpc('gs_cafe_customer_visit_history', params: {'p_customer_id': id}),
        _db.rpc('gs_cafe_customer_reservation_history', params: {'p_customer_id': id}),
        _db.rpc('gs_cafe_customer_cash_spend_history', params: {'p_customer_id': id}),
      ]);
      if (!mounted) return;
      final visits = (results[0] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final reservations = (results[1] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final payments = (results[2] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final cashTotal = payments.fold<int>(0, (total, row) =>
        total + ((row['amount_iqd'] as num?)?.toInt() ?? 0));
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text('Customer profile · ${customer['full_name']}'),
        content: SizedBox(width: 670, height: 560, child: ListView(children: [
          Text('Phone: ${customer['phone'] ?? 'Not provided'}'),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 8, children: [
            Chip(label: Text('${customer['visit_count'] ?? visits.length} recorded visits')),
            Chip(label: Text('${reservations.length} linked reservations (up to history limit)')),
            Chip(label: Text('${payments.length} qualifying cash settlements shown')),
          ]),
          const SizedBox(height: 6),
          Text('Qualifying cash shown: $cashTotal IQD',
            style: Theme.of(ctx).textTheme.titleMedium),
          const Text('Cash figure is a sum of the returned history (maximum 500 records). '
            'It excludes credit, card, mixed and unverified payments; not lifetime total spending.'),
          const Divider(),
          Text('Recent visits', style: Theme.of(ctx).textTheme.titleMedium),
          if (visits.isEmpty) const Text('No visits recorded.'),
          for (final v in visits.take(20)) ListTile(
            dense: true, leading: const Icon(Icons.history),
            title: Text(v['table_number'] == null ? 'Visit' : 'Table ${v['table_number']}'),
            subtitle: Text('${v['visited_at']}')),
          const Divider(),
          Text('Recent reservations', style: Theme.of(ctx).textTheme.titleMedium),
          if (reservations.isEmpty) const Text('No linked reservations.'),
          for (final r in reservations.take(20)) ListTile(
            dense: true, leading: const Icon(Icons.event),
            title: Text('${r['status']} · ${r['party_size']} guests'),
            subtitle: Text('${r['requested_at']}')),
          const Divider(),
          Text('Attested cash payments', style: Theme.of(ctx).textTheme.titleMedium),
          if (payments.isEmpty) const Text('No qualifying cash payments.'),
          for (final p in payments.take(30)) ListTile(
            dense: true, leading: const Icon(Icons.receipt_long),
            title: Text('${p['amount_iqd']} IQD · Order #${p['order_id']}'),
            subtitle: Text('Table ${p['table_number']} · ${p['settled_at']}')),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (e) { _message('Could not load customer profile: $e'); }
  }


  // Server-side aggregate: not limited by the 500-row history display cap.
  Future<void> _showCustomerAnalytics(Map<String, dynamic> customer) async {
    try {
      final data = await Future.wait<dynamic>([
        _db.rpc('gs_cafe_customer_performance', params: {'p_customer_id': customer['id']}),
        _db.rpc('gs_cafe_customer_monthly_trend', params: {
          'p_customer_id': customer['id'], 'p_months': 6,
        }),
      ]);
      if (!mounted) return;
      final summaryRows = (data[0] as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final trend = (data[1] as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (summaryRows.isEmpty) { _message('No analytics available.'); return; }
      final s = summaryRows.first;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text('Customer analytics · ${customer['full_name']}'),
        content: SizedBox(width: 610, height: 490, child: ListView(children: [
          Text('First visit: ${s['first_visit'] ?? 'No visits'}'),
          Text('Last visit: ${s['last_visit'] ?? 'No visits'}'),
          Text('Total recorded visits: ${s['total_visits']}'),
          Text('Attested cash total: ${s['attested_cash_iqd']} IQD'),
          Text('Qualifying cash orders: ${s['attested_cash_orders']}'),
          Text('Average qualifying cash order: ${s['average_cash_order_iqd']} IQD'),
          const SizedBox(height: 8),
          const Text('Cash figures exclude card, credit, mixed and unverified payments. '
              'Average is per qualifying cash order, not per visit.'),
          const Divider(),
          Text('Last six months', style: Theme.of(ctx).textTheme.titleMedium),
          for (final m in trend) ListTile(
            dense: true,
            title: Text('${m['month_start']} · ${m['visit_count']} visits'),
            subtitle: Text('${m['attested_cash_orders']} cash orders'),
            trailing: Text('${m['attested_cash_iqd']} IQD'),
          ),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (e) { _message('Could not load customer analytics: $e'); }
  }

  Future<void> _recordVisit(Map<String, dynamic> customer) async {
    final table = TextEditingController();
    final notes = TextEditingController();
    try {
      final save = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: Text('Record visit · ${customer['full_name']}'),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: table, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Table number (optional)')),
          TextField(controller: notes, decoration: const InputDecoration(labelText: 'Visit notes')),
          const SizedBox(height: 8),
          const Text('Record only real visits. This does not charge the customer.'),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Record'))],
      ));
      if (save != true) return;
      final number = table.text.trim().isEmpty ? null : int.tryParse(table.text.trim());
      if (table.text.trim().isNotEmpty && number == null) { _message('Invalid table number'); return; }
      await _db.rpc('gs_record_cafe_customer_visit', params: {
        'p_customer_id': customer['id'], 'p_table_number': number, 'p_notes': notes.text.trim(),
      });
      await _reload();
    } catch (e) { _message('Could not record visit: $e'); }
    finally { table.dispose(); notes.dispose(); }
  }

  Future<void> _showMonthlyRankings() async {
    DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
    String rankBy = 'spend';
    List<Map<String, dynamic>> rows = [];
    bool loading = false;
    String? error;
    _monthlyLoaded = false;
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (dialogContext) =>
      StatefulBuilder(builder: (ctx, update) {
        Future<void> load() async {
          update(() { loading = true; error = null; });
          try {
            final value = await _db.rpc('gs_cafe_customer_period_rankings', params: {
              'p_month': '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-01',
              'p_rank_by': rankBy,
            });
            if (ctx.mounted) update(() => rows = (value as List)
                .map((e) => Map<String, dynamic>.from(e as Map)).toList());
          } catch (e) {
            if (ctx.mounted) update(() => error = '$e');
          } finally {
            if (ctx.mounted) update(() => loading = false);
          }
        }
        // Fetch on first frame, once per dialog instance.
        if (!loading && rows.isEmpty && error == null && !_monthlyLoaded) {
          _monthlyLoaded = true;
          WidgetsBinding.instance.addPostFrameCallback((_) { if (ctx.mounted) load(); });
        }
        return AlertDialog(
          title: const Text('Monthly customer rankings'),
          content: SizedBox(width: 610, height: 470, child: Column(children: [
            Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              IconButton(tooltip: 'Previous month', onPressed: loading ? null : () {
                update(() => month = DateTime(month.year, month.month - 1)); load();
              }, icon: const Icon(Icons.chevron_left)),
              Text('${month.year}-${month.month.toString().padLeft(2, '0')}'),
              IconButton(tooltip: 'Next month', onPressed: loading ? null : () {
                update(() => month = DateTime(month.year, month.month + 1)); load();
              }, icon: const Icon(Icons.chevron_right)),
              DropdownButton<String>(value: rankBy, items: const [
                DropdownMenuItem(value: 'spend', child: Text('Highest cash spending')),
                DropdownMenuItem(value: 'visits', child: Text('Most visits')),
              ], onChanged: loading ? null : (v) {
                if (v == null) return;
                update(() => rankBy = v); load();
              }),
            ]),
            const Text('Only attested cash-only settlements count toward spending. Other payment types are excluded.'),
            if (loading) const LinearProgressIndicator(),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
            Expanded(child: rows.isEmpty && !loading
              ? const Center(child: Text('No customer activity for this month.'))
              : ListView.builder(itemCount: rows.length, itemBuilder: (context, index) {
                final c = rows[index];
                return ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text('${c['customer_name']}'),
                  subtitle: Text('${c['visit_count']} visits · ${c['settled_orders']} cash orders'),
                  trailing: Text('${c['cash_spent_iqd']} IQD'),
                );
              })),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        );
      }));
    _monthlyLoaded = false;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _customers.where((c) =>
      '${c['full_name']} ${c['phone'] ?? ''}'.toLowerCase().contains(_search.toLowerCase())).toList();
    return Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        FilledButton.icon(onPressed: _addCustomer, icon: const Icon(Icons.person_add),
          label: const Text('Add customer')),
        OutlinedButton.icon(onPressed: _showMonthlyRankings, icon: const Icon(Icons.leaderboard),
          label: const Text('Monthly rankings')),
        OutlinedButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh),
          label: const Text('Refresh')),
        SizedBox(width: 270, child: TextField(onChanged: (s) => setState(() => _search = s),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search),
            labelText: 'Search name or phone'))),
      ]),
      const SizedBox(height: 12),
      const Text('Customer list is ranked by visits. Top cash customers uses only fully attested cash-only settlements; it is not total spending across all payment methods.'),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      if (_busy) const LinearProgressIndicator(),
      Expanded(child: ListView.builder(itemCount: visible.length, itemBuilder: (ctx, index) {
        final c = visible[index];
        return Card(child: ListTile(
          leading: CircleAvatar(child: Text('${index + 1}')),
          title: Text('${c['full_name']}'),
          subtitle: Text('${c['visit_count']} visits · Last visit: ${c['last_visit'] ?? 'None'}\n${c['phone'] ?? 'No phone'}'),
          isThreeLine: true,
          trailing: Wrap(children: [
            IconButton(tooltip: 'Customer profile', onPressed: () => _showCustomerProfile(c), icon: const Icon(Icons.account_box_outlined)),
            IconButton(tooltip: 'Customer analytics', onPressed: () => _showCustomerAnalytics(c), icon: const Icon(Icons.insights)),
            IconButton(tooltip: 'Visit history', onPressed: () => _showHistory(c), icon: const Icon(Icons.history)),
            IconButton(tooltip: 'Reservation history', onPressed: () => _showReservations(c), icon: const Icon(Icons.event_note)),
            IconButton(tooltip: 'Record visit', onPressed: () => _recordVisit(c), icon: const Icon(Icons.add_circle_outline)),
          ]),
        ));
      })),
    ]));
  }
}
