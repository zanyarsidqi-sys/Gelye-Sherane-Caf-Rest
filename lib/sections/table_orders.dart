import '../shared/professional_mobile_widgets.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/section_shell.dart';
import '../shared/staff_order_guest_editor.dart';
import '../shared/table_replacement_recovery.dart';
import '../shared/order_preview_workspace.dart';
import '../shared/counter_orders_workspace.dart';
import '../shared/public_menu_screen.dart';
import '../shared/staff_product_recommendations.dart';
import '../shared/staff_customer_calls_screen.dart';
import '../shared/staff_bill_reconciliation_screen.dart';
import '../shared/wrong_order_correction_workspace.dart';
import '../shared/table_orders_replacement_delivery_progress.dart';
import 'tables.dart';
import 'payments_management.dart';
import 'kitchen.dart';
import 'menu.dart';
import 'customers.dart';

class TableOrdersScreen extends StatelessWidget {
  const TableOrdersScreen({super.key});
  @override
  Widget build(BuildContext context) => const SectionShell(
    title: 'Table Orders',
    description: 'Create and manage table orders',
    sectionId: 'table_orders',
    authorizedContent: const _TableOrdersTabs(),
  );
}

/// Staff-only order management. Customer ordering uses the independent public
/// menu/ordering screens; this view never grants a customer staff privileges.
class _TableOrdersTabs extends StatelessWidget {
  static const _tabNames = <String>[
    'Table orders', 'Guest & Notes', 'Takeaway & Delivery',
    'Employee Jobs', 'Order Board', 'Recommendations',
    'Customer Calls', 'Bill Reconciliation',
    'Wrong Orders & Waste', 'Replacement Delivery',
  ];
  const _TableOrdersTabs();
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 10,
    child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 0), child: ProfessionalMobileWidgets.heading(context, title: 'Table Orders', subtitle: 'Tables  •  Guests  •  Kitchen  •  Payments', icon: Icons.table_restaurant)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ProfessionalMobileWidgets.workspaceIntro(context,
          eyebrow: 'Staff workspace',
          title: 'Orders and table service',
          description: 'Choose a workspace below. Actions and order records remain subject to your existing staff permissions.',
          icon: Icons.receipt_long_outlined),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ProfessionalMobileWidgets.operationalNotice(context, message: 'Workspace actions use existing staff authorization and order checks.', icon: Icons.lock_outline),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ProfessionalMobileWidgets.workspaceGuide(context),
      ),
      Builder(builder: (context) {
        final tabs = DefaultTabController.of(context);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ProfessionalMobileWidgets.mobileActions(context, actions: [
            ('Orders', Icons.receipt_long, () => tabs.animateTo(0)),
            ('Order board', Icons.view_kanban_outlined, () => tabs.animateTo(4)),
            ('Bills', Icons.receipt_outlined, () => tabs.animateTo(7)),
            ('Standing Cash', Icons.payments_outlined, () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PaymentsManagementScreen(initialFocus: 'standing')))),
          ]),
        );
      }),

      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Employee & management screen',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Staff order entry, review and fulfillment'),
                  ],
                ),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _SectionLink(label: 'Tables', icon: Icons.table_restaurant,
                    builder: (_) => const TablesScreen()),
                  _SectionLink(label: 'Kitchen', icon: Icons.soup_kitchen,
                    builder: (_) => const KitchenScreen()),
                  _SectionLink(label: 'Menu', icon: Icons.restaurant_menu,
                    builder: (_) => const MenuScreen()),
                  _SectionLink(label: 'Customers', icon: Icons.people_outline,
                    builder: (_) => const CustomersScreen()),
                ]),
                OutlinedButton.icon(
                  icon: const Icon(Icons.phone_iphone),
                  label: const Text('Preview customer menu'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PublicMenuScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      Builder(builder: (context) {
        final controller = DefaultTabController.of(context);
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) => LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth >= 600) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              child: DropdownButtonFormField<int>(
                key: ValueKey(controller.index),
                initialValue: controller.index,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Choose Table Orders workspace',
                  prefixIcon: const Icon(Icons.phone_iphone, color: Color(0xFFD9A744)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  isDense: true,
                ),
                items: [for (var i = 0; i < _tabNames.length; i++)
                  DropdownMenuItem(value: i, child: Text(_tabNames[i], overflow: TextOverflow.ellipsis))],
                onChanged: (index) { if (index != null) controller.animateTo(index); },
              ),
            );
          }),
        );
      }),
      const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, labelColor: ProfessionalMobileWidgets.navy, unselectedLabelColor: Color(0xFF647587), labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 12), indicatorColor: ProfessionalMobileWidgets.gold, indicatorWeight: 4, dividerColor: Color(0xFFE1E7EC), tabs: [
        Tab(text: 'Table orders'),
        Tab(text: 'Guest & Notes'),
        Tab(text: 'Takeaway & Delivery'),
        Tab(text: 'Employee Jobs'),
        Tab(text: 'Order Board'),
        Tab(text: 'Recommendations'),
        Tab(text: 'Customer Calls'),
        Tab(text: 'Bill Reconciliation'),
        Tab(text: 'Wrong Orders & Waste'),
        Tab(text: 'Replacement Delivery'),
      ]),
      const Expanded(child: TabBarView(children: [
        Column(children: [
          const _TableOrderCards(),
          const Expanded(child: OrderPreviewWorkspace(kind: 'table')),
        ]),
        StaffOrderGuestEditor(),
        CounterOrdersWorkspace(),
        _EmployeeJobList(),
        _TableOrderBoard(),
        StaffProductRecommendations(),
        StaffCustomerCallsScreen(),
        StaffBillReconciliationScreen(),
        WrongOrderCorrectionWorkspace(),
        TableOrdersReplacementDeliveryProgress(),
      ])),
    ]),
  );
}

/// Cross-section navigation retains each destination's existing SectionShell
/// authorization. This does not grant access to a restricted section.
class _SectionLink extends StatelessWidget {
  const _SectionLink({required this.label, required this.icon, required this.builder});
  final String label;
  final IconData icon;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: Icon(icon, size: 18),
    label: Text(label),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: builder),
    ),
  );
}

/// Real, permission-scoped service job queue. This is not the kitchen order
/// fulfillment status board; it uses the existing guarded table-job RPCs.
class _EmployeeJobList extends StatefulWidget {
  const _EmployeeJobList();
  @override
  State<_EmployeeJobList> createState() => _EmployeeJobListState();
}

class _EmployeeJobListState extends State<_EmployeeJobList> {
  bool loading = false;
  bool _refreshQueued = false;
  static const int _boardPageSize = 250;
  static const int _boardMaximumItems = 5000;
  bool _boardComplete = false;
  bool busy = false;
  String? error;
  String filter = 'All';
  List<Map<String, dynamic>> jobs = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (loading || busy) { _refreshQueued = true; return; }
    setState(() { loading = true; error = null; jobs = []; });
    try {
      final client = Supabase.instance.client;
      // Manager RPC requires tables.can_edit. If unavailable, fall back to
      // the employee's own jobs. Neither call exposes other tables publicly.
      dynamic rows;
      try {
        rows = await client.rpc('gs_manager_table_job_overview');
      } catch (_) {
        rows = await client.rpc('gs_list_my_table_jobs');
      }
      if (!mounted) return;
      setState(() {
        jobs = (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (e) {
      if (mounted) setState(() { jobs = []; error = 'Unable to load authorized jobs: Please retry or contact a manager'; });
    } finally {
      if (mounted) {
        setState(() { loading = false; });
        if (_refreshQueued) {
          _refreshQueued = false;
          await _refresh();
        }
      }
    }
  }

  Future<void> _act(Map<String, dynamic> job, String action) async {
    if (busy || loading || error != null || job['job_id'] == null) return;
    setState(() => busy = true);
    try {
      await Supabase.instance.client.rpc('gs_update_my_table_job', params: {
        'p_job_id': job['job_id'], 'p_action': action,
      });
      // Do not refresh while a mutation is active: it could clear the
      // authorized job list before the backend has committed the change.
      _refreshQueued = true;
    } catch (e) {
      _refreshQueued = true; // Reconcile status even when the RPC fails.
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Job action rejected: Please retry or contact a manager')),
      );
    } finally {
      if (mounted) {
        setState(() => busy = false);
        if (_refreshQueued) {
          _refreshQueued = false;
          await _refresh();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = jobs.where((j) => filter == 'All' || j['status'] == filter).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Text('Live table service jobs', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final value in ['All', 'unassigned', 'assigned', 'in_progress'])
            ChoiceChip(label: Text(value.replaceAll('_', ' ')), selected: filter == value,
              onSelected: (_) => setState(() => filter = value)),
          IconButton(onPressed: loading || busy ? null : _refresh, icon: const Icon(Icons.refresh),
            tooltip: 'Refresh jobs'),
        ]),
      ),
      if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!,
        style: TextStyle(color: Theme.of(context).colorScheme.error))),
      if (loading) ...[
        const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Text('Loading authorized service jobs…',
            style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
      Expanded(child: visible.isEmpty
        ? Center(child: Text(error != null
            ? 'Authorized jobs are unavailable. Retry to reload.'
            : loading ? 'Loading authorized jobs…' : 'No matching authorized jobs. Refresh to check again.'))
        : ListView.builder(itemCount: visible.length, itemBuilder: (context, index) {
            final j = visible[index];
            final status = (j['status'] ?? '').toString();
            final kind = (j['kind'] ?? 'Service').toString().replaceAll('_', ' ');
            final isMine = j['assigned_to'] == null ||
              j['assigned_to'].toString() == Supabase.instance.client.auth.currentUser?.id;
            return Card(child: ListTile(
              title: Text("Table ${j['table_number'] ?? '?'} • $kind"),
              subtitle: Text("${j['details'] ?? ''}\nStatus: $status • Priority: ${j['priority'] ?? 'normal'}"
                "${j['employee_name'] == null ? '' : ' • ${j['employee_name']}'}"),
              isThreeLine: true,
              trailing: !loading && error == null && isMine && (status == 'assigned' || status == 'in_progress')
                ? OutlinedButton(onPressed: busy ? null : () => _act(j,
                    status == 'assigned' ? 'start' : 'complete'),
                    child: Text(status == 'assigned' ? 'Start' : 'Complete'))
                : null,
            ));
          })),
      const Padding(padding: EdgeInsets.all(8), child: Text(
        'Service-job status is separate from kitchen preparation and delivery. '
        'Delivery confirmation must use the verified item-delivery workflow.',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 12))),
    ]);
  }
}

/// Authorized fulfillment board. Status is per ORDER ITEM, never a guessed
/// aggregate order status. Backend RPC enforces transition permissions.
class _TableOrderBoard extends StatefulWidget {
  const _TableOrderBoard();
  @override
  State<_TableOrderBoard> createState() => _TableOrderBoardState();
}

class _TableOrderBoardState extends State<_TableOrderBoard> with WidgetsBindingObserver {
  final stages = const <String, String>{
    'not_accepted': 'Pending', 'accepted': 'New',
    'preparing': 'Preparing', 'prepared': 'Prepared',
    'picked_up': 'Delivery', 'delivered': 'Delivered',
  };
  List<Map<String, dynamic>> items = [];
  String selected = 'All';
  String searchQuery = '';
  String sortMode = 'oldest';
  String selectedTable = 'All';
  bool showWaitingOnly = false;
  int waitingThresholdMinutes = 30;
  DateTime boardLoadedAt = DateTime.now().toUtc();
  final TextEditingController _searchController = TextEditingController();
  String? error;
  bool loading = false;
  bool _refreshQueued = false;
  static const int _boardPageSize = 250;
  static const int _boardMaximumItems = 5000;
  bool _boardComplete = false;
  int _loadedPageCount = 0;
  int _loadedRowCount = 0;
  bool _editingInstructions = false;
  Map<String, dynamic>? _pendingReplacement;
  bool _checkingReplacement = false;

  // Only the latest load may update the UI. Lifecycle resumes and account
  // changes can overlap with an earlier asynchronous SharedPreferences read.
  int _recoveryLoadVersion = 0;

  Future<void> _loadPendingReplacement() async {
    final version = ++_recoveryLoadVersion;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _pendingReplacement = null);
      return;
    }
    try {
      final pending = await TableReplacementRecovery.load(uid);
      if (!mounted || version != _recoveryLoadVersion ||
          Supabase.instance.client.auth.currentUser?.id != uid) return;
      // Do not overwrite a newer, in-flight replacement with an older read.
      if (_editingInstructions && _pendingReplacement != null) return;
      setState(() => _pendingReplacement = pending);
    } catch (e) {
      if (mounted && version == _recoveryLoadVersion &&
          Supabase.instance.client.auth.currentUser?.id == uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Replacement recovery record needs review: Please retry or contact a manager')));
      }
    }
  }

  Future<void> _checkPendingReplacement() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final pending = _pendingReplacement;
    if (uid == null || pending == null || _checkingReplacement) return;
    setState(() => _checkingReplacement = true);
    try {
      if (Supabase.instance.client.auth.currentUser?.id != uid) {
        throw StateError('Employee session changed; reopen Table Orders');
      }
      final receipt = await Supabase.instance.client.rpc(
        'gs_table_replacement_request_status',
        params: {'p_request_id': pending['request_id']});
      // Do not clear a saved pointer when the account changes mid-request.
      if (Supabase.instance.client.auth.currentUser?.id != uid) {
        throw StateError('Employee session changed during recovery');
      }
      final expected = pending['expected_difference_iqd'];
      if (receipt is Map && receipt['status'] == 'committed' &&
          receipt['result'] is Map &&
          _validId(receipt['result']['order_item_id']) == pending['order_item_id'] &&
          _validId(receipt['result']['product_id']) == pending['product_id'] &&
          receipt['result']['difference_iqd'] == expected) {
        await TableReplacementRecovery.clear(uid, pending['request_id'] as String);
        // Local persistence is asynchronous. Another employee may sign in
        // while it completes; never update their recovery UI or board.
        if (!mounted || Supabase.instance.client.auth.currentUser?.id != uid) return;
        if (_pendingReplacement?['request_id'] != pending['request_id']) return;
        setState(() => _pendingReplacement = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Replacement confirmed by durable server receipt.')));
        await refresh();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No matching committed receipt yet. Do not retry; contact a manager to review the order and kitchen history.'),
          duration: Duration(seconds: 9)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recovery lookup unavailable: Please retry or contact a manager')));
    } finally {
      if (mounted) setState(() => _checkingReplacement = false);
    }
  }

  // Cross-device history is authoritative only for committed receipts. It
  // cannot reveal a request that is still running or failed before commit.
  Future<void> _showReplacementReceiptHistory() async {
    final initiatingUser = Supabase.instance.client.auth.currentUser?.id;
    if (initiatingUser == null) return;
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_table_replacement_receipt_history', params: {'p_limit': 20});
      if (result is! List) throw StateError('Invalid receipt history response');
      if (!mounted || Supabase.instance.client.auth.currentUser?.id != initiatingUser) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('My completed replacements'),
        content: SizedBox(width: 460, child: ListView(
          shrinkWrap: true,
          children: [
            const Text('Committed receipts from any device using your employee account. An absent receipt does not prove an outstanding request is safe to repeat.'),
            const SizedBox(height: 12),
            if (result.isEmpty) const Text('No completed receipts found.'),
            for (final entry in result)
              if (entry is Map) ListTile(
                dense: true,
                title: Text('Order item ${entry['order_item_id']} → product ${entry['product_id']}'),
                subtitle: Text('Request: ${entry['request_id']}\nCommitted: ${entry['committed_at']}'),
                trailing: Text('${entry['difference_iqd']} IQD'),
                onTap: () {
                  final id = entry['request_id']?.toString();
                  if (id == null || id.isEmpty) return;
                  Navigator.pop(ctx);
                  _lookupReplacementRequestId(initialRequestId: id);
                },
              ),
          ],
        )),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not load replacement receipts: Please retry or contact a manager')));
    }
  }

  // Manual lookup supports recovery on a different device when the employee
  // retained the original request ID. It never replays the mutation.
  Future<void> _lookupReplacementRequestId({String? initialRequestId}) async {
    final initiatingUser = Supabase.instance.client.auth.currentUser?.id;
    if (initiatingUser == null) return;
    final controller = TextEditingController(text: initialRequestId ?? '');
    try {
      final requestId = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Find replacement by request ID'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Use the original transaction ID. This checks your server receipt without repeating the replacement.'),
          const SizedBox(height: 12),
          TextField(controller: controller, autocorrect: false,
            decoration: const InputDecoration(labelText: 'Request UUID')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Check')),
        ],
      ));
      if (requestId == null || !mounted ||
          Supabase.instance.client.auth.currentUser?.id != initiatingUser) return;
      final validUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      if (!validUuid.hasMatch(requestId)) {
        throw const FormatException('Enter a valid replacement request UUID');
      }
      final response = await Supabase.instance.client.rpc(
        'gs_table_replacement_kitchen_receipt_status', params: {'p_request_id': requestId});
      if (response is! Map || response['status'] is! String) {
        throw StateError('Invalid recovery status response');
      }
      if (!mounted || Supabase.instance.client.auth.currentUser?.id != initiatingUser) return;
      final committed = response['status'] == 'committed' && response['result'] is Map;
      final details = committed ? response['result'] as Map : null;
      // A manual/cross-device lookup can also resolve this device's pending
      // recovery pointer, but only when the exact request and financial
      // identity match. A different employee receipt must never clear it.
      final pending = _pendingReplacement;
      final actorId = initiatingUser;
      final resolvesPending = committed && pending != null && actorId != null &&
          Supabase.instance.client.auth.currentUser?.id == actorId &&
          pending['request_id'] == requestId &&
          _validId(details!['order_item_id']) == pending['order_item_id'] &&
          _validId(details['product_id']) == pending['product_id'] &&
          details['difference_iqd'] is int &&
          details['difference_iqd'] == pending['expected_difference_iqd'];
      if (resolvesPending) {
        if (Supabase.instance.client.auth.currentUser?.id != initiatingUser) return;
        await TableReplacementRecovery.clear(actorId, requestId);
        if (!mounted || Supabase.instance.client.auth.currentUser?.id != initiatingUser) return;
        setState(() => _pendingReplacement = null);
        await refresh();
        if (!mounted) return;
      }
      if (Supabase.instance.client.auth.currentUser?.id != initiatingUser) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text(committed ? 'Committed replacement receipt' : 'No confirmed receipt'),
        content: SelectableText(committed
          ? 'Request: $requestId\nOrder item: ${details!['order_item_id']}\nProduct: ${details['product_id']}\nDifference: ${details['difference_iqd']} IQD\nCommitted: ${response['committed_at']}\nRevision matches: ${response['revision_matches_receipt']}\nKitchen dispatch recorded: ${response['kitchen_dispatch_recorded']}\nKitchen receipt status: ${response['kitchen_receipt_state']}\nKitchen acknowledged: ${response['kitchen_acknowledged']}\nDispatches checked: ${response['kitchen_receipt_dispatch_count']}\nConsistent: ${response['kitchen_receipt_consistent_count']}\nPending: ${response['kitchen_receipt_waiting_count']}\nProblems: ${response['kitchen_receipt_problem_count']}\nDuplicate audits: ${response['kitchen_receipt_duplicate_audit_count']}\nKitchen action: ${response['kitchen_receipt_guidance']}\nCurrent item matches: ${response['current_item_matches_receipt']}\nPayment records present: ${response['payment_records_present']}\nReview: ${response['review_state']}\nAction: ${response['staff_guidance']}\nKitchen acknowledgment records do not prove preparation. Financial ledger accuracy remains unverified.'
          : 'No committed receipt was found for this request and employee. This does not prove that the transaction failed. Do not repeat the replacement without reviewing the order and kitchen history.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Replacement receipt lookup: Please retry or contact a manager')));
    } finally {
      controller.dispose();
    }
  }

  // A late response from a prior request must never repopulate an invalidated
  // board after a newer refresh or widget disposal.
  int _boardRequestVersion = 0;

  bool _isCurrentBoardItem(int id, String expectedStatus) {
    if (loading || error != null) return false;
    return items.any((row) => _validId(row['order_item_id']) == id &&
        row['status'] == expectedStatus);
  }
  // A staff member must not act on an old board snapshot. This is a client
  // safety guard, not a replacement for the server's optimistic concurrency.
  static const Duration _maxActionSnapshotAge = Duration(minutes: 2);
  bool get _boardSnapshotFresh =>
      DateTime.now().toUtc().difference(boardLoadedAt) >= Duration.zero &&
      DateTime.now().toUtc().difference(boardLoadedAt) <= _maxActionSnapshotAge;

  Future<void> _requestFreshBoard() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Order data is older than 2 minutes. Refreshing before any changes.'),
    ));
    await refresh();
  }

  final Set<int> updating = {};

  // Never treat a floating-point, negative, or malformed identifier as a
  // database ID. History and dispatch RPCs must receive verified IDs.
  // Quantities must be positive whole units. Reject malformed records rather
  // than permitting staff to fulfill or hand off an ambiguous amount.
  int? _validQuantity(dynamic value) {
    if (value is! int || value <= 0 || value > 1000000) return null;
    return value;
  }

  int? _validId(dynamic value) {
    if (value is! num || !value.isFinite || value <= 0 ||
        value != value.roundToDouble()) return null;
    return value.toInt();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    _loadPendingReplacement();
  }

  // On returning from background, discard any old permission-scoped board
  // rather than allowing actions against an obsolete visit or kitchen state.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // A concurrent edit or transition queues the refresh safely.
      refresh();
      // Re-read the account-scoped recovery pointer after app resume.
      _loadPendingReplacement();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _boardRequestVersion++;
    _recoveryLoadVersion++;
    _searchController.dispose();
    super.dispose();
  }

  // Search only the permission-scoped records returned by the staff RPC.
  // Never fetch unrestricted records or send free-text filters to the server.
  bool _matchesSearch(Map<String, dynamic> item) {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    final searchable = [
      item['table_number'], item['product_name'], item['order_id'],
      item['order_item_id'], item['status'],
    ].where((value) => value != null).map((value) => value.toString().toLowerCase()).join(' ');
    return query.split(RegExp(r'\s+')).every(searchable.contains);
  }

  Future<void> refresh() async {
    if (loading || updating.isNotEmpty || _editingInstructions) { _refreshQueued = true; return; }
    final requestVersion = ++_boardRequestVersion;
    setState(() { loading = true; error = null; items = []; _boardComplete = false; _loadedPageCount = 0; _loadedRowCount = 0; });
    try {
      final rows = <Map<String, dynamic>>[];
      // Fetch all available pages. Never silently treat a truncated queue as
      // complete or permit actions against a partially loaded board.
      bool complete = false;
      DateTime? previousCreatedAt;
      int? previousId;
      for (int offset = 0; offset <= _boardMaximumItems; offset += _boardPageSize) {
        final result = await Supabase.instance.client.rpc(
          'gs_staff_table_order_board_page',
          params: {'p_offset': offset, 'p_limit': _boardPageSize});
        if (!mounted || requestVersion != _boardRequestVersion) return;
        if (result is! List) throw const FormatException('Unexpected order board page');
        // Offset pagination can shift when another employee inserts an order
        // during loading. Enforce the server's descending (created_at, id)
        // ordering across *all* pages; fail closed on overlaps or reversals.
        final page = result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        for (final row in page) {
          final rawTime = row['created_at'];
          final id = _validId(row['order_item_id']);
          final time = rawTime is String ? DateTime.tryParse(rawTime)?.toUtc() : null;
          if (id == null || time == null ||
              (previousCreatedAt != null &&
                (time.isAfter(previousCreatedAt!) ||
                 (time.isAtSameMomentAs(previousCreatedAt!) && id >= previousId!)))) {
            throw const FormatException('Order queue changed or returned out-of-order records; retry refresh');
          }
          previousCreatedAt = time;
          previousId = id;
        }
        rows.addAll(page);
        if (mounted && requestVersion == _boardRequestVersion) {
          setState(() { _loadedPageCount++; _loadedRowCount = rows.length; });
        }
        if (result.length < _boardPageSize) { complete = true; break; }
      }
      if (!complete || rows.length > _boardMaximumItems) {
        throw const FormatException('Order board exceeds the safe 5000-item limit; use the live kitchen queue');
      }
      // Offset-based pagination may silently omit records if a new order is
      // inserted while the pages are loading. Re-read the first page and
      // require its ordered identity and timestamp sequence to be unchanged.
      // This catches head insertions/deletions during loading; it is not a
      // substitute for transactional snapshot/keyset pagination on the server.
      if (rows.isNotEmpty) {
        final headResult = await Supabase.instance.client.rpc(
          'gs_staff_table_order_board_page',
          params: {'p_offset': 0, 'p_limit': _boardPageSize});
        if (!mounted || requestVersion != _boardRequestVersion) return;
        if (headResult is! List) {
          throw const FormatException('Unable to recheck order queue consistency');
        }
        final expected = rows.take(_boardPageSize).toList();
        if (headResult.length != expected.length) {
          throw const FormatException('Order queue changed while loading; refresh required');
        }
        for (var index = 0; index < expected.length; index++) {
          if (headResult[index] is! Map) {
            throw const FormatException('Invalid order queue consistency response');
          }
          final current = Map<String, dynamic>.from(headResult[index] as Map);
          final earlier = expected[index];
          if (_validId(current['order_item_id']) !=
                  _validId(earlier['order_item_id']) ||
              current['created_at'] != earlier['created_at'] ||
              current['status'] != earlier['status'] ||
              current['quantity'] != earlier['quantity'] ||
              current['order_id'] != earlier['order_id'] ||
              current['product_name'] != earlier['product_name'] ||
              current['unit_price_iqd'] != earlier['unit_price_iqd']) {
            throw const FormatException('Order queue changed during pagination; refresh required');
          }
        }
      }
      // Upgrade 534: also recheck the final page boundary. A head-only
      // verification cannot detect a deletion or insertion in the tail while
      // offset pagination is running. Compare every returned field for the
      // tail page, including price/product identity, rather than only status.
      if (rows.length > _boardPageSize) {
        final tailOffset = ((rows.length - 1) ~/ _boardPageSize) * _boardPageSize;
        final tailResult = await Supabase.instance.client.rpc(
          'gs_staff_table_order_board_page',
          params: {'p_offset': tailOffset, 'p_limit': _boardPageSize});
        if (!mounted || requestVersion != _boardRequestVersion) return;
        if (tailResult is! List || tailResult.length != rows.length - tailOffset) {
          throw const FormatException('Order queue tail changed during pagination; refresh required');
        }
        for (var index = 0; index < tailResult.length; index++) {
          if (tailResult[index] is! Map) {
            throw const FormatException('Invalid order queue tail response');
          }
          final current = Map<String, dynamic>.from(tailResult[index] as Map);
          final earlier = rows[tailOffset + index];
          if (current.length != earlier.length ||
              current.keys.any((key) => !earlier.containsKey(key) || current[key] != earlier[key])) {
            throw const FormatException('Order queue tail changed during pagination; refresh required');
          }
        }
      }
      // Malformed or duplicated IDs make fulfillment controls unsafe. Fail
      // closed rather than showing an incomplete or ambiguous order queue.
      final ids = <int>{};
      for (final row in rows) {
        final id = _validId(row['order_item_id']);
        if (id == null || !ids.add(id) ||
            _validId(row['order_id']) == null ||
            _validQuantity(row['quantity']) == null ||
            row['table_number'] is! int || row['table_number'] <= 0 ||
            row['product_name'] is! String ||
            (row['product_name'] as String).trim().isEmpty ||
            !stages.containsKey(row['status'])) {
          throw const FormatException('Invalid or duplicate order board item');
        }
      }
      setState(() { items = rows; _boardComplete = true; boardLoadedAt = DateTime.now().toUtc(); });
    } catch (e) {
      if (mounted && requestVersion == _boardRequestVersion) setState(() { items = []; _boardComplete = false; error = 'Order board unavailable: Please retry or contact a manager'; });
    } finally {
      if (mounted && requestVersion == _boardRequestVersion) {
        setState(() => loading = false);
        if (_refreshQueued) {
          _refreshQueued = false;
          await refresh();
        }
      }
    }
  }

  Future<void> advance(Map<String, dynamic> item) async {
    final id = _validId(item['order_item_id']);
    if (loading || error != null || id == null || _editingInstructions) return;
    if (!_boardSnapshotFresh) { await _requestFreshBoard(); return; }
    final current = item['status'].toString();
    final next = const <String, String>{
      'not_accepted':'accepted', 'accepted':'preparing',
      'preparing':'prepared', 'prepared':'picked_up',
      'picked_up':'delivered',
    }[current];
    if (next == null || updating.contains(id) ||
        !_isCurrentBoardItem(id, current)) return;
    // Delivery is a consequential staff action. Require an explicit second
    // confirmation, then revalidate the locally loaded item before sending
    // the guarded RPC. The server remains the authority on delivery state.
    if (next == 'delivered') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm item delivery'),
          content: Text('Confirm that ${item['quantity']} × '
              '${item['product_name'] ?? 'this item'} for table '
              '${item['table_number']} has been delivered. '
              'This records a fulfillment transition, not a payment.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm delivered'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true || loading || error != null ||
          !_boardSnapshotFresh || _editingInstructions || updating.isNotEmpty ||
          !_isCurrentBoardItem(id, current)) return;
    }
    setState(() => updating.add(id));
    try {
      await Supabase.instance.client.rpc('gs_advance_table_item_fulfillment', params: {
        'p_order_item_id': id,
        'p_expected_status': current,
        'p_next_status': next,
      });
      await refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transition rejected: Please retry or contact a manager')));
      await refresh();
    } finally {
      if (mounted) {
        setState(() => updating.remove(id));
        if (_refreshQueued && updating.isEmpty && !loading) {
          _refreshQueued = false;
          await refresh();
        }
      }
    }
  }

  // Only unaccepted items may be edited. The server rechecks authorization,
  // open visit, ticket state, and optimistic concurrency on submission.
  Future<void> editInstructions(Map<String, dynamic> item) async {
    final id = _validId(item['order_item_id']);
    if (id == null || loading || error != null || updating.isNotEmpty ||
        _editingInstructions || item['status'] != 'not_accepted' ||
        !_isCurrentBoardItem(id, 'not_accepted')) return;
    if (!_boardSnapshotFresh) { await _requestFreshBoard(); return; }
    setState(() => _editingInstructions = true);
    try {
    await _editInstructionsLocked(id);
    } finally {
      if (mounted) {
        setState(() => _editingInstructions = false);
        _refreshQueued = false;
        await refresh();
      }
    }
  }

  Future<void> _editInstructionsLocked(int id) async {
    String? expected;
    try {
      expected = await Supabase.instance.client.rpc(
        'gs_staff_table_item_instructions', params: {'p_order_item_id': id});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Editing unavailable: $e')));
      return;
    }
    if (!mounted) return;
    final controller = TextEditingController(text: expected ?? '');
    try {
      final submitted = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Edit preparation instructions · Item #$id'),
          content: SizedBox(width: 440, child: TextField(
            controller: controller, maxLength: 500, maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Preparation instructions',
              helperText: 'Only before acceptance; changes are audited.'),
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(
                dialogContext, controller.text), child: const Text('Save')),
          ],
        ),
      );
      if (submitted == null || !mounted || loading || error != null ||
          updating.isNotEmpty) return;
      // Dialogs can remain open while the app is backgrounded or while the
      // server state changes. Re-check the snapshot and original item before
      // submitting; the RPC independently enforces optimistic concurrency.
      if (!_boardSnapshotFresh || !_isCurrentBoardItem(id, 'not_accepted')) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order data changed or expired. Refresh before editing.')));
        _refreshQueued = true;
        return;
      }
      // The backend normalizes surrounding whitespace and blank instructions.
      // Do not submit a no-op or claim that an unchanged value was audited.
      if (submitted.trim() == (expected ?? '').trim()) return;
      setState(() => updating.add(id));
      try {
        await Supabase.instance.client.rpc(
          'gs_edit_unaccepted_item_with_revision', params: {
            'p_order_item_id': id,
            'p_expected_instructions': expected,
            'p_new_instructions': submitted,
          });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Instructions saved; revision and notifications queued when changed.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Edit rejected: $e')));
      } finally {
        if (mounted) {
          setState(() => updating.remove(id));
          await refresh();
        }
      }
    } finally {
      controller.dispose();
    }
  }

  // Pre-acceptance quantity correction is atomic and server-priced. Never
  // calculate or submit a monetary amount from the client.
  // Replacement is priced and committed only by the transactional database RPC.
  // The catalog prices displayed here are indicative and never submitted.
  Future<void> replaceProduct(Map<String, dynamic> item) async {
    final id = _validId(item['order_item_id']);
    if (id == null || loading || error != null || updating.isNotEmpty ||
        _editingInstructions || item['status'] != 'not_accepted' ||
        !_isCurrentBoardItem(id, 'not_accepted')) return;
    if (!_boardSnapshotFresh) { await _requestFreshBoard(); return; }
    setState(() => _editingInstructions = true);
    final search = TextEditingController();
    final reason = TextEditingController();
    try {
      final client = Supabase.instance.client;
      final rawItem = await client.from('gs_order_items')
          .select('id,product_id,unit_price_iqd,quantity')
          .eq('id', id).single();
      final oldProduct = _validId(rawItem['product_id']);
      final oldPrice = rawItem['unit_price_iqd'];
      final quantity = _validQuantity(rawItem['quantity']);
      if (oldProduct == null || oldPrice is! num || oldPrice < 0 ||
          quantity == null) throw StateError('Invalid order item; refresh required');
      // Search on the server: never load a truncated 500-item catalog.
      Future<List<Map<String, dynamic>>> findProducts(String query) async {
        final rows = await client.rpc('gs_search_table_replacement_products',
          params: {'p_query': query, 'p_limit': 50, 'p_offset': 0});
        return (rows as List).whereType<Map>().map(
          (p) => Map<String, dynamic>.from(p)).where((p) =>
            _validId(p['id']) != null && _validId(p['id']) != oldProduct &&
            p['name'] is String).toList();
      }
      var products = await findProducts('');
      var searching = false;
      var searchGeneration = 0;
      if (!mounted) return;
      Map<String, dynamic>? chosen;
      final confirmed = await showDialog<bool>(context: context,
        builder: (dialogContext) => StatefulBuilder(builder: (context, updateDialog) {
          final filtered = products;
          Future<void> updateSearch(String query) async {
            final generation = ++searchGeneration;
            updateDialog(() { searching = true; chosen = null; });
            try {
              final found = await findProducts(query);
              if (generation == searchGeneration && dialogContext.mounted) {
                updateDialog(() { products = found; searching = false; });
              }
            } catch (_) {
              if (generation == searchGeneration && dialogContext.mounted) {
                updateDialog(() { products = []; searching = false; });
              }
            }
          }
          return AlertDialog(
            title: Text('Replace product · Item #$id'),
            content: SizedBox(width: 460, height: 450, child: Column(children: [
              Text('Current: ${item['product_name']} × $quantity · '
                  '${oldPrice.toInt()} IQD each'),
              const SizedBox(height: 8),
              TextField(controller: search, onChanged: updateSearch,
                decoration: const InputDecoration(labelText: 'Search name or barcode',
                  prefixIcon: Icon(Icons.search))),
              if (searching) const LinearProgressIndicator(),
              Expanded(child: ListView.builder(itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final p = filtered[index];
                  return RadioListTile<int>(
                    title: Text(p['name'].toString()),
                    subtitle: Text('Normal: ${p['normal_price_iqd']} IQD · '
                      'Tourism: ${p['tourism_price_iqd']} IQD'),
                    value: _validId(p['id'])!,
                    groupValue: chosen == null ? null : _validId(chosen!['id']),
                    onChanged: (_) => updateDialog(() => chosen = p));
                })),
              TextField(controller: reason, maxLength: 250, maxLines: 2,
                // Rebuild the action whenever the reason changes. Without this,
                // the Review button can remain disabled after a valid reason
                // is entered unless the employee reselects the product.
                onChanged: (_) => updateDialog(() {}),
                decoration: const InputDecoration(
                  labelText: 'Reason for replacement (required)')),
              const Text('Final price is determined by Supabase using the order mode.',
                style: TextStyle(fontSize: 12)),
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
              FilledButton(onPressed: searching || chosen == null ||
                  reason.text.trim().length < 5 || reason.text.trim().length > 250
                  ? null : () => Navigator.pop(dialogContext, true),
                child: const Text('Review replacement')),
            ],
          );
        }));
      if (!mounted || confirmed != true || chosen == null) return;
      final newId = _validId(chosen!['id']);
      if (newId == null) return;
      final quoteRaw = await client.rpc('gs_quote_unaccepted_table_replacement', params: {
        'p_order_item_id': id,
        'p_expected_product_id': oldProduct,
        'p_expected_unit_price_iqd': oldPrice.toInt(),
        'p_new_product_id': newId,
      });
      if (quoteRaw is! Map || _validId(quoteRaw['order_item_id']) != id ||
          _validId(quoteRaw['product_id']) != newId ||
          quoteRaw['new_unit_price_iqd'] is! num) {
        throw StateError('Invalid server price quote');
      }
      // Reject malformed or fractional monetary values instead of silently
      // truncating them before presenting a financial confirmation.
      int quotedIqd(String key) {
        final value = quoteRaw[key];
        if (value is! int) throw StateError('Invalid server quote: $key');
        return value;
      }
      final confirmedPrice = quotedIqd('new_unit_price_iqd');
      final quotedQuantity = quoteRaw['quantity'];
      if (confirmedPrice < 0 || quotedQuantity is! int ||
          quotedQuantity != quantity || quoteRaw['tourism_mode'] is! bool ||
          quotedIqd('old_unit_price_iqd') != oldPrice.toInt() ||
          quotedIqd('old_line_total_iqd') != quantity * oldPrice.toInt() ||
          quotedIqd('new_line_total_iqd') != quantity * confirmedPrice ||
          quotedIqd('difference_iqd') != quantity * (confirmedPrice - oldPrice.toInt())) {
        throw StateError('Replacement quote changed or is inconsistent; refresh required');
      }
      if (!mounted) return;
      final approved = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm product replacement'),
          content: Text('Replace ${item['product_name']} with ${chosen!['name']} '
            'for $quantity unit(s)?\n\n'
            'Mode: ${quoteRaw['tourism_mode'] == true ? 'Tourism' : 'Normal'}\n'
            'Original total: ${quoteRaw['old_line_total_iqd']} IQD\n'
            'New unit price: $confirmedPrice IQD\n'
            'New total: ${quoteRaw['new_line_total_iqd']} IQD\n'
            'Difference: ${quoteRaw['difference_iqd']} IQD\n\n'
            'Confirm this exact server price. Any later price change will reject the replacement.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm')),
          ]));
      if (approved != true || !mounted || !_boardSnapshotFresh ||
          !_isCurrentBoardItem(id, 'not_accepted')) return;
      // Stable identity for this confirmed action; never generate a new key
      // when checking whether the database committed this same request.
      final requestBytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
      requestBytes[6] = (requestBytes[6] & 0x0f) | 0x40;
      requestBytes[8] = (requestBytes[8] & 0x3f) | 0x80;
      final hex = requestBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final requestId = '${hex.substring(0,8)}-${hex.substring(8,12)}-${hex.substring(12,16)}-${hex.substring(16,20)}-${hex.substring(20)}';
      final actorId = client.auth.currentUser?.id;
      if (actorId == null) throw StateError('Employee session expired');
      // Persist before sending the mutation. A crashed app can recover the
      // original request identity instead of creating a second replacement.
      if (await TableReplacementRecovery.load(actorId) != null) {
        throw StateError('An earlier replacement needs recovery. Check its receipt first.');
      }
      // Invalidate any earlier background recovery read before persisting.
      _recoveryLoadVersion++;
      await TableReplacementRecovery.save(actorId, {
        'request_id': requestId,
        'order_item_id': id,
        'product_id': newId,
        'expected_difference_iqd': quotedIqd('difference_iqd'),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) setState(() => _pendingReplacement = {
        'request_id': requestId,
        'order_item_id': id,
        'product_id': newId,
        'expected_difference_iqd': quotedIqd('difference_iqd'),
      });
      // A transport failure can occur after the database commits. Do not
      // classify it as a rejection or automatically repeat the mutation.
      Object? result;
      Object? rpcFailure;
      try {
        result = await client.rpc('gs_replace_unaccepted_table_item', params: {
          'p_order_item_id': id,
          'p_expected_product_id': oldProduct,
          'p_expected_unit_price_iqd': oldPrice.toInt(),
          'p_new_product_id': newId,
          'p_reason': reason.text.trim(),
          'p_confirmed_new_unit_price_iqd': confirmedPrice,
          'p_expected_quantity': quotedQuantity,
          'p_expected_tourism_mode': quoteRaw['tourism_mode'],
          'p_request_id': requestId,
        });
      } catch (e) {
        rpcFailure = e;
      }
      // A completed network request must not update another employee's UI.
      if (client.auth.currentUser?.id != actorId) {
        throw StateError('Employee session changed. Original recovery record is preserved.');
      }
      final responseVerified = result is Map &&
          _validId(result['order_item_id']) == id &&
          _validId(result['product_id']) == newId &&
          result['difference_iqd'] is int &&
          result['difference_iqd'] == quotedIqd('difference_iqd');
      if (rpcFailure != null || !responseVerified) {
        // Resolve by request identity, not by matching product values.
        try {
          final recorded = await client.rpc('gs_table_replacement_request_status',
              params: {'p_request_id': requestId});
          if (client.auth.currentUser?.id != actorId) {
            throw StateError('Employee session changed during receipt verification');
          }
          if (recorded is Map && recorded['status'] == 'committed' &&
              recorded['result'] is Map &&
              _validId(recorded['result']['order_item_id']) == id &&
              _validId(recorded['result']['product_id']) == newId &&
              recorded['result']['difference_iqd'] == quotedIqd('difference_iqd')) {
            await TableReplacementRecovery.clear(actorId, requestId);
            if (!mounted || client.auth.currentUser?.id != actorId) return;
            if (_pendingReplacement?['request_id'] == requestId) {
              setState(() => _pendingReplacement = null);
            }
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Replacement confirmed from the server request record.')));
            await refresh();
            return;
          }
        } catch (_) { /* Preserve uncertain outcome; never retry automatically. */ }
        // A read-back is diagnostic only: it cannot prove which concurrent
        // request performed the change, nor that kitchen dispatch succeeded.
        String outcome = 'Outcome uncertain. Do not retry automatically. '
            'Refresh and review the order and kitchen revision history.';
        try {
          final current = await client.from('gs_order_items')
              .select('product_id,unit_price_iqd,quantity')
              .eq('id', id).single();
          final matchesNew = _validId(current['product_id']) == newId &&
              current['unit_price_iqd'] == confirmedPrice &&
              current['quantity'] == quotedQuantity;
          if (matchesNew) {
            outcome = 'Replacement values appear on the order, but the '
                'transaction response was not verified. Check kitchen '
                'revision history before further action.';
          }
        } catch (_) {
          // Preserve the uncertain outcome if read-back is unavailable.
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(outcome), duration: const Duration(seconds: 9)));
        return;
      }
      if (client.auth.currentUser?.id != actorId) {
        throw StateError('Employee session changed before confirmation');
      }
      await TableReplacementRecovery.clear(actorId, requestId);
      if (!mounted || client.auth.currentUser?.id != actorId) return;
      if (_pendingReplacement?['request_id'] == requestId) {
        setState(() => _pendingReplacement = null);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Product replacement confirmed by server. Difference: '
          '${result['difference_iqd']} IQD.')));
      await refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Replacement could not be submitted: $e')));
    } finally {
      search.dispose();
      reason.dispose();
      if (mounted) {
        setState(() => _editingInstructions = false);
        _refreshQueued = false;
        await refresh();
      }
    }
  }

  Future<void> editQuantity(Map<String, dynamic> item) async {
    final id = _validId(item['order_item_id']);
    final original = _validQuantity(item['quantity']);
    if (id == null || original == null || loading || error != null ||
        updating.isNotEmpty || _editingInstructions ||
        item['status'] != 'not_accepted' ||
        !_isCurrentBoardItem(id, 'not_accepted')) return;
    if (!_boardSnapshotFresh) { await _requestFreshBoard(); return; }
    setState(() => _editingInstructions = true);
    final controller = TextEditingController(text: '$original');
    final reasonController = TextEditingController();
    try {
      final submitted = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Correct quantity · Item #$id'),
          content: SizedBox(width: 380, child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3)],
                decoration: const InputDecoration(
                  labelText: 'New quantity (1–999)',
                  helperText: 'Before acceptance only. Server recalculates totals.'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLength: 250,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Correction reason (required)',
                  hintText: 'Example: customer requested another portion'),
              ),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Save correction')),
          ],
        ),
      );
      if (!mounted || submitted == null) return;
      final requested = int.tryParse(submitted.trim());
      if (requested == null || requested < 1 || requested > 999) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quantity must be a whole number between 1 and 999.')));
        return;
      }
      if (requested == original) return;
      final reason = reasonController.text.trim();
      if (reason.length < 5 || reason.length > 250) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a correction reason (5–250 characters).')));
        return;
      }
      // Obtain a read-only, server-priced preview. Never infer IQD amounts
      // from untrusted board data or submit a client-calculated price.
      final previewResult = await Supabase.instance.client.rpc(
        'gs_preview_unaccepted_table_item_quantity',
        params: {'p_order_item_id': id, 'p_expected_quantity': original,
          'p_new_quantity': requested});
      if (previewResult is! Map) {
        throw StateError('Financial preview unavailable; correction blocked');
      }
      final preview = Map<String, dynamic>.from(previewResult);
      // Bind the financial preview to the exact item and quantities requested.
      // A mismatched response must never be presented for employee approval.
      final previewItem = preview['order_item_id'];
      final previewOld = preview['previous_quantity'];
      final previewNew = preview['new_quantity'];
      final previewPrice = preview['unit_price_iqd'];
      if (previewItem is! num || previewItem.toInt() != id ||
          previewItem != id || previewOld is! num ||
          previewOld.toInt() != original || previewOld != original ||
          previewNew is! num || previewNew.toInt() != requested ||
          previewNew != requested || previewPrice is! num ||
          previewPrice < 0 || previewPrice > 1000000000 ||
          previewPrice != previewPrice.toInt()) {
        throw StateError('Financial preview identity mismatch; correction blocked');
      }
      final before = preview['previous_line_total_iqd'];
      final after = preview['new_line_total_iqd'];
      final delta = preview['difference_iqd'];
      if (before is! num || after is! num || delta is! num ||
          before < 0 || after < 0 || after - before != delta ||
          before != before.toInt() || after != after.toInt() ||
          delta != delta.toInt() ||
          before.toInt() != original * previewPrice.toInt() ||
          after.toInt() != requested * previewPrice.toInt()) {
        throw StateError('Invalid financial preview; correction blocked');
      }
      if (!mounted) return;
      // A quantity correction changes the order total. Require an explicit
      // second confirmation before sending the atomic, server-priced RPC.
      // Never estimate money in the client: the persisted unit price and
      // authoritative financial totals are calculated by Supabase.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (confirmationContext) => AlertDialog(
          title: const Text('Confirm quantity correction'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Product: ${item['product_name']}'),
              Text('Table: ${item['table_number']}'),
              Text('Previous quantity: $original'),
              Text('New quantity: $requested'),
              Text('Change: ${requested > original ? '+' : ''}${requested - original} units'),
              Text('Reason: $reason'),
              const SizedBox(height: 8),
              Text('Previous line total: ${before.toInt()} IQD'),
              Text('New line total: ${after.toInt()} IQD'),
              Text('Financial difference: ${delta > 0 ? '+' : ''}${delta.toInt()} IQD',
                style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('This changes the order total. Supabase will use the stored unit price, verify the order is still editable, and record an audit revision.'),
            ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(confirmationContext, false),
              child: const Text('Keep original')),
            FilledButton(onPressed: () => Navigator.pop(confirmationContext, true),
              child: const Text('Confirm correction')),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      // A confirmation dialog can stay open while the queue changes. Ensure
      // the same item, quantity and order still appear in this board snapshot.
      final matching = items.where((row) =>
          _validId(row['order_item_id']) == id &&
          _validId(row['order_id']) == _validId(item['order_id']) &&
          row['status'] == 'not_accepted' &&
          _validQuantity(row['quantity']) == original).toList();
      if (!_boardSnapshotFresh || loading || error != null ||
          matching.length != 1) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Order or quantity changed. Refresh before editing.')));
        return;
      }
      // The employee may have kept the confirmation open while another
      // authorized actor changed the price, payment state or kitchen tickets.
      // Revalidate the exact server-priced preview immediately before mutation.
      // The transactional mutation still performs its own locked checks.
      final recheckResult = await Supabase.instance.client.rpc(
        'gs_preview_unaccepted_table_item_quantity',
        params: {'p_order_item_id': id, 'p_expected_quantity': original,
          'p_new_quantity': requested});
      if (recheckResult is! Map) {
        throw StateError('Financial preview expired; refresh before editing');
      }
      final recheck = Map<String, dynamic>.from(recheckResult);
      const financialFields = <String>[
        'order_item_id', 'previous_quantity', 'new_quantity',
        'unit_price_iqd', 'previous_line_total_iqd',
        'new_line_total_iqd', 'difference_iqd',
      ];
      if (financialFields.any((field) =>
          recheck[field] is! num || preview[field] is! num ||
          recheck[field] != preview[field])) {
        throw StateError('Order financial details changed during confirmation; '
            'refresh before editing');
      }
      // Network latency during the recheck can outlive the authorized board
      // snapshot. Never submit an edit after the board was replaced or expired.
      // The database RPC remains the final transactional authority.
      if (!mounted || !_boardSnapshotFresh || loading || error != null ||
          !_isCurrentBoardItem(id, 'not_accepted') ||
          items.where((row) =>
            _validId(row['order_item_id']) == id &&
            _validId(row['order_id']) == _validId(item['order_id']) &&
            _validQuantity(row['quantity']) == original &&
            row['status'] == 'not_accepted').length != 1) {
        throw StateError('Order board changed during financial recheck; refresh required');
      }
      final serverQuantity = await Supabase.instance.client.rpc(
        'gs_correct_unaccepted_table_item_quantity',
        params: {'p_order_item_id': id, 'p_expected_quantity': original,
          'p_new_quantity': requested, 'p_reason': reason});
      if (serverQuantity is! num || serverQuantity.toInt() != requested ||
          serverQuantity != requested) {
        throw StateError('Unexpected quantity confirmation from server; refresh required');
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Quantity corrected. Price and audit recorded by server.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quantity correction rejected: $e')));
    } finally {
      controller.dispose();
      reasonController.dispose();
      if (mounted) {
        setState(() => _editingInstructions = false);
        _refreshQueued = false;
        await refresh();
      }
    }
  }

  Future<void> showItemTimeline(Map<String, dynamic> item) async {
    final id = _validId(item['order_item_id']);
    if (id == null || loading || error != null) return;
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_table_item_timeline', params: {'p_order_item_id': id});
      if (!mounted) return;
      final events = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text('Item timeline · #$id'),
        content: SizedBox(width: 480, child: events.isEmpty
          ? const Text('No recorded events available.')
          : ListView(shrinkWrap: true, children: [
              for (final event in events)
                ListTile(
                  leading: const Icon(Icons.history),
                  title: Text((event['event_label'] ?? 'Event').toString()),
                  subtitle: Text('${orderTimeLabel(event['occurred_at'], label: 'Event')}'
                    '${event['previous_value'] == null ? '' : '\nBefore: ${event['previous_value']}'}'
                    '${event['new_value'] == null ? '' : '\nAfter: ${event['new_value']}'}'
                    '${event['actor_id'] == null ? '' : '\nActor ID: ${event['actor_id']}'}'),
                ),
            ])),
        actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item timeline unavailable: $e')));
    }
  }

  Future<void> showOrderRevisions(Map<String, dynamic> item) async {
    final orderId = _validId(item['order_id']);
    if (orderId == null || loading || error != null) return;
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_table_order_revisions', params: {'p_order_id': orderId});
      if (!mounted) return;
      final revisions = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text('Order #$orderId · Change history'),
        content: SizedBox(width: 520, child: revisions.isEmpty
          ? const Text('No recorded order revisions.')
          : ListView(shrinkWrap: true, children: [
              for (final rev in revisions) Card(child: ListTile(
                leading: const Icon(Icons.history),
                title: Text('Revision ${rev['revision_number']} · ${rev['change_type']}'),
                subtitle: Text(
                  '${orderTimeLabel(rev['changed_at'], label: 'Changed')}\n'
                  'Item: ${rev['order_item_id'] ?? 'Order'}\n'
                  'Before: ${rev['before_snapshot']}\n'
                  'After: ${rev['after_snapshot']}\n'
                  'Employee ID: ${rev['changed_by']}'
                  '${rev['reason'] == null ? '' : '\nReason: ${rev['reason']}'}'),
              )),
            ])),
        actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order history unavailable: $e')));
    }
  }

  Future<void> showRevisionDispatch(Map<String, dynamic> item) async {
    final orderId = _validId(item['order_id']);
    if (orderId == null || loading || error != null) return;
    try {
      final result = await Supabase.instance.client.rpc(
        'gs_staff_order_revision_dispatch',
        params: {'p_order_id': orderId},
      );
      if (!mounted) return;
      final rows = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      // Only kitchen replacement dispatches count as actionable kitchen work.
      // Employee/customer notifications and printing are independent channels.
      final kitchenRows = rows.where((r) =>
          r['destination_type'] == 'kitchen_revision').toList();
      final pendingKitchen = kitchenRows.where((r) =>
          r['dispatch_status'] != 'acknowledged').length;
      final failedKitchen = kitchenRows.where((r) =>
          r['dispatch_status'] == 'failed').length;
      // Reconciliation is a read-only, independently permission-checked RPC.
      // A failure must not be represented as a clean reconciliation result.
      List<Map<String, dynamic>>? reconciliation;
      String? reconciliationError;
      try {
        final result = await Supabase.instance.client.rpc(
          'gs_staff_kitchen_revision_reconciliation',
          params: {'p_order_id': orderId},
        );
        reconciliation = (result as List)
            .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (e) {
        reconciliationError = e.toString();
      }
      if (!mounted) return;
      final reconciliationByDispatch = <String, Map<String, dynamic>>{
        for (final r in reconciliation ?? <Map<String, dynamic>>[])
          if (r['dispatch_id'] != null) r['dispatch_id'].toString(): r,
      };
      final anomalies = (reconciliation ?? <Map<String, dynamic>>[])
          .where((r) => !['acknowledged_consistent',
              'awaiting_kitchen_receipt', 'failed_requires_recovery']
              .contains(r['reconciliation_state']))
          .length;
      List<Map<String, dynamic>> exceptionCases = [];
      String? exceptionCasesError;
      try {
        final casesResult = await Supabase.instance.client.rpc(
          'gs_staff_kitchen_revision_exception_cases',
          params: {'p_order_id': orderId},
        );
        exceptionCases = (casesResult as List)
            .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (e) {
        exceptionCasesError = e.toString();
      }
      if (!mounted) return;
      final openCaseDispatches = exceptionCases
          .where((c) => c['status'] == 'open')
          .map((c) => c['dispatch_id'].toString()).toSet();
      bool showKitchenOnly = false;
      bool unresolvedOnly = false;
      bool exceptionsOnly = false;
      const healthyReceiptStates = <String>{
        'acknowledged_consistent', 'awaiting_kitchen_receipt',
        'failed_requires_recovery',
      };
      bool needsManagerReview(Map<String, dynamic> row) {
        if (row['destination_type'] != 'kitchen_revision') return false;
        final audit = reconciliationByDispatch[row['dispatch_id'].toString()];
        return audit != null &&
            !healthyReceiptStates.contains(audit['reconciliation_state']);
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Order #$orderId · Revision dispatch'),
          content: SizedBox(
            width: 520, height: 460,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Kitchen revisions: ${kitchenRows.length} · Awaiting receipt: $pendingKitchen · Failed: $failedKitchen',
                style: Theme.of(dialogContext).textTheme.titleSmall),
              if (reconciliationError != null)
                Text('Receipt reconciliation unavailable: $reconciliationError',
                  style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
              if (reconciliation != null)
                Text('Receipt reconciliation: ${reconciliation.length} checked · '
                    '$anomalies inconsistent',
                  style: TextStyle(color: anomalies > 0
                      ? Theme.of(dialogContext).colorScheme.error : null)),
              if (exceptionCasesError != null)
                Text('Exception case history unavailable: $exceptionCasesError'),
              Text('Open investigation cases: ${openCaseDispatches.length}'),
              if (exceptionCases.isNotEmpty)
                ExpansionTile(
                  title: const Text('Investigation case history'),
                  children: [
                    for (final c in exceptionCases)
                      ListTile(
                        dense: true,
                        title: Text('Case ${c['case_id']} · ${c['status']}'),
                        subtitle: Text('Dispatch: ${c['dispatch_id']}\n'
                          'Opened: ${c['opened_at']} by ${c['opened_by']}\n'
                          'Investigation: ${c['investigation_note']}'
                          '${c['reopened_from_case_id'] == null ? '' : '\nReopened from: ${c['reopened_from_case_id']}'}'
                          '${c['closed_at'] == null ? '' : '\nClosed: ${c['closed_at']} by ${c['closed_by']}'}'
                          '${c['resolution_note'] == null ? '' : '\nResolution: ${c['resolution_note']}'}'),
                        trailing: c['status'] == 'closed' &&
                          !openCaseDispatches.contains(c['dispatch_id'].toString()) &&
                          reconciliationByDispatch.containsKey(c['dispatch_id'].toString()) &&
                          !healthyReceiptStates.contains(reconciliationByDispatch[c['dispatch_id'].toString()]?['reconciliation_state'])
                          ? TextButton(
                            child: const Text('Reinvestigate'),
                            onPressed: () async {
                              final reason = TextEditingController();
                              try {
                                final confirmed = await showDialog<bool>(
                                  context: dialogContext,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Reopen investigation as a new case'),
                                    content: TextField(controller: reason, maxLines: 3,
                                      maxLength: 1000,
                                      decoration: const InputDecoration(
                                        labelText: 'Reason (10–1000 characters)'),),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel')),
                                      FilledButton(onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Create new case')),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;
                                await Supabase.instance.client.rpc(
                                  'gs_staff_reopen_kitchen_revision_exception',
                                  params: {'p_order_id': orderId,
                                    'p_closed_case_id': c['case_id'],
                                    'p_reason': reason.text.trim()},
                                );
                                if (!mounted) return;
                                Navigator.of(dialogContext).pop();
                                await showRevisionDispatch(item);
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Could not reopen case: $e')));
                              } finally { reason.dispose(); }
                            },
                          ) : c['status'] == 'open' &&
                          healthyReceiptStates.contains(
                            reconciliationByDispatch[c['dispatch_id'].toString()]?['reconciliation_state'])
                          ? TextButton(
                            child: const Text('Resolve'),
                            onPressed: () async {
                              final note = TextEditingController();
                              try {
                                final confirmed = await showDialog<bool>(
                                  context: dialogContext,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Close investigation case'),
                                    content: TextField(
                                      controller: note, maxLines: 3, maxLength: 1000,
                                      decoration: const InputDecoration(
                                        labelText: 'Resolution note (10–1000 characters)'),
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel')),
                                      FilledButton(onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Close case')),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;
                                await Supabase.instance.client.rpc(
                                  'gs_staff_close_kitchen_revision_exception',
                                  params: {'p_order_id': orderId,
                                    'p_case_id': c['case_id'],
                                    'p_resolution_note': note.text.trim()},
                                );
                                if (!mounted) return;
                                Navigator.of(dialogContext).pop();
                                await showRevisionDispatch(item);
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Could not close case: $e')));
                              } finally { note.dispose(); }
                            },
                          ) : null,
                      ),
                  ],
                ),
              if (anomalies > 0)
                Text('Manager review required: $anomalies receipt audit exceptions. '
                    'Do not acknowledge or retry inconsistent records until reviewed.',
                  style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Audit exceptions only'),
                value: exceptionsOnly,
                onChanged: reconciliation == null ? null : (v) =>
                    setDialogState(() => exceptionsOnly = v ?? false),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Kitchen revisions only'),
                value: showKitchenOnly,
                onChanged: (v) => setDialogState(() => showKitchenOnly = v ?? false),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Awaiting kitchen receipt only'),
                value: unresolvedOnly,
                onChanged: (v) => setDialogState(() => unresolvedOnly = v ?? false),
              ),
              Expanded(child: (rows.where((r) =>
                  (!exceptionsOnly || needsManagerReview(r)) &&
                  (!showKitchenOnly || r['destination_type'] == 'kitchen_revision') &&
                  (!unresolvedOnly || (r['destination_type'] == 'kitchen_revision' &&
                    r['dispatch_status'] != 'acknowledged'))).isEmpty)
                ? const Center(child: Text('No revisions match these filters.'))
                : ListView(shrinkWrap: true, children: [
                    for (final row in rows.where((r) =>
                        (!exceptionsOnly || needsManagerReview(r)) &&
                  (!showKitchenOnly || r['destination_type'] == 'kitchen_revision') &&
                        (!unresolvedOnly || (r['destination_type'] == 'kitchen_revision' &&
                          r['dispatch_status'] != 'acknowledged'))))
                      Card(child: ListTile(
                        leading: const Icon(Icons.notifications_active_outlined),
                        title: Text('Revision ${row['revision_number']} · '
                            '${row['destination_type']}'),
                        trailing: row['destination_type'] == 'kitchen_revision' &&
                                reconciliation != null &&
                                reconciliationByDispatch.containsKey(row['dispatch_id'].toString()) &&
                                !needsManagerReview(row) &&
                                ['pending', 'sent', 'claimed'].contains(row['dispatch_status'])
                            ? IconButton(
                                tooltip: 'Acknowledge kitchen revision',
                                icon: const Icon(Icons.check_circle_outline),
                                onPressed: () async {
                                  try {
                                    final confirmed = await showDialog<bool>(
                                      context: dialogContext,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Confirm kitchen receipt'),
                                        content: Text('Confirm that the kitchen actually received revision ${row['revision_number']} for order #$orderId. This does not confirm printing, preparation, or delivery.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm receipt')),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true) return;
                                    await Supabase.instance.client.rpc(
                                      'gs_acknowledge_table_replacement_kitchen_revision',
                                      params: {'p_dispatch_id': row['dispatch_id']});
                                    if (!mounted) return;
                                    Navigator.of(dialogContext).pop();
                                    await showRevisionDispatch(item);
                                  } catch (e) {
                                    if (mounted) ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(content: Text('Kitchen acknowledgment failed: $e')));
                                  }
                                },
                              ) : null,
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (row['destination_type'] == 'kitchen_revision' &&
                                reconciliationByDispatch.containsKey(row['dispatch_id'].toString()))
                              Builder(builder: (context) {
                                final state = reconciliationByDispatch[
                                    row['dispatch_id'].toString()]!['reconciliation_state'].toString();
                                final inconsistent = !['acknowledged_consistent',
                                  'awaiting_kitchen_receipt', 'failed_requires_recovery'].contains(state);
                                return Text('Receipt audit: $state'
                                    '${inconsistent ? ' — MANAGER REVIEW REQUIRED' : ''}',
                                  style: TextStyle(color: inconsistent
                                      ? Theme.of(context).colorScheme.error : null));
                              }),
                            if (needsManagerReview(row) &&
                                openCaseDispatches.contains(row['dispatch_id'].toString()))
                              const Text('An investigation case is already open for this dispatch.'),
                            if (needsManagerReview(row) &&
                                !openCaseDispatches.contains(row['dispatch_id'].toString()))
                              TextButton.icon(
                                icon: const Icon(Icons.report_problem_outlined),
                                label: const Text('Open investigation case'),
                                onPressed: () async {
                                  final note = TextEditingController();
                                  try {
                                    final accepted = await showDialog<bool>(
                                      context: dialogContext,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Escalate receipt audit exception'),
                                        content: TextField(
                                          controller: note, maxLength: 1000,
                                          maxLines: 3,
                                          decoration: const InputDecoration(
                                            labelText: 'Investigation note (10–1000 characters)'),
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open case')),
                                        ],
                                      ),
                                    );
                                    if (accepted != true) return;
                                    await Supabase.instance.client.rpc(
                                      'gs_staff_open_kitchen_revision_exception',
                                      params: {
                                        'p_order_id': orderId,
                                        'p_dispatch_id': row['dispatch_id'],
                                        'p_note': note.text.trim(),
                                      },
                                    );
                                    if (!mounted) return;
                                    Navigator.of(dialogContext).pop();
                                    await showRevisionDispatch(item);
                                  } catch (e) {
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Could not open investigation case: $e')));
                                  } finally {
                                    note.dispose();
                                  }
                                },
                              ),
                            if (needsManagerReview(row))
                              const Text('ACTION REQUIRED: Audit mismatch. Escalate to a manager; '
                                  'do not change receipt state automatically.'),
                            if (row['destination_type'] == 'kitchen_revision' &&
                                (reconciliation == null ||
                                 !reconciliationByDispatch.containsKey(row['dispatch_id'].toString())))
                              const Text('Receipt audit not verified; acknowledgment and retry are disabled.'),
                            Text('Destination: ${row['destination_key']}\n'
                              'Status: ${row['dispatch_status']}\n'
                              '${row['dispatch_status'] == 'failed' ? 'ACTION REQUIRED: Retry failed dispatch before confirming receipt.\n' : ''}'
                              'Attempts: ${row['attempts']}\n'
                              'Queued: ${row['queued_at']}'
                              '${row['acknowledged_at'] == null ? '' : '\nAcknowledged: ${row['acknowledged_at']}'}'
                              '${row['acknowledged_by'] == null ? '' : '\nAcknowledged by employee: ${row['acknowledged_by']}'}'
                              '\nRetry count: ${row['retry_count'] ?? 0}'
                              '${row['last_retry_at'] == null ? '' : '\nLast retry: ${row['last_retry_at']}'}'
                              '${row['last_retry_reason'] == null ? '' : '\nLast retry reason: ${row['last_retry_reason']}'}'),
                            if (row['destination_type'] == 'kitchen_revision' &&
                                row['dispatch_status'] == 'failed' &&
                                reconciliation != null &&
                                reconciliationByDispatch.containsKey(row['dispatch_id'].toString()) &&
                                !needsManagerReview(row))
                              TextButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('Requeue failed kitchen revision'),
                                onPressed: () async {
                                  final reason = TextEditingController();
                                  try {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Retry kitchen revision'),
                                        content: Column(mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('This queues another delivery attempt. It does not confirm kitchen receipt.'),
                                            TextField(controller: reason, maxLength: 250,
                                              decoration: const InputDecoration(labelText: 'Reason (5–250 characters)')),
                                          ]),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Requeue')),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true) return;
                                    await Supabase.instance.client.rpc(
                                      'gs_retry_failed_kitchen_replacement_revision',
                                      params: {'p_dispatch_id': row['dispatch_id'], 'p_reason': reason.text.trim()});
                                    if (!mounted) return;
                                    Navigator.of(dialogContext).pop();
                                    await showRevisionDispatch(item);
                                  } catch (e) {
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Revision retry failed: $e')));
                                  } finally { reason.dispose(); }
                                },
                              ),
                          ]),
                      )),
                  ])),
            ]),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh status'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await showRevisionDispatch(item);
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Revision dispatch unavailable: $e')),
      );
    }
  }

  /// Format a backend timestamp in Iraq local time. Caller supplies the
  /// appropriate event label; not every timestamp represents order creation.
  String orderTimeLabel(dynamic raw, {String label = 'Ordered'}) {
    if (raw == null) return '$label time unavailable';
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return '$label time unavailable';
    final baghdad = parsed.toUtc().add(const Duration(hours: 3));
    String two(int n) => n.toString().padLeft(2, '0');
    return '$label ${baghdad.year}-${two(baghdad.month)}-${two(baghdad.day)} '
        '${two(baghdad.hour)}:${two(baghdad.minute)} Iraq time';
  }

  // Waiting alerts are advisory, based on the timestamp when the authorized
  // board was fetched. They never mutate an order or assert a kitchen SLA.
  int? _waitingMinutes(Map<String, dynamic> item) {
    if (item['status'] == 'delivered') return null;
    final created = DateTime.tryParse(item['created_at']?.toString() ?? '');
    if (created == null) return null;
    final minutes = boardLoadedAt.difference(created.toUtc()).inMinutes;
    if (minutes < 0) return null; // Reject future/clock-skewed timestamps.
    return minutes;
  }

  // Queue priority is a display aid only. It never changes fulfillment state.
  // Pending and in-progress items appear ahead of completed deliveries.
  int _actionPriority(dynamic raw) {
    switch (raw?.toString()) {
      case 'not_accepted': return 0;
      case 'accepted': return 1;
      case 'preparing': return 2;
      case 'prepared': return 3;
      case 'picked_up': return 4;
      case 'delivered': return 5;
      default: return 6;
    }
  }

  // Sorting is presentation-only: it never changes fulfillment state or
  // bypasses the permission-scoped server response. Missing timestamps sort
  // after valid timestamps, with a stable item-ID tie-breaker.
  int _compareItems(Map<String, dynamic> a, Map<String, dynamic> b) {
    int compareTime() {
      final at = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final bt = DateTime.tryParse(b['created_at']?.toString() ?? '');
      if (at == null && bt != null) return 1;
      if (at != null && bt == null) return -1;
      if (at != null && bt != null) {
        final order = at.compareTo(bt);
        if (order != 0) return sortMode == 'newest' ? -order : order;
      }
      return 0;
    }
    if (sortMode == 'action') {
      final byPriority = _actionPriority(a['status'])
          .compareTo(_actionPriority(b['status']));
      if (byPriority != 0) return byPriority;
    }
    if (sortMode == 'table') {
      final tableA = a['table_number']?.toString() ?? '';
      final tableB = b['table_number']?.toString() ?? '';
      final aNumber = int.tryParse(tableA);
      final bNumber = int.tryParse(tableB);
      if (aNumber != null && bNumber != null && aNumber != bNumber) {
        return aNumber.compareTo(bNumber);
      }
      final byTable = tableA.compareTo(tableB);
      if (byTable != 0) return byTable;
    }
    final byTime = compareTime();
    if (byTime != 0) return byTime;
    return (_validId(a['order_item_id']) ?? 0)
        .compareTo(_validId(b['order_item_id']) ?? 0);
  }

  // Treat product names as untrusted display data when copying a multiline
  // operational report. Newlines/control characters must not create forged
  // table rows, order IDs, or handoff instructions.
  String _handoffField(Object? value) => (value?.toString() ?? '')
      .replaceAll(RegExp(r'[\x00-\x1f\x7f]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // A manual handoff is a copy of the permission-scoped queue, not a kitchen
  // dispatch or an order mutation. Exclude delivered items and customer data.
  Future<void> copyKitchenHandoff(List<Map<String, dynamic>> visible) async {
    if (loading || error != null || updating.isNotEmpty ||
        _editingInstructions) return;
    if (!_boardSnapshotFresh) { await _requestFreshBoard(); return; }
    // A capped response cannot establish that the kitchen queue is complete.
    // Refuse to generate a handoff that could omit undisclosed pending items.
    if (!_boardComplete) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Kitchen handoff blocked: order board is incomplete. Use the live kitchen queue.'),
      ));
      return;
    }
    final actionable = visible.where((item) =>
        item['status'] != 'delivered' &&
        _validId(item['order_item_id']) != null &&
        _validId(item['order_id']) != null &&
        _validQuantity(item['quantity']) != null).toList();
    if (actionable.isEmpty) return;
    final quantityTotal = actionable.fold<int>(0,
        (total, item) => total + (_validQuantity(item['quantity']) ?? 0));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm manual kitchen handoff'),
        content: Text('Copy ${actionable.length} filtered items ($quantityTotal units) '
            'from the current authorized board? This does not dispatch tickets, '
            'change kitchen status, or guarantee the complete backlog. '
            'Verify live orders before preparing food.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Copy handoff')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    // The board may have changed while the dialog was open.
    if (loading || error != null || updating.isNotEmpty ||
        _editingInstructions || !_boardSnapshotFresh || !_boardComplete ||
        actionable.any((row) => !_isCurrentBoardItem(
            _validId(row['order_item_id']) ?? -1, row['status'].toString()))) {
      await _requestFreshBoard();
      return;
    }
    final lines = <String>[
      'TABLE ORDERS — STAFF HANDOFF (manual copy; not dispatched)',
      'Generated: ${orderTimeLabel(DateTime.now().toUtc().toIso8601String(), label: 'Snapshot')}',
      'Authorized, filtered items: ${actionable.length} | Total units: $quantityTotal',
      'Note: this is a filtered snapshot, not an automatic kitchen dispatch.',
      for (final item in actionable)
        'Table ${item['table_number'] ?? 'Unknown'} | '
        'Order #${item['order_id']} | Item #${item['order_item_id']} | '
        '${_handoffField(item['product_name'])} x ${item['quantity'] ?? '?'} | '
        '${stages[item['status']] ?? item['status']}',
      'Verify live status before taking action; this copy may become outdated.',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Copied ${actionable.length} authorized items for manual handoff. '
          'No kitchen ticket was dispatched.'),
    ));
  }

  Widget _queueMetric(String title, int count, IconData icon) => Semantics(
    container: true,
    label: '$title: $count authorized order items',
    child: Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF183C54),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF36546B)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 19, color: const Color(0xFFE1B75E)),
          const Spacer(),
          Text('$count', style: const TextStyle(color: Colors.white,
            fontWeight: FontWeight.w800, fontSize: 22)),
        ]),
        const SizedBox(height: 9),
        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFFDAE5EE), fontSize: 12)),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Table choices are derived exclusively from the permission-scoped board.
    // No unrestricted table lookup is performed to populate this filter.
    final availableTables = items.map((i) => i['table_number']?.toString().trim())
        .whereType<String>().where((number) => number.isNotEmpty).toSet().toList()
      ..sort((a, b) {
        final an = int.tryParse(a);
        final bn = int.tryParse(b);
        if (an != null && bn != null) return an.compareTo(bn);
        return a.compareTo(b);
      });
    final activeTable = availableTables.contains(selectedTable) ? selectedTable : 'All';
    final visible = items.where((i) =>
        (selected == 'All' || i['status'] == selected) &&
        (activeTable == 'All' || i['table_number']?.toString().trim() == activeTable) &&
        _matchesSearch(i) &&
        (!showWaitingOnly || ((_waitingMinutes(i) ?? -1) >= waitingThresholdMinutes))).toList()
      ..sort(_compareItems);
    // Counts use only the employee-authorized, fully fetched board rows.
    final awaitingAcceptance = visible.where((row) => row['status'] == 'not_accepted').length;
    final inPreparation = visible.where((row) => row['status'] == 'preparing').length;
    final readyForPickup = visible.where((row) => row['status'] == 'prepared').length;
    final awaitingDelivery = visible.where((row) => row['status'] != 'delivered').length;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF071D31),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF29455C)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.space_dashboard_rounded, color: Color(0xFFD9A744)),
              SizedBox(width: 9),
              Expanded(child: Text('Order queue', style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19))),
            ]),
            const SizedBox(height: 5),
            Text(loading ? 'Loading authorized order items…' :
              error != null ? 'Unable to load the queue' :
              '${visible.length} matching items • ${items.length} authorized items',
              style: const TextStyle(color: Color(0xFFCBD7E0), fontSize: 12)),
            const SizedBox(height: 13),
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 580 ? 4 : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                childAspectRatio: columns == 4 ? 1.6 : 1.45,
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
                children: [
                  _queueMetric('New', awaitingAcceptance, Icons.notifications_active_outlined),
                  _queueMetric('Preparing', inPreparation, Icons.soup_kitchen_outlined),
                  _queueMetric('Ready', readyForPickup, Icons.check_circle_outline),
                  _queueMetric('Undelivered', awaitingDelivery, Icons.delivery_dining_outlined),
                ],
              );
            }),
            if (!_boardComplete && !loading && error == null)
              const Padding(padding: EdgeInsets.only(top: 10), child: Text(
                'Queue incomplete — totals are partial; actions stay protected.',
                style: TextStyle(color: Color(0xFFFFD88A), fontSize: 12))),
          ]),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _showReplacementReceiptHistory,
          icon: const Icon(Icons.receipt_long),
          label: const Text('My replacement receipts (all devices)'),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => _lookupReplacementRequestId(),
          icon: const Icon(Icons.manage_search),
          label: const Text('Find replacement by request ID'),
        ),
      ),
      if (_pendingReplacement != null) MaterialBanner(
        content: Text('Replacement request ${_pendingReplacement!['request_id']} has a saved recovery identity. Verify its server receipt before another replacement.'),
        actions: [TextButton(
          onPressed: _checkingReplacement ? null : _checkPendingReplacement,
          child: Text(_checkingReplacement ? 'Checking…' : 'Check receipt'))],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => searchQuery = value),
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            filled: true,
            prefixIcon: const Icon(Icons.search, color: Color(0xFFD9A744)),
            labelText: 'Search orders',
            helperText: 'Search only orders you are authorized to view',
            hintText: 'Table, product, order ID, item ID or status',
            suffixIcon: searchQuery.isEmpty ? null : IconButton(
              tooltip: 'Clear search',
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() => searchQuery = '');
              },
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 390;
          final tablePicker = Semantics(
            label: 'Filter orders by table',
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: activeTable,
              decoration: InputDecoration(
                labelText: 'Table',
                prefixIcon: const Icon(Icons.table_restaurant_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              items: [
                const DropdownMenuItem(value: 'All', child: Text('All authorized tables')),
                for (final number in availableTables)
                  DropdownMenuItem(value: number, child: Text('Table $number')),
              ],
              onChanged: loading || error != null ? null : (value) {
                if (value != null) setState(() => selectedTable = value);
              },
            ),
          );
          final waitingFilter = Semantics(
            label: 'Show orders waiting longer than selected threshold',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: FilterChip(
                label: const Text('Waiting longer than'),
                selected: showWaitingOnly,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: loading || error != null ? null : (value) =>
                    setState(() => showWaitingOnly = value),
              ),
            ),
          );
          final waitingDuration = Semantics(
            label: 'Waiting time threshold in minutes',
            child: DropdownButton<int>(
              value: waitingThresholdMinutes,
              isDense: false,
              items: const [15, 30, 60, 120].map((minutes) =>
                  DropdownMenuItem(value: minutes, child: Text('$minutes min'))).toList(),
              onChanged: loading || error != null ? null : (value) {
                if (value != null) setState(() => waitingThresholdMinutes = value);
              },
            ),
          );
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            tablePicker,
            const SizedBox(height: 8),
            if (compact) ...[
              waitingFilter,
              const SizedBox(height: 4),
              waitingDuration,
            ] else Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [waitingFilter, waitingDuration],
            ),
            const SizedBox(height: 4),
            Text('Actions require a board refreshed within 2 minutes',
              style: Theme.of(context).textTheme.bodySmall),
            if (!_boardSnapshotFresh && !loading && error == null)
              ActionChip(
                avatar: const Icon(Icons.sync_problem_outlined, size: 18),
                label: const Text('Refresh stale orders'),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onPressed: updating.isNotEmpty || _editingInstructions ? null : refresh,
              ),
          ]);
        }),
      ),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Align(alignment: Alignment.centerLeft,
          child: Text('Showing ${visible.length} of ${items.length} authorized items',
            style: Theme.of(context).textTheme.bodySmall))),
      // Aggregate only the authorized, currently filtered records. Never infer
      // hidden orders or amounts from records the employee cannot read.
      // This visual overview is built only from the permission-scoped order
      // board already loaded above. It does NOT claim to show all tables,
      // reservations, seating availability or guest/payment details.
      if (!loading && error == null && availableTables.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF071D31),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.grid_view_rounded, color: Color(0xFFD9A744)),
                SizedBox(width: 8),
                Expanded(child: Text('Tables with authorized order items',
                  style: TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 5),
              const Text('Order activity overview · not a live seating or reservation map',
                style: TextStyle(color: Color(0xFFCBD7E0), fontSize: 11)),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 620 ? 5 :
                    constraints.maxWidth >= 390 ? 3 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: availableTables.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns, crossAxisSpacing: 8,
                    mainAxisSpacing: 8, childAspectRatio: 1.45),
                  itemBuilder: (context, index) {
                    final tableNumber = availableTables[index];
                    final tableItems = items.where((row) =>
                      row['table_number']?.toString().trim() == tableNumber).toList();
                    final pending = tableItems.where((row) =>
                      row['status'] != 'delivered').length;
                    final isSelected = activeTable == tableNumber;
                    return Material(
                      color: isSelected ? const Color(0xFFD9A744) :
                        const Color(0xFF183C54),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() =>
                          selectedTable = isSelected ? 'All' : tableNumber),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.table_restaurant_outlined, size: 20,
                                color: isSelected ? const Color(0xFF071D31) :
                                  const Color(0xFFD9A744)),
                              Text('Table $tableNumber', maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w800,
                                  color: isSelected ? const Color(0xFF071D31) : Colors.white)),
                              Text('$pending pending · ${tableItems.length} items',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10,
                                  color: isSelected ? const Color(0xFF071D31) :
                                    const Color(0xFFCBD7E0))),
                            ]),
                        ),
                      ),
                    );
                  },
                );
              }),
              if (activeTable != 'All')
                Align(alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() => selectedTable = 'All'),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Show all tables'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFD9A744)),
                  )),
            ]),
          ),
        ),
      if (!loading && error == null && items.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Wrap(
            spacing: 8, runSpacing: 6,
            children: [
              Chip(
                avatar: const Icon(Icons.table_restaurant_outlined, size: 17),
                label: Text('Tables: ${visible.map((i) => i['table_number']?.toString()).where((v) => v != null && v.isNotEmpty).toSet().length}'),
              ),
              Chip(
                avatar: const Icon(Icons.receipt_long_outlined, size: 17),
                label: Text('Orders: ${visible.map((i) => _validId(i['order_id'])).whereType<int>().toSet().length}'),
              ),
              Chip(
                avatar: const Icon(Icons.pending_actions_outlined, size: 17),
                label: Text('Awaiting delivery: ${visible.where((i) => i['status'] != 'delivered').length}'),
              ),
              if (searchQuery.isNotEmpty || selected != 'All' || activeTable != 'All')
                ActionChip(
                  avatar: const Icon(Icons.filter_alt_off_outlined, size: 17),
                  label: const Text('Clear filters'),
                  onPressed: () => setState(() {
                    selected = 'All';
                    selectedTable = 'All';
                    searchQuery = '';
                    _searchController.clear();
                  }),
                ),
            ],
          ),
        ),
      if (!loading && error == null &&
          visible.any((i) => i['status'] != 'delivered' &&
              _validId(i['order_item_id']) != null &&
              _validId(i['order_id']) != null))
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: updating.isNotEmpty || _editingInstructions || !_boardSnapshotFresh || !_boardComplete ? null : () => copyKitchenHandoff(visible),
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Copy filtered kitchen handoff'),
            ),
          ),
        ),
      if (!loading && error == null && !_boardComplete)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text('Kitchen handoff disabled: order board is incomplete. Use the live kitchen queue.'),
        ),
      Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 0), child: Row(
        children: [
          const Icon(Icons.sort, size: 18),
          const SizedBox(width: 8),
          const Text('Sort queue'),
          const SizedBox(width: 12),
          Flexible(child: DropdownButton<String>(
            value: sortMode,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'oldest', child: Text('Oldest first')),
              DropdownMenuItem(value: 'action', child: Text('Needs action first')),
              DropdownMenuItem(value: 'newest', child: Text('Newest first')),
              DropdownMenuItem(value: 'table', child: Text('By table number')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => sortMode = value);
            },
          )),
        ],
      )),
      if (!loading && error == null && visible.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Pending acceptance: ${visible.where((i) => i['status'] == 'not_accepted').length}  ·  '
              'Preparing: ${visible.where((i) => i['status'] == 'preparing').length}  ·  '
              'Ready for pickup: ${visible.where((i) => i['status'] == 'prepared').length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      Padding(padding: const EdgeInsets.all(10), child: Wrap(
        spacing: 7, runSpacing: 7, crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Order fulfillment', style: TextStyle(fontWeight: FontWeight.bold)),
          ChoiceChip(label: const Text('All'), selected: selected == 'All',
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: (_) => setState(() => selected = 'All')),
          for (final entry in stages.entries)
            ChoiceChip(label: Text('${entry.value} (${items.where((i) => i['status'] == entry.key).length})'),
              selected: selected == entry.key,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onSelected: (_) => setState(() => selected = entry.key)),
          IconButton(onPressed: loading || updating.isNotEmpty || _editingInstructions ? null : refresh,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.refresh), tooltip: 'Refresh orders'),
        ],
      )),
      if (loading) const LinearProgressIndicator(semanticsLabel: 'Loading authorized orders'),
      if (error != null) Padding(padding: const EdgeInsets.all(12),
        child: Semantics(liveRegion: true, child: Card(
          child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8), const Expanded(child: Text('Orders could not be loaded', style: TextStyle(fontWeight: FontWeight.bold)))]),
              const SizedBox(height: 8), Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 8), OutlinedButton.icon(
                onPressed: updating.isNotEmpty || _editingInstructions ? null : refresh,
                icon: const Icon(Icons.refresh), label: const Text('Retry securely')),
            ],
          )),
        ))),
      Expanded(child: visible.isEmpty
        ? Center(child: Padding(padding: const EdgeInsets.all(20),
            child: Semantics(liveRegion: true, child: Column(
              mainAxisSize: MainAxisSize.min, children: [
                Icon(loading ? Icons.hourglass_top : error != null ? Icons.cloud_off_outlined : Icons.inbox_outlined,
                  size: 42, color: const Color(0xFFD9A744)),
                const SizedBox(height: 12),
                Text(error != null ? 'Authorized order items are unavailable.'
                  : loading ? 'Loading authorized order items…'
                  : items.isEmpty ? 'No authorized order items found.'
                  : 'No orders match your current filters.', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                if (!loading && error == null && items.isNotEmpty)
                  OutlinedButton.icon(onPressed: () => setState(() {
                    searchQuery = ''; _searchController.clear(); selected = 'All';
                    selectedTable = 'All'; showWaitingOnly = false;
                  }), icon: const Icon(Icons.filter_alt_off_outlined), label: const Text('Clear filters')),
                if (!loading && error == null && items.isEmpty)
                  TextButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh), label: const Text('Refresh orders')),
              ],
            )),
          ))
        : ListView.builder(itemCount: visible.length, itemBuilder: (context, index) {
          final i = visible[index];
          final id = _validId(i['order_item_id']);
          final orderId = _validId(i['order_id']);
          final status = i['status'].toString();
          final next = const <String, String>{
            'not_accepted':'Accept', 'accepted':'Start preparing',
            'preparing':'Mark prepared', 'prepared':'Pick up',
            'picked_up':'Confirm delivery',
          }[status];
          final stageColor = <String, Color>{
            'not_accepted': const Color(0xFFC98738),
            'accepted': const Color(0xFF468CC4),
            'preparing': const Color(0xFFBD8B43),
            'prepared': const Color(0xFF32A38B),
            'picked_up': const Color(0xFF4F91C6),
            'delivered': const Color(0xFF2B9B74),
          }[status] ?? const Color(0xFFB6C1CC);
          final canEdit = !loading && error == null && id != null &&
              updating.isEmpty && !_editingInstructions && _boardSnapshotFresh;
          final canInspect = !loading && error == null && orderId != null && !_editingInstructions;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                LayoutBuilder(builder: (context, cardConstraints) {
                  final compact = cardConstraints.maxWidth < 350 ||
                      MediaQuery.textScalerOf(context).scale(16) > 22;
                  final tableBadge = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFF5E7C8),
                      borderRadius: BorderRadius.circular(12)),
                    child: Text('T${i['table_number'] ?? '?'}',
                      style: const TextStyle(color: Color(0xFF071D31), fontWeight: FontWeight.w800)));
                  final productInfo = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((i['product_name'] ?? 'Unnamed product').toString(),
                      softWrap: true, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('Order #${i['order_id']}  •  Qty ${i['quantity']}',
                      style: Theme.of(context).textTheme.bodySmall),
                  ]);
                  final statusBadge = Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(color: stageColor.withOpacity(.13),
                      borderRadius: BorderRadius.circular(20)),
                    child: Semantics(label: 'Order item status: ${stages[status] ?? status}',
                      child: Text(stages[status] ?? status, softWrap: true,
                        style: TextStyle(color: stageColor, fontWeight: FontWeight.w700, fontSize: 12))));
                  if (compact) {
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
                        children: [tableBadge, statusBadge]),
                      const SizedBox(height: 10),
                      productInfo,
                    ]);
                  }
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    tableBadge, const SizedBox(width: 10),
                    Expanded(child: productInfo), const SizedBox(width: 8),
                    Flexible(child: Align(alignment: Alignment.topRight, child: statusBadge)),
                  ]);
                }),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 5, children: [
                  Text(orderTimeLabel(i['created_at']), style: Theme.of(context).textTheme.bodySmall),
                  Text(_waitingMinutes(i) == null ? 'Wait: unavailable/completed'
                      : 'Wait: ${_waitingMinutes(i)} min at refresh',
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
                const SizedBox(height: 8),
                Text(status == 'delivered' ? 'Delivered • editing locked'
                    : 'Pre-delivery changes require authorization',
                  style: Theme.of(context).textTheme.bodySmall),
                const Divider(height: 24),
                Semantics(header: true, child: Text('Order actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                const SizedBox(height: 12),
                _orderActionPanel(
                  context: context,
                  icon: Icons.receipt_long_outlined,
                  title: 'History & printing',
                  subtitle: 'Inspect printing, revisions and item timestamps',
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(
                      onPressed: canInspect ? () => showRevisionDispatch(i) : null,
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Print status')),
                    OutlinedButton.icon(
                      onPressed: canInspect ? () => showOrderRevisions(i) : null,
                      icon: const Icon(Icons.manage_history),
                      label: const Text('Revisions')),
                    OutlinedButton.icon(
                      onPressed: !loading && error == null && id != null && !_editingInstructions
                        ? () => showItemTimeline(i) : null,
                      icon: const Icon(Icons.history),
                      label: const Text('Timeline')),
                  ]),
                ),
                if (status == 'not_accepted') ...[
                  const SizedBox(height: 12),
                  _orderActionPanel(
                    context: context,
                    icon: Icons.edit_note_outlined,
                    title: 'Pre-acceptance corrections',
                    subtitle: 'Authorized changes are audited',
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton.icon(
                        onPressed: canEdit ? () => replaceProduct(i) : null,
                        icon: const Icon(Icons.swap_horiz), label: const Text('Replace product')),
                      OutlinedButton.icon(
                        onPressed: canEdit ? () => editQuantity(i) : null,
                        icon: const Icon(Icons.exposure_outlined), label: const Text('Quantity')),
                      OutlinedButton.icon(
                        onPressed: canEdit ? () => editInstructions(i) : null,
                        icon: const Icon(Icons.edit_note_outlined), label: const Text('Instructions')),
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                _orderActionPanel(
                  context: context,
                  icon: Icons.arrow_circle_right_outlined,
                  title: 'Order status',
                  subtitle: 'Advance this item through its authorized workflow',
                  child: next == null
                    ? Semantics(label: 'Order item workflow completed',
                        child: Chip(avatar: Icon(Icons.check_circle_outline, size: 17),
                          label: Text('Completed')))
                    : Semantics(
                        button: true, enabled: canEdit,
                        label: 'Advance order item to $next',
                        hint: canEdit ? 'Updates the order item status' : 'Unavailable without permission or while busy',
                        child: SizedBox(width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: canEdit ? () => advance(i) : null,
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: Text(next),
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                          )),
                      ),
                ),
              ]),
            ),
          );
        })),
      const Padding(padding: EdgeInsets.all(8), child: Text(
        'Per-item status. Delivery quantities and station tickets are managed separately. '
        'Refresh to see changes from other devices.', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12))),
    ]);
  }
}


Widget _orderActionPanel({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  required Widget child,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: scheme.surfaceContainerLow,
      border: Border.all(color: scheme.outlineVariant),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 21, color: const Color(0xFFC99A3A)),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ])),
      ]),
      const SizedBox(height: 12),
      child,
    ]),
  );
}


/// Read-only, authorized table cards above the existing order workspace.
/// Table status is sourced from gs_cafe_tables, never inferred from local orders.
class _TableOrderCards extends StatefulWidget {
  const _TableOrderCards();
  @override
  State<_TableOrderCards> createState() => _TableOrderCardsState();
}

class _TableOrderCardsState extends State<_TableOrderCards> {
  bool _loading = true;
  bool _expanded = true;
  bool _filtersOpen = true;
  String _occupancyFilter = 'Any';
  String _updatedWithin = 'Any time';
  String? _error;
  String _filter = 'All';
  String _search = '';
  int _minimumSeats = 0;
  Map<String, dynamic>? _selectedTable;
  List<Map<String, dynamic>> _tables = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await Supabase.instance.client
          .from('gs_cafe_tables')
          .select('table_number,capacity,occupied,guests,tourism_mode,cleaning_needed,updated_at')
          .order('table_number');
      final rows = List<Map<String, dynamic>>.from(result);
      final ids = <int>{};
      for (final row in rows) {
        final id = row['table_number'];
        if (id is! num || id.toInt() <= 0 || id != id.toInt() ||
            !ids.add(id.toInt()) ||
            row['occupied'] is! bool ||
            row['cleaning_needed'] is! bool) {
          throw const FormatException('Invalid authorized table data');
        }
      }
      if (mounted) setState(() => _tables = rows);
    } catch (_) {
      if (mounted) setState(() {
        _tables = [];
        _error = 'Table cards unavailable. Check table access and retry.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _status(Map<String, dynamic> row) {
    if (row['cleaning_needed'] == true) return 'Cleaning';
    if (row['occupied'] == true) return 'Occupied';
    return 'Available';
  }

  Widget _buildSelectedTable(BuildContext context) {
    final row = _selectedTable!;
    final number = row['table_number'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Table $number · ${_status(row)}',
                style: const TextStyle(fontWeight: FontWeight.bold))),
            IconButton(tooltip: 'Close table details',
              onPressed: () => setState(() => _selectedTable = null),
              icon: const Icon(Icons.close)),
          ]),
          Text('Capacity: ${row['capacity'] ?? 'Unknown'} · '
              'Guests: ${row['guests'] ?? 'Unverified'}'),
          const Text('Orders and partial payments are not inferred from seating status. '
              'Open the source workspace to review the active visit and its authorization.',
              style: TextStyle(fontSize: 12)),
          Wrap(spacing: 6, runSpacing: 6, children: [
            OutlinedButton.icon(icon: const Icon(Icons.receipt_long),
              label: const Text('Orders / visit'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const TablesScreen()))),
            OutlinedButton.icon(icon: const Icon(Icons.payments_outlined),
              label: const Text('Standing Cash / partial payment'),
              onPressed: row['occupied'] == true ? () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) =>
                  const PaymentsManagementScreen(initialFocus: 'standing'))) : null),
            OutlinedButton.icon(icon: const Icon(Icons.room_service_outlined),
              label: const Text('Guest requests'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const TablesScreen()))),
            OutlinedButton.icon(icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Authorized staff actions'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const TablesScreen()))),
          ]),
          const Text('Source screens enforce employee permissions. This panel does not '
              'submit payments, modify orders, or assume Table 03 has an active bill.',
              style: TextStyle(fontSize: 11)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = _tables.where((row) {
      final status = _status(row);
      final guests = row['guests'];
      final matchesGuests = _occupancyFilter == 'Any' ||
          (_occupancyFilter == 'With guests' && guests is num && guests > 0) ||
          (_occupancyFilter == 'No guests' && guests is num && guests == 0);
      // This is the table's last-update time, NOT an order or visit time.
      // Missing or malformed timestamps never pass an active time filter.
      final rawUpdated = row['updated_at'];
      final updated = rawUpdated is String ? DateTime.tryParse(rawUpdated) : null;
      final now = DateTime.now().toUtc();
      final age = updated == null ? null : now.difference(updated.toUtc());
      final matchesTime = _updatedWithin == 'Any time' ||
          (age != null && !age.isNegative &&
            (_updatedWithin == 'Last hour' && age <= const Duration(hours: 1) ||
             _updatedWithin == 'Today (24h)' && age <= const Duration(hours: 24) ||
             _updatedWithin == 'Last 7 days' && age <= const Duration(days: 7)));
      return matchesTime && matchesGuests && (_filter == 'All' || _filter == status) &&
          row['table_number'].toString().contains(_search.trim()) &&
          (row['capacity'] is num && (row['capacity'] as num) >= _minimumSeats);
    }).toList();
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Expanded(child: Text('Tables · Live cards',
                style: TextStyle(fontWeight: FontWeight.bold))),
            IconButton(
              tooltip: 'Refresh authorized tables',
              onPressed: _loading ? null : _reload,
              icon: const Icon(Icons.refresh)),
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Hide' : 'Show')),
          ]),
          if (_expanded) ...[
            Row(children: [
              Expanded(child: Text('Showing ${shown.length} of ${_tables.length} authorized tables',
                  style: const TextStyle(fontSize: 12))),
              TextButton.icon(
                icon: const Icon(Icons.filter_list),
                label: Text(_filtersOpen ? 'Hide filters' : 'Show filters'),
                onPressed: () => setState(() => _filtersOpen = !_filtersOpen)),
            ]),
            if (_filtersOpen) Wrap(spacing: 6, runSpacing: 6, children: [
              SizedBox(width: 135, child: TextField(
                decoration: const InputDecoration(
                  isDense: true, labelText: 'Table number'),
                onChanged: (v) => setState(() => _search = v))),
              DropdownButton<int>(
                value: _minimumSeats,
                items: [0, 2, 4, 6, 8].map((v) => DropdownMenuItem(
                  value: v, child: Text(v == 0 ? 'Any seats' : '$v+ seats'))).toList(),
                onChanged: (v) { if (v != null) setState(() => _minimumSeats = v); },
              ),
              DropdownButton<String>(
                value: _occupancyFilter,
                items: ['Any', 'With guests', 'No guests']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) { if (v != null) setState(() => _occupancyFilter = v); },
              ),
              DropdownButton<String>(
                value: _updatedWithin,
                items: ['Any time', 'Last hour', 'Today (24h)', 'Last 7 days']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) { if (v != null) setState(() => _updatedWithin = v); },
              ),
              TextButton.icon(
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset filters'),
                onPressed: () => setState(() {
                  _filter = 'All';
                  _minimumSeats = 0;
                  _occupancyFilter = 'Any';
                  _updatedWithin = 'Any time';
                  _search = '';
                })),
              DropdownButton<String>(
                value: _filter,
                items: ['All', 'Available', 'Occupied', 'Cleaning']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) { if (v != null) setState(() => _filter = v); },
              ),
            ]),
            if (_filtersOpen) const Align(
              alignment: Alignment.centerLeft,
              child: Text('Time filter: last table update (not order or visit time). '
                  'Filters apply to authorized returned tables only.',
                  style: TextStyle(fontSize: 11))),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (!_loading && _error == null)
              SizedBox(height: 155, child: LayoutBuilder(
                builder: (context, constraints) => GridView.builder(
                  itemCount: shown.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: constraints.maxWidth >= 640 ? 4 : 2,
                    mainAxisSpacing: 6, crossAxisSpacing: 6,
                    childAspectRatio: constraints.maxWidth >= 640 ? 2.4 : 2.0),
                  itemBuilder: (context, index) {
                    final row = shown[index];
                    final status = _status(row);
                    return OutlinedButton(
                      onPressed: () => setState(() => _selectedTable = row),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Table ${row['table_number']}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(status, style: const TextStyle(fontSize: 12)),
                          Text('Seats: ${row['capacity'] ?? 'Unknown'}',
                              style: const TextStyle(fontSize: 11)),
                        ]),
                    );
                  },
                ),
              )),
            if (_selectedTable != null) _buildSelectedTable(context),
            const Align(alignment: Alignment.centerLeft,
              child: Text('Cards show authorized table state only. Order totals and payment eligibility '
                  'must be checked in their secured source workspaces.',
                  style: TextStyle(fontSize: 11))),
          ],
        ]),
      ),
    );
  }
}
