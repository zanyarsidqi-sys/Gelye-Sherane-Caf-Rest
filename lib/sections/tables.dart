import '../shared/professional_section_summary.dart';
import '../shared/staff_event_request_screen.dart';
import '../shared/admin_event_reservations_screen.dart';
import '../shared/staff_reservation_management_screen.dart';
import '../shared/staff_specific_reservation_screen.dart';
import '../services/pos_heartbeat_service.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/section_shell.dart';

class TablesScreen extends StatelessWidget {
  final bool compact;
  const TablesScreen({super.key, this.compact = false});
  @override
  Widget build(BuildContext context) => SectionShell(
    title: 'Tables',
    description: 'Floor map, seating, reservations and table status',
    sectionId: 'tables',
    compact: compact,
    authorizedContent: const TablesWorkspace(),
  );
}

class TablesWorkspace extends StatefulWidget {
  const TablesWorkspace({super.key});
  @override
  State<TablesWorkspace> createState() => _TablesWorkspaceState();
}

class _TablesWorkspaceState extends State<TablesWorkspace> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _tables = [];
  Map<int, Map<String, dynamic>> _visits = {};
  Map<int, int> _qrActive = {};
  Map<int, Map<String, dynamic>> _tableMoney = {};
  bool _loading = false;
  int? _busyTable;
  String? _error;
  String _filter = 'All';
  String _floorFilter = 'All floors';
  String _search = '';

  @override
  void initState() { super.initState(); _reload(); }

  Future<void> _showAdminBillDiscount() async {
    final orderController = TextEditingController();
    final valueController = TextEditingController(text: '10');
    final reasonController = TextEditingController();
    String type = 'percent';
    bool allowStacking = false;
    bool busy = false;
    String? message;
    Map<String, dynamic>? result;
    Map<String, dynamic>? invoiceQuote;
    Map<String, dynamic>? reconciliation; 
    Map<String, dynamic>? readiness;
    Map<String, dynamic>? invoiceSnapshot;
    await showDialog<void>(context: context, builder: (dialogContext) =>
      StatefulBuilder(builder: (context, update) {
        Future<void> preview() async {
          final id = int.tryParse(orderController.text.trim());
          final amount = num.tryParse(valueController.text.trim());
          if (id == null || id <= 0 || amount == null || amount < 0 ||
              (type == 'percent' && amount > 100) ||
              (type == 'fixed_iqd' && amount != amount.truncateToDouble())) {
            update(() => message = 'Enter a valid order ID and discount.');
            return;
          }
          update(() { busy = true; message = null; result = null; });
          try {
            final response = await _db.rpc('gs_preview_admin_bill_discount', params: {
              'p_order_id': id, 'p_discount_type': type,
              'p_discount_value': amount, 'p_allow_item_discount_stacking': allowStacking,
            });
            update(() => result = Map<String, dynamic>.from(response as Map));
          } catch (e) {
            update(() => message = 'Preview denied or failed: Please retry or contact a manager');
          } finally { update(() => busy = false); }
        }
        Future<void> approve() async {
          if (result == null || reasonController.text.trim().length < 5) {
            update(() => message = 'Preview first and enter an approval reason (5+ characters).');
            return;
          }
          update(() { busy = true; message = null; });
          try {
            final response = await _db.rpc('gs_approve_admin_bill_discount_draft', params: {
              'p_order_id': int.parse(orderController.text.trim()),
              'p_discount_type': type,
              'p_discount_value': num.parse(valueController.text.trim()),
              'p_allow_item_discount_stacking': allowStacking,
              'p_reason': reasonController.text.trim(),
            });
            update(() => message = 'Discount draft saved (#$response). NOT applied to settlement or printed bills.');
          } catch (e) {
            update(() => message = 'Approval failed: Please retry or contact a manager');
          } finally { update(() => busy = false); }
        }
        Future<void> quoteInvoice() async {
          final id = int.tryParse(orderController.text.trim());
          if (id == null || id <= 0) {
            update(() => message = 'Enter a valid order ID.'); return;
          }
          update(() { busy = true; message = null; invoiceQuote = null; });
          try {
            final response = await _db.rpc('gs_admin_bill_discount_invoice_quote',
              params: {'p_order_id': id});
            update(() => invoiceQuote = Map<String, dynamic>.from(response as Map));
          } catch (e) {
            update(() => message = 'Invoice quote unavailable: Please retry or contact a manager');
          } finally { update(() => busy = false); }
        }
        Future<void> inspectPayments() async {
          final id = int.tryParse(orderController.text.trim());
          if (id == null || id <= 0) {
            update(() => message = 'Enter a valid order ID.'); return;
          }
          update(() { busy = true; message = null; reconciliation = null; });
          try {
            final response = await _db.rpc('gs_admin_discount_payment_reconciliation',
              params: {'p_order_id': id});
            update(() => reconciliation = Map<String, dynamic>.from(response as Map));
          } catch (e) {
            update(() => message = 'Payment reconciliation unavailable: Please retry or contact a manager');
          } finally { update(() => busy = false); }
        }
        Future<void> checkFinalizationReadiness() async {
          final id = int.tryParse(orderController.text.trim());
          if (id == null || id <= 0) {
            update(() => message = 'Enter a valid order ID.'); return;
          }
          update(() { busy = true; message = null; readiness = null; });
          try {
            final response = await _db.rpc('gs_admin_discount_finalization_readiness',
              params: {'p_order_id': id});
            if (!dialogContext.mounted) return;
            update(() => readiness = Map<String, dynamic>.from(response as Map));
          } catch (e) {
            if (dialogContext.mounted) update(() => message = 'Finalization check failed: Please retry or contact a manager');
          } finally {
            if (dialogContext.mounted) update(() => busy = false);
          }
        }
        Future<void> inspectLockedPayable() async {
          final id = int.tryParse(orderController.text.trim());
          if (id == null || id <= 0) {
            update(() => message = 'Enter a valid order ID.'); return;
          }
          update(() { busy = true; message = null; });
          try {
            final response = await _db.rpc('gs_get_locked_discount_payable',
              params: {'p_order_id': id});
            if (!dialogContext.mounted) return;
            final details = Map<String, dynamic>.from(response as Map);
            update(() => message = details['status'] == 'locked_unpaid_invoice'
              ? 'LOCKED invoice #${details['snapshot_id']}\n'
                'Original: ${details['source_total_iqd']} IQD\n'
                'Discount: ${details['bill_discount_iqd']} IQD\n'
                'Amount due: ${details['amount_due_iqd']} IQD\n'
                'Payment capture is NOT connected. Do not collect through this preview.'
              : 'No locked discounted invoice for this order.');
          } catch (e) {
            if (dialogContext.mounted) update(() => message = 'Locked payable lookup failed: Please retry or contact a manager');
          } finally {
            if (dialogContext.mounted) update(() => busy = false);
          }
        }
        Future<void> preparePaymentIntent() async {
          final id = int.tryParse(orderController.text.trim());
          if (id == null || id <= 0) {
            update(() => message = 'Enter a valid locked order ID.'); return;
          }
          update(() { busy = true; message = null; });
          try {
            final response = await _db.rpc('gs_prepare_locked_discount_payment',
              params: {'p_order_id': id});
            if (!dialogContext.mounted) return;
            final details = Map<String, dynamic>.from(response as Map);
            update(() => message = 'PAYMENT PREPARATION ONLY — NO CHARGE\n'
              'Intent: ${details['intent_id']}\n'
              'Amount: ${details['amount_due_iqd']} IQD\n'
              'Status: ${details['status']}\n'
              'Cash, credit and mixed settlement are NOT enabled.');
          } catch (e) {
            if (dialogContext.mounted) update(() => message = 'Payment preparation blocked: Please retry or contact a manager');
          } finally {
            if (dialogContext.mounted) update(() => busy = false);
          }
        }
        Future<void> commitInvoiceSnapshot() async {
          final id = int.tryParse(orderController.text.trim());
          if (id == null || id <= 0) {
            update(() => message = 'Enter a valid order ID.'); return;
          }
          update(() { busy = true; message = null; invoiceSnapshot = null; });
          try {
            final response = await _db.rpc('gs_commit_admin_discount_invoice_snapshot',
              params: {'p_order_id': id});
            if (!dialogContext.mounted) return;
            update(() => invoiceSnapshot = Map<String, dynamic>.from(response as Map));
          } catch (e) {
            if (dialogContext.mounted) update(() => message = 'Invoice snapshot blocked: Please retry or contact a manager');
          } finally {
            if (dialogContext.mounted) update(() => busy = false);
          }
        }
        return AlertDialog(title: const Text('Admin · Bill Discount Draft'),
          content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Admin-only preview and audited draft. Final settlement/printing integration is not enabled.'),
              TextField(controller: orderController, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Order ID')),
              DropdownButtonFormField<String>(value: type,
                decoration: const InputDecoration(labelText: 'Bill discount type'),
                items: const [DropdownMenuItem(value: 'percent', child: Text('Percentage')),
                  DropdownMenuItem(value: 'fixed_iqd', child: Text('Fixed IQD off total'))],
                onChanged: busy ? null : (v) => update(() { type = v ?? 'percent'; result = null; })),
              TextField(controller: valueController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Discount value'), onChanged: (_) => update(() => result = null)),
              CheckboxListTile(contentPadding: EdgeInsets.zero, value: allowStacking,
                title: const Text('Allow additional discount on already discounted items'),
                onChanged: busy ? null : (v) => update(() { allowStacking = v ?? false; result = null; })),
              TextField(controller: reasonController,
                decoration: const InputDecoration(labelText: 'Admin approval reason')),
              if (result != null) SelectableText('Current total: ${result!['current_total_iqd']} IQD\n'
                'Bill discount: ${result!['bill_discount_iqd']} IQD\n'
                'Proposed total: ${result!['proposed_total_iqd']} IQD'),
              if (invoiceQuote != null) SelectableText(
                'UNPAID INVOICE PREVIEW ONLY\n'
                'Approval draft: ${invoiceQuote!['draft_id']}\n'
                'Original total: ${invoiceQuote!['source_total_iqd']} IQD\n'
                'Bill discount: ${invoiceQuote!['bill_discount_iqd']} IQD\n'
                'Proposed due: ${invoiceQuote!['proposed_total_iqd']} IQD\n'
                'NOT applied to payment, invoice or printer.'),
              if (reconciliation != null) SelectableText(
                'PAYMENT RECONCILIATION (READ ONLY)\n'
                'Eligibility: ${reconciliation!['eligibility']}\n'
                'Order total: ${reconciliation!['order_total_iqd']} IQD\n'
                'Recorded payment sources: ${reconciliation!['payment_sources']}\n'
                'Unresolved sources: ${reconciliation!['unresolved_sources']}\n'
                'No financial changes performed.'),
              if (readiness != null) SelectableText(
                'FINALIZATION READINESS — NO CHARGES APPLIED\n'
                'Status: ${readiness!['status']}\n'
                'Reason: ${readiness!['reason']}\n'
                'Order: ${readiness!['order_id']}\n'
                'Draft: ${readiness!['draft_id']}\n'
                'Proposed total: ${readiness!['proposed_total_iqd']} IQD\n'
                'Payment check: ${readiness!['payment_eligibility']}\n'
                'Invoice / printing integration remains disabled.'),
              if (invoiceSnapshot != null) SelectableText(
                'IMMUTABLE INVOICE SNAPSHOT (NOT SETTLED)\n'
                'Snapshot: ${invoiceSnapshot!['snapshot_id']}\n'
                'Original: ${invoiceSnapshot!['source_total_iqd']} IQD\n'
                'Admin discount: ${invoiceSnapshot!['bill_discount_iqd']} IQD\n'
                'Amount due: ${invoiceSnapshot!['amount_due_iqd']} IQD\n'
                'Payment capture and physical printing remain disabled.'),
              if (message != null) SelectableText(message!),
            ],
          ))),
          actions: [TextButton(onPressed: busy ? null : () => Navigator.pop(dialogContext), child: const Text('Close')),
            OutlinedButton(onPressed: busy ? null : preview, child: const Text('Preview')),
            OutlinedButton(onPressed: busy ? null : quoteInvoice, child: const Text('Invoice quote')),
            OutlinedButton(onPressed: busy ? null : inspectPayments, child: const Text('Check payments')),
            OutlinedButton(onPressed: busy ? null : checkFinalizationReadiness, child: const Text('Finalization check')),
            OutlinedButton(onPressed: busy ? null : commitInvoiceSnapshot, child: const Text('Lock invoice snapshot')),
            OutlinedButton(onPressed: busy ? null : inspectLockedPayable, child: const Text('View locked payable')),
            OutlinedButton(onPressed: busy ? null : preparePaymentIntent, child: const Text('Prepare payment (no charge)')),
            FilledButton(onPressed: busy || result == null ? null : approve,
              child: const Text('Save approval draft'))],
        );
      }));
    orderController.dispose(); valueController.dispose(); reasonController.dispose();
  }

  Future<void> _showAdminDiscountSettings() async {
    List<Map<String, dynamic>> configs = [];
    String? error;
    bool busy = false;
    String scope = 'table';
    String discountType = 'percent';
    String baseMode = 'normal';
    bool active = true;
    final referenceController = TextEditingController();
    final valueController = TextEditingController(text: '10');
    try {
      final rows = await _db.rpc('gs_list_cafe_discount_modes');
      configs = (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      error = 'Admin authorization or loading failed: Please retry or contact a manager';
    }
    if (!mounted) {
      referenceController.dispose();
      valueController.dispose();
      return;
    }
    await showDialog<void>(context: context, builder: (dialogContext) {
      return StatefulBuilder(builder: (context, update) {
        Future<void> save() async {
          final reference = referenceController.text.trim();
          final value = num.tryParse(valueController.text.trim());
          if (reference.isEmpty || reference.length > 120 || value == null ||
              value < 0 || (discountType == 'percent' && value > 100) ||
              (discountType == 'fixed_iqd' && (value != value.truncateToDouble() || value > 1000000000))) {
            update(() => error = 'Enter a valid destination and discount (percentage 0–100 or whole IQD).');
            return;
          }
          update(() { busy = true; error = null; });
          try {
            await _db.rpc('gs_set_cafe_discount_mode', params: {
              'p_scope': scope,
              'p_scope_reference': reference,
              'p_is_active': active,
              'p_discount_type': discountType,
              'p_discount_value': value,
              'p_base_mode': baseMode,
            });
            final rows = await _db.rpc('gs_list_cafe_discount_modes');
            update(() => configs = (rows as List)
                .map((e) => Map<String, dynamic>.from(e as Map)).toList());
          } catch (e) {
            update(() => error = 'Could not save discount: Please retry or contact a manager');
          } finally {
            update(() => busy = false);
          }
        }
        return AlertDialog(
          title: const Text('Admin · Discount Mode'),
          content: SizedBox(width: 540, child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Admin-only configuration. These settings do not yet change scanned-item prices or printed bills.'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(value: scope,
                decoration: const InputDecoration(labelText: 'Destination type'),
                items: const [DropdownMenuItem(value: 'table', child: Text('Table')),
                  DropdownMenuItem(value: 'motel', child: Text('Motel'))],
                onChanged: busy ? null : (v) { if (v != null) update(() => scope = v); }),
              TextField(controller: referenceController,
                decoration: InputDecoration(labelText: scope == 'table' ? 'Table number' : 'Motel destination reference')),
              DropdownButtonFormField<String>(value: baseMode,
                decoration: const InputDecoration(labelText: 'Base pricing mode'),
                items: const [DropdownMenuItem(value: 'normal', child: Text('Normal')),
                  DropdownMenuItem(value: 'tourism', child: Text('Tourism')),
                  DropdownMenuItem(value: 'owner', child: Text('Owner'))],
                onChanged: busy ? null : (v) { if (v != null) update(() => baseMode = v); }),
              DropdownButtonFormField<String>(value: discountType,
                decoration: const InputDecoration(labelText: 'Discount method'),
                items: const [DropdownMenuItem(value: 'percent', child: Text('Percentage (%)')),
                  DropdownMenuItem(value: 'fixed_iqd', child: Text('Fixed IQD per item (planned)'))],
                onChanged: busy ? null : (v) { if (v != null) update(() => discountType = v); }),
              TextField(controller: valueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: discountType == 'percent' ? 'Discount percentage' : 'Discount amount (IQD)')),
              SwitchListTile(contentPadding: EdgeInsets.zero,
                title: const Text('Discount Mode active'), value: active,
                onChanged: busy ? null : (v) => update(() => active = v)),
              if (error != null) Padding(padding: const EdgeInsets.only(bottom: 8),
                child: SelectableText(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
              const Divider(),
              const Text('Saved discount configurations', style: TextStyle(fontWeight: FontWeight.bold)),
              if (configs.isEmpty) const Text('No configurations available.'),
              for (final item in configs) ListTile(dense: true,
                title: Text('${item['scope']} · ${item['scope_reference']}'),
                subtitle: Text('${item['base_mode']} · ${item['discount_value']} ${item['discount_type'] == 'percent' ? '%' : 'IQD'}'),
                trailing: Icon(item['is_active'] == true ? Icons.check_circle : Icons.pause_circle_outline,
                  color: item['is_active'] == true ? Colors.green : null),
                onTap: busy ? null : () => update(() {
                  scope = item['scope'].toString();
                  referenceController.text = item['scope_reference'].toString();
                  discountType = item['discount_type'].toString();
                  valueController.text = item['discount_value'].toString();
                  baseMode = item['base_mode'].toString();
                  active = item['is_active'] == true;
                })),
            ],
          ))),
          actions: [TextButton(onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Close')),
            FilledButton(onPressed: busy ? null : save,
              child: Text(busy ? 'Saving…' : 'Save (Admin only)'))],
        );
      });
    });
    referenceController.dispose();
    valueController.dispose();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final tables = await _db.from('gs_cafe_tables').select(
        'id,table_number,capacity,occupied,guests,tourism_mode,cleaning_needed,floor_name,updated_at'
      ).order('table_number');
      final visits = await _db.rpc('gs_dashboard_active_table_visits');
      final qrRows = await _db.rpc('gs_list_active_table_qr_sessions');
      final qrMapped = <int, int>{};
      for (final row in (qrRows as List)) {
        final entry = Map<String, dynamic>.from(row as Map);
        qrMapped[(entry['table_number'] as num).toInt()] =
          (entry['active_sessions'] as num).toInt();
      }
      final mapped = <int, Map<String, dynamic>>{};
      for (final item in (visits as List)) {
        final visit = Map<String, dynamic>.from(item as Map);
        mapped[(visit['table_number'] as num).toInt()] = visit;
      }
      // Read-only per-table financial summaries; never substitute invented zeroes
      // when a summary is missing or inaccessible.
      final financial = <int, Map<String, dynamic>>{};
      await Future.wait(mapped.keys.map((number) async {
        try {
          final raw = await _db.rpc('gs_table_item_money_overview',
            params: {'p_table_number': number});
          if (raw is Map) financial[number] = Map<String, dynamic>.from(raw);
        } catch (_) { // A missing permission or RPC must not hide table cards.
        }
      }));
      final tableRows = List<Map<String, dynamic>>.from(tables);
      final floorNames = tableRows.map(_floorName).toSet();
      if (mounted) setState(() {
        if (_floorFilter != 'All floors' && !floorNames.contains(_floorFilter)) {
          _floorFilter = 'All floors';
        }
        _tableMoney = financial;
        _tables = tableRows;
        _visits = mapped;
        _qrActive = qrMapped;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load table state: Please retry or contact a manager');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _floorName(Map<String, dynamic> table) {
    final value = table['floor_name'];
    return value is String && value.trim().isNotEmpty
      ? value.trim()
      : 'Unassigned floor';
  }



  String? _nextItemFulfillmentStatus(String? current) {
    const steps = ['not_accepted','accepted','preparing','prepared',
      'picked_up','delivered'];
    final i = steps.indexOf(current ?? 'not_accepted');
    return i < 0 || i == steps.length - 1 ? null : steps[i + 1];
  }

  Future<void> _showTableItemsAndMoney(Map<String, dynamic> table) async {
    final number = (table['table_number'] as num).toInt();
    Map<String, dynamic>? summary;
    String? error;
    try {
      final result = await _db.rpc('gs_table_item_money_overview',
        params: {'p_table_number': number});
      summary = Map<String, dynamic>.from(result as Map);
    } catch (e) {
      error = 'Please retry or contact a manager';
    }
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (dialogContext) {
      final items = (summary?['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final counts = <String, int>{};
      for (final item in items) {
        final status = item['status']?.toString() ?? 'not_accepted';
        counts[status] = (counts[status] ?? 0) + (item['quantity'] as num).toInt();
      }
      String money(Object? value) =>
          '${(value is num ? value.toInt() : 0)} IQD';
      return AlertDialog(
        title: Text('Table $number · Items & money'),
        content: SizedBox(width: 620,height: 450,
          child: error != null
            ? SelectableText('Could not load: $error')
            : ListView(children: [
              const Text('Fulfillment counts (item quantities)',
                style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(spacing: 8,runSpacing: 4,children: [
                for (final status in [
                  'not_accepted','accepted','preparing','prepared',
                  'picked_up','delivered'])
                  Chip(label: Text('${status.replaceAll('_',' ')}: '
                    '${counts[status] ?? 0}')),
              ]),
              const Divider(),
              Text('Billed: ${money(summary?['billed_iqd'])}'),
              Text('Verified cash: ${money(summary?['verified_cash_paid_iqd'])}'),
              Text('Cash-only outstanding: '
                '${money(summary?['cash_only_outstanding_iqd'])}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
              const Text('Cash-only preview. Credit and mixed payments are '
                'NOT reconciled; this is not a final settlement balance.'),
              const Divider(),
              for (final item in items)
                ListTile(
                  title: Text('${item['quantity']} × ${item['product']}'),
                  subtitle: Text('Order #${item['order_id']} · '
                    '${item['status'].toString().replaceAll('_',' ')} · '
                    '${money(item['amount_iqd'])}'),
                  trailing: (_nextItemFulfillmentStatus(item['status']?.toString()) == null ||
                    ['picked_up', 'delivered'].contains(
                      _nextItemFulfillmentStatus(item['status']?.toString())))
                    ? null
                    : TextButton(
                        onPressed: () async {
                          final next = _nextItemFulfillmentStatus(
                            item['status']?.toString());
                          if (next == null) return;
                          try {
                            await _db.rpc('gs_advance_table_item_fulfillment',
                              params: {
                                'p_order_item_id': item['order_item_id'],
                                'p_expected_status': item['status'],
                                'p_next_status': next,
                              });
                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                            if (mounted) await _showTableItemsAndMoney(table);
                          } catch (e) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text('Status update failed: Please retry or contact a manager')));
                            }
                          }
                        },
                        child: Text('Mark ${_nextItemFulfillmentStatus(item['status']?.toString())!.replaceAll('_',' ')}')),
                ),
              const Text('Pickup and delivery quantities are confirmed in My Jobs → Quantity handover. ' 
                'Whole-item status buttons are disabled to avoid conflicting records.'),
              if (items.isEmpty) const Text('No linked items in the active visit.'),
            ])),
        actions: [TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'))],
      );
    });
  }

  Future<void> _cashierReservation() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final notes = TextEditingController();
    final guests = TextEditingController(text: '2');
    List<Map<String, dynamic>> customers = [];
    int? customerId;
    try {
      final result = await _db.rpc('gs_list_cafe_customers');
      customers = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) { /* Manual guest entry remains available. */ }
    DateTime when = DateTime.now().add(const Duration(days: 1));
    bool saving = false;
    String? error;
    try {
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (dialogContext) =>
        StatefulBuilder(builder: (context, change) {
          Future<void> save() async {
            final count = int.tryParse(guests.text.trim());
            if (name.text.trim().length < 2 ||
                phone.text.trim().length < 6 ||
                count == null || count < 1 || count > 30) {
              change(() => error = 'Enter customer name, phone and 1–30 guests.');
              return;
            }
            change(() { saving = true; error = null; });
            try {
              await _db.rpc('gs_cashier_create_customer_reservation', params: {
                'p_customer_id': customerId,
                'p_name': name.text.trim(),
                'p_phone': phone.text.trim(),
                'p_requested_at': when.toUtc().toIso8601String(),
                'p_party_size': count,
                'p_notes': notes.text.trim(),
              });
              if (!dialogContext.mounted || !mounted) return;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text(
                  'Reservation request recorded; awaiting table approval.')));
            } catch (e) {
              if (dialogContext.mounted) change(() => error = 'Please retry or contact a manager');
            } finally {
              if (dialogContext.mounted) change(() => saving = false);
            }
          }
          return AlertDialog(
            title: const Text('Cashier · New reservation request'),
            content: SizedBox(width: 460,
              child: SingleChildScrollView(child: Column(
                mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField<int>(
                    value: customerId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Existing customer (optional)'),
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('Guest not in directory')),
                      ...customers.map((c) => DropdownMenuItem<int>(
                        value: (c['id'] as num).toInt(),
                        child: Text('${c['full_name']} · ${c['phone'] ?? 'no phone'}',
                          overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: saving ? null : (id) {
                      change(() {
                        customerId = id;
                        if (id != null) {
                          final selected = customers.firstWhere((c) => (c['id'] as num).toInt() == id);
                          name.text = '${selected['full_name']}';
                          phone.text = '${selected['phone'] ?? ''}';
                        }
                      });
                    },
                  ),
                  TextField(controller: name,
                    decoration: const InputDecoration(labelText: 'Customer name')),
                  TextField(controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone number')),
                  TextField(controller: guests,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Number of guests')),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Requested arrival'),
                    subtitle: Text(when.toLocal().toString().substring(0, 16)),
                    trailing: const Icon(Icons.event),
                    onTap: saving ? null : () async {
                      final date = await showDatePicker(
                        context: dialogContext,
                        initialDate: when,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)));
                      if (date == null || !dialogContext.mounted) return;
                      final time = await showTimePicker(
                        context: dialogContext, initialTime: TimeOfDay.fromDateTime(when));
                      if (time == null || !dialogContext.mounted) return;
                      change(() => when = DateTime(date.year,date.month,date.day,
                        time.hour,time.minute));
                    }),
                  TextField(controller: notes,maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Special requests / food / shisha notes')),
                  const SizedBox(height: 8),
                  const Text('This creates a pending request, not a confirmed table. '
                    'Availability and capacity are checked when approved.'),
                  if (error != null) SelectableText(error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ]))),
            actions: [
              TextButton(onPressed: saving ? null :
                () => Navigator.pop(dialogContext),child: const Text('Cancel')),
              FilledButton(onPressed: saving ? null : save,
                child: Text(saving ? 'Saving...' : 'Record request')),
            ],
          );
        }));
    } finally {
      name.dispose(); phone.dispose(); notes.dispose(); guests.dispose();
    }
  }

  Future<void> _seat(Map<String, dynamic> table) async {
    final number = (table['table_number'] as num).toInt();
    final capacity = (table['capacity'] as num).toInt();
    int guests = 1;
    bool tourism = false;
    int? customerId;
    final newName = TextEditingController();
    final newPhone = TextEditingController();
    List<Map<String, dynamic>> customers = [];
    try {
      // Failure to load customer records must not disable anonymous seating.
      try {
        final response = await _db.rpc('gs_list_cafe_customers');
        customers = (response as List)
            .map((row) => Map<String, dynamic>.from(row as Map)).toList();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Customer directory unavailable; anonymous seating is still possible: $e')));
      }
      if (!mounted) return;
      final accepted = await showDialog<bool>(context: context,
        builder: (dialogContext) => StatefulBuilder(builder: (context, change) => AlertDialog(
          title: Text('Open visit · Table $number'),
          content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min, children: [
              Text('Capacity: $capacity guests. Normal Mode is the default.'),
              const SizedBox(height: 12),
              Row(children: [const Text('Guests'), const Spacer(),
                IconButton(onPressed: guests > 1 ? () => change(() => guests--) : null,
                  icon: const Icon(Icons.remove_circle_outline)),
                Text('$guests'),
                IconButton(onPressed: guests < capacity ? () => change(() => guests++) : null,
                  icon: const Icon(Icons.add_circle_outline)),
              ]),
              SwitchListTile.adaptive(title: const Text('Tourism pricing'),
                subtitle: const Text('Use tourism prices for this visit'),
                value: tourism, onChanged: (value) => change(() => tourism = value)),
              DropdownButtonFormField<int>(
                value: customerId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Existing customer (optional)'),
                items: [const DropdownMenuItem<int>(value: null, child: Text('Walk-in / no profile')),
                  ...customers.map((c) => DropdownMenuItem<int>(
                    value: (c['id'] as num).toInt(),
                    child: Text("${c['full_name']} · ${c['phone'] ?? 'No phone'}",
                      overflow: TextOverflow.ellipsis)))],
                onChanged: (value) => change(() => customerId = value),
              ),
              if (customerId == null) ...[
                const SizedBox(height: 8),
                TextField(controller: newName, maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Or create new customer (name)')),
                TextField(controller: newPhone, keyboardType: TextInputType.phone,
                  maxLength: 30,
                  decoration: const InputDecoration(labelText: 'New customer phone (optional)')),
              ],
              const Text('Select a customer or enter a new name to link visit history. '
                'Leave blank for an anonymous visit.'),
            ]))),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Open visit'))],
        )),
      );
      if (accepted != true || !mounted) return;
      setState(() { _busyTable = number; _error = null; });
      try {
        // A single database transaction creates the profile (if requested),
        // opens the visit and links its history. Failure rolls back everything.
        await _db.rpc('gs_open_cafe_table_visit_with_customer', params: {
          'p_table_number': number, 'p_guests': guests, 'p_tourism': tourism,
          'p_customer_id': customerId,
          'p_new_customer_name': customerId == null ? newName.text.trim() : null,
          'p_new_customer_phone': customerId == null ? newPhone.text.trim() : null,
        });
        await _reload();
      } catch (e) {
        if (mounted) setState(() => _error =
          'Visit was not opened. Check permissions, cleaning, reservations and customer details: $e');
      } finally {
        if (mounted) setState(() => _busyTable = null);
      }
    } finally {
      newName.dispose();
      newPhone.dispose();
    }
  }

  Future<void> _checkInReservation() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await _db.rpc('gs_list_approved_cafe_reservations');
      if (!mounted) return;
      final reservations = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() => _loading = false);
      if (reservations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No approved reservations awaiting check-in.')));
        return;
      }
      final selected = await showDialog<String>(context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Check in reservation'),
          content: SizedBox(width: 440, child: ListView(
            shrinkWrap: true, children: reservations.map((r) => ListTile(
              title: Text('Table ${r['table_label']} · ${r['customer_name']}'),
              subtitle: Text('${r['party_size']} guests · ${r['requested_at']}'),
              trailing: const Icon(Icons.login),
              onTap: () => Navigator.pop(dialogContext, r['reservation_id'] as String),
            )).toList())),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'))],
        ));
      if (selected == null || !mounted) return;
      setState(() => _loading = true);
      await _db.rpc('gs_check_in_cafe_reservation',
        params: {'p_reservation_id': selected});
      await _reload();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Reservation checked in successfully.')));
    } catch (e) {
      if (mounted) setState(() => _error = 'Reservation check-in failed: Please retry or contact a manager');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelReservation() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final response = await _db.rpc('gs_list_cancellable_cafe_reservations');
      if (!mounted) return;
      final reservations = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() => _loading = false);
      if (reservations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No pending or approved reservations to cancel.')));
        return;
      }
      final selected = await showDialog<Map<String, dynamic>>(
        context: context, builder: (dialogContext) => AlertDialog(
          title: const Text('Cancel reservation'),
          content: SizedBox(width: 460, child: ListView(shrinkWrap: true,
            children: reservations.map((r) => ListTile(
              title: Text('${r['customer_name']} · ${r['status']}'),
              subtitle: Text('Table ${r['table_label'] ?? 'Unassigned'} · '
                  '${r['party_size']} guests · ${r['requested_at']}'),
              onTap: () => Navigator.pop(dialogContext, r),
            )).toList())),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'))],
        ));
      if (selected == null || !mounted) return;
      // Server-side preflight is advisory. Execution repeats all checks under locks.
      final previewRaw = await _db.rpc('gs_preview_guest_move_safety',
        params: {'p_request_id': selected['request_id']});
      final preview = Map<String, dynamic>.from((previewRaw as List).first as Map);
      if (!mounted) return;
      final issues = (preview['blockers'] as List?)?.map((v) => '$v').toList() ?? [];
      if (issues.isNotEmpty || preview['can_execute'] != true) {
        await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('Guest move blocked'),
          content: Text('This request cannot safely execute:\n${issues.join('\n')}'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'))],
        ));
        return;
      }
      final confirmed = await showDialog<bool>(context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm cancellation'),
          content: Text('Cancel ${selected['customer_name']} reservation? '
            'This action is audited and cannot cancel a checked-in visit.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep reservation')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cancel reservation')),
          ],
        ));
      if (confirmed != true || !mounted) return;
      setState(() => _loading = true);
      await _db.rpc('gs_cancel_reservation', params: {
        'p_id': selected['reservation_id'],
      });
      await _reload();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Reservation cancelled; audit record created.')));
    } catch (e) {
      if (mounted) setState(() => _error = 'Reservation cancellation failed: Please retry or contact a manager');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  // Creates an auditable request only. Does NOT move guests, orders or money.
  String _newRequestKey() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final h = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0,8)}-${h.substring(8,12)}-${h.substring(12,16)}-${h.substring(16,20)}-${h.substring(20)}';
  }

  Future<void> _requestGuestMove(Map<String, dynamic> source) async {
    final sourceNumber = (source['table_number'] as num).toInt();
    final sourceVisit = _visits[sourceNumber];
    if (sourceVisit == null || sourceVisit['status'] != 'active') return;
    final candidates = _tables.where((table) {
      final n = (table['table_number'] as num).toInt();
      return n != sourceNumber && table['occupied'] == true &&
        table['cleaning_needed'] != true && _visits[n]?['status'] == 'active';
    }).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No other active occupied table can receive a guest move request.')));
      return;
    }
    int destination = (candidates.first['table_number'] as num).toInt();
    int moving = 1;
    bool moveBill = false;
    final reason = TextEditingController();
    try {
      final approved = await showDialog<bool>(context: context,
        builder: (dialogContext) => StatefulBuilder(builder: (context, change) {
          final target = candidates.firstWhere((t) => t['table_number'] == destination);
          final srcCount = (sourceVisit['guest_count'] as num).toInt();
          final targetVisit = _visits[destination]!;
          final space = (target['capacity'] as num).toInt() -
            (targetVisit['guest_count'] as num).toInt();
          final maxMoving = min(srcCount, space);
          return AlertDialog(
            title: Text('Request move from Table $sourceNumber'),
            content: SizedBox(width: 430, child: Column(
              mainAxisSize: MainAxisSize.min, children: [
                const Text('This records a request for review; it does not move guests or bills.'),
                DropdownButtonFormField<int>(value: destination,
                  decoration: const InputDecoration(labelText: 'Destination occupied table'),
                  items: candidates.map((t) => DropdownMenuItem<int>(
                    value: (t['table_number'] as num).toInt(),
                    child: Text('Table ${t['table_number']}'))).toList(),
                  onChanged: (v) { if (v != null) change(() { destination = v; moving = 1; }); }),
                Text('Source guests: $srcCount · Destination free seats: $space'),
                Row(children: [const Text('Guests to move'), const Spacer(),
                  IconButton(onPressed: moving > 1 ? () => change(() => moving--) : null,
                    icon: const Icon(Icons.remove_circle_outline)),
                  Text('$moving'),
                  IconButton(onPressed: moving < maxMoving ? () => change(() => moving++) : null,
                    icon: const Icon(Icons.add_circle_outline))]),
                CheckboxListTile(value: moveBill, onChanged: (v) =>
                  change(() => moveBill = v ?? false),
                  title: const Text('Bill transfer also requested'),
                  subtitle: const Text('Requires separate financial review; no automatic transfer.')),
                TextField(controller: reason, maxLength: 500,
                  onChanged: (_) => change(() {}),
                  decoration: const InputDecoration(labelText: 'Reason (at least 5 characters)')),
              ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
              FilledButton(onPressed: maxMoving < 1 || reason.text.trim().length < 5
                  ? null : () => Navigator.pop(dialogContext, true),
                child: const Text('Submit request')),
            ],
          );
        }));
      if (approved != true || !mounted) return;
      setState(() { _busyTable = sourceNumber; _error = null; });
      final destVisit = _visits[destination];
      if (destVisit == null) throw StateError('Destination visit no longer active');
      final id = await _db.rpc('gs_request_table_guest_move', params: {
        'p_source_visit_id': sourceVisit['visit_id'],
        'p_destination_visit_id': destVisit['visit_id'],
        'p_moving_guests': moving,
        'p_move_bill': moveBill,
        'p_reason': reason.text.trim(),
        'p_request_key': _newRequestKey(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Guest move request #$id submitted; no guests or payments moved.')));
      await _reload();
    } catch (e) {
      if (mounted) setState(() => _error = 'Guest move request was not submitted: Please retry or contact a manager');
    } finally {
      reason.dispose();
      if (mounted) setState(() => _busyTable = null);
    }
  }


  // Read-only, permission-scoped pending guest moves; no private table grants.
  Future<void> _reviewGuestMoves() async {
    if (_loading || _busyTable != null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _db.rpc('gs_list_pending_guest_moves');
      final requests = (result as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();
      if (!mounted) return;
      setState(() => _loading = false);
      if (requests.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No pending guest movement requests.')));
        return;
      }
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Pending guest movements'),
          content: SizedBox(width: 470, child: ListView(
            shrinkWrap: true,
            children: requests.map((r) => ListTile(
              title: Text('Request #${r['request_id']} · Table ${r['source_table_number']} → ${r['destination_table_number']}'),
              subtitle: Text('${r['moving_guests']} guests · ${r['move_bill'] == true ? 'Bill transfer requested (cannot execute here)' : 'Guest count only'}\n${r['reason']}'),
              isThreeLine: true,
              enabled: r['move_bill'] != true,
              onTap: r['move_bill'] == true ? null : () => Navigator.pop(dialogContext, r),
            )).toList(),
          )),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'))],
        ),
      );
      if (selected == null || !mounted) return;
      final confirmed = await showDialog<bool>(context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Execute guest-count move?'),
          content: Text('Move ${selected['moving_guests']} guests from Table '
            '${selected['source_table_number']} to Table '
            '${selected['destination_table_number']}?\n\n'
            'Only guest counts change. Orders, bills, payments and reservations '
            'remain with their original visits. The server rechecks capacity '
            'and permissions before committing.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm guest move')),
          ],
        ));
      if (confirmed != true || !mounted) return;
      setState(() { _loading = true; _error = null; });
      final applied = await _db.rpc('gs_execute_guest_count_only_move',
        params: {'p_request_id': selected['request_id']});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(applied == true ? 'Guest movement applied and audited.'
          : 'This guest movement was already applied.')));
      await _reload();
    } catch (e) {
      if (mounted) setState(() => _error = 'Guest movement review failed: Please retry or contact a manager');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  // Read-only preparation for joining tables. The backend enforces permissions,
  // financial restrictions and visit ownership. No guest/order/payment mutation.
  Future<void> _previewBillTransfer() async {
    if (_loading || _busyTable != null) return;
    final active = _visits.entries.where((entry) =>
      entry.value['status'] == 'active').toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (active.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Two active table visits are required for a transfer preview.')));
      return;
    }
    int source = active.first.key;
    int destination = active[1].key;
    final chosen = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Review joining tables / bill transfer'),
          content: SizedBox(width: 460, child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Read-only financial review. This will not join tables, '
                'move orders, change prices or transfer payments.'),
              DropdownButtonFormField<int>(
                value: source,
                decoration: const InputDecoration(labelText: 'Source table'),
                items: active.map((e) => DropdownMenuItem(
                  value: e.key, child: Text('Table ${e.key}'))).toList(),
                onChanged: (v) { if (v != null) update(() => source = v); },
              ),
              DropdownButtonFormField<int>(
                value: destination,
                decoration: const InputDecoration(labelText: 'Destination table'),
                items: active.map((e) => DropdownMenuItem(
                  value: e.key, child: Text('Table ${e.key}'))).toList(),
                onChanged: (v) { if (v != null) update(() => destination = v); },
              ),
              if (source == destination)
                const Text('Choose two different tables.'),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
            FilledButton(
              onPressed: source == destination ? null :
                () => Navigator.pop(dialogContext, true),
              child: const Text('Review unpaid items')),
          ],
        ),
      ),
    );
    if (chosen != true || !mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await _db.rpc('gs_preview_table_bill_transfer', params: {
        'p_source_visit_id': _visits[source]!['visit_id'],
        'p_destination_visit_id': _visits[destination]!['visit_id'],
      });
      final items = (rows as List)
          .map((v) => Map<String, dynamic>.from(v as Map)).toList();
      if (!mounted) return;
      setState(() => _loading = false);
      await showDialog<void>(context: context, builder: (dialogContext) =>
        AlertDialog(
          title: Text('Table $source → Table $destination'),
          content: SizedBox(width: 540, height: 350, child: items.isEmpty
            ? const Center(child: Text('No order items to review.'))
            : ListView.builder(itemCount: items.length, itemBuilder: (context, i) {
                final item = items[i];
                final eligible = item['transfer_eligible'] == true;
                return ListTile(
                  leading: Icon(eligible ? Icons.info_outline : Icons.block,
                    color: eligible ? null : Theme.of(context).colorScheme.error),
                  title: Text('Order #${item['order_id']} · Item #${item['order_item_id']}'),
                  subtitle: Text('Qty ${item['original_quantity']} · '
                    'Unit ${item['original_unit_price_iqd']} IQD · '
                    'Line ${item['line_total_iqd']} IQD\n'
                    '${item['restriction_reason'] ?? 'Requires finance review'}'),
                  isThreeLine: true,
                );
              })),
          actions: [TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close review'))],
        ));
    } catch (e) {
      if (mounted) setState(() => _error = 'Transfer preview failed: Please retry or contact a manager');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  // A request is NOT an execution: financial ownership and payments stay put.
  String _newTransferRequestKey() {
    final random = Random.secure();
    final b = List<int>.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _requestBillTransfer() async {
    if (_loading || _busyTable != null) return;
    final active = _visits.entries.where((e) => e.value['status'] == 'active')
        .toList()..sort((a, b) => a.key.compareTo(b.key));
    if (active.length < 2) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Two active table visits are required.')));
      return;
    }
    int source = active.first.key;
    int destination = active[1].key;
    int? itemId;
    int quantity = 1;
    List<Map<String, dynamic>> candidates = [];
    String? previewError;
    bool fetching = false;
    final reason = TextEditingController();
    // A single idempotency key is reused if staff retries the same submission.
    final requestKey = _newTransferRequestKey();
    try {
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (dialogContext) =>
        StatefulBuilder(builder: (context, change) {
          Future<void> fetchItems() async {
            if (source == destination) return;
            change(() { fetching = true; previewError = null; itemId = null;
              candidates = []; quantity = 1; });
            try {
              final result = await _db.rpc('gs_preview_table_bill_transfer', params: {
                'p_source_visit_id': _visits[source]!['visit_id'],
                'p_destination_visit_id': _visits[destination]!['visit_id'],
              });
              if (!dialogContext.mounted) return;
              change(() => candidates = (result as List)
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .where((e) => e['transfer_eligible'] == true).toList());
            } catch (e) {
              if (dialogContext.mounted) change(() => previewError = 'Please retry or contact a manager');
            } finally {
              if (dialogContext.mounted) change(() => fetching = false);
            }
          }
          final selected = candidates.where((e) => e['order_item_id'] == itemId);
          final selectedItem = selected.isEmpty ? null : selected.first;
          final maxQty = selectedItem == null ? 1 :
              (selectedItem['original_quantity'] as num).toInt();
          return AlertDialog(
            title: const Text('Request unpaid bill transfer'),
            content: SizedBox(width: 480, child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Request only — no orders, payments or guests move. '
                    'Finance approval and secure execution are separate.'),
                DropdownButtonFormField<int>(value: source,
                  decoration: const InputDecoration(labelText: 'Source table'),
                  items: active.map((e) => DropdownMenuItem(value: e.key,
                    child: Text('Table ${e.key}'))).toList(),
                  onChanged: (v) { if (v != null) change(() {
                    source = v; candidates = []; itemId = null; quantity = 1;
                  }); }),
                DropdownButtonFormField<int>(value: destination,
                  decoration: const InputDecoration(labelText: 'Destination table'),
                  items: active.map((e) => DropdownMenuItem(value: e.key,
                    child: Text('Table ${e.key}'))).toList(),
                  onChanged: (v) { if (v != null) change(() {
                    destination = v; candidates = []; itemId = null; quantity = 1;
                  }); }),
                TextButton.icon(onPressed: fetching || source == destination ? null : fetchItems,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Load eligible items')),
                if (fetching) const LinearProgressIndicator(),
                if (previewError != null) Text(previewError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
                if (!fetching && candidates.isEmpty)
                  const Text('No eligible items loaded. Paid items require financial review.'),
                if (candidates.isNotEmpty) DropdownButtonFormField<int>(value: itemId,
                  decoration: const InputDecoration(labelText: 'Unpaid item'),
                  items: candidates.map((e) => DropdownMenuItem<int>(
                    value: (e['order_item_id'] as num).toInt(),
                    child: Text('Order ${e['order_id']} · Item ${e['order_item_id']} '
                      '(${e['original_unit_price_iqd']} IQD × ${e['original_quantity']})'))).toList(),
                  onChanged: (v) => change(() { itemId = v; quantity = 1; })),
                if (selectedItem != null) Row(children: [
                  const Text('Quantity'), const Spacer(),
                  IconButton(onPressed: quantity > 1 ? () => change(() => quantity--) : null,
                    icon: const Icon(Icons.remove_circle_outline)),
                  Text('$quantity / $maxQty'),
                  IconButton(onPressed: quantity < maxQty ? () => change(() => quantity++) : null,
                    icon: const Icon(Icons.add_circle_outline)),
                ]),
                TextField(controller: reason, maxLength: 500, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Reason (5–500 characters)')),
              ]))),
            actions: [
              TextButton(onPressed: fetching ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
              FilledButton(onPressed: fetching || itemId == null || source == destination
                  ? null : () async {
                final why = reason.text.trim();
                if (why.length < 5 || why.length > 500) {
                  change(() => previewError = 'Enter a reason of 5–500 characters.');
                  return;
                }
                change(() { fetching = true; previewError = null; });
                try {
                  final id = await _db.rpc('gs_request_table_bill_transfer', params: {
                    'p_source_visit_id': _visits[source]!['visit_id'],
                    'p_destination_visit_id': _visits[destination]!['visit_id'],
                    'p_order_item_id': itemId, 'p_quantity': quantity,
                    'p_reason': why, 'p_request_key': requestKey,
                  });
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                    content: Text('Transfer request #$id created. No bill was moved.')));
                } catch (e) {
                  if (dialogContext.mounted) change(() => previewError = 'Please retry or contact a manager');
                } finally {
                  if (dialogContext.mounted) change(() => fetching = false);
                }
              }, child: const Text('Submit request')),
            ],
          );
        }));
    } finally { reason.dispose(); }
  }


  // Review only: the existing financial preflight always denies execution.
  Future<void> _reviewBillTransferRequests() async {
    if (_loading || _busyTable != null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _db.rpc('gs_list_table_bill_transfer_reviews');
      final requests = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (!mounted) return;
      setState(() => _loading = false);
      await showDialog<void>(context: context, builder: (dialogContext) =>
        AlertDialog(
          title: const Text('Bill transfer requests — financial review'),
          content: SizedBox(width: 640, height: 460, child: requests.isEmpty
            ? const Center(child: Text('No pending bill transfer requests.'))
            : ListView.builder(itemCount: requests.length, itemBuilder: (context, i) {
                final request = requests[i];
                final requestId = (request['request_id'] as num).toInt();
                return Card(child: ListTile(
                  title: Text('Request #$requestId · '
                    'Visit ${request['source_visit_id']} → ${request['destination_visit_id']}'),
                  subtitle: Text('Items: ${request['item_count']} · '
                    'Requested: ${request['requested_value_iqd']} IQD\n'
                    'Status: ${request['request_status']} · ${request['reason']}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.fact_check_outlined),
                  onTap: () async {
                    try {
                      final data = await _db.rpc('gs_table_transfer_financial_preflight',
                        params: {'p_request_id': requestId});
                      final checks = (data as List)
                          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
                      // Independent request-wide financial validation; never an approval.
                      final validationData = await _db.rpc(
                        'gs_validate_table_bill_transfer_request',
                        params: {'p_request_id': requestId});
                      final validationRows = (validationData as List)
                          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
                      final validation = validationRows.isEmpty
                          ? <String, dynamic>{} : validationRows.first;
                      final blockerCodes = (validation['blocker_codes'] as List?)
                          ?.map((e) => e.toString()).toList() ?? <String>[];
                      // Finance preparation is advisory only: backend always returns
                      // execution_permitted=false and does not persist an approval.
                      final preparationData = await _db.rpc(
                        'gs_prepare_table_bill_transfer_approval',
                        params: {'p_request_id': requestId});
                      final preparationRows = (preparationData as List)
                          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
                      if (preparationRows.isEmpty) {
                        throw StateError('Financial approval preparation unavailable');
                      }
                      final preparation = preparationRows.first;
                      if (preparation['execution_permitted'] != false) {
                        throw StateError('Unexpected transfer execution permission; refusing review');
                      }
                      if (!dialogContext.mounted) return;
                      await showDialog<void>(context: dialogContext,
                        builder: (detailsContext) => AlertDialog(
                          title: Text('Request #$requestId — item checks'),
                          content: SizedBox(width: 540, height: 360,
                            child: ListView(children: [
                              const Text('Review only. Approval and execution are disabled '
                                'until payment allocation is verified.'),
                              const SizedBox(height: 12),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.verified_user_outlined),
                                title: Text(preparation['review_ready'] == true
                                  ? 'Preliminary review: no blockers found'
                                  : 'Preliminary review: blocked'),
                                subtitle: Text('Next: ${preparation['next_action'] ?? 'Finance review required'}\n'
                                  'Reviewer: ${preparation['reviewer_id'] ?? '—'}\n'
                                  'Checked: ${preparation['reviewed_at'] ?? '—'}'),
                                trailing: const Icon(Icons.lock_outline),
                              ),
                              const Text('No approval or transfer can be performed from this screen.'),
                              const Divider(),
                              Text('Requested total: ${validation['requested_value_iqd'] ?? '—'} IQD'),
                              Text('Changed/invalid items: ${validation['invalid_item_count'] ?? '—'}'),
                              Text('Cash payments: ${validation['cash_payment_count'] ?? '—'}'
                                ' · Ledger entries: ${validation['ledger_entry_count'] ?? '—'}'),
                              Text('External evidence: ${validation['external_evidence_count'] ?? '—'}'
                                ' · Owner offers: ${validation['owner_offer_count'] ?? '—'}'),
                              Text('Overlapping requests: ${validation['overlapping_request_count'] ?? '—'}'),
                              const SizedBox(height: 8),
                              Text(blockerCodes.isEmpty
                                  ? 'No blockers detected by these preliminary checks; execution remains disabled.'
                                  : 'Blocking reasons: ${blockerCodes.join(', ')}',
                                style: TextStyle(color: blockerCodes.isEmpty ? null :
                                  Theme.of(detailsContext).colorScheme.error)),
                              const Divider(),
                              ...checks.map((c) => ListTile(
                                title: Text('Item ${c['order_item_id']} · '
                                  'Qty ${c['requested_quantity']}'),
                                subtitle: Text('${c['requested_value_iqd']} IQD · '
                                  '${c['blocker_reason']}'),
                                trailing: const Icon(Icons.lock_outline),
                              )),
                            ])),
                          actions: [
                            TextButton.icon(
                              icon: const Icon(Icons.fact_check_outlined),
                              label: const Text('Record independent finance review'),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: detailsContext,
                                  builder: (confirmationContext) => AlertDialog(
                                    title: const Text('Record finance review?'),
                                    content: const Text('This records an immutable review of the current transfer request. It does not approve or execute any transfer. Independent finance permissions and MFA are required.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(confirmationContext, false), child: const Text('Cancel')),
                                      FilledButton(onPressed: () => Navigator.pop(confirmationContext, true), child: const Text('Record review')),
                                    ],
                                  ),
                                );
                                if (confirm != true || !detailsContext.mounted) return;
                                try {
                                  final reviewId = await _db.rpc(
                                    'gs_record_table_transfer_finance_review',
                                    params: {'p_request_id': requestId},
                                  );
                                  if (!detailsContext.mounted) return;
                                  ScaffoldMessenger.of(detailsContext).showSnackBar(
                                    SnackBar(content: Text('Finance review #$reviewId recorded. No transfer was approved or executed.')),
                                  );
                                  Navigator.pop(detailsContext);
                                } catch (e) {
                                  if (!detailsContext.mounted) return;
                                  ScaffoldMessenger.of(detailsContext).showSnackBar(
                                    SnackBar(content: Text('Finance review not recorded: Please retry or contact a manager')),
                                  );
                                }
                              },
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.history),
                              label: const Text('Review history'),
                              onPressed: () async {
                                try {
                                  final response = await _db.rpc(
                                    'gs_list_table_transfer_finance_reviews',
                                    params: {'p_request_id': requestId});
                                  final history = (response as List)
                                      .map((e) => Map<String, dynamic>.from(e as Map))
                                      .toList();
                                  if (!detailsContext.mounted) return;
                                  await showDialog<void>(
                                    context: detailsContext,
                                    builder: (historyContext) => AlertDialog(
                                      title: const Text('Immutable finance review history'),
                                      content: SizedBox(
                                        width: 520, height: 360,
                                        child: history.isEmpty
                                          ? const Center(child: Text('No finance reviews recorded.'))
                                          : ListView.builder(
                                              itemCount: history.length,
                                              itemBuilder: (context, i) {
                                                final entry = history[i];
                                                final blockers = (entry['blocker_codes'] as List?)
                                                  ?.join(', ') ?? '';
                                                return ListTile(
                                                  title: Text('Review #${entry['review_id']} · ${entry['reviewed_at']}'),
                                                  subtitle: Text(
                                                    'Reviewer: ${entry['reviewed_by']}\n'
                                                    'Amount: ${entry['requested_value_iqd']} IQD\n'
                                                    'Ready for review: ${entry['review_ready']}\n'
                                                    'Blockers: ${blockers.isEmpty ? 'None detected' : blockers}\n'
                                                    'Execution permitted: No'),
                                                  isThreeLine: true,
                                                );
                                              })),
                                      actions: [TextButton(
                                        onPressed: () => Navigator.pop(historyContext),
                                        child: const Text('Close'))],
                                    ),
                                  );
                                } catch (e) {
                                  if (!detailsContext.mounted) return;
                                  ScaffoldMessenger.of(detailsContext).showSnackBar(
                                    SnackBar(content: Text('Unable to load review history: Please retry or contact a manager')));
                                }
                              },
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(detailsContext),
                              child: const Text('Close')),
                          ],
                        ));
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('Financial review failed: Please retry or contact a manager')));
                      }
                    }
                  },
                ));
              })),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'))],
        ));
    } catch (e) {
      if (mounted) setState(() => _error = 'Transfer review failed: Please retry or contact a manager');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  // Must be set to the deployed HTTPS customer website using --dart-define.
  static const _publicMenuUrl = String.fromEnvironment('CAFE_PUBLIC_MENU_URL');

  Future<void> _manageTableQr(Map<String, dynamic> table) async {
    final number = (table['table_number'] as num).toInt();
    final tableId = (table['id'] as num).toInt();
    final visitId = int.tryParse(_visits[number]?['visit_id']?.toString() ?? '');
    setState(() { _busyTable = number; _error = null; });
    try {
      final rows = await _db.rpc('gs_get_table_qr',
        params: {'p_table_number': number});
      final data = (rows as List).cast<Map>().first;
      String token = data['qr_token'].toString();
      String? visitToken;
      bool issuingVisitSession = false;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) {
            final configured = _publicMenuUrl.startsWith('https://');
            final link = configured
              ? '${_publicMenuUrl.replaceAll(RegExp(r"/+$"), "")}/table?token=${Uri.encodeComponent(token)}'
              : '';
            final visitLink = configured && visitToken != null
              ? Uri.parse(link).replace(queryParameters: {
                  ...Uri.parse(link).queryParameters,
                  'visit': visitToken!,
                }).toString()
              : link;
            return AlertDialog(
              title: Text('Table $number · Customer QR'),
              content: SizedBox(
                width: 330,
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (configured) ...[
                    QrImageView(data: visitLink, version: QrVersions.auto, size: 225,
                      backgroundColor: Colors.white),
                    const SizedBox(height: 8),
                    SelectableText(visitLink, style: const TextStyle(fontSize: 11)),
                  ] else const Text(
                    'Configure CAFE_PUBLIC_MENU_URL with the deployed HTTPS '
                    'customer website before printing or sharing table codes.'),
                  const SizedBox(height: 10),
                  const Text('The table QR identifies the table. A separate '
                    'staff-issued visit session is required for customer requests. '
                    'The server creates no order until staff accepts a request.'),
                  if (visitToken != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('This visit link expires after 2 hours or when the table visit ends.'),
                    ),
                  if (visitId != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: !configured || issuingVisitSession ? null : () async {
                        update(() => issuingVisitSession = true);
                        try {
                          final result = await _db.rpc(
                            'gs_staff_issue_customer_visit_session',
                            params: {
                              'p_table_id': tableId,
                              'p_visit_id': visitId,
                            },
                          );
                          if (dialogContext.mounted) {
                            update(() => visitToken = result.toString());
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(content: Text(
                                'Could not authorize this visit. Check that the table is occupied and its visit is open.')),
                            );
                          }
                        } finally {
                          if (dialogContext.mounted) {
                            update(() => issuingVisitSession = false);
                          }
                        }
                      },
                      icon: const Icon(Icons.verified_user_outlined),
                      label: Text(issuingVisitSession
                          ? 'Preparing visit link…'
                          : visitToken == null
                              ? 'Issue customer order session'
                              : 'Issue a new visit link'),
                    ),
                  ] else
                    const Text('Seat guests first to enable a visit-scoped order session.'),
                  ]),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: configured ? () async {
                    await Clipboard.setData(ClipboardData(text: visitLink));
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Table QR link copied')));
                    }
                  } : null,
                  child: const Text('Copy link')),
                TextButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: dialogContext,
                      builder: (confirmContext) => AlertDialog(
                        title: const Text('Replace existing QR code?'),
                        content: const Text(
                          'Old printed codes will stop working immediately. '
                          'Print new codes only after updating all table stickers.'),
                        actions: [
                          TextButton(onPressed: () =>
                            Navigator.pop(confirmContext, false),
                            child: const Text('Cancel')),
                          FilledButton(onPressed: () =>
                            Navigator.pop(confirmContext, true),
                            child: const Text('Regenerate')),
                        ]));
                    if (confirmed != true) return;
                    try {
                      final next = await _db.rpc('gs_rotate_table_qr',
                        params: {'p_table_number': number});
                      if (dialogContext.mounted) update(() => token = next.toString());
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('QR regeneration failed: Please retry or contact a manager')));
                      }
                    }
                  },
                  child: const Text('Regenerate')),
                TextButton(onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close')),
              ],
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Table QR unavailable: Please retry or contact a manager');
    } finally {
      if (mounted) setState(() => _busyTable = null);
    }
  }



  Future<void> _showTableWorkNotifications() async {
    List<Map<String, dynamic>> events = [];
    String? error;
    bool loading = true;
    Future<void> load(StateSetter refresh) async {
      refresh(() { loading = true; error = null; });
      try {
        final result = await _db.rpc('gs_list_my_table_notifications');
        refresh(() => events = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList());
      } catch (e) {
        refresh(() => error = 'Could not load notifications: Please retry or contact a manager');
      } finally {
        refresh(() => loading = false);
      }
    }
    try {
      final result = await _db.rpc('gs_list_my_table_notifications');
      events = (result as List)
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) { error = 'Could not load notifications: $e'; }
    loading = false;
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (dialogContext) =>
      StatefulBuilder(builder: (context, refresh) => AlertDialog(
        title: const Text('Table work notifications'),
        content: SizedBox(width: 560, height: 450,
          child: Column(children: [
            Row(children: [
              Text('${events.where((e) => e['is_read'] != true).length} unread / ${events.length} recent'),
              const Spacer(),
              IconButton(tooltip: 'Refresh', onPressed: loading ? null :
                () => load(refresh), icon: const Icon(Icons.refresh)),
            ]),
            if (loading) const LinearProgressIndicator(),
            if (error != null) SelectableText(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
            Expanded(child: events.isEmpty
              ? const Center(child: Text('No work events available.'))
              : ListView.builder(itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  return ListTile(
                    leading: Icon(event['is_read'] == true ? Icons.drafts_outlined : Icons.markunread_outlined),
                    title: Text(event['message']?.toString() ?? 'Work update'),
                    subtitle: Text('Table ${event['table_number'] ?? '-'} · '
                      '${event['event_type'] ?? ''} · '
                      '${event['created_at'] ?? ''}'),
                    trailing: event['is_read'] == true
                      ? const Icon(Icons.check, size: 18)
                      : TextButton(onPressed: () async {
                          try {
                            await _db.rpc('gs_mark_my_table_notification_read',
                              params: {'p_id': event['id']});
                            if (dialogContext.mounted) await load(refresh);
                          } catch (e) {
                            if (dialogContext.mounted) refresh(() =>
                              error = 'Cannot mark notification read: $e');
                          }
                        }, child: const Text('Mark read')),
                  );
                })),
          ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'))],
      )));
  }


  Future<void> _showManagerJobOverview() async {
    List<Map<String, dynamic>> jobs = [];
    String? error;
    bool loading = true;
    String filter = 'all';
    String selectedEmployee = 'all';
    String selectedTable = 'all';
    Future<void> fetch(StateSetter refresh) async {
      refresh(() { loading = true; error = null; });
      try {
        final result = await _db.rpc('gs_manager_table_job_overview');
        if (!mounted) return;
        refresh(() => jobs = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList());
      } catch (e) {
        if (mounted) refresh(() => error = 'Manager overview unavailable: $e');
      } finally {
        if (mounted) refresh(() => loading = false);
      }
    }
    try {
      final result = await _db.rpc('gs_manager_table_job_overview');
      jobs = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      loading = false;
    } catch (e) { error = 'Manager overview unavailable: $e'; loading = false; }
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (dialogContext) =>
      StatefulBuilder(builder: (context, refresh) {
        final now = DateTime.now();
        bool overdue(Map<String, dynamic> job) {
          final due = DateTime.tryParse(job['due_at']?.toString() ?? '');
          return due != null && due.isBefore(now);
        }
        final urgent = jobs.where((j) => j['priority'] == 'urgent').length;
        final late = jobs.where(overdue).length;
        final active = jobs.where((j) => j['status'] == 'in_progress').length;
        // Derived from the same permission-scoped, currently loaded job snapshot.
        // Counts reflect the RPC's 500-job cap; refresh to retrieve new changes.
        final assignedJobs = jobs.where((j) => j['assigned_to'] != null).toList();
        final byEmployee = <String, List<Map<String, dynamic>>>{};
        for (final job in assignedJobs) {
          final employeeId = job['assigned_to'].toString();
          byEmployee.putIfAbsent(employeeId, () => []).add(job);
        }
        final employeeSummary = byEmployee.entries.map((entry) {
          final employeeJobs = entry.value;
          final name = employeeJobs.first['employee_name']?.toString() ?? 'Employee';
          final lateCount = employeeJobs.where(overdue).length;
          final urgentCount = employeeJobs.where((j) => j['priority'] == 'urgent').length;
          final working = employeeJobs.where((j) => j['status'] == 'in_progress').length;
          return (id: entry.key, name: name, count: employeeJobs.length,
            overdue: lateCount, urgent: urgentCount, working: working);
        }).toList()..sort((a,b) {
          final overdueCompare = b.overdue.compareTo(a.overdue);
          return overdueCompare != 0 ? overdueCompare : b.count.compareTo(a.count);
        });
        final overdueByTable = <String, int>{};
        for (final job in jobs.where(overdue)) {
          final key = job['table_number']?.toString() ?? 'Unknown';
          overdueByTable[key] = (overdueByTable[key] ?? 0) + 1;
        }
        final tableRanks = overdueByTable.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final tableOptions = jobs.map((j) => j['table_number']?.toString() ?? 'Unknown')
          .toSet().toList()..sort();
        final shown = jobs.where((j) => (selectedEmployee == 'all' ||
          (j['assigned_to']?.toString() ?? 'unassigned') == selectedEmployee) &&
          (selectedTable == 'all' ||
          (j['table_number']?.toString() ?? 'Unknown') == selectedTable) &&
          (filter == 'all' ||
          (filter == 'urgent' && j['priority'] == 'urgent') ||
          (filter == 'overdue' && overdue(j)) ||
          (filter == 'in_progress' && j['status'] == 'in_progress') ||
          (filter == 'unassigned' && j['status'] == 'unassigned'))).toList();
        return AlertDialog(
          title: const Text('Manager · Table service overview'),
          content: SizedBox(width: 720, height: 560, child: Column(children: [
            Wrap(spacing: 6, runSpacing: 4, children: [
              Chip(label: Text('Open: ${jobs.length}')),
              Chip(label: Text('In progress: $active')),
              Chip(label: Text('Urgent: $urgent')),
              Chip(label: Text('Overdue: $late')),
              IconButton(onPressed: loading ? null : () => fetch(refresh),
                tooltip: 'Refresh overview', icon: const Icon(Icons.refresh)),
            ]),
            ExpansionTile(
              title: Text('Employee workload (${employeeSummary.length} employees)'),
              subtitle: Text('Assigned: ${assignedJobs.length} · Unassigned: '
                '${jobs.length - assignedJobs.length} · Overdue: $late'),
              children: employeeSummary.isEmpty
                ? [const ListTile(title: Text('No employee assignments in this snapshot.'))]
                : employeeSummary.map((employee) => ListTile(
                    dense: true,
                    leading: Icon(employee.overdue > 0 ? Icons.warning_amber : Icons.person_outline),
                    title: Text(employee.name),
                    subtitle: Text('Active: ${employee.count} · In progress: '
                      '${employee.working} · Urgent: ${employee.urgent} · '
                      'Overdue: ${employee.overdue}'),
                    trailing: employee.overdue > 0
                      ? Chip(label: Text('${employee.overdue} overdue')) : null,
                  )).toList(),
            ),
            Wrap(spacing: 12, runSpacing: 4, children: [
              DropdownButton<String>(
                value: selectedEmployee,
                hint: const Text('Employee'),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All employees')),
                  const DropdownMenuItem(value: 'unassigned', child: Text('Unassigned')),
                  for (final e in employeeSummary)
                    DropdownMenuItem(value: e.id,
                      child: Text(e.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => refresh(() => selectedEmployee = v ?? 'all'),
              ),
              DropdownButton<String>(
                value: selectedTable,
                hint: const Text('Table'),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All tables')),
                  for (final table in tableOptions)
                    DropdownMenuItem(value: table, child: Text('Table $table')),
                ],
                onChanged: (v) => refresh(() => selectedTable = v ?? 'all'),
              ),
              TextButton.icon(
                onPressed: () => refresh(() {
                  selectedEmployee = 'all'; selectedTable = 'all'; filter = 'all';
                }),
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Clear filters'),
              ),
            ]),
            ExpansionTile(
              title: Text('Overdue by table (${tableRanks.length} tables)'),
              subtitle: const Text('Based on current 500-job maximum snapshot'),
              children: tableRanks.isEmpty
                ? [const ListTile(title: Text('No overdue jobs in this snapshot.'))]
                : tableRanks.take(25).map((entry) => ListTile(
                    dense: true,
                    title: Text('Table ${entry.key}'),
                    trailing: Text('${entry.value} overdue'),
                    onTap: () => refresh(() {
                      selectedTable = entry.key;
                      selectedEmployee = 'all';
                      filter = 'overdue';
                    }),
                  )).toList(),
            ),
            SingleChildScrollView(scrollDirection: Axis.horizontal,
              child: Row(children: [for (final entry in const <String,String>{
                'all':'All', 'urgent':'Urgent', 'overdue':'Overdue',
                'in_progress':'In progress', 'unassigned':'Unassigned'
              }.entries) Padding(padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(label: Text(entry.value),
                  selected: filter == entry.key,
                  onSelected: (_) => refresh(() => filter = entry.key)))])),
            if (loading) const LinearProgressIndicator(),
            if (error != null) SelectableText(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
            Expanded(child: shown.isEmpty
              ? Center(child: Text(loading ? 'Loading jobs...' : 'No jobs match the selected filters.'))
              : ListView.builder(itemCount: shown.length, itemBuilder: (context, index) {
                  final j = shown[index];
                  final lateJob = overdue(j);
                  final worker = j['employee_name']?.toString();
                  final due = DateTime.tryParse(j['due_at']?.toString() ?? '');
                  return Card(child: ListTile(
                    leading: Icon(lateJob ? Icons.warning_amber_outlined :
                      Icons.assignment_outlined,
                      color: lateJob ? Theme.of(context).colorScheme.error : null),
                    title: Text('Job #${j['job_id']} · Table ${j['table_number']} · ${j['kind']}'),
                    subtitle: Text('Assigned: ${worker == null || worker.isEmpty ? 'Unassigned' : worker} '
                      '· ${j['status']} · ${j['priority']}\n'
                      '${j['details'] ?? ''}'
                      '${due == null ? '' : '\nDue: ${due.toLocal()}'}'
                      '${lateJob ? ' · OVERDUE' : ''}'),
                    isThreeLine: true,
                  ));
                })),
            const Text('Read-only overview. Reassignments require the separate '
              'authorized manager action and are audited.'),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'))],
        );
      }));
  }


  Future<void> _showServiceDurationReport() async {
    List<Map<String, dynamic>> rows = [];
    String? error;
    bool loading = true;
    int days = 30;
    Future<void> load(StateSetter refresh) async {
      refresh(() { loading = true; error = null; });
      try {
        final data = await _db.rpc('gs_manager_table_service_duration_report',
          params: {'p_days': days});
        if (!mounted) return;
        refresh(() => rows = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList());
      } catch (e) {
        if (mounted) refresh(() => error = 'Duration report unavailable: $e');
      } finally {
        if (mounted) refresh(() => loading = false);
      }
    }
    try {
      final data = await _db.rpc('gs_manager_table_service_duration_report',
        params: {'p_days': days});
      rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) { error = 'Duration report unavailable: $e'; }
    loading = false;
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (dialogContext) =>
      StatefulBuilder(builder: (context, refresh) {
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final r in rows) {
          final key = r['employee_name']?.toString() ?? 'Unknown employee';
          grouped.putIfAbsent(key, () => []).add(r);
        }
        String fmt(Object? minutes) {
          if (minutes == null) return 'N/A';
          final value = num.tryParse(minutes.toString());
          return value == null ? 'N/A' : '${value.toStringAsFixed(1)} min';
        }
        return AlertDialog(
          title: const Text('Manager · Service response times'),
          content: SizedBox(width: 690, height: 520, child: Column(children: [
            Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Period:'),
                DropdownButton<int>(value: days,
                  items: const [7,30,90].map((d) => DropdownMenuItem(
                    value: d, child: Text('$d days'))).toList(),
                  onChanged: loading ? null : (v) {
                    if (v != null) { days = v; load(refresh); }
                  }),
                TextButton.icon(onPressed: loading ? null : () => load(refresh),
                  icon: const Icon(Icons.refresh), label: const Text('Refresh')),
                Chip(label: Text('${rows.length} completed jobs')),
              ]),
            const Text('Response: creation → claim. Service: claim → completion. '
              'Only completed jobs are included; missing timestamps show N/A.'),
            if (loading) const LinearProgressIndicator(),
            if (error != null) SelectableText(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
            Expanded(child: rows.isEmpty
              ? Center(child: Text(loading ? 'Loading report...' :
                'No completed jobs in the selected period.'))
              : ListView(children: [
                  for (final entry in grouped.entries) ExpansionTile(
                    title: Text('${entry.key} · ${entry.value.length} completed'),
                    children: entry.value.map((r) => ListTile(
                      dense: true,
                      title: Text('Job #${r['job_id']} · Table ${r['table_number']} '
                        '· ${r['kind']}'),
                      subtitle: Text('Response: ${fmt(r['response_minutes'])} · '
                        'Service: ${fmt(r['service_minutes'])} · '
                        '${r['completed_after_due'] == true ? 'Late' : 'On time / no due date'}'),
                    )).toList(),
                  ),
                ])),
            const Text('Snapshot: up to 500 recently completed jobs. '
              'This is not a complete historical employee performance report.'),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'))],
        );
      }));
  }

  Future<void> _showEmployeePerformance() async {
    List<Map<String, dynamic>> employees = [];
    int days = 30;
    bool loading = true;
    String? error;
    Future<void> reload(StateSetter update) async {
      update(() { loading = true; error = null; });
      try {
        final result = await _db.rpc('gs_manager_table_employee_performance',
          params: {'p_days': days});
        if (!mounted) return;
        update(() => employees = (result as List)
          .map((r) => Map<String, dynamic>.from(r as Map)).toList());
      } catch (e) {
        if (mounted) update(() => error = 'Employee report unavailable: $e');
      } finally {
        if (mounted) update(() => loading = false);
      }
    }
    try {
      final result = await _db.rpc('gs_manager_table_employee_performance',
        params: {'p_days': days});
      employees = (result as List)
        .map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (e) { error = 'Employee report unavailable: $e'; }
    loading = false;
    if (!mounted) return;
    String metric(Object? value, String suffix) => value == null
      ? 'N/A' : '${value.toString()}$suffix';
    await showDialog<void>(context: context, builder: (dialogContext) =>
      StatefulBuilder(builder: (context, update) => AlertDialog(
        title: const Text('Manager · Employee service performance'),
        content: SizedBox(width: 700, height: 510, child: Column(children: [
          Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Completed in last'),
              DropdownButton<int>(value: days,
                items: const [7,30,90].map((d) => DropdownMenuItem(
                  value: d, child: Text('$d days'))).toList(),
                onChanged: loading ? null : (v) {
                  if (v != null) { days = v; reload(update); }
                }),
              IconButton(onPressed: loading ? null : () => reload(update),
                tooltip: 'Refresh report', icon: const Icon(Icons.refresh)),
              Chip(label: Text('${employees.length} employees')),
            ]),
          const Text('Response = job created to claim; service = claim to completion. '
            'Late rate uses only completed jobs with deadlines.'),
          if (loading) const LinearProgressIndicator(),
          if (error != null) SelectableText(error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
          Expanded(child: employees.isEmpty
            ? Center(child: Text(loading ? 'Loading...' : 'No completed jobs in period.'))
            : ListView.builder(itemCount: employees.length,
              itemBuilder: (context, index) {
                final r = employees[index];
                return Card(child: ListTile(
                  title: Text('${r['employee_name']} · ${r['completed_jobs']} completed'),
                  subtitle: Text('Average response: ${metric(r['avg_response_minutes'], ' min')} '
                    '(${r['measured_responses']} measured)\n'
                    'Average service: ${metric(r['avg_service_minutes'], ' min')} '
                    '(${r['measured_services']} measured)\n'
                    'Late: ${r['late_jobs']} / ${r['jobs_with_deadline']} '
                    '(${metric(r['late_percent'], '%')})'),
                  isThreeLine: true,
                ));
              })),
          const Text('Database aggregates all matching completed jobs; '
            'unassigned jobs and missing timestamps are not guessed.'),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'))],
      )));
  }

  Future<void> _showPartialDelivery(int jobId) async {
    Map<String, dynamic>? snapshot;
    String? error;
    bool saving = false;
    String action = 'picked_up';
    final quantity = TextEditingController(text: '1');
    Future<void> reload(StateSetter refresh) async {
      try {
        final rows = await _db.rpc('gs_my_table_delivery_quantity_status',
          params: {'p_job_id': jobId});
        if (!mounted) return;
        refresh(() {
          snapshot = (rows as List).isEmpty ? null :
            Map<String, dynamic>.from(rows.first as Map);
          error = snapshot == null ? 'Delivery job unavailable.' : null;
        });
      } catch (e) {
        if (mounted) refresh(() => error = 'Could not load delivery: $e');
      }
    }
    try {
      await showDialog<void>(context: context, builder: (dialogContext) =>
        StatefulBuilder(builder: (context, refresh) {
          Future<void> submit() async {
            final count = int.tryParse(quantity.text.trim());
            final remaining = (snapshot?[action == 'picked_up' ?
              'remaining_to_pick' : 'available_to_deliver'] as num?)?.toInt() ?? 0;
            if (count == null || count < 1 || count > remaining) {
              refresh(() => error = 'Enter a quantity between 1 and $remaining.');
              return;
            }
            refresh(() { saving = true; error = null; });
            try {
              await _db.rpc('gs_record_table_item_delivery_quantity', params: {
                'p_order_item_id': snapshot!['order_item_id'],
                'p_action': action, 'p_quantity': count,
              });
              if (!dialogContext.mounted) return;
              await reload(refresh);
              if (dialogContext.mounted) quantity.text = '1';
            } catch (e) {
              if (dialogContext.mounted) refresh(() => error = 'Update failed: $e');
            } finally {
              if (dialogContext.mounted) refresh(() => saving = false);
            }
          }
          final pickLeft = (snapshot?['remaining_to_pick'] as num?)?.toInt() ?? 0;
          final deliverable = (snapshot?['available_to_deliver'] as num?)?.toInt() ?? 0;
          return AlertDialog(
            title: Text('Job #$jobId · Quantity handover'),
            content: SizedBox(width: 420, child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Ordered: ${snapshot?['ordered_quantity'] ?? '—'}'),
                Text('Picked: ${snapshot?['picked_quantity'] ?? '—'}'),
                Text('Delivered: ${snapshot?['delivered_quantity'] ?? '—'}'),
                Text('Remaining to pick: $pickLeft'),
                Text('Picked and ready to deliver: $deliverable'),
                Text('Remaining to deliver: ${snapshot?['remaining_to_deliver'] ?? '—'}'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(value: action,
                  decoration: const InputDecoration(labelText: 'Action'),
                  items: const [
                    DropdownMenuItem(value: 'picked_up', child: Text('Pick up items')),
                    DropdownMenuItem(value: 'delivered', child: Text('Confirm delivered items')),
                  ],
                  onChanged: saving ? null : (v) => refresh(() => action = v ?? action)),
                TextField(controller: quantity, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity')),
                if (error != null) SelectableText(error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 8),
                const Text('Only the assigned employee can record handovers. '
                  'The backend validates quantities and prevents over-delivery.'),
              ]))),
            actions: [
              TextButton(onPressed: saving ? null : () => reload(refresh),
                child: const Text('Refresh')),
              TextButton(onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close')),
              FilledButton(onPressed: saving || snapshot == null ||
                (action == 'picked_up' ? pickLeft : deliverable) == 0 ? null : submit,
                child: Text(saving ? 'Saving...' : 'Confirm quantity')),
            ],
          );
        }));
    } finally { quantity.dispose(); }
  }

  Future<void> _showMyJobs() async {
    List<Map<String, dynamic>> jobs = [];
    String? error;
    bool busy = false;
    String filter = 'all';
    Future<void> reload(StateSetter update) async {
      try {
        final result = await _db.rpc('gs_list_my_table_jobs');
        if (!mounted) return;
        update(() {
          jobs = (result as List)
              .map((e) => Map<String, dynamic>.from(e as Map)).toList();
          error = null;
        });
      } catch (e) {
        if (mounted) update(() => error = 'Could not load jobs: $e');
      }
    }
    try {
      final result = await _db.rpc('gs_list_my_table_jobs');
      jobs = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) { error = '$e'; }
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (dialogContext) =>
      StatefulBuilder(builder: (context, update) {
        Future<void> transition(int id, String action) async {
          if (busy) return;
          update(() { busy = true; error = null; });
          try {
            await _db.rpc('gs_update_my_table_job', params: {
              'p_job_id': id, 'p_action': action,
            });
            if (dialogContext.mounted) await reload(update);
          } catch (e) {
            if (dialogContext.mounted) update(() => error = '$e');
          } finally {
            if (dialogContext.mounted) update(() => busy = false);
          }
        }
        final inProgress = jobs.where((j) => j['status'] == 'in_progress').length;
        final urgent = jobs.where((j) => j['priority'] == 'urgent').length;
        final overdue = jobs.where((j) {
          final raw = j['due_at']?.toString();
          final due = raw == null ? null : DateTime.tryParse(raw);
          return due != null && due.isBefore(DateTime.now());
        }).length;
        final visible = jobs.where((j) => filter == 'all' ||
          (filter == 'urgent' && j['priority'] == 'urgent') ||
          (filter == 'in_progress' && j['status'] == 'in_progress') ||
          (filter == 'overdue' && (() {
            final raw = j['due_at']?.toString();
            final due = raw == null ? null : DateTime.tryParse(raw);
            return due != null && due.isBefore(DateTime.now());
          })())).toList();
        return AlertDialog(
          title: const Text('My table service jobs'),
          content: SizedBox(width: 620, height: 520,
            child: Column(children: [
              Wrap(spacing: 10, runSpacing: 6, children: [
                Chip(label: Text('Active: ${jobs.length}')),
                Chip(label: Text('In progress: $inProgress')),
                Chip(label: Text('Urgent: $urgent')),
                Chip(label: Text('Overdue: $overdue')),
                IconButton(onPressed: busy ? null : () => reload(update),
                  tooltip: 'Refresh jobs', icon: const Icon(Icons.refresh)),
              ]),
              SingleChildScrollView(scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final option in const <String, String>{
                    'all': 'All', 'urgent': 'Urgent',
                    'in_progress': 'In progress', 'overdue': 'Overdue',
                  }.entries)
                    Padding(padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(label: Text(option.value),
                        selected: filter == option.key,
                        onSelected: (_) => update(() => filter = option.key))),
                ])),
              if (error != null) SelectableText(error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
              Expanded(child: visible.isEmpty
                ? const Center(child: Text('No jobs match this filter.'))
                : ListView.builder(itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final job = visible[index];
                      final id = (job['job_id'] as num).toInt();
                      final status = job['status'].toString();
                      final isDelivery = job['kind'] == 'deliver_items';
                      final raw = job['due_at']?.toString();
                      final due = raw == null ? null : DateTime.tryParse(raw);
                      final isOverdue = due != null && due.isBefore(DateTime.now());
                      return Card(child: ListTile(
                        title: Text('Table ${job['table_number']} · ${job['kind']}'),
                        subtitle: Text('${job['details'] ?? ''}\n'
                          'Priority: ${job['priority']} · $status'
                          '${due == null ? '' : '\nDue: ${due.toLocal()}'}'
                          '${isOverdue ? ' · OVERDUE' : ''}'),
                        isThreeLine: true,
                        leading: Icon(isOverdue ? Icons.warning_amber_rounded :
                          status == 'in_progress' ? Icons.pending_actions : Icons.assignment_outlined,
                          color: isOverdue ? Theme.of(context).colorScheme.error : null),
                        trailing: isDelivery
                          ? FilledButton(onPressed: busy ? null : () async {
                              await _showPartialDelivery(id);
                              if (dialogContext.mounted) await reload(update);
                            }, child: const Text('Pickup / Deliver'))
                          : status == 'assigned'
                          ? FilledButton(onPressed: busy ? null :
                              () => transition(id, 'start'),
                              child: const Text('Start'))
                          : FilledButton(onPressed: busy ? null :
                              () => transition(id, 'complete'),
                              child: const Text('Complete')),
                      ));
                    })),
            ])),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'))],
        );
      }));
  }



  Future<void> _manageWorkerCapabilities() async {
    const kinds = <String, String>{
      'take_order': 'Take orders',
      'deliver_items': 'Deliver items',
      'clean': 'Clean tables',
      'shisha_service': 'Shisha service',
      'tea_service': 'Tea service',
      'bring_bill': 'Bring bill',
      'other': 'Other requests',
    };
    List<Map<String, dynamic>> employees = [];
    String? selected;
    String search = '';
    Set<String> granted = {};
    Map<String, int> activeJobs = {};
    bool loading = false;
    bool saving = false;
    String? error;
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (dialogContext) =>
      StatefulBuilder(builder: (context, refresh) {
        Future<void> loadEmployees() async {
          refresh(() { loading = true; error = null; });
          try {
            final result = await _db.rpc('gs_list_table_capability_employees');
            if (!dialogContext.mounted) return;
            refresh(() { employees = (result as List)
              .map((e) => Map<String, dynamic>.from(e as Map)).toList(); });
          } catch (e) {
            if (dialogContext.mounted) refresh(() => error = '$e');
          } finally {
            if (dialogContext.mounted) refresh(() => loading = false);
          }
        }
        Future<void> selectEmployee(String id) async {
          refresh(() { selected = id; loading = true; error = null; granted = {}; activeJobs = {}; });
          try {
            final result = await _db.rpc('gs_list_table_worker_capabilities',
              params: {'p_employee': id});
            final jobs = await _db.rpc('gs_list_table_worker_active_job_counts',
              params: {'p_employee': id});
            if (!dialogContext.mounted || selected != id) return;
            refresh(() {
              granted = (result as List).map((e) => e.toString()).toSet();
              activeJobs = {
                for (final entry in (jobs as List))
                  (entry as Map)['job_kind'].toString():
                    ((entry['active_count'] as num?)?.toInt() ?? 0),
              };
            });
          } catch (e) {
            if (dialogContext.mounted) refresh(() => error = '$e');
          } finally {
            if (dialogContext.mounted) refresh(() => loading = false);
          }
        }
        Future<void> toggle(String kind, bool enabled) async {
          final id = selected;
          if (id == null) return;
          refresh(() { saving = true; error = null; });
          try {
            await _db.rpc('gs_set_table_worker_capability', params: {
              'p_employee': id, 'p_kind': kind, 'p_enabled': enabled,
            });
            if (!dialogContext.mounted) return;
            refresh(() { if (enabled) { granted.add(kind); }
              else { granted.remove(kind); } });
            await selectEmployee(id);
          } catch (e) {
            if (dialogContext.mounted) refresh(() => error = '$e');
          } finally {
            if (dialogContext.mounted) refresh(() => saving = false);
          }
        }
        // Load only once when dialog first builds; no network work in build.
        return AlertDialog(
          title: const Text('Manager · Employee job permissions'),
          content: SizedBox(width: 560, height: 520, child: Column(children: [
            TextField(decoration: const InputDecoration(
              labelText: 'Search active employees', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => refresh(() => search = v)),
            Row(children: [
              Expanded(child: Text(selected == null
                ? 'Select an employee' : 'Selected employee')),
              TextButton(onPressed: saving ? null : loadEmployees,
                child: const Text('Load / Refresh employees')),
            ]),
            if (loading) const LinearProgressIndicator(),
            if (error != null) SelectableText(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
            Expanded(child: ListView(children: [
              for (final e in employees.where((e) =>
                '${e['full_name']} ${e['user_id']}'.toLowerCase()
                  .contains(search.toLowerCase())))
                RadioListTile<String>(dense: true,
                  title: Text(e['full_name']?.toString() ?? 'Employee'),
                  value: e['user_id'].toString(), groupValue: selected,
                  onChanged: saving ? null : (v) {
                    if (v != null) selectEmployee(v);
                  }),
              if (selected != null) ...[
                const Divider(),
                const Text('Allowed table-service responsibilities'),
                for (final entry in kinds.entries)
                  CheckboxListTile(dense: true, title: Text(entry.value),
                    subtitle: (activeJobs[entry.key] ?? 0) > 0
                      ? Text('${activeJobs[entry.key]} active assignment(s) · reassign first')
                      : const Text('No active assignments'),
                    value: granted.contains(entry.key),
                    onChanged: loading || saving ||
                      (granted.contains(entry.key) &&
                       (activeJobs[entry.key] ?? 0) > 0) ? null : (v) {
                      if (v != null) toggle(entry.key, v);
                    }),
              ],
            ])),
            const Text('Changes are saved individually and audited. '
              'Permissions with active jobs cannot be revoked until jobs are reassigned or completed.'),
          ])),
          actions: [TextButton(onPressed: saving ? null :
            () => Navigator.pop(dialogContext), child: const Text('Close'))],
        );
      }));
  }

  Future<void> _manageTableWorkloadLimits() async {
    List<Map<String, dynamic>> limits = [];
    String? error;
    bool busy = false;
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (dialogContext) =>
      StatefulBuilder(builder: (context, refresh) {
        Future<void> reload() async {
          refresh(() { busy = true; error = null; });
          try {
            final result = await _db.rpc('gs_list_table_job_workload_limits');
            if (!dialogContext.mounted) return;
            refresh(() => limits = (result as List)
              .map((e) => Map<String, dynamic>.from(e as Map)).toList());
          } catch (e) {
            if (dialogContext.mounted) refresh(() => error = '$e');
          } finally {
            if (dialogContext.mounted) refresh(() => busy = false);
          }
        }
        Future<void> changeLimit(Map<String, dynamic> row) async {
          final controller = TextEditingController(text: '${row['max_active']}');
          final newLimit = await showDialog<int>(context: dialogContext,
            builder: (inner) => AlertDialog(
              title: Text('Max active · ${row['job_kind']}'),
              content: TextField(controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  helperText: '0 blocks new assignments; maximum 100')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(inner),
                  child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(inner,
                  int.tryParse(controller.text.trim())),
                  child: const Text('Save')),
              ],
            ));
          controller.dispose();
          if (newLimit == null || !dialogContext.mounted) return;
          refresh(() { busy = true; error = null; });
          try {
            await _db.rpc('gs_set_table_job_workload_limit', params: {
              'p_kind': row['job_kind'], 'p_limit': newLimit,
            });
            if (dialogContext.mounted) await reload();
          } catch (e) {
            if (dialogContext.mounted) refresh(() => error = '$e');
          } finally {
            if (dialogContext.mounted) refresh(() => busy = false);
          }
        }
        return AlertDialog(
          title: const Text('Manager · Job workload limits'),
          content: SizedBox(width: 490, height: 460, child: Column(children: [
            const Text('Limits apply per employee and responsibility. '
              'Existing jobs are not cancelled when a limit is lowered.'),
            TextButton.icon(onPressed: busy ? null : reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Load / Refresh limits')),
            if (busy) const LinearProgressIndicator(),
            if (error != null) SelectableText(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
            Expanded(child: ListView(children: [
              for (final row in limits)
                ListTile(title: Text(row['job_kind'].toString()),
                  subtitle: Text('Max per employee: ${row['max_active']} · '
                    'Total active across staff: ${row['currently_assigned']}'),
                  trailing: IconButton(icon: const Icon(Icons.edit_outlined),
                    onPressed: busy ? null : () => changeLimit(row))),
            ])),
          ])),
          actions: [TextButton(onPressed: busy ? null :
            () => Navigator.pop(dialogContext), child: const Text('Close'))],
        );
      }));
  }

  Future<void> _reassignTableJob() async {
    final jobId = TextEditingController();
    final reason = TextEditingController();
    String query = '';
    String? selectedEmployee;
    String? error;
    String? jobKind;
    bool loading = false;
    bool saving = false;
    List<Map<String, dynamic>> eligible = [];
    if (!mounted) return;
    try {
      await showDialog<void>(context: context, builder: (dialogContext) =>
        StatefulBuilder(builder: (context, refresh) {
          Future<void> loadEligible() async {
            final id = int.tryParse(jobId.text.trim());
            if (id == null || id < 1) {
              refresh(() => error = 'Enter a valid job number first.');
              return;
            }
            refresh(() { loading = true; error = null; eligible = []; selectedEmployee = null; jobKind = null; });
            try {
              final result = await _db.rpc('gs_list_eligible_table_job_workers',
                params: {'p_job_id': id});
              if (!dialogContext.mounted) return;
              final rows = (result as List)
                .map((e) => Map<String, dynamic>.from(e as Map)).toList();
              refresh(() {
                eligible = rows;
                if (rows.isNotEmpty) jobKind = rows.first['job_kind']?.toString();
              });
            } catch (e) {
              if (dialogContext.mounted) refresh(() => error = 'Cannot load eligible workers: $e');
            } finally {
              if (dialogContext.mounted) refresh(() => loading = false);
            }
          }
          final filtered = eligible.where((e) =>
            ('${e['full_name']} ${e['user_id']}').toLowerCase()
              .contains(query.toLowerCase())).toList();
          return AlertDialog(
            title: const Text('Manager · Reassign table job'),
            content: SizedBox(width: 510, height: 480, child: Column(children: [
              TextField(controller: jobId, keyboardType: TextInputType.number,
                onChanged: (_) => refresh(() {
                  eligible = []; selectedEmployee = null; jobKind = null;
                }),
                decoration: const InputDecoration(labelText: 'Job number')),
              Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                onPressed: loading || saving ? null : loadEligible,
                icon: const Icon(Icons.people_alt_outlined),
                label: const Text('Find eligible employees & workload'))),
              if (jobKind != null) Text('Job responsibility: $jobKind'),
              TextField(onChanged: (v) => refresh(() => query = v),
                decoration: const InputDecoration(labelText: 'Search eligible employees',
                  prefixIcon: Icon(Icons.search))),
              if (loading) const LinearProgressIndicator(),
              Expanded(child: filtered.isEmpty
                ? Center(child: Text(eligible.isEmpty
                    ? 'Enter a job number and load eligible employees.'
                    : 'No matching employees'))
                : ListView.builder(itemCount: filtered.length, itemBuilder: (context, index) {
                    final e = filtered[index];
                    final id = e['user_id'].toString();
                    return RadioListTile<String>(dense: true,
                      title: Text(e['full_name']?.toString() ?? 'Employee'),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('All active jobs: ${e['active_jobs']} · ${e['kind_jobs']}/${e['max_active']} for this responsibility'),
                        Text(e['capacity_state'] == 'full' ? 'At capacity — cannot assign' :
                          e['capacity_state'] == 'near_limit' ? 'Nearly full · ${e['remaining_slots']} slot left' :
                          'Available · ${e['remaining_slots']} slots left',
                          style: TextStyle(color: e['capacity_state'] == 'full'
                            ? Theme.of(context).colorScheme.error
                            : e['capacity_state'] == 'near_limit'
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context).colorScheme.primary)),
                      ]),
                      value: id, groupValue: selectedEmployee,
                      onChanged: saving || e['capacity_state'] == 'full' ? null :
                        (v) => refresh(() => selectedEmployee = v));
                  })),
              TextField(controller: reason, maxLines: 2,
                decoration: const InputDecoration(labelText: 'Reassignment reason (required)')),
              if (error != null) SelectableText(error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const Text('Eligibility and workload are advisory snapshots. '
                'Capacity is a snapshot; Supabase enforces current limits when saving.'),
            ])),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
              FilledButton(onPressed: saving || loading || selectedEmployee == null ? null : () async {
                final id = int.tryParse(jobId.text.trim());
                if (id == null || id < 1 || reason.text.trim().length < 3) {
                  refresh(() => error = 'Enter a valid job and reason.'); return;
                }
                refresh(() { saving = true; error = null; });
                try {
                  await _db.rpc('gs_reassign_table_service_job', params: {
                    'p_job_id': id, 'p_new_employee': selectedEmployee,
                    'p_reason': reason.text.trim(),
                  });
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Job reassigned.')));
                } catch (e) {
                  if (dialogContext.mounted) refresh(() => error = '$e');
                } finally {
                  if (dialogContext.mounted) refresh(() => saving = false);
                }
              }, child: Text(saving ? 'Saving...' : 'Reassign')),
            ],
          );
        }));
    } finally {
      jobId.dispose(); reason.dispose();
    }
  }

  Future<void> _showAvailableJobs() async {
    if (!mounted) return;
    List<Map<String, dynamic>> jobs = [];
    bool loading = true;
    String? error;
    bool claiming = false;
    Map<String, Map<String, dynamic>> myCapacity = {};
    String? capacityError;
    try {
      final result = await _db.rpc('gs_list_unassigned_table_jobs');
      jobs = (result as List)
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      try {
        final capacity = await _db.rpc('gs_my_table_job_capacity');
        myCapacity = {for (final raw in (capacity as List))
          (raw as Map)['job_kind'].toString(): Map<String, dynamic>.from(raw)};
      } catch (e) { capacityError = 'Capacity unavailable: $e'; }
    } catch (e) {
      error = 'Could not load available jobs: $e';
    }
    loading = false;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) {
          Future<void> load() async {
            refresh(() { loading = true; error = null; });
            try {
              final result = await _db.rpc('gs_list_unassigned_table_jobs');
              final capacity = await _db.rpc('gs_my_table_job_capacity');
              if (!dialogContext.mounted) return;
              refresh(() {
                myCapacity = {for (final raw in (capacity as List))
                  (raw as Map)['job_kind'].toString(): Map<String, dynamic>.from(raw)};
                capacityError = null;
                jobs = (result as List)
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();
              });
            } catch (e) {
              if (dialogContext.mounted) {
                refresh(() => error = 'Could not load jobs or capacity: $e');
              }
            } finally {
              if (dialogContext.mounted) refresh(() => loading = false);
            }
          }

          Future<void> claim(int id) async {
            if (claiming) return;
            refresh(() { claiming = true; error = null; });
            try {
              await _db.rpc('gs_claim_table_service_job',
                params: {'p_job_id': id});
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(content: Text('Job #$id assigned to you.')));
              await load();
            } catch (e) {
              if (dialogContext.mounted) {
                refresh(() => error =
                  'Claim failed. Another employee may have taken this job: $e');
                await load();
              }
            } finally {
              if (dialogContext.mounted) refresh(() => claiming = false);
            }
          }

          return AlertDialog(
            title: const Text('Unassigned table jobs'),
            content: SizedBox(
              width: 570, height: 430,
              child: Column(children: [
                Row(children: [
                  Text('${jobs.length} available jobs'),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh jobs',
                    onPressed: claiming ? null : load,
                    icon: const Icon(Icons.refresh)),
                ]),
                if (loading) const LinearProgressIndicator(),
                if (capacityError != null) SelectableText(capacityError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
                if (error != null) SelectableText(error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
                Expanded(child: jobs.isEmpty
                  ? Center(child: Text(loading ? 'Loading...' :
                      'No unassigned jobs. Tap refresh to check again.'))
                  : ListView.builder(
                      itemCount: jobs.length,
                      itemBuilder: (context, i) {
                        final job = jobs[i];
                        final id = (job['job_id'] as num).toInt();
                        final kind = job['kind'].toString();
                        final cap = myCapacity[kind];
                        final eligible = cap?['eligible'] == true;
                        final active = (cap?['active_jobs'] as num?)?.toInt() ?? 0;
                        final limit = (cap?['max_active'] as num?)?.toInt() ?? 0;
                        final canClaim = eligible && active < limit;
                        final capacityLabel = cap == null ? 'Capacity unavailable'
                          : !eligible ? 'Not authorized for this task'
                          : '$active / $limit active · ${limit > active ? limit-active : 0} slots left';
                        return Card(child: ListTile(
                          title: Text('Table ${job['table_number']} · ${job['kind']}'),
                          subtitle: Text(
                            '${job['priority']} priority · ${job['details'] ?? ''}'
                            '${job['due_at'] == null ? '' : '\nDue: ${job['due_at']}'}'
                            '\n$capacityLabel'),
                          trailing: FilledButton(
                            onPressed: claiming || loading || !canClaim ? null : () => claim(id),
                            child: Text(cap == null ? 'Unavailable' :
                              !eligible ? 'Not eligible' :
                              !canClaim ? 'At limit' : 'Claim')),
                        ));
                      })),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createTable() async {
    final numberController = TextEditingController();
    final chairsController = TextEditingController(text: '4');
    final floorController = TextEditingController();
    String? error;
    bool saving = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Add a new table'),
            content: SizedBox(width: 380, child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Table number'),
                ),
                TextField(
                  controller: chairsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Number of chairs (1–50)'),
                ),
                TextField(
                  controller: floorController,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Floor / zone name',
                    hintText: 'Enter the table’s floor name',
                  ),
                ),
                const SizedBox(height: 8),
                const Text('New tables start available, with zero guests and Normal Mode.'),
                if (error != null) SelectableText(error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            )),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
              FilledButton(
                onPressed: saving ? null : () async {
                  final number = int.tryParse(numberController.text.trim());
                  final chairs = int.tryParse(chairsController.text.trim());
                  final floor = floorController.text.trim();
                  if (number == null || number < 1 || chairs == null || chairs < 1 ||
                      chairs > 50 || floor.isEmpty || floor.length > 80) {
                    update(() => error = 'Enter a positive table number, 1–50 chairs, and a floor name up to 80 characters.');
                    return;
                  }
                  update(() { saving = true; error = null; });
                  try {
                    await _db.rpc('gs_create_cafe_table_in_floor', params: {
                      'p_table_number': number,
                      'p_capacity': chairs,
                      'p_floor_name': floor,
                    });
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    await _reload();
                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('Table $number created on $floor with $chairs chairs.')));
                  } catch (_) {
                    if (dialogContext.mounted) update(() => error =
                      'Unable to create table. Check the table number, floor name, and permissions.');
                  } finally {
                    if (dialogContext.mounted) update(() => saving = false);
                  }
                },
                child: Text(saving ? 'Creating...' : 'Create table'),
              ),
            ],
          ),
        ),
      );
    } finally {
      numberController.dispose();
      chairsController.dispose();
      floorController.dispose();
    }
  }

  Future<void> _setTableFloor(Map<String, dynamic> table) async {
    final number = (table['table_number'] as num).toInt();
    final floorController = TextEditingController(text: _floorName(table));
    String? error;
    bool saving = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text('Table $number · Floor'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: floorController,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Floor / zone name',
                  helperText: 'Use the same name for tables on the same floor.',
                ),
              ),
              if (error != null) SelectableText(error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ]),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving ? null : () async {
                  final floor = floorController.text.trim();
                  if (floor.isEmpty || floor.length > 80) {
                    update(() => error = 'Enter a floor name up to 80 characters.');
                    return;
                  }
                  update(() { saving = true; error = null; });
                  try {
                    await _db.rpc('gs_set_cafe_table_floor', params: {
                      'p_table_number': number,
                      'p_floor_name': floor,
                    });
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    await _reload();
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('Table $number floor updated to $floor.')));
                    }
                  } catch (_) {
                    if (dialogContext.mounted) {
                      update(() => error =
                        'Floor was not changed. Check the table status and your permissions.');
                    }
                  } finally {
                    if (dialogContext.mounted) update(() => saving = false);
                  }
                },
                child: Text(saving ? 'Saving…' : 'Save floor'),
              ),
            ],
          ),
        ),
      );
    } finally {
      floorController.dispose();
    }
  }

  Future<void> _adjustChairs(Map<String, dynamic> table) async {
    final number = (table['table_number'] as num).toInt();
    final capacity = (table['capacity'] as num).toInt();
    final guests = (table['guests'] as num?)?.toInt() ?? 0;
    int delta = 0;
    final reason = TextEditingController();
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text('Table $number · Chair management'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Current capacity: $capacity · Guests: $guests'),
              const SizedBox(height: 8),
              const Text('Add or remove chairs. Orders and bills are unchanged.'),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                  tooltip: 'Remove chair',
                  onPressed: capacity + delta > guests && capacity + delta > 1
                    && delta > -20 ? () => update(() => delta--) : null,
                  icon: const Icon(Icons.remove_circle_outline)),
                Text('New capacity: ${capacity + delta}'),
                IconButton(
                  tooltip: 'Add chair',
                  onPressed: capacity + delta < 50 && delta < 20
                    ? () => update(() => delta++) : null,
                  icon: const Icon(Icons.add_circle_outline)),
              ]),
              TextField(
                controller: reason,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Reason for chair change',
                  hintText: 'e.g. Add chair for arriving guest')),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
              FilledButton(
                onPressed: delta == 0 ? null :
                  () => Navigator.pop(dialogContext, true),
                child: const Text('Save chair change')),
            ],
          ),
        ),
      );
      if (accepted != true || !mounted) return;
      if (reason.text.trim().length < 3) {
        setState(() => _error = 'Enter a reason of at least 3 characters.');
        return;
      }
      setState(() { _busyTable = number; _error = null; });
      await _db.rpc('gs_adjust_table_chairs', params: {
        'p_table_number': number,
        'p_delta': delta,
        'p_reason': reason.text.trim(),
      });
      if (!mounted) return;
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Table $number capacity updated.')));
    } catch (e) {
      if (mounted) setState(() =>
        _error = 'Chair change rejected by server: $e');
    } finally {
      reason.dispose();
      if (mounted) setState(() => _busyTable = null);
    }
  }



  Future<void> _registerPosDevice() async {
    final name = TextEditingController();
    final model = TextEditingController(text: 'sunmi_v2');
    final key = TextEditingController();
    String department = 'cashier';
    bool saving = false;
    String? error;
    try {
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Register POS device'),
          content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min, children: [
              const Text('Register a device for future POS delivery. This does not install a printer driver or activate automatic printing.'),
              TextField(controller: name, maxLength: 120,
                decoration: const InputDecoration(labelText: 'Device name')),
              TextField(controller: model, maxLength: 120,
                decoration: const InputDecoration(labelText: 'Device model')),
              TextField(controller: key, maxLength: 120,
                decoration: const InputDecoration(labelText: 'Unique device identifier (not a password)')),
              DropdownButtonFormField<String>(value: department,
                decoration: const InputDecoration(labelText: 'Department'),
                items: const [
                  DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                  DropdownMenuItem(value: 'kitchen', child: Text('Kitchen')),
                  DropdownMenuItem(value: 'shisha', child: Text('Shisha')),
                  DropdownMenuItem(value: 'general', child: Text('General')),
                ],
                onChanged: saving ? null : (v) { if (v != null) update(() => department = v); }),
              if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ))),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: saving ? null : () async {
              if (name.text.trim().isEmpty || model.text.trim().isEmpty || key.text.trim().isEmpty) {
                update(() => error = 'Name, model, and unique identifier are required.');
                return;
              }
              update(() { saving = true; error = null; });
              try {
                await _db.rpc('gs_register_cafe_pos_device', params: {
                  'p_name': name.text.trim(),
                  'p_device_model': model.text.trim(),
                  'p_department': department,
                  'p_device_key': key.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('POS device registered. Refresh the device list.')));
              } catch (e) {
                if (ctx.mounted) update(() => error = 'Registration failed: $e');
              } finally { if (ctx.mounted) update(() => saving = false); }
            }, child: Text(saving ? 'Registering…' : 'Register')),
          ],
        ),
      ));
    } finally { name.dispose(); model.dispose(); key.dispose(); }
  }

  Future<void> _showDeviceRoutingSettings() async {
    List<Map<String, dynamic>> devices = [];
    List<Map<String, dynamic>> policies = [];
    String department = 'kitchen';
    String route = 'both';
    String? error;
    bool saving = false;
    Future<void> refresh(StateSetter update) async {
      try {
        final d = await _db.rpc('gs_list_cafe_pos_devices');
        final p = await _db.rpc('gs_list_cafe_print_routing_policy');
        update(() {
          devices = (d as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          policies = (p as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          error = null;
        });
      } catch (e) { update(() => error = '$e'); }
    }
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => AlertDialog(
        title: const Text('POS Devices & Print Routing'),
        content: SizedBox(width: 580, height: 460, child: ListView(children: [
          const Text('Online: SUNMI POS, traditional printer, or both. '
            'Offline policy: local printer only. This configures routing preferences; '
            'native SUNMI printing, local offline storage, and gateways are not yet implemented.'),
          const SizedBox(height: 12),
          if (error != null) SelectableText('Error: $error',
            style: const TextStyle(color: Colors.red)),
          DropdownButtonFormField<String>(value: department,
            decoration: const InputDecoration(labelText: 'Department'),
            items: const [
              DropdownMenuItem(value: 'kitchen', child: Text('Kitchen')),
              DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
              DropdownMenuItem(value: 'shisha', child: Text('Shisha')),
              DropdownMenuItem(value: 'general', child: Text('General')),
            ],
            onChanged: saving ? null : (v) { if (v != null) update(() {
              department = v;
              final found = policies.where((p) => p['department'] == v);
              route = found.isEmpty ? 'both' : found.first['online_route'].toString();
            }); },
          ),
          DropdownButtonFormField<String>(value: route,
            decoration: const InputDecoration(labelText: 'Online delivery mode'),
            items: const [
              DropdownMenuItem(value: 'pos', child: Text('SUNMI POS only')),
              DropdownMenuItem(value: 'printer', child: Text('Traditional printer only')),
              DropdownMenuItem(value: 'both', child: Text('Both POS and printer')),
            ],
            onChanged: saving ? null : (v) { if (v != null) update(() => route = v); },
          ),
          const ListTile(title: Text('Offline delivery: local printing only'),
            subtitle: Text('Requires a working local connection and an offline-capable app.')),
          const Divider(),
          Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(
            onPressed: saving ? null : () async {
              await _registerPosDevice();
              if (ctx.mounted) await refresh(update);
            },
            icon: const Icon(Icons.add), label: const Text('Register POS device'))),
          const Text('Registered POS devices', style: TextStyle(fontWeight: FontWeight.bold)),
          const Text('Status reflects authenticated device heartbeats, not printer hardware health.'),
          if (devices.isEmpty) const Text('No POS devices registered.'),
          for (final d in devices) ListTile(
            title: Text(d['name']?.toString() ?? 'POS device'),
            onTap: saving ? null : () async {
              final controller = TextEditingController();
              try {
                final employee = await showDialog<String>(context: ctx, builder: (dialogCtx) => AlertDialog(
                  title: const Text('Bind POS to authenticated employee'),
                  content: TextField(controller: controller,
                    decoration: const InputDecoration(labelText: 'Employee auth UUID',
                      helperText: 'Only this signed-in account may report device heartbeats.')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(dialogCtx, controller.text.trim()), child: const Text('Bind')),
                  ],
                ));
                if (employee == null || employee.isEmpty) return;
                update(() { saving = true; error = null; });
                await _db.rpc('gs_bind_cafe_pos_device_employee', params: {
                  'p_device_id': d['id'], 'p_employee_id': employee,
                });
                if (ctx.mounted) await refresh(update);
              } catch (e) { if (ctx.mounted) update(() => error = '$e'); }
              finally { controller.dispose(); if (ctx.mounted) update(() => saving = false); }
            },
            trailing: Switch(value: d['enabled'] == true, onChanged: saving ? null : (enabled) async {
              update(() { saving = true; error = null; });
              try {
                await _db.rpc('gs_set_cafe_pos_device_enabled', params: {
                  'p_device_id': d['id'], 'p_enabled': enabled,
                });
                if (ctx.mounted) await refresh(update);
              } catch (e) { if (ctx.mounted) update(() => error = '$e'); }
              finally { if (ctx.mounted) update(() => saving = false); }
            }),
            subtitle: Text('${d['department']} · ${d['device_model']} · '
              '${d['connection_status'] ?? 'Unknown'} · ${d['last_seen_at'] == null ? 'Never reported' : 'Last seen: ${d['last_seen_at']}'}'),
          ),
          OutlinedButton.icon(
            onPressed: saving ? null : () async {
              update(() { saving = true; error = null; });
              try {
                final result = await _db.rpc('gs_my_bound_cafe_pos_devices');
                final mine = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
                if (!ctx.mounted) return;
                if (mine.isEmpty) throw StateError('No enabled POS is assigned to your account. Ask a manager to bind one.');
                final choice = await showDialog<int>(context: ctx, builder: (dialogCtx) => SimpleDialog(
                  title: const Text('Select this Android POS terminal'),
                  children: [for (final device in mine) SimpleDialogOption(
                    onPressed: () => Navigator.pop(dialogCtx, (device['id'] as num).toInt()),
                    child: Text('${device['name']} · ${device['department']} · #${device['id']}'),
                  )],
                ));
                if (choice != null) {
                  await PosHeartbeatService().selectDevice(choice);
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Selected POS #$choice for foreground heartbeats.')));
                }
              } catch (e) { if (ctx.mounted) update(() => error = '$e'); }
              finally { if (ctx.mounted) update(() => saving = false); }
            }, icon: const Icon(Icons.devices),
            label: const Text('Select my Android POS device')),
          OutlinedButton.icon(
            onPressed: saving ? null : () async {
              update(() { saving = true; error = null; });
              try {
                final selected = await PosHeartbeatService().selectedDeviceId();
                if (selected == null) throw StateError('Select a bound device on this Android terminal first.');
                await _db.rpc('gs_cafe_pos_heartbeat_for_device', params: {'p_device_id': selected});
                if (ctx.mounted) await refresh(update);
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Heartbeat sent for POS device $selected.')));
              } catch (e) { if (ctx.mounted) update(() => error = '$e'); }
              finally { if (ctx.mounted) update(() => saving = false); }
            }, icon: const Icon(Icons.favorite_outline),
            label: const Text('Test selected POS heartbeat')),
          OutlinedButton.icon(
            onPressed: saving ? null : () async {
              update(() { saving = true; error = null; });
              try {
                final service = PosHeartbeatService();
                final enabled = await service.isEnabledForCurrentUser();
                await service.setEnabledForCurrentUser(!enabled);
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(!enabled
                    ? 'Automatic heartbeat enabled on this Android device while the management app is open.'
                    : 'Automatic heartbeat disabled on this device.')));
              } catch (e) { if (ctx.mounted) update(() => error = '$e'); }
              finally { if (ctx.mounted) update(() => saving = false); }
            }, icon: const Icon(Icons.sync),
            label: const Text('Toggle automatic Android POS heartbeat on this device')),
          const Text('Select a manager-bound device on Android first. Heartbeat proves account activity for that selection, not physical hardware identity or printer readiness.'),
          const Divider(),
          const Text('Saved department policies', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final p in policies) ListTile(
            title: Text(p['department']?.toString() ?? ''),
            subtitle: Text('Online: ${p['online_route']} · Offline: local printer'),
          ),
        ])),
        actions: [
          TextButton(onPressed: saving ? null : () => refresh(update),
            child: const Text('Refresh')),
          TextButton(onPressed: saving ? null : () => Navigator.pop(ctx),
            child: const Text('Close')),
          FilledButton(onPressed: saving ? null : () async {
            update(() { saving = true; error = null; });
            try {
              await _db.rpc('gs_set_cafe_print_routing_policy', params: {
                'p_department': department, 'p_online_route': route,
              });
              if (ctx.mounted) await refresh(update);
            } catch (e) { if (ctx.mounted) update(() => error = '$e'); }
            finally { if (ctx.mounted) update(() => saving = false); }
          }, child: Text(saving ? 'Saving…' : 'Save routing')),
        ],
      ),
    ));
  }

  Future<void> _showStationDispatchCenter() async {
    List<Map<String, dynamic>> tickets = [];
    List<Map<String, dynamic>> alerts = [];
    String? error;
    bool busy = false;
    bool loaded = false;
    final reasonController = TextEditingController();
    Future<void> refresh(StateSetter update) async {
      try {
        final results = await Future.wait([
          _db.rpc('gs_list_station_dispatch_tickets'),
          _db.rpc('gs_list_station_dispatch_alerts'),
        ]);
        update(() {
          tickets = (results[0] as List)
              .map((e) => Map<String, dynamic>.from(e as Map)).toList();
          alerts = (results[1] as List)
              .map((e) => Map<String, dynamic>.from(e as Map)).toList();
          error = null;
          loaded = true;
        });
      } catch (e) {
        update(() { error = '$e'; loaded = true; });
      }
    }
    if (!mounted) return;
    try {
      await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          if (!loaded && !busy) {
            // Initial fetch occurs after the dialog is mounted.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ctx.mounted) { update(() => loaded = true); refresh(update); }
            });
          }
          return AlertDialog(
            title: const Text('Preparation Station · Dispatch Center'),
            content: SizedBox(width: 720, height: 520, child: ListView(children: [
              const Text('Monitor routed tickets and printing acknowledgements. '
                  'A queued or received ticket is NOT proof of physical printing.'),
              if (error != null) Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SelectableText('Dispatch error: $error',
                    style: const TextStyle(color: Colors.red))),
              const SizedBox(height: 12),
              Text('Unresolved alerts: ${alerts.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              for (final a in alerts) ListTile(
                leading: const Icon(Icons.warning_amber_outlined, color: Colors.orange),
                title: Text('Ticket #${a['ticket_id']} · ${a['station_key']}'),
                subtitle: Text('Order #${a['order_id']} · ${a['status']} · '
                    'Attempts ${a['attempts']}\n${a['last_error'] ?? 'No acknowledgement received'}'),
                isThreeLine: true,
              ),
              const Divider(),
              const Text('Recent station tickets',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (tickets.isEmpty) const Text('No tickets returned. Refresh to check.'),
              for (final t in tickets) Card(child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Ticket #${t['ticket_id']} · Order #${t['order_id']} · ${t['station_key']}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Status: ${t['status']} · ${t['delivery_method']} · '
                      'Attempts: ${t['attempts']}'),
                  Text('Destination: ${t['destination_label'] ?? 'Unassigned'}'),
                  if (t['last_error'] != null) Text('Error: ${t['last_error']}'),
                  if (t['status'] == 'failed' || t['status'] == 'unknown')
                    Align(alignment: Alignment.centerRight, child: TextButton.icon(
                      onPressed: busy ? null : () async {
                        reasonController.clear();
                        final confirmed = await showDialog<bool>(context: ctx,
                          builder: (confirmCtx) => AlertDialog(
                            title: Text('Retry ticket #${t['ticket_id']}?'),
                            content: Column(mainAxisSize: MainAxisSize.min, children: [
                              const Text('Check the physical printer first. Retrying an '
                                  'uncertain ticket may produce a duplicate paper ticket.'),
                              TextField(controller: reasonController,
                                maxLength: 500,
                                decoration: const InputDecoration(labelText: 'Reason (at least 5 characters)')),
                            ]),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(confirmCtx, false),
                                  child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(confirmCtx, true),
                                  child: const Text('Authorize retry')),
                            ],
                          ));
                        if (confirmed != true || !ctx.mounted) return;
                        if (reasonController.text.trim().length < 5) {
                          update(() => error = 'A retry reason of at least 5 characters is required.');
                          return;
                        }
                        update(() { busy = true; error = null; });
                        try {
                          await _db.rpc('gs_retry_station_ticket', params: {
                            'p_ticket_id': t['ticket_id'],
                            'p_reason': reasonController.text.trim(),
                          });
                          if (ctx.mounted) await refresh(update);
                        } catch (e) {
                          if (ctx.mounted) update(() => error = '$e');
                        } finally {
                          if (ctx.mounted) update(() => busy = false);
                        }
                      }, icon: const Icon(Icons.replay),
                      label: const Text('Manager retry'))),
                ]),
              )),
            ])),
            actions: [
              TextButton(onPressed: busy ? null : () => refresh(update),
                  child: const Text('Refresh')),
              TextButton(onPressed: busy ? null : () => Navigator.pop(ctx),
                  child: const Text('Close')),
            ],
          );
        },
      ));
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _showPrinterCenter() async {
    List<Map<String,dynamic>> printers = [];
    List<Map<String,dynamic>> jobs = [];
    String? error;
    int? selectedPrinter;
    String kind = 'receipt';
    int copies = 1;
    bool submitting = false;
    Future<void> refresh(StateSetter update) async {
      try {
        final p = await _db.rpc('gs_list_cafe_printers');
        final j = await _db.rpc('gs_list_cafe_print_jobs');
        update(() {
          printers = (p as List).map((e) => Map<String,dynamic>.from(e as Map)).toList();
          jobs = (j as List).map((e) => Map<String,dynamic>.from(e as Map)).toList();
          if (!printers.any((p) => p['id'] == selectedPrinter)) selectedPrinter = null;
          error = null;
        });
      } catch (e) { update(() => error = '$e'); }
    }
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => AlertDialog(
        title: const Text('Printer Center · Print Queue'),
        content: SizedBox(width: 650, height: 490, child: ListView(children: [
          const Text('Queue a document for a registered printer. Printing requires '
            'a connected local gateway; queued does not mean physically printed.'),
          if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
            child: SelectableText('Printer error: $error',
              style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 12),
          const Text('Printer', style: TextStyle(fontWeight: FontWeight.bold)),
          if (printers.isEmpty) const Text('No enabled printers registered.'),
          for (final p in printers) RadioListTile<int>(
            value: (p['id'] as num).toInt(),
            groupValue: selectedPrinter,
            onChanged: submitting ? null : (v) => update(() => selectedPrinter = v),
            title: Text(p['name']?.toString() ?? 'Printer'),
            subtitle: Text('${p['location'] ?? ''} · ${p['connection_type'] ?? ''} · '
              '${p['connection_state'] ?? 'unknown'}'),
          ),
          DropdownButtonFormField<String>(
            value: kind,
            decoration: const InputDecoration(labelText: 'Document type'),
            items: const [
              DropdownMenuItem(value: 'receipt', child: Text('Customer receipt')),
              DropdownMenuItem(value: 'kitchen_ticket', child: Text('Kitchen ticket')),
              DropdownMenuItem(value: 'shisha_ticket', child: Text('Shisha ticket')),
              DropdownMenuItem(value: 'daily_report', child: Text('Daily report')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: submitting ? null : (v) { if (v != null) update(() => kind = v); },
          ),
          Row(children: [
            const Expanded(child: Text('Number of copies (1–20)')),
            IconButton(onPressed: submitting || copies <= 1 ? null :
              () => update(() => copies--), icon: const Icon(Icons.remove)),
            Text('$copies'),
            IconButton(onPressed: submitting || copies >= 20 ? null :
              () => update(() => copies++), icon: const Icon(Icons.add)),
          ]),
          const Text('This queues a document request only. Content rendering, '
            'printer drivers, and secure gateway execution are not yet implemented.'),
          const Divider(),
          const Text('Recent jobs', style: TextStyle(fontWeight: FontWeight.bold)),
          if (jobs.isEmpty) const Text('No print jobs yet.'),
          for (final j in jobs) ListTile(
            title: Text('${j['document_kind']} · ${j['copies']} copies'),
            subtitle: Text('${j['printer_name']} · ${j['created_at']}'),
            trailing: Text('${j['status']}'),
          ),
        ])),
        actions: [
          TextButton(onPressed: submitting ? null : () => refresh(update),
            child: const Text('Refresh')),
          TextButton(onPressed: submitting ? null : () => Navigator.pop(ctx),
            child: const Text('Close')),
          FilledButton(onPressed: submitting || selectedPrinter == null ? null : () async {
            update(() { submitting = true; error = null; });
            try {
              await _db.rpc('gs_submit_cafe_print_job', params: {
                'p_printer_id': selectedPrinter,
                'p_document_kind': kind,
                'p_copies': copies,
              });
              if (!ctx.mounted) return;
              await refresh(update);
            } catch (e) { if (ctx.mounted) update(() => error = '$e'); }
            finally { if (ctx.mounted) update(() => submitting = false); }
          }, child: Text(submitting ? 'Queuing…' : 'Queue print job')),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final occupied = _tables.where((t) => t['occupied'] == true).length;
    final cleaning = _tables.where((t) => t['cleaning_needed'] == true).length;
    final floorNames = _tables.map(_floorName).toSet().toList()..sort();
    final shown = _tables.where((t) {
      final number = (t['table_number'] as num).toInt();
      final visit = _visits[number];
      final match = switch (_filter) {
        'Available' => t['occupied'] != true && t['cleaning_needed'] != true && visit == null,
        'Occupied' => t['occupied'] == true,
        'Cleaning' => t['cleaning_needed'] == true || visit?['status'] == 'cleaning',
        'Tourism' => t['tourism_mode'] == true,
        _ => true,
      };
      final floorMatch = _floorFilter == 'All floors' ||
        _floorName(t) == _floorFilter;
      final query = _search.trim().toLowerCase();
      final searchMatch = number.toString().contains(query) ||
        _floorName(t).toLowerCase().contains(query);
      return match && floorMatch && searchMatch;
    }).toList();
    return LayoutBuilder(builder: (context, bounds) {
      final columns = bounds.maxWidth >= 1100 ? 4 : bounds.maxWidth >= 720 ? 3 :
        bounds.maxWidth >= 430 ? 2 : 1;
      return ListView(padding: const EdgeInsets.all(16), children: [
        ProfessionalSectionSummary(title: 'Tables overview', subtitle: 'Live, permission-scoped seating and reservations', icon: Icons.table_restaurant_outlined, items: ['${_tables.length} total', '$occupied occupied', '$cleaning cleaning']),
        Row(children: [Expanded(child: Text('Live tables',
          style: Theme.of(context).textTheme.headlineSmall)),
          IconButton(onPressed: _loading || _busyTable != null ? null : _createTable,
            icon: const Icon(Icons.add_circle_outline), tooltip: 'Create table and set its floor and chairs'),
          IconButton(onPressed: _showAdminBillDiscount,
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Admin: bill discount approval draft'),
          IconButton(onPressed: _showAdminDiscountSettings,
            icon: const Icon(Icons.percent_outlined),
            tooltip: 'Admin: configure Discount Mode'),
          IconButton(onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
          IconButton(onPressed: _loading ? null : () async {
            final created = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const StaffSpecificReservationScreen()));
            if (created == true && mounted) await _reload();
          }, icon: const Icon(Icons.event_available),
            tooltip: 'Create specific-table reservation'),
          IconButton(onPressed: _loading ? null : () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StaffReservationManagementScreen())),
            icon: const Icon(Icons.manage_accounts), tooltip: 'Manage specific-table reservations'),
          IconButton(onPressed: _loading ? null : () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StaffEventRequestScreen())),
            icon: const Icon(Icons.celebration_outlined), tooltip: 'Request café event'),
          IconButton(onPressed: _loading ? null : () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AdminEventReservationsScreen())),
            icon: const Icon(Icons.event_note), tooltip: 'Admin event approvals'),
          IconButton(onPressed: _loading ? null : _checkInReservation,
            icon: const Icon(Icons.event_available), tooltip: 'Reservation check-in'),
          IconButton(onPressed: _loading ? null : _cancelReservation,
            icon: const Icon(Icons.event_busy), tooltip: 'Cancel reservation'),
          IconButton(onPressed: _loading || _busyTable != null ? null : _reviewGuestMoves,
            icon: const Icon(Icons.pending_actions), tooltip: 'Review guest moves'),
          IconButton(onPressed: _loading || _busyTable != null ? null : _previewBillTransfer,
            icon: const Icon(Icons.rule_folder_outlined),
            tooltip: 'Review joining tables / unpaid bill transfer'),
          IconButton(onPressed: _loading || _busyTable != null ? null : _requestBillTransfer,
            icon: const Icon(Icons.post_add_outlined),
            tooltip: 'Request selected unpaid bill transfer'),
          IconButton(onPressed: _loading || _busyTable != null ? null : _reviewBillTransferRequests,
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: 'Review pending bill transfer requests'),
          IconButton(onPressed: _showDeviceRoutingSettings,
            icon: const Icon(Icons.devices_other_outlined),
            tooltip: 'POS devices and online/offline print routing'),
          IconButton(onPressed: _showStationDispatchCenter,
            icon: const Icon(Icons.local_print_shop_outlined),
            tooltip: 'Preparation station dispatch · failures and retries'),
          IconButton(onPressed: _showPrinterCenter,
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Printer Center · connection and print queue'),
          IconButton(onPressed: _showAvailableJobs,
            icon: const Icon(Icons.assignment_ind_outlined),
            tooltip: 'Available unassigned jobs'),
          IconButton(onPressed: _manageWorkerCapabilities,
            icon: const Icon(Icons.admin_panel_settings_outlined),
            tooltip: 'Manager: employee job permissions'),
          IconButton(onPressed: _manageTableWorkloadLimits,
            icon: const Icon(Icons.speed_outlined),
            tooltip: 'Manager · Job workload limits'),
          IconButton(onPressed: _reassignTableJob,
            icon: const Icon(Icons.swap_horiz_outlined),
            tooltip: 'Manager: reassign a table service job'),
          IconButton(onPressed: _showManagerJobOverview,
            icon: const Icon(Icons.supervisor_account_outlined),
            tooltip: 'Manager: all active table jobs'),
          IconButton(onPressed: _showServiceDurationReport,
            icon: const Icon(Icons.timer_outlined),
            tooltip: 'Manager: service response and completion durations'),
          IconButton(onPressed: _showEmployeePerformance,
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Manager: employee response and service performance'),
          IconButton(onPressed: _showMyJobs,
            icon: const Icon(Icons.assignment_turned_in_outlined),
            tooltip: 'My assigned service jobs'),
          IconButton(onPressed: _showTableWorkNotifications,
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Table work notifications'),
          IconButton(onPressed: _cashierReservation,
            icon: const Icon(Icons.event_available_outlined),
            tooltip: 'Cashier: record customer reservation request')]),
        const SizedBox(height: 8),
        if (_error != null) SelectableText(_error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (_loading) const LinearProgressIndicator(),
        Wrap(spacing: 8, runSpacing: 6, children: [
          Chip(label: Text('Total ${_tables.length}')),
          Chip(label: Text('Occupied $occupied')),
          Chip(label: Text('QR menu active: ${_qrActive.length} tables')),
          Chip(label: Text('Cleaning $cleaning')),
          Chip(label: Text('Available ${_tables.length - occupied - cleaning} (estimated)')),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [for (final f in
          ['All','Available','Occupied','Cleaning','Tourism'])
          ChoiceChip(label: Text(f), selected: _filter == f,
            onSelected: (_) => setState(() => _filter = f))]),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final floor in ['All floors', ...floorNames])
            ChoiceChip(
              label: Text(floor),
              selected: _floorFilter == floor,
              onSelected: (_) => setState(() => _floorFilter = floor),
            ),
        ]),
        TextField(decoration: const InputDecoration(
          labelText: 'Search table number or floor', prefixIcon: Icon(Icons.search)),
          onChanged: (value) => setState(() => _search = value)),
        const SizedBox(height: 12),
        if (!_loading && _tables.isEmpty) const Text(
          'No configured tables found. Management must configure real table numbers.'),
        GridView.builder(shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: shown.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns, crossAxisSpacing: 10, mainAxisSpacing: 10,
            mainAxisExtent: 320),
          itemBuilder: (context, index) {
            final t = shown[index];
            final number = (t['table_number'] as num).toInt();
            final visit = _visits[number];
            final money = _tableMoney[number];
            final customer = (visit?['customer_name'] ??
              visit?['guest_name'] ?? visit?['name'])?.toString().trim();
            final amount = money?['final_amount_iqd'] ??
              money?['amount_due_iqd'] ?? money?['outstanding_iqd'] ??
              money?['total_iqd'] ?? money?['total'];
            final busy = t['occupied'] == true;
            final needsCleaning = t['cleaning_needed'] == true;
            final blocked = busy || needsCleaning || visit != null;
            final status = needsCleaning ? 'Cleaning required' :
              visit?['status'] == 'cleaning' ? 'Cleaning in progress' :
              busy ? 'Occupied' : visit != null ? 'Open visit' : 'Available';
            return Card(child: Padding(padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('Table $number',
                    style: Theme.of(context).textTheme.titleMedium)),
                  IconButton(
                    tooltip: 'Set floor name',
                    onPressed: _loading || _busyTable != null
                      ? null : () => _setTableFloor(t),
                    icon: const Icon(Icons.edit_location_alt_outlined)),
                  IconButton(
                    tooltip: 'Items, delivery status and cash-only balance',
                    onPressed: () => _showTableItemsAndMoney(t),
                    icon: const Icon(Icons.receipt_long_outlined)),
                ]),
                const SizedBox(height: 5),
                Text('Floor: ${_floorName(t)}', maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(status),
                if (customer != null && customer.isNotEmpty)
                  Text('Customer: $customer', maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (amount is num)
                  Text('Recorded amount: ${amount.toStringAsFixed(0)} IQD',
                    style: const TextStyle(fontWeight: FontWeight.bold))
                else if (busy)
                  const Text('Price unavailable — open Items & money',
                    style: TextStyle(fontSize: 12)),
                if (visit?['arrival_at'] != null || visit?['started_at'] != null)
                  Text('Arrival: ${visit?['arrival_at'] ?? visit?['started_at']}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (visit?['expected_departure_at'] != null)
                  Text('Expected departure: ${visit?['expected_departure_at']}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('Capacity ${t['capacity']} · Guests ${t['guests']}'),
                if ((_qrActive[number] ?? 0) > 0)
                  Chip(avatar: const Icon(Icons.qr_code_scanner, size: 18),
                    label: Text('Menu active · ${_qrActive[number]} device(s)')),
                Text(t['tourism_mode'] == true ? 'Tourism Mode' : 'Normal Mode'),
                if (visit != null) Text('Visit #${visit['visit_id']}',
                  style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                if (_busyTable == number) const LinearProgressIndicator(),
                TextButton.icon(
                  onPressed: _loading || _busyTable != null
                    ? null : () => _adjustChairs(t),
                  icon: const Icon(Icons.chair_outlined),
                  label: const Text('Add / remove chairs'),
                ),
                TextButton.icon(
                  onPressed: _loading || _busyTable != null
                    ? null : () => _manageTableQr(t),
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Table QR'),
                ),
                if (visit?['status'] == 'active' && busy)
                  TextButton.icon(
                    onPressed: _loading || _busyTable != null ? null : () => _requestGuestMove(t),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Request guest move'),
                  ),
                SizedBox(width: double.infinity, child: FilledButton.icon(
                  onPressed: _loading || _busyTable != null || blocked ? null : () => _seat(t),
                  icon: Icon(blocked ? Icons.lock_outline : Icons.event_seat),
                  label: Text(blocked ? 'Managed checkout required' : 'Seat guests'),
                )),
              ])));
          }),
        const SizedBox(height: 12),
        const Text('Safety: occupied tables cannot be released or transferred from this screen. '
          'Use authorized visit-aware checkout and transfer workflows; financial records '
          'and existing order prices must be preserved.'),
      ]);
    });
  }
}
