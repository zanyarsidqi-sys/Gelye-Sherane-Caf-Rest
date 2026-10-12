import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-supplied, read-only table detail widgets. The backend is responsible
/// for authorizing and filtering guest, reservation and financial records.
/// Missing data is explicitly unavailable, never treated as a zero balance.
class TableDashboardDetails {
  const TableDashboardDetails._();

  static List<Widget> readOnlySections(Map<String, dynamic> table, {VoidCallback? onTableReleased}) {
    final widgets = <Widget>[];
    // A visit must be identified by its server-issued ID, never inferred
    // from a table number or from unrelated historical orders.
    final visitId = table['active_visit_id'] ?? table['table_visit_id'];
    if (visitId is num && visitId.toInt() > 0) {
      widgets.add(_VisitSettlementStatus(visitId: visitId.toInt()));
      widgets.add(_VisitPhysicalCheckoutStatus(visitId: visitId.toInt()));
      widgets.add(_CashOnlyVisitRelease(visitId: visitId.toInt(), onTableReleased: onTableReleased));
      widgets.add(_MixedPaymentCheckoutReadiness(visitId: visitId.toInt()));
      widgets.add(_VisitDepartureAndCleaning(visitId: visitId.toInt()));
    } else {
      widgets.add(const ListTile(
        leading: Icon(Icons.lock_outline),
        title: Text('Checkout not available'),
        subtitle: Text('No verified active visit ID was provided. ' 
          'Do not infer settlement from the table number.'),
      ));
    }
    final reservation = table['reservation'];
    if (reservation is Map) {
      final row = Map<String, dynamic>.from(reservation);
      widgets.add(const _Heading('Reservation'));
      for (final entry in <String, String>{
        'status': 'Status', 'arrival_time': 'Expected arrival',
        'party_size': 'Reserved guests', 'reservation_id': 'Reservation ID',
      }.entries) {
        if (row[entry.key] != null) widgets.add(_field(entry.value, row[entry.key]));
      }
    }
    final guests = table['guests'];
    if (guests is List) {
      widgets.add(const _Heading('Individual guests'));
      if (guests.isEmpty) widgets.add(const ListTile(title: Text('No guest details supplied')));
      for (var i = 0; i < guests.length; i++) {
        final guest = guests[i];
        if (guest is! Map) continue;
        final g = Map<String, dynamic>.from(guest);
        widgets.add(ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text((g['name'] is String && (g['name'] as String).trim().isNotEmpty)
              ? g['name'].toString() : 'Guest ${i + 1}'),
          subtitle: Text('Bill: ${_iqd(g['bill_iqd'])}  ·  Paid: ${_iqd(g['paid_iqd'])}'),
        ));
      }
    }
    final orders = table['orders'];
    if (orders is List) {
      widgets.add(const _Heading('Orders'));
      for (final order in orders) {
        if (order is! Map) continue;
        final o = Map<String, dynamic>.from(order);
        widgets.add(ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: Text('Order ${o['order_id'] ?? '—'}'),
          subtitle: Text('Status: ${o['status'] ?? 'Unavailable'}'),
          trailing: Text(_iqd(o['total_iqd'])),
        ));
      }
    }
    final payments = table['payments'];
    if (payments is List) {
      widgets.add(const _Heading('Payment records'));
      for (final payment in payments) {
        if (payment is! Map) continue;
        final p = Map<String, dynamic>.from(payment);
        widgets.add(ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: Text('${p['method'] ?? 'Unknown method'} · ${_iqd(p['amount_iqd'])}'),
          subtitle: Text('Status: ${p['status'] ?? 'Unavailable'}'),
        ));
      }
      widgets.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Pending payments are not collected funds. Confirmations must be performed by an independently authorized receiver.'),
      ));
    }
    if (widgets.isEmpty) {
      widgets.add(const ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('Detailed records unavailable'),
        subtitle: Text('Reservation, individual guest, order and payment details require authorized backend data.'),
      ));
    }
    return widgets;
  }

  static Widget _field(String label, Object? value) => ListTile(
    dense: true, title: Text(label), subtitle: Text(value?.toString() ?? 'Unavailable'));

  static String _iqd(Object? amount) => amount is num
      ? '${amount.toStringAsFixed(0)} IQD' : 'Unavailable';
}

class _Heading extends StatelessWidget {
  const _Heading(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 4),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}


/// Read-only, backend-authorized visit checkout gate. A provisional balance
/// is never sufficient evidence of settlement or guest departure.
class _VisitSettlementStatus extends StatefulWidget {
  const _VisitSettlementStatus({required this.visitId});
  final int visitId;
  @override
  State<_VisitSettlementStatus> createState() => _VisitSettlementStatusState();
}

class _VisitSettlementStatusState extends State<_VisitSettlementStatus> {
  late Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() async {
    final raw = await Supabase.instance.client.rpc(
      'gs_visit_settlement_gate',
      params: {'p_visit_id': widget.visitId},
    );
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw StateError('Visit settlement gate returned no record');
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Visit settlement and checkout',
            style: TextStyle(fontWeight: FontWeight.bold))),
          IconButton(
            tooltip: 'Refresh verified visit status',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _future = _load()),
          ),
        ]),
        FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Checkout blocked'),
                subtitle: Text(snapshot.hasError
                  ? 'Could not verify visit status. Check access and server migrations.'
                  : 'Checking authoritative server status…'),
              );
            }
            final data = snapshot.data!;
            // This panel deliberately never exposes a release action.
            // A future checkout mutation requires a separate audited RPC.
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Checkout not enabled in this dashboard'),
                subtitle: Text('Payment reconciliation is provisional. ' 
                  'Guest departure, cleaning and shisha must also be verified.'),
              ),
              Text('Visit: ${data['visit_id'] ?? widget.visitId}'),
              Text('Linked orders: ${data['order_count'] ?? 'Unavailable'}'),
              Text('Reconciliation exceptions: '
                '${data['reconciliation_exceptions'] ?? 'Unavailable'}'),
              Text('Unlinked historical orders: '
                '${data['unlinked_historical_orders'] ?? 'Unavailable'}'),
              const SizedBox(height: 8),
              Text('${data['blocking_reason'] ?? 'Checkout authorization unavailable'}'),
            ]);
          },
        ),
      ]),
    ),
  );
}


/// Authorized operational actions for the current, server-issued visit.
/// Physical departure is not a payment settlement or a table release.
class _VisitDepartureAndCleaning extends StatefulWidget {
  const _VisitDepartureAndCleaning({required this.visitId});
  final int visitId;
  @override
  State<_VisitDepartureAndCleaning> createState() => _VisitDepartureAndCleaningState();
}

class _VisitDepartureAndCleaningState extends State<_VisitDepartureAndCleaning> {
  bool _busy = false;
  bool _shisha = false;
  late Future<List<Map<String, dynamic>>> _tasks = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final response = await Supabase.instance.client.rpc(
      'gs_visit_cleaning_tasks', params: {'p_visit_id': widget.visitId});
    if (response is! List) throw StateError('No verified tasks returned');
    return response.map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  Future<void> _act(String rpc, Map<String, dynamic> params) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc(rpc, params: params);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Operation saved. Refresh visit settlement separately.')));
      setState(() => _tasks = _load());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Operation denied or server unavailable. Check permissions and migrations.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDeparture() async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm physical guest departure'),
        content: Text('Confirm all guests have physically left visit ${widget.visitId}. '
          'A cleaning task will be created. This does NOT confirm payment or release the table.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm departure')),
        ],
      ));
    if (confirmed != true || !mounted) return;
    await _act('gs_record_visit_guest_departure', {
      'p_visit_id': widget.visitId, 'p_shisha_pickup_required': _shisha});
  }

  Future<void> _complete(Map<String, dynamic> task) async {
    final id = task['id'];
    if (id is! num) return;
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm task completed'),
        content: Text('Has ${task['request_type']} actually been completed? '
          'This will not release the table.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Complete task')),
        ],
      ));
    if (confirmed != true || !mounted) return;
    await _act('gs_complete_visit_service_task', {
      'p_task_id': id.toInt(), 'p_visit_id': widget.visitId,
      'p_completion_note': 'Confirmed completed by authenticated employee in Dashboard'});
  }

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Guest departure & cleaning · Visit ${widget.visitId}',
        style: Theme.of(context).textTheme.titleMedium),
      const Text('Physical service only. Settlement and table release remain blocked.'),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Shisha pickup required'),
        value: _shisha, onChanged: _busy ? null : (value) => setState(() => _shisha = value ?? false)),
      FilledButton.icon(
        onPressed: _busy ? null : _confirmDeparture,
        icon: const Icon(Icons.directions_walk),
        label: const Text('Record guest departure')),
      Row(children: [
        const Expanded(child: Text('Visit cleaning and shisha tasks')),
        IconButton(onPressed: _busy ? null : () => setState(() => _tasks = _load()),
          icon: const Icon(Icons.refresh), tooltip: 'Refresh tasks'),
      ]),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _tasks,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Text('Tasks unavailable. Verify permissions and migration 109.');
          if (!snapshot.hasData) return const LinearProgressIndicator();
          if (snapshot.data!.isEmpty) return const Text('No visit-bound cleaning tasks.');
          return Column(children: snapshot.data!.map((task) {
            final status = '${task['status'] ?? 'unknown'}';
            return ListTile(
              title: Text('${task['request_type'] ?? 'Task'}'),
              subtitle: Text('Status: $status'),
              trailing: status == 'completed' || status == 'cancelled'
                ? const Icon(Icons.check_circle_outline)
                : TextButton(onPressed: _busy ? null : () => _complete(task),
                    child: const Text('Mark complete')),
            );
          }).toList());
        },
      ),
    ]),
  ));
}


/// Physical readiness is independent of financial settlement. This card never
/// provides a table-release action even if all physical tasks are complete.
class _VisitPhysicalCheckoutStatus extends StatefulWidget {
  const _VisitPhysicalCheckoutStatus({required this.visitId});
  final int visitId;
  @override
  State<_VisitPhysicalCheckoutStatus> createState() =>
      _VisitPhysicalCheckoutStatusState();
}

class _VisitPhysicalCheckoutStatusState extends State<_VisitPhysicalCheckoutStatus> {
  late Future<Map<String, dynamic>> _status = _fetch();

  Future<Map<String, dynamic>> _fetch() async {
    final result = await Supabase.instance.client.rpc(
      'gs_visit_physical_checkout_status',
      params: {'p_visit_id': widget.visitId},
    );
    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    if (result is Map) return Map<String, dynamic>.from(result);
    throw StateError('Physical checkout status unavailable');
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Physical checkout requirements',
            style: TextStyle(fontWeight: FontWeight.bold))),
          IconButton(tooltip: 'Refresh physical checkout status',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _status = _fetch())),
        ]),
        FutureBuilder<Map<String, dynamic>>(
          future: _status,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Text(snapshot.hasError
                ? 'Physical status unavailable. Check access and server migrations.'
                : 'Checking departure and cleaning…');
            }
            final row = snapshot.data!;
            Widget check(String label, String key) => ListTile(
              dense: true,
              leading: Icon(row[key] == true ? Icons.check_circle_outline
                  : Icons.pending_outlined),
              title: Text(label),
              trailing: Text(row[key] == true ? 'Yes' : 'No'),
            );
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              check('Guests departed', 'guests_departed'),
              check('Cleaning completed', 'cleaning_completed'),
              if (row['shisha_required'] == true)
                check('Shisha pickup completed', 'shisha_completed'),
              Text('Physical readiness: ${row['physical_ready'] == true ? 'Complete' : 'Blocked'}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${row['blocking_reason'] ?? 'Status unavailable'}'),
              const SizedBox(height: 8),
              const Text('Financial settlement is separately required. '
                'This status cannot release a table or certify payment.'),
            ]);
          },
        ),
      ]),
    ),
  );
}


/// Restricted cash-only checkout: all final decisions are made by the
/// transactionally locked Supabase RPC, never by UI readiness flags.
class _CashOnlyVisitRelease extends StatefulWidget {
  const _CashOnlyVisitRelease({required this.visitId, this.onTableReleased});
  final int visitId;
  final VoidCallback? onTableReleased;
  @override
  State<_CashOnlyVisitRelease> createState() => _CashOnlyVisitReleaseState();
}

class _CashOnlyVisitReleaseState extends State<_CashOnlyVisitRelease> {
  bool _submitting = false;
  bool _released = false;

  Future<void> _release() async {
    if (_submitting || _released) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Release cash-only table?'),
        content: Text('Visit ${widget.visitId} will be closed ONLY if the server '
          'verifies independently attested cash-only payment for every order, '
          'physical guest departure, cleaning and required shisha pickup. '
          'Credit, mixed, online and corrected payments are NOT supported. '
          'This action is audited. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Request secure release')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      final tableId = await Supabase.instance.client.rpc(
        'gs_release_cash_only_table_visit',
        params: {'p_visit_id': widget.visitId},
      );
      if (!mounted) return;
      setState(() => _released = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Visit closed by server. Released table: $tableId. '
          'Refreshing dashboard data.'),
      ));
      // The surrounding table details were loaded before checkout and are
      // now stale. Close them and request a fresh server snapshot.
      widget.onTableReleased?.call();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Checkout refused or unavailable. The table remains '
          'occupied. Confirm payment, permissions, tasks and server migrations.'),
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Restricted cash-only checkout',
          style: Theme.of(context).textTheme.titleMedium),
        const Text('Only independent cash-only finance attestations qualify. '
          'The server rechecks all requirements before any table is released.'),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _submitting || _released ? null : _release,
          icon: Icon(_released ? Icons.check_circle_outline : Icons.lock_open),
          label: Text(_released ? 'Table released' : _submitting
            ? 'Verifying with server…' : 'Request cash-only table release'),
        ),
      ]),
    ),
  );
}


/// Read-only mixed-payment checkout preflight. This deliberately never invokes
/// gs_release_mixed_payment_table_visit: the feature is disabled pending
/// real provider integration and staging validation.
class _MixedPaymentCheckoutReadiness extends StatefulWidget {
  const _MixedPaymentCheckoutReadiness({required this.visitId});
  final int visitId;
  @override
  State<_MixedPaymentCheckoutReadiness> createState() =>
      _MixedPaymentCheckoutReadinessState();
}

class _MixedPaymentCheckoutReadinessState
    extends State<_MixedPaymentCheckoutReadiness> {
  late Future<Map<String, dynamic>> _status = _load();

  Future<Map<String, dynamic>> _load() async {
    final raw = await Supabase.instance.client.rpc(
      'gs_mixed_visit_checkout_preflight',
      params: {'p_visit_id': widget.visitId},
    );
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw StateError('Mixed checkout preflight returned no record');
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Mixed-payment checkout readiness',
              style: TextStyle(fontWeight: FontWeight.bold))),
          IconButton(
            tooltip: 'Refresh mixed-payment checkout readiness',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _status = _load()),
          ),
        ]),
        FutureBuilder<Map<String, dynamic>>(
          future: _status,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Mixed-payment release unavailable'),
                subtitle: Text(snapshot.hasError
                    ? 'Unable to verify readiness. Check permissions and migrations.'
                    : 'Checking settlement and physical checkout…'),
              );
            }
            final data = snapshot.data!;
            final ready = data['eligible_for_future_release'] == true;
            Widget metric(String label, String key) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('$label: ${data[key] ?? 'Unavailable'}'),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                metric('Active orders', 'active_orders'),
                metric('Cash-only approved orders', 'cash_attested_orders'),
                metric('Mixed-payment approved orders', 'mixed_attested_orders'),
                metric('Unapproved orders', 'unapproved_orders'),
                Text('Cancelled order financial conflict: '
                    '${data['financial_evidence_on_cancelled'] == true ? 'Yes' : 'No'}'),
                Text('Departure and service tasks: '
                    '${data['physical_ready'] == true ? 'Complete' : 'Incomplete'}'),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(ready
                      ? Icons.fact_check_outlined : Icons.lock_outline),
                  title: Text(ready
                      ? 'Preflight passed — release still disabled'
                      : 'Checkout blocked'),
                  subtitle: Text(ready
                      ? 'This is a read-only snapshot, not release authorization.'
                      : '${data['blocking_reason'] ?? 'Server did not approve readiness'}'),
                ),
                const Text(
                  'Mixed-payment table release remains disabled until trusted '
                  'payment-provider integration and staging validation. '
                  'Do not release the table from this panel.',
                ),
              ],
            );
          },
        ),
      ]),
    ),
  );
}
