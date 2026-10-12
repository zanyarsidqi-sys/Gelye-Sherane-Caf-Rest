import 'gelye_section_header.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/employee_permission_service.dart';
import 'inventory_catalog_panel.dart';
import 'customer_activity_panel.dart';
import 'cost_planning_panel.dart';
import 'invoice_review_panel.dart';
import 'notification_center_panel.dart';
import 'reports_workspace_panel.dart';
import 'analytics_workspace_panel.dart';
import 'action_center_panel.dart';
import 'payments_management_panel.dart';
import 'settings_rules_panel.dart';
import 'appearance_preferences_panel.dart';
import 'language_preferences_panel.dart';

class SectionShell extends StatefulWidget {
  final String title;
  final String description;
  final String sectionId;
  final Widget? authorizedContent;
  const SectionShell({
    super.key,
    required this.title,
    required this.description,
    required this.sectionId,
    this.authorizedContent,
  });
  @override
  State<SectionShell> createState() => _SectionShellState();
}

class _SectionShellState extends State<SectionShell> with WidgetsBindingObserver {
  final EmployeePermissionService _permissionService =
      EmployeePermissionService();
  late Future<bool> _accessFuture;
  // Periodically revalidate section access, including revoked staff roles.
  Timer? _periodicAccessRecheck;
  static const Duration _accessRecheckInterval = Duration(minutes: 10);
  StreamSubscription<AuthState>? _authSubscription;
  String? _permissionUserId;
  int _accessGeneration = 0;
  // Bound each network operation; an unresponsive server must never leave a
  // section indefinitely waiting to establish employee permissions.
  static const Duration _permissionTimeout = Duration(seconds: 12);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _periodicAccessRecheck = Timer.periodic(_accessRecheckInterval, (_) {
      if (!mounted || _privacyShield) return;
      // Conceal the section before any asynchronous permission lookup.
      _sessionHandoverChecks.clear();
      _refreshAccess();
    });
    _permissionUserId = Supabase.instance.client.auth.currentUser?.id;
    _accessFuture = _checkAccess();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (!mounted) return;
      // Prevent the old employee's data from remaining visible across any
      // authentication transition, including refresh and MFA transitions.
      _sessionHandoverChecks.clear();
      setState(() => _privacyShield = true);
      _refreshAccess();
    });
  }

  @override
  void dispose() {
    _periodicAccessRecheck?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _workflowSearchController.dispose();
    super.dispose();
  }

  // Recheck server-backed employee access whenever the app returns to foreground.
  // All registered management sections use this same guarded shell.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Conceal sensitive section data before the OS backgrounds the application.
    // Re-entry always requires a new server-backed permission check.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (mounted) {
        // Discard unaudited handover markers when the app is concealed.
        // An interrupted review must never look completed after re-entry.
        setState(() {
          _sessionHandoverChecks.clear();
          _privacyShield = true;
          _accessGeneration++;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      _refreshAccess();
    }
  }

  Future<bool> _checkAccess() async {
    final generation = _accessGeneration;
    final sectionAtStart = widget.sectionId;
    final userAtStart = Supabase.instance.client.auth.currentUser?.id;
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) {
        return false;
      }

      final expectedSectionId = widget.sectionId;
    final response = await client.auth.getUser().timeout(_permissionTimeout);
      final user = response.user;

      if (user == null) {
        return false;
      }

      final profile = await _permissionService.getActiveEmployee().timeout(_permissionTimeout);

      if (profile == null ||
          profile['user_id'] != user.id ||
          profile['is_active'] != true) {
        return false;
      }

      final allowed = await _permissionService.getAllowedSections().timeout(_permissionTimeout);
      // Never grant permissions from an old employee's in-flight lookup.
      if (client.auth.currentUser?.id != user.id) return false;
      return generation == _accessGeneration &&
          widget.sectionId == sectionAtStart &&
          widget.sectionId == expectedSectionId &&
          userAtStart == user.id &&
          allowed.contains(expectedSectionId);
    } catch (_) {
      return false;
    }
  }

  void _refreshAccess() {
    if (!mounted) return;
    late final Future<bool> check;
    setState(() {
      _privacyShield = true;
      _accessGeneration++;
      _permissionUserId = Supabase.instance.client.auth.currentUser?.id;
      check = _checkAccess();
      _accessFuture = check;
    });
    final generation = _accessGeneration;
    check.then((allowed) {
      if (!mounted || generation != _accessGeneration ||
          !identical(_accessFuture, check)) return;
      if (allowed) setState(() => _privacyShield = false);
    });
  }

  @override
  void didUpdateWidget(covariant SectionShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sectionId != widget.sectionId) {
      // Do not leak a previous section's workflow filter into the next one.
      _search = '';
      _sessionHandoverChecks.clear();
      _workflowSearchController.clear();
      _privacyShield = true;
      _refreshAccess();
    }
  }

  Widget _accessDenied() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Access Unavailable',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your employee session or permission could not be verified.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _refreshAccess,
              icon: const Icon(Icons.refresh),
              label: const Text('Check Again'),
            ),
          ],
        ),
      ),
    );
  }

  static const Map<String, List<String>> _moduleFeatures = {
    'dashboard': <String>[
      'Live order totals',
      'Active tables',
      'Tourism customer sales',
      'Kitchen queue',
      'Motel order totals',
      'Revenue by payment method'
    ],
    'tables': <String>[
      'Table map and availability',
      'Normal Mode by default',
      'Activate Tourism Mode',
      'Open table orders',
      'Transfer or merge tables',
      'Close table and release seating'
    ],
    'table_orders': <String>[
      'Create table order',
      'Barcode and product search',
      'Normal or Tourism pricing',
      'Send to kitchen',
      'Split and merge bills',
      'Payment and receipt'
    ],
    'motel_orders': <String>[
      'Select motel room or villa',
      'Tourism prices enforced',
      'Room-linked orders',
      'Send to kitchen',
      'Room account settlement',
      'Guest delivery status'
    ],
    'kitchen': <String>[
      'New orders queue',
      'Preparing and ready status',
      'Order priority and timing',
      'Kitchen item notes',
      'Preparation stations',
      'Completed orders history'
    ],
    'menu': <String>[
      'Menu categories',
      'Product barcode and photo',
      'Normal selling price',
      'Tourism selling price',
      'Availability and modifiers',
      'Price change history'
    ],
    'products_inventory': <String>[
      'Product catalog and barcodes',
      'Stock receipts and adjustments',
      'Supplier and purchase cost',
      'Low stock and reorder alerts',
      'Expiry and batches',
      'Stocktaking and audit'
    ],
    'customers': <String>[
      'Customer directory',
      'Tourism customer tracking',
      'Visit and order history',
      'Customer credit limits',
      'Loyalty and preferences',
      'Privacy and access rules'
    ],
    'cost': <String>[
      'Expense categories',
      'Daily expense entry',
      'Supplier expenses',
      'Employee cost allocation',
      'Approval workflow',
      'Cost by period and department'
    ],
    'revenue': <String>[
      'Daily and monthly sales',
      'Normal vs Tourism revenue',
      'Revenue by section',
      'Revenue by payment method',
      'Refund and cancellation effects',
      'Reconciliation'
    ],
    'invoices_payments': <String>[
      'Invoice list and detail',
      'Receipts and refunds',
      'Cash and electronic payments',
      'Invoice status',
      'Print and share invoice',
      'Payment reconciliation'
    ],
    'employees': <String>[
      'Employee profiles',
      'Roles and section permissions',
      'Shift and attendance',
      'Payroll and transport',
      'Device sessions and MFA',
      'Audit of employee actions'
    ],
    'maintenance': <String>[
      'Maintenance requests',
      'Priority and assignment',
      'Equipment registry',
      'Repair costs',
      'Progress and completion',
      'Maintenance history'
    ],
    'notifications': <String>[
      'New order alerts',
      'Kitchen ready notifications',
      'Employee assignments',
      'Payment alerts',
      'Stock and price alerts',
      'Read and delivery status'
    ],
    'reports': <String>[
      'Sales report',
      'Tourism pricing report',
      'Inventory report',
      'Employee performance',
      'Expense and profitability',
      'Export and date filters'
    ],
    'backup_restore': <String>[
      'Backup schedules',
      'Backup verification',
      'Encrypted backup destinations',
      'Restore preview',
      'Recovery test log',
      'Retention rules'
    ],
    'settings_rules': <String>[
      'Business hours and currency',
      'Table and motel rules',
      'Tourism pricing policy',
      'Tax and service settings',
      'Approvals and thresholds',
      'Audit settings'
    ],
    'analytics': <String>[
      'Revenue trends',
      'Product performance',
      'Tourism vs Normal comparison',
      'Peak service hours',
      'Profit and cost trends',
      'Staff and service metrics'
    ],
    'action_center': <String>[
      'Pending approvals',
      'Overdue orders',
      'Low stock tasks',
      'Price update tasks',
      'Maintenance assignments',
      'Priority task tracking'
    ],
    'pay_now': <String>[
      'Select payable invoice',
      'Confirm amount due',
      'Cash payment',
      'Card or wallet payment',
      'Payment confirmation',
      'Receipt and transaction log'
    ],
    'discount_management': <String>[
      'Discount campaigns',
      'Eligibility by item and mode',
      'Maximum discount guardrails',
      'Manager approval',
      'Discount history',
      'Profit impact preview'
    ],
    'payments_management': <String>[
      'Cashier settlement',
      'Cash and card reconciliation',
      'Wallet and bank transfers',
      'Payment failures',
      'Refund requests',
      'Shift closing'
    ],
    'credit_management': <String>[
      'Credit customer accounts',
      'Credit sale approval',
      'Outstanding balances',
      'Partial repayments',
      'Due dates and reminders',
      'Credit aging report'
    ],
    'device_layout_mode': <String>[
      'Automatic device detection',
      'iPhone bottom navigation',
      'Windows sidebar layout',
      'Tablet adaptive grids',
      'Accessibility sizing',
      'Per-device preferences'
    ],
    'appearance_dark_mode': <String>[
      'Light and dark themes',
      'System theme preference',
      'Brand colors',
      'Typography and density',
      'Theme preview',
      'Per-user appearance settings'
    ],
    'dictionary_language_management': <String>[
      'English and Kurdish labels',
      'Arabic translations',
      'Translation search',
      'Custom terms',
      'Fallback language',
      'RTL support'
    ],
    'websites_management': <String>[
      'Public café website',
      'Online menu publishing',
      'Customer online ordering',
      'Table reservations',
      'Contact and location details',
      'Publication settings'
    ],
    'general_information': <String>[
      'Business identity and logo',
      'Branches and locations',
      'Contact details',
      'Working hours',
      'Legal and tax details',
      'Public profile settings'
    ],
    'invoice_design_customization': <String>[
      'Receipt template',
      'Logo and header',
      'Tax and service breakdown',
      'Footer and policies',
      'Printer paper sizes',
      'Preview and print'
    ],
    'security_access_control': <String>[
      'Role and section matrix',
      'MFA enforcement',
      'Saved device sessions',
      'Login and activity history',
      'Permission review',
      'Session revocation'
    ],
    'offline_mode_synchronization': <String>[
      'Local device queue',
      'Connectivity status',
      'Conflict detection',
      'Offline order creation rules',
      'Sync retry history',
      'Server reconciliation'
    ],
    'app_publishing_updates': <String>[
      'App version information',
      'Windows release checklist',
      'Android and iOS releases',
      'Web deployment',
      'Release notes',
      'Rollback strategy'
    ],
    'system_health_monitoring': <String>[
      'Supabase connectivity',
      'Application errors',
      'Sync failures',
      'Database response times',
      'Background jobs',
      'System incident log'
    ],
    'test_mode_real_mode': <String>[
      'Isolated test data',
      'Mode indicator',
      'Test scenario checklist',
      'Production change safeguards',
      'Data reset rules',
      'Mode switch audit'
    ],
    'nargile_management': <String>[
      'Nargile menu and pricing',
      'Table-linked orders',
      'Flavor and equipment stock',
      'Preparation queue',
      'Cleaning and maintenance',
      'Staff and service reports'
    ],
  };

  // A local privacy shield prevents protected content from appearing on shared screens.
  bool _privacyShield = false;
  String _search = '';
  final TextEditingController _workflowSearchController = TextEditingController();

  Widget _sectionContent() {
    final allFeatures = _moduleFeatures[widget.sectionId] ?? <String>[];
    final filtered = allFeatures
        .where((item) => item.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          Text(widget.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(widget.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Icon(Icons.construction_outlined),
                const SizedBox(width: 12),
                const Expanded(child: Text(
                  'Development preview: workflows below are planned, not active buttons or live transactions.',
                )),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _workflowSearchController,
            decoration: InputDecoration(
              hintText: 'Search workflows',
              suffixIcon: _search.isEmpty ? null : IconButton(
                tooltip: 'Clear workflow search',
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _workflowSearchController.clear();
                  setState(() => _search = '');
                },
              ),
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: Text('Planned workflows', style: theme.textTheme.titleMedium)),
            Text('${filtered.length} of ${allFeatures.length}', style: theme.textTheme.labelMedium),
          ]),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No matching workflows')),
            ),
          for (var i = 0; i < filtered.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  child: Text('${allFeatures.indexOf(filtered[i]) + 1}',
                      style: theme.textTheme.labelSmall),
                ),
                title: Text(filtered[i]),
                subtitle: const Text('Planned · not yet enabled'),
                trailing: const Icon(Icons.lock_clock_outlined, size: 18),
              ),
            ),
          const SizedBox(height: 14),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.verified_user_outlined),
            title: Text('Section access'),
            subtitle: Text('Verified through the authenticated employee permission gate'),
          ),
          const ListTile(
            leading: Icon(Icons.cloud_off_outlined),
            title: Text('Live records'),
            subtitle: Text('Not enabled in this preview; no data is modified'),
          ),
        ],
      ),
    );
  }

  // Source-based classification only: this is not a production-readiness certificate.
  bool get _hasImplementedPanel => widget.authorizedContent != null ||
      const <String>{'dictionary_language_management', 'appearance_dark_mode', 'settings_rules', 'payments_management', 'action_center', 'analytics', 'reports', 'notifications', 'products_inventory', 'customers', 'cost', 'invoices_payments'}.contains(widget.sectionId);

  // Executable shared support workflow: copy a safe, section-scoped diagnostic
  // without names, tokens, personal records, balances or employee identifiers.
  Future<void> _copySectionSupportSummary() async {
    // Universal fail-closed support action: clipboard reports are unavailable
    // while hidden, signed out, or after a different permission generation.
    final sectionAtStart = widget.sectionId;
    final generationAtStart = _accessGeneration;
    final userAtStart = Supabase.instance.client.auth.currentUser?.id;
    if (!mounted || _privacyShield || userAtStart == null ||
        _permissionUserId != userAtStart) return;
    final permitted = await _accessFuture;
    if (!mounted || !permitted || _privacyShield ||
        _accessGeneration != generationAtStart ||
        widget.sectionId != sectionAtStart ||
        Supabase.instance.client.auth.currentUser?.id != userAtStart) return;
    final report = <String>[
      'Gelye Sherane section support report',
      'Section ID: $sectionAtStart',
      'Section title: ${widget.title}',
      'Flutter runtime: not verified in this release',
      'Supabase staging: not verified in this release',
      'Financial totals: not certified',
      'No customer data, authentication tokens or payment amounts included.',
    ].join('\n');
    try {
      await Clipboard.setData(ClipboardData(text: report));
      if (!mounted || widget.sectionId != sectionAtStart) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Section support summary copied')),
      );
    } catch (_) {
      if (!mounted || widget.sectionId != sectionAtStart) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to copy support summary')),
      );
    }
  }

  // Universal verification disclosure: factual and intentionally fail-closed.
  // A registered section is not certified by the existence of a widget.
  bool _verificationExpanded = false;
  Widget _verificationChecklist() {
    final style = Theme.of(context).textTheme.bodySmall;
    return ExpansionTile(
      key: ValueKey('verification_${widget.sectionId}'),
      initiallyExpanded: false,
      onExpansionChanged: (expanded) => _verificationExpanded = expanded,
      leading: const Icon(Icons.fact_check_outlined),
      title: const Text('Verification checklist'),
      subtitle: const Text('Runtime and financial certification not established'),
      children: <Widget>[
        TextButton.icon(
          onPressed: _copySectionSupportSummary,
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('Copy safe section support summary'),
        ),
        for (final check in <String>[
          'Employee access: checked before showing section content',
          'Flutter build and device behavior: not verified in this release',
          'Supabase staging integration: not verified in this release',
          'End-to-end workflow: not verified in this release',
          'Financial IQD reconciliation: not certified',
        ])
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
            child: Row(children: <Widget>[
              const Icon(Icons.info_outline, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(check, style: style)),
            ]),
          ),
      ],
    );
  }

  // Upgrade: session-only, section-scoped operational handover checklist.
  // This is a real interactive workflow, not a payment or a database write.
  // Never persist employee/customer details in local storage or a clipboard.
  final Map<String, Set<int>> _sessionHandoverChecks = <String, Set<int>>{};
  static const List<String> _handoverSteps = <String>[
    'Review outstanding work in this section',
    'Check pending approvals and assigned tasks',
    'Confirm unresolved issues are handed to the next shift',
  ];

  Widget _sectionHandoverChecklist() {
    final sectionId = widget.sectionId;
    final checked = _sessionHandoverChecks.putIfAbsent(sectionId, () => <int>{});
    return ExpansionTile(
      key: ValueKey('handover_$sectionId'),
      leading: const Icon(Icons.assignment_turned_in_outlined),
      title: const Text('Shift handover checklist'),
      subtitle: Text('${checked.length}/${_handoverSteps.length} reviewed · session only'),
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Text('Local review markers only. No task is submitted, paid, approved or synchronized.'),
        ),
        for (var index = 0; index < _handoverSteps.length; index++)
          CheckboxListTile(
            dense: true,
            value: checked.contains(index),
            title: Text(_handoverSteps[index]),
            onChanged: (value) {
              if (!mounted || widget.sectionId != sectionId || _privacyShield ||
                  Supabase.instance.client.auth.currentUser?.id != _permissionUserId) return;
              setState(() {
                if (value == true) {
                  checked.add(index);
                } else {
                  checked.remove(index);
                }
              });
            },
          ),
        TextButton.icon(
          onPressed: checked.length == _handoverSteps.length
              ? () => _copyCompletedHandover(sectionId)
              : null,
          icon: const Icon(Icons.assignment_turned_in_outlined),
          label: const Text('Copy completed handover review'),
        ),
        TextButton.icon(
          onPressed: checked.isEmpty ? null : () {
            if (!mounted || _privacyShield ||
                Supabase.instance.client.auth.currentUser?.id != _permissionUserId) return;
            setState(checked.clear);
          },
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reset this section checklist'),
        ),
      ],
    );
  }

  // Upgrade: session-scoped handover confirmation for every registered section.
  // A confirmation is only available after all checks have been reviewed.
  // No user, guest, transaction, balance or sensitive text is copied.
  Future<void> _copyCompletedHandover(String sectionId) async {
    if (!mounted || widget.sectionId != sectionId || _privacyShield ||
        Supabase.instance.client.auth.currentUser?.id != _permissionUserId) return;
    // Upgrade: an action must not rely on an old visual permission grant.
    // Re-check the current section's permission Future and generation before
    // allowing a sensitive employee workflow to complete.
    final permissionCheck = _accessFuture;
    final generation = _accessGeneration;
    final employee = _permissionUserId;
    final allowed = await permissionCheck;
    if (!allowed || !mounted || _privacyShield ||
        !identical(permissionCheck, _accessFuture) ||
        generation != _accessGeneration || widget.sectionId != sectionId ||
        employee == null || Supabase.instance.client.auth.currentUser?.id != employee) return;
    final checks = _sessionHandoverChecks[sectionId];
    if (checks == null || checks.length != _handoverSteps.length) return;
    final summary = <String>[
      'Gelye Sherane section handover review',
      'Section: $sectionId',
      'All ${_handoverSteps.length} review steps marked complete in this session.',
      'Review only: no remote task, approval, payment, or reconciliation performed.',
      'Financial totals are not certified.',
    ].join('\n');
    try {
      await Clipboard.setData(ClipboardData(text: summary));
      if (!mounted || widget.sectionId != sectionId || _privacyShield) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Handover review summary copied')),
      );
    } catch (_) {
      if (!mounted || widget.sectionId != sectionId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to copy handover summary')),
      );
    }
  }

  IconData _sectionIcon(String sectionId) {
    switch (sectionId) {
      case 'kitchen': return Icons.soup_kitchen_rounded;
      case 'menu': return Icons.restaurant_menu_rounded;
      case 'tables': return Icons.table_restaurant_rounded;
      case 'products_inventory': return Icons.inventory_2_rounded;
      case 'customers': return Icons.people_alt_rounded;
      case 'invoices_payments': return Icons.receipt_long_rounded;
      case 'system_health_monitoring': return Icons.monitor_heart_rounded;
      default: return Icons.dashboard_customize_rounded;
    }
  }

  // One action resets local section-only workflow state, conceals data, and
  // forces a new server-backed permission check before any section is shown.
  // It never clears remote orders, invoices, payments, or audit records.
  void _resetSectionWorkspace() {
    if (!mounted) return;
    _workflowSearchController.clear();
    _sessionHandoverChecks.clear();
    _search = '';
    _refreshAccess(); // fail-closed: privacy shield first, new generation
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                tooltip: 'Back to previous screen',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Reset local section workspace and verify access',
            icon: const Icon(Icons.restart_alt_outlined),
            onPressed: _resetSectionWorkspace,
          ),
          // Every one of the 35 management sections can revalidate access on demand.
          IconButton(
            tooltip: 'Recheck employee access',
            icon: const Icon(Icons.verified_user_outlined),
            onPressed: _refreshAccess,
          ),
          if (Navigator.of(context).canPop())
            TextButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('Back'),
            ),
        ],
      ),
      body: FutureBuilder<bool>(
        future: _accessFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data != true || snapshot.hasError) {
            return _accessDenied();
          }

          if (_privacyShield) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(children: [
            // Upgrade universal section safety context: all 35 registry sections.
            // Visible only AFTER the employee permission check succeeds.
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 17),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Section: ${widget.title} · Access rechecked on resume · Financial totals require independent reconciliation',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  )),
                ]),
              ),
            ),
            // Upgrade 1480: honest execution status on all 35 registered sections.
            // Only actual supplied/implemented panels are labeled interactive;
            // a catalog-only section must never imply it can process transactions.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              child: Semantics(
                liveRegion: true,
                label: _hasImplementedPanel ? 'Interactive section panel' : 'Planning preview only',
                child: Row(children: [
                  Icon(_hasImplementedPanel ? Icons.check_circle_outline : Icons.pending_outlined,
                      size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    _hasImplementedPanel
                      ? 'Interactive section panel · functionality still requires integration testing'
                      : 'Planning preview only · listed workflows cannot execute transactions',
                    style: Theme.of(context).textTheme.labelSmall,
                  )),
                ]),
              ),
            ),
            // All 35 sections expose their own conservative verification status.
            _verificationChecklist(),
            _sectionHandoverChecklist(),
            Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), child: GelyeSectionHeader(
              title: widget.title, subtitle: widget.description,
              icon: _sectionIcon(widget.sectionId),
            )),
            Expanded(child: widget.authorizedContent ??
              (widget.sectionId == 'dictionary_language_management'
                  ? const LanguagePreferencesPanel()
                  : widget.sectionId == 'appearance_dark_mode'
                  ? const AppearancePreferencesPanel()
                  : widget.sectionId == 'settings_rules'
                  ? const SettingsRulesPanel()
                  : widget.sectionId == 'payments_management'
                  ? const PaymentsManagementPanel()
                  : widget.sectionId == 'action_center'
                  ? const ActionCenterPanel()
                  : widget.sectionId == 'analytics'
                  ? const AnalyticsWorkspacePanel()
                  : widget.sectionId == 'reports'
                  ? const ReportsWorkspacePanel()
                  : widget.sectionId == 'notifications'
                  ? const NotificationCenterPanel()
                  : widget.sectionId == 'products_inventory'
                  ? const InventoryCatalogPanel()
                  : widget.sectionId == 'customers'
                      ? const CustomerActivityPanel()
                      : widget.sectionId == 'cost'
                          ? const CostPlanningPanel()
                          : widget.sectionId == 'invoices_payments'
                              ? const InvoiceReviewPanel()
                          : _sectionContent())),
            // Branding and installed version are provided once by CafeApp.
          ]);
        },
      ),
    );
  }
}
