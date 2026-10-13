import 'dashboard_integration_review.dart';
import 'owner_guest_offers_panel.dart';
import 'motel_meal_offers_panel.dart';
import 'service_task_notification_inbox.dart';
import 'dashboard_insights.dart';
import 'table_dashboard_details.dart';
import 'dashboard_cloud_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'customer_count_card.dart';
import 'guest_engagement_cards.dart';
import 'guest_engagement_review_panel.dart';
import 'live_table_map.dart';
import 'payment_confirmation_panel.dart';
import 'system_audit_panel.dart';
import 'table_service_tasks_panel.dart';
import 'package:flutter/material.dart';
import '../../shared/payments_management_panel.dart';
import '../../shared/app_release_version.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Dashboard figures come from a permission-filtered server RPC, never local
/// preview orders. Cash collected is not equivalent to all-channel revenue.
bool dashboardMetricIsVisible({
  required Set<String> allowedSections,
  required bool hasMetric,
  String? section,
}) {
  if (!hasMetric) return false;
  return section != null && allowedSections.contains(section);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen(
      {super.key, required this.allowedSections, required this.onOpenSection});
  final Set<String> allowedSections;
  final ValueChanged<String> onOpenSection;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  // The selected date is interpreted in the resort's Asia/Baghdad timezone.
  late DateTime _day = DateTime.now().toUtc().add(const Duration(hours: 3));
  late Future<Map<String, dynamic>> _overview;
  late Future<List<dynamic>> _week;
  // Local per-employee preferences. Cloud synchronization requires an
  // authorized profile endpoint and remains a separate backend task.
  List<String> _cardOrder = [];
  final Map<String, int> _cardColors = {};
  final Map<String, int> _cardSizes = {}; // 0 compact, 1 regular, 2 large
  final Set<String> _hiddenCards = {};
  bool _editingCards = false;
  final _cloudPreferences = DashboardCloudPreferences();
  // Focus mode changes presentation order only. It never grants access to data.
  String _focusMode = 'manager';
  static const _focusModes = <String, String>{
    'manager': 'Manager', 'cashier': 'Cashier',
    'waiter': 'Waiter', 'kitchen': 'Kitchen',
  };
  static const _focusPriorities = <String, List<String>>{
    'manager': ['cash_collected_iqd', 'orders', 'active_orders', 'outstanding_iqd'],
    'cashier': ['outstanding_iqd', 'cash_collected_iqd', 'order_value_iqd', 'orders'],
    'waiter': ['active_orders', 'orders', 'tourism_orders', 'outstanding_iqd'],
    'kitchen': ['active_orders', 'orders', 'tourism_orders'],
  };

  static const _palette = <Color>[
    Color(0xFF2563EB), Color(0xFF16A34A), Color(0xFF9333EA),
    Color(0xFFEA580C), Color(0xFFDC2626), Color(0xFF0891B2),
    Color(0xFF64748B), Color(0xFFDB2777),
  ];
  String get _prefsKey =>
      'dashboard_cards_v1_${Supabase.instance.client.auth.currentUser?.id ?? 'signed_out'}';

  Future<void> _loadCardPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) {
      await _loadCloudPreferences();
      return;
    }
    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _focusMode = _focusModes.containsKey(parsed['focus_mode'])
            ? parsed['focus_mode'] as String : 'manager';
        _cardOrder = (parsed['order'] as List<dynamic>? ?? [])
            .whereType<String>().toList();
        _cardColors.clear();
        _cardSizes.clear();
        _hiddenCards.clear();
        final sizes = parsed['sizes'];
        if (sizes is Map) {
          for (final entry in sizes.entries) {
            if (entry.key is String && entry.value is int && entry.value >= 0 && entry.value <= 2) {
              _cardSizes[entry.key as String] = entry.value as int;
            }
          }
        }
        final hidden = parsed['hidden'];
        if (hidden is List) _hiddenCards.addAll(hidden.whereType<String>());
        final colors = parsed['colors'];
        if (colors is Map) {
          for (final entry in colors.entries) {
            if (entry.key is String && entry.value is int &&
                entry.value >= 0 && entry.value < _palette.length) {
              _cardColors[entry.key as String] = entry.value as int;
            }
          }
        }
      });
    } catch (_) {
      // Malformed device preferences never prevent Dashboard access.
    }
    await _loadCloudPreferences();
  }

  // Remote preferences are scoped by auth.uid() in the RPC. Missing migrations,
  // offline connections, and permissions never prevent the local Dashboard.
  Future<void> _loadCloudPreferences() async {
    try {
      final cloud = await _cloudPreferences.load();
      if (cloud == null || !mounted) return;
      final parsed = cloud['preferences'];
      if (parsed is! Map) return;
      setState(() {
        _focusMode = _focusModes.containsKey(parsed['focus_mode'])
            ? parsed['focus_mode'] as String : _focusMode;
        _cardOrder = (parsed['order'] as List<dynamic>? ?? []).whereType<String>().toList();
        _cardColors.clear();
        _cardSizes.clear();
        _hiddenCards.clear();
        final colors = parsed['colors'];
        if (colors is Map) {
          for (final entry in colors.entries) {
            if (entry.key is String && entry.value is int &&
                entry.value >= 0 && entry.value < _palette.length) {
              _cardColors[entry.key as String] = entry.value as int;
            }
          }
        }
        final sizes = parsed['sizes'];
        if (sizes is Map) {
          for (final entry in sizes.entries) {
            if (entry.key is String && entry.value is int &&
                entry.value >= 0 && entry.value <= 2) {
              _cardSizes[entry.key as String] = entry.value as int;
            }
          }
        }
        final hidden = parsed['hidden'];
        if (hidden is List) _hiddenCards.addAll(hidden.whereType<String>());
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(parsed));
    } catch (_) {
      // Cloud sync is best-effort; the local dashboard preferences remain usable.
    }
  }

  Future<void> _saveCardPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = <String, dynamic>{
      'order': _cardOrder, 'colors': _cardColors, 'sizes': _cardSizes,
      'hidden': _hiddenCards.toList(), 'focus_mode': _focusMode,
    };
    await prefs.setString(_prefsKey, jsonEncode(snapshot));
    try {
      await _cloudPreferences.save(snapshot);
    } catch (_) {
      // Local preferences were already saved; cloud sync can be retried later.
    }
  }

  void _moveCard(String id, int direction, List<String> visibleIds) {
    final order = [...visibleIds];
    final index = order.indexOf(id);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= order.length) return;
    final value = order.removeAt(index);
    order.insert(target, value);
    setState(() => _cardOrder = order);
    _saveCardPreferences();
  }

  // Drag-and-drop updates only the visible, authorized KPI card order.
  // Cards that are not currently visible retain no access privileges.
  void _reorderCards(int oldIndex, int newIndex, List<String> visibleIds) {
    if (oldIndex < 0 || oldIndex >= visibleIds.length) return;
    final reordered = List<String>.from(visibleIds);
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= reordered.length) return;
    final id = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, id);
    setState(() => _cardOrder = reordered);
    _saveCardPreferences();
  }

  void _changeCardColor(String id, int colorIndex) {
    setState(() => _cardColors[id] = colorIndex);
    _saveCardPreferences();
  }

  void _changeCardSize(String id, int size) {
    if (size < 0 || size > 2) return;
    setState(() => _cardSizes[id] = size);
    _saveCardPreferences();
  }

  void _setCardVisibility(String id, bool visible) {
    setState(() {
      if (visible) { _hiddenCards.remove(id); } else { _hiddenCards.add(id); }
    });
    _saveCardPreferences();
  }

  Timer? _autoRefresh;
  bool _automatic = true;
  bool _refreshInProgress = false;
  bool _refreshRequestedWhileBusy = false;
  // Pull-to-refresh must wait for the actual coordinated refresh, including
  // any queued follow-up, rather than an older overview Future.
  final List<Completer<void>> _pullRefreshWaiters = <Completer<void>>[];
  bool _appIsForeground = true;
  String? _loadingDay;
  DateTime? _lastSuccessfulRefresh;
  String? _lastSuccessfulDay;
  String? _lastRefreshError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize both Dashboard RPCs with the same Baghdad business date.
    // These loaders require an explicit date; calling them without one
    // prevents Flutter compilation before the Dashboard can open.
    final initialBusinessDay = _dateString();
    _refreshInProgress = true;
    _loadingDay = initialBusinessDay;
    _overview = _loadWithStatus(initialBusinessDay);
    _week = _loadWeek(initialBusinessDay);
    // Treat startup as an in-flight refresh too. Otherwise a quick date
    // change can overlap startup RPCs and attach old data to the new day.
    _finishRefreshWhenSettled(_overview, _week);
    _loadCardPreferences();
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _automatic && _appIsForeground) _refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    final wasForeground = _appIsForeground;
    _appIsForeground = foreground;
    // Background devices should not keep issuing dashboard requests.
    // Refresh on return so stale figures are not presented as current.
    if (foreground && !wasForeground && _automatic) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefresh?.cancel();
    // A disappearing Dashboard must not strand a pending RefreshIndicator.
    for (final waiter in _pullRefreshWaiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _pullRefreshWaiters.clear();
    super.dispose();
  }

  Future<List<dynamic>> _loadWeek(String day) async {
    final result = await Supabase.instance.client
        .rpc('gs_dashboard_week', params: {'p_day': day})
        .timeout(const Duration(seconds: 20));
    // Validate the entire weekly payload before handing it to FutureBuilder.
    // The chart casts every row to a string-keyed map and reads 'orders' as
    // num. Invalid rows must become a recoverable error, not a build crash.
    if (result is! List) {
      throw const FormatException('Dashboard weekly response is not a list');
    }
    // This endpoint represents exactly one seven-day reporting window.
    // An unexpectedly oversized response can overflow the compact iPhone
    // chart; reject it rather than rendering misleading extra bars.
    if (result.length > 7) {
      throw const FormatException('Dashboard weekly response has too many days');
    }
    // The RPC may return [] when the employee has no order permissions.
    // For populated responses, reject repeated, missing or out-of-window
    // business dates instead of plotting misleading duplicated day labels.
    // Use UTC calendar dates for comparisons, not device-local midnights.
    // Subtracting six 24-hour periods from a local date can cross a DST
    // transition and incorrectly exclude the first reporting day.
    final requestedLocalDay = DateTime.tryParse(day);
    if (requestedLocalDay == null) {
      throw const FormatException('Dashboard weekly request day is invalid');
    }
    final requestedDay = DateTime.utc(
      requestedLocalDay.year, requestedLocalDay.month, requestedLocalDay.day,
    );
    final seenDays = <String>{};
    final points = <Map<String, dynamic>>[];
    for (final row in result) {
      if (row is! Map) {
        throw const FormatException('Dashboard weekly row is not a map');
      }
      final Map<String, dynamic> point;
      try {
        point = Map<String, dynamic>.from(row);
      } on TypeError {
        throw const FormatException('Dashboard weekly row has invalid keys');
      }
      final rawDay = point['day'];
      if (rawDay is! String ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawDay)) {
        throw const FormatException('Dashboard weekly day is invalid');
      }
      final parsedLocalDay = DateTime.tryParse(rawDay);
      final parsedDay = parsedLocalDay == null
          ? null
          : DateTime.utc(
              parsedLocalDay.year, parsedLocalDay.month, parsedLocalDay.day,
            );
      if (parsedDay == null ||
          parsedDay.year.toString().padLeft(4, '0') != rawDay.substring(0, 4) ||
          parsedDay.month.toString().padLeft(2, '0') != rawDay.substring(5, 7) ||
          parsedDay.day.toString().padLeft(2, '0') != rawDay.substring(8, 10) ||
          parsedDay.isAfter(requestedDay) ||
          parsedDay.isBefore(requestedDay.subtract(const Duration(days: 6))) ||
          !seenDays.add(rawDay)) {
        throw const FormatException('Dashboard weekly day is outside the reporting window or repeated');
      }
      final orders = point['orders'];
      // Order counts represent whole, non-negative quantities. Reject
      // NaN, infinity, fractions and negatives before chart scaling or
      // integer conversion can produce invalid bars or runtime errors.
      // Missing counts are not the same as a verified zero orders.
      // Do not silently convert null into a zero-height bar.
      if (orders == null ||
          (orders is! num ||
              !orders.isFinite ||
              orders < 0 ||
              // Dart web uses JavaScript numbers. Counts beyond the maximum
              // safe integer cannot be represented without precision loss.
              orders > 9007199254740991 ||
              orders != orders.truncateToDouble())) {
        throw const FormatException('Dashboard weekly order count is invalid');
      }
      // Supabase may decode an integral JSON number as 7.0. Normalize it
      // after validation so chart labels and VoiceOver announce '7 orders',
      // never '7.0 orders'. Safe-integer checks above protect conversion.
      point['orders'] = orders.toInt();
      // Cash is optional for employees without receipt permissions. If the
      // field is present, it must be a finite numeric amount: NaN, infinity,
      // or a string can otherwise break the money formatter or mislead staff.
      // Signed amounts are retained because legitimate adjustments may be
      // negative; do not impose an unsupported accounting rule here.
      if (point.containsKey('cash_iqd')) {
        final cash = point['cash_iqd'];
        // IQD is displayed as whole dinars by _money(). Reject fractional
        // or non-finite RPC values rather than silently truncating them.
        // Negative whole-dinar adjustments remain valid.
        if (cash != null &&
            (cash is! num || !cash.isFinite ||
                // Avoid silently rounding large IQD figures on Flutter web.
                cash.abs() > 9007199254740991 ||
                cash != cash.truncateToDouble())) {
          throw const FormatException('Dashboard weekly cash amount is invalid');
        }
        // Preserve null (hidden/unavailable) and normalize valid numeric
        // cash values to exact whole IQD for consistent formatting.
        if (cash is num) point['cash_iqd'] = cash.toInt();
      }
      points.add(point);
    }
    // The RPC may return valid rows in any order. Always plot oldest to
    // newest so the chart and cash breakdown follow the calendar, rather
    // than depending on the database query's incidental row ordering.
    points.sort((a, b) => (a['day'] as String).compareTo(b['day'] as String));
    return points;
  }

  String _dateString() =>
      '${_day.year.toString().padLeft(4, '0')}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> _load(String day) async {
    final result = await Supabase.instance.client
        .rpc('gs_dashboard_overview', params: {'p_day': day})
        .timeout(const Duration(seconds: 20));
    // A malformed RPC response is not a valid Dashboard snapshot. Reject it
    // explicitly rather than crashing on an unchecked cast or presenting
    // missing figures as real business data.
    if (result is! Map) {
      throw const FormatException('Dashboard overview response is not a map');
    }
    final Map<String, dynamic> overview;
    try {
      overview = Map<String, dynamic>.from(result);
    } on TypeError {
      throw const FormatException('Dashboard overview contains invalid keys');
    }
    // An empty map is not a usable Dashboard snapshot. Do not treat an
    // unexpected empty RPC result as a successful zero-activity business day.
    // FutureBuilder should display the existing safe error and Retry action.
    if (overview.isEmpty) {
      throw const FormatException('Dashboard overview response is empty');
    }
    // The operational extension is optional until migration 037 is deployed.
    // Failure to load it must not hide the already-verified overview values.
    try {
      final operational = await Supabase.instance.client.rpc(
        'gs_dashboard_operational_metrics', params: {'p_day': day})
          .timeout(const Duration(seconds: 8));
      if (operational is Map) {
        final optionalMetrics = Map<String, dynamic>.from(operational);
        // The optional extension must never overwrite canonical figures
        // returned by gs_dashboard_overview, including null/hidden values.
        // This preserves the main endpoint's authoritative permission and
        // availability decisions if the two RPCs return a duplicate key.
        for (final entry in optionalMetrics.entries) {
          overview.putIfAbsent(entry.key, () => entry.value);
        }
      }
    } catch (_) {
      // Never substitute invented operational numbers or zeroes.
    }
    return overview;
  }

  // Keep backend error details out of employee-facing messages while
  // distinguishing network delays, authorization failures and other errors.
  String _dashboardFailureMessage(Object error, {required bool weekly}) {
    final prefix = weekly ? 'Weekly trend' : 'Dashboard';
    if (error is TimeoutException) {
      return '$prefix request timed out. Check your connection and retry.';
    }
    if (error is FormatException) {
      return '$prefix received an invalid server response. Retry, then '
          'contact an administrator if the problem continues.';
    }
    if (error is PostgrestException) {
      // PostgreSQL insufficient_privilege and PostgREST authorization errors.
      if (error.code == '42501' || error.code == 'PGRST301' ||
          error.code == 'PGRST302') {
        return '$prefix access was denied. Ask an administrator to review '
            'your permissions and sign-in session.';
      }
      return '$prefix data is unavailable. Retry, then contact an '
          'administrator if the problem continues.';
    }
    return '$prefix data could not be refreshed. Check your connection and retry.';
  }

  Future<Map<String, dynamic>> _loadWithStatus(String requestedDay) async {
    try {
      final result = await _load(requestedDay);
      // An empty response is not a successful metrics snapshot.
      // Never label stale figures with a newer business day or load time.
      if (mounted && requestedDay == _dateString()) {
        setState(() {
          _lastSuccessfulRefresh = DateTime.now();
          _lastSuccessfulDay = requestedDay;
          _lastRefreshError = null;
        });
      }
      return result;
    } catch (error) {
      // An older request may fail after the user selects another business
      // day. Never attach that failure to the newly selected day's figures.
      // _refresh() queues the latest day once the in-flight request settles.
      if (mounted && requestedDay == _dateString()) {
        setState(() => _lastRefreshError =
            _dashboardFailureMessage(error, weekly: false));
      }
      rethrow;
    }
  }

  Future<void> _refreshFromPull() {
    if (!mounted) return Future<void>.value();
    final waiter = Completer<void>();
    _pullRefreshWaiters.add(waiter);
    _refresh();
    return waiter.future;
  }

  void _refresh() {
    if (!mounted) return;
    if (_refreshInProgress) {
      // A date change or resumed app may arrive during a request. Queue one
      // follow-up rather than losing it or issuing overlapping RPCs.
      _refreshRequestedWhileBusy = true;
      return;
    }
    _refreshInProgress = true;
    _loadingDay = _dateString();
    // Pin both RPCs to the same business day. Changing the date during
    // an in-flight request must not mix different days in one overview.
    final requestedDay = _loadingDay!;
    final overview = _loadWithStatus(requestedDay);
    final week = _loadWeek(requestedDay);
    setState(() {
      _overview = overview;
      _week = week;
      // Re-fetch the independently permission-gated unpaid-balance contract
      // whenever the Dashboard refreshes. Never retain an old certified value
      // if the latest finance RPC is unavailable or incomplete.
      _liveUnpaidFuture = _loadLiveUnpaidBalances();
    });
    _finishRefreshWhenSettled(overview, week);
  }

  void _finishRefreshWhenSettled(
    Future<Map<String, dynamic>> overview,
    Future<List<dynamic>> week,
  ) {
    // Both RPCs must settle before releasing the refresh lock. Convert
    // failures to null only for coordination; FutureBuilder still receives
    // the original error and can render the existing retry state.
    Future.wait<Object?>([
      overview.then<Object?>((value) => value).catchError((Object _) => null),
      week.then<Object?>((value) => value).catchError((Object _) => null),
    ]).whenComplete(() {
      _refreshInProgress = false;
      if (!mounted) return;
      final dateChanged = _loadingDay != _dateString();
      final queued = _refreshRequestedWhileBusy || dateChanged;
      _refreshRequestedWhileBusy = false;
      _loadingDay = null;
      if (queued) {
        _refresh();
      } else {
        // FutureBuilder may already have rendered the failure while the
        // coordinated refresh lock was held. Rebuild once it is released
        // so disabled Retry trend and overview retry actions become usable.
        setState(() {});
        // Both overview and trend are settled and no newer day is queued.
        // Only now can the pull-to-refresh spinner finish truthfully.
        for (final waiter in _pullRefreshWaiters) {
          if (!waiter.isCompleted) waiter.complete();
        }
        _pullRefreshWaiters.clear();
      }
    });
  }

  // Calendar limits must be based on the Baghdad *calendar date*, not the
  // device's local clock. DateTime(y, m, d) is used only as a date-picker
  // calendar value; no timezone conversion is applied to the chosen day.
  DateTime _baghdadCalendarToday() {
    final baghdadNow = DateTime.now().toUtc().add(const Duration(hours: 3));
    return DateTime(baghdadNow.year, baghdadNow.month, baghdadNow.day);
  }

  // Quick dates are Baghdad calendar dates. Multi-day finance totals require
  // server-side period-aware, permission-filtered RPCs and are not fabricated.
  void _selectQuickDay(int offset) {
    final today = _baghdadCalendarToday();
    final selected = DateTime(today.year, today.month, today.day + offset);
    if (selected.year == _day.year && selected.month == _day.month && selected.day == _day.day) return;
    setState(() => _day = selected);
    _refresh();
  }

  void _periodNotAvailable(String period) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
      '$period requires an authorized multi-day finance endpoint; no totals have been invented.')));
  }

  // Accessible entry point for the existing date and focus filters.
  // Focus mode only changes card presentation, never backend authorization.
  Future<void> _openDashboardFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Dashboard filters', style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Business date'),
              subtitle: Text('${_day.year}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickDay();
              },
            ),
            DropdownButtonFormField<String>(
              value: _focusMode,
              decoration: const InputDecoration(labelText: 'Card focus (display only)'),
              items: _focusModes.entries.map((entry) => DropdownMenuItem<String>(
                value: entry.key, child: Text(entry.value),
              )).toList(),
              onChanged: (mode) {
                if (mode == null || !_focusModes.containsKey(mode)) return;
                setState(() => _focusMode = mode);
                _saveCardPreferences();
              },
            ),
            const SizedBox(height: 12),
            const Text('Employee, payment-method and multi-day financial filters require verified backend endpoints.'),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => Navigator.of(sheetContext).pop(), child: const Text('Done')),
          ]),
        ),
      ),
    );
  }

  Future<void> _pickDay() async {
    final today = _baghdadCalendarToday();
    final selectedCalendarDay = DateTime(_day.year, _day.month, _day.day);
    final picked = await showDatePicker(
        context: context,
        initialDate: selectedCalendarDay.isAfter(today) ? today : selectedCalendarDay,
        firstDate: DateTime(2020),
        lastDate: today);
    if (picked != null && mounted &&
        (picked.year != _day.year ||
         picked.month != _day.month ||
         picked.day != _day.day)) {
      setState(() => _day = picked);
      _refresh();
    }
  }

  String _money(Object? value) {
    // Overview and detail RPCs can return values not covered by the
    // weekly-trend validator. Never truncate fractional dinars or display
    // non-finite / web-unsafe amounts as if they were exact cash figures.
    if (value is! num ||
        !value.isFinite ||
        value.abs() > 9007199254740991 ||
        value != value.truncateToDouble()) {
      return '—';
    }
    final s = value.toInt().toString();
    return '${s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')} IQD';
  }

  // Explicit definitions prevent users from mistaking a KPI for a complete
  // transaction ledger. These are descriptions, not locally calculated data.
  String _metricDefinition(String key) {
    switch (key) {
      case 'urgent_actions_count':
        return 'Currently counts unresolved urgent guest feedback only. '
            'Other urgent tasks are not yet included.';
      case 'overdue_service_orders':
        return 'Orders in new, preparing or ready status that were created '
            'on the selected Baghdad-local day and are older than the '
            'provisional 30-minute service threshold. Cancelled and '
            'completed orders are excluded.';
      case 'top_product_units_sold':
        return 'Largest quantity sold for a single product on the selected '
            'day, excluding cancelled orders. This is not total product '
            'units sold across all products.';
      case 'table_occupancy_percent':
        return 'Occupied configured tables divided by all configured '
            'tables, expressed as a percentage. This is not chair occupancy.';
      case 'standing_cash_active_visits_iqd':
        return 'LIVE unpaid balance of active, occupied café table visits '
            'for customers still present. Deduct confirmed partial payments; '
            'exclude paid, departed, cancelled and non-seated online/motel '
            'orders. This is not cash received, drawer cash or revenue. '
            'Past dates require historical snapshots, not today’s live balance.';
      case 'pending_online_motel_unpaid_iqd':
        return 'Unpaid balance on online orders and motel food orders, '
            'including partially paid orders. Exclude settled/cancelled '
            'orders and any balance already included in active seated '
            'café visits. Prepaid motel packages must not be charged twice. '
            'This is not payment confirmation approval status.';
      case 'cash_reconciliation_discrepancies':
        return 'Expected cash versus verified counted cash. Requires a '
            'separately authorized reconciliation data source.';
      case 'employees_on_duty':
        return 'Attendance-confirmed employees currently on duty. '
            'Requires the attendance data source.';
      case 'open_maintenance_issues':
        return 'Unresolved maintenance records. Requires the maintenance '
            'data source.';
      case 'pending_offline_sync':
        return 'Locally queued operations awaiting safe server '
            'synchronization. Requires device-specific sync monitoring.';
      default:
        return 'Summary supplied by the authorized Dashboard endpoint. '
            'Underlying transactions require separate access checks.';
    }
  }

  String _metricDataStatus(String key, Object? value) {
    if (value == null) return 'Unavailable: the required authorized data '
        'source has not supplied this metric.';
    if (const {
      'urgent_actions_count', 'overdue_service_orders',
      'top_product_units_sold', 'table_occupancy_percent',
    }.contains(key)) {
      return 'Draft operational metric: calculation and permissions require '
          'Supabase migration verification before production use.';
    }
    return 'Reported by the authorized Dashboard endpoint. Verify the '
        'underlying records before taking financial or operational action.';
  }

  // Dedicated authorized drill-down: use the real Payments Management widget,
  // not an illustrative financial-detail placeholder. Mobile is full screen;
  // desktop uses a right-side sheet, matching other Dashboard details.
  void _openUnpaidPaymentWorkflow(String key) {
    if (!widget.allowedSections.contains('payments_management')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Payments Management access required.')));
      return;
    }
    final focus = key == 'standing_cash_active_visits_iqd'
        ? 'standing' : 'pending';
    final title = focus == 'standing' ? 'Standing Cash · Active tables'
        : 'Pending Payment · Online & motel';
    final page = Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: ListView(children: [
        PaymentsManagementPanel(initialFocus: focus),
      ])),
    );
    if (MediaQuery.sizeOf(context).width < 900) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    } else {
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close financial workflow',
        pageBuilder: (dialogContext, _, __) => Align(
          alignment: Alignment.centerRight,
          child: Material(elevation: 16, child: SizedBox(
            width: 520, height: MediaQuery.sizeOf(dialogContext).height,
            child: page,
          )),
        ),
      );
    }
  }

  void _openMetricDetails(String title, String key, Object? value,
      {required bool money, String? section}) {
    if (!dashboardMetricIsVisible(
      allowedSections: widget.allowedSections,
      hasMetric: true,
      section: section,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('This dashboard detail is unavailable for this account.'),
      ));
      return;
    }
    final permitted = section != null && widget.allowedSections.contains(section);
    final detail = Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Data is scoped to the current authenticated account. Other employee filtering requires a permission-scoped backend endpoint.'),
        const SizedBox(height: 8),
        Text('Selected business date: ${_dateString()}',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 18),
        Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(money ? _money(value) : '${value ?? '—'}',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('Value supplied by the authorized Dashboard RPC.'),
          ],
        ))),
        const SizedBox(height: 12),
        if (permitted) FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onOpenSection(section);
          },
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open related management section'),
        ) else const Text('No linked section is available for this account.'),
        const SizedBox(height: 12),
        Text('What this card measures',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(_metricDefinition(key)),
        const SizedBox(height: 12),
        Text('Data availability',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(_metricDataStatus(key, value)),
        const SizedBox(height: 12),
        const Text('Transaction-level details and actions require a separately '
            'authorized backend endpoint. This view never invents records '
            'or allows direct edits to financial data.'),
      ])),
    );
    if (MediaQuery.sizeOf(context).width < 900) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => detail));
    } else {
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close details',
        pageBuilder: (dialogContext, _, __) => Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 16,
            child: SizedBox(
              width: 480,
              height: MediaQuery.sizeOf(dialogContext).height,
              child: detail,
            ),
          ),
        ),
      );
    }
  }

  void _openGuestEngagement(GuestEngagementType type) {
    // Restrict staff-only recommendations; guest form is a preview here.
    if (type == GuestEngagementType.productRecommendation &&
        !widget.allowedSections.contains('menu')) return;
    final detail = GuestEngagementDetails(type: type);
    if (MediaQuery.sizeOf(context).width < 900) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => detail));
    } else {
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close details',
        pageBuilder: (dialogContext, _, __) => Align(
          alignment: Alignment.centerRight,
          child: Material(elevation: 16, child: SizedBox(
            width: 480,
            height: MediaQuery.sizeOf(dialogContext).height,
            child: detail,
          )),
        ),
      );
    }
  }

  void _openEngagementReview() {
    if (!widget.allowedSections.contains('dashboard')) return;
    // Empty lists are intentional: do not invent records or bypass RLS.
    const review = GuestEngagementReviewPanel(
      feedback: [], suggestions: [],
    );
    final detail = Scaffold(
      appBar: AppBar(title: const Text('Guest & Product Reviews')),
      body: review,
    );
    if (MediaQuery.sizeOf(context).width < 900) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => detail));
    } else {
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close reviews',
        pageBuilder: (dialogContext, _, __) => Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 16,
            child: SizedBox(
              width: 520,
              height: MediaQuery.sizeOf(dialogContext).height,
              child: detail,
            ),
          ),
        ),
      );
    }
  }

  void _openSystemAudit() {
    if (!widget.allowedSections.contains('dashboard') ||
        !widget.allowedSections.contains('security_access_control')) return;
    const detail = SystemAuditPanel();
    if (MediaQuery.sizeOf(context).width < 900) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => detail));
    } else {
      showGeneralDialog<void>(context: context, barrierDismissible: true,
        barrierLabel: 'Close system audit', pageBuilder: (dialogContext, _, __) =>
          Align(alignment: Alignment.centerRight, child: Material(elevation: 16,
            child: SizedBox(width: 560, height: MediaQuery.sizeOf(dialogContext).height, child: detail))));
    }
  }

  void _openPaymentConfirmations() {
    if (!widget.allowedSections.contains('dashboard') ||
        !widget.allowedSections.contains('payments_management')) return;
    const detail = PaymentConfirmationPanel();
    if (MediaQuery.sizeOf(context).width < 900) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => detail),
      );
    } else {
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close payment confirmations',
        pageBuilder: (dialogContext, _, __) => Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 16,
            child: SizedBox(
              width: 540,
              height: MediaQuery.sizeOf(dialogContext).height,
              child: detail,
            ),
          ),
        ),
      );
    }
  }

  void _openTableDetails(Map<String, dynamic> table) {
    final label = (table['label'] ?? table['number'] ?? 'Table').toString();
    final status = (table['status'] ?? 'Unknown').toString();
    final guestCount = table['guest_count'];
    final detail = Scaffold(
      appBar: AppBar(title: Text('$label · Details')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        ListTile(title: const Text('Status'), subtitle: Text(status)),
        ListTile(title: const Text('Customers'),
          subtitle: Text(guestCount is num ? '${guestCount.toInt()}' : 'Not available')),
        if (table['customer_name'] is String &&
            (table['customer_name'] as String).trim().isNotEmpty)
          ListTile(title: const Text('Customer name'),
            subtitle: Text(table['customer_name'] as String)),
        if (table['total_bill_iqd'] is num)
          ListTile(title: const Text('Total bill'),
            subtitle: Text(_money(table['total_bill_iqd']))),
        if (table['paid_iqd'] is num)
          ListTile(title: const Text('Paid'),
            subtitle: Text(_money(table['paid_iqd']))),
        if (table['remaining_iqd'] is num)
          ListTile(title: const Text('Remaining'),
            subtitle: Text(_money(table['remaining_iqd']))),
        const SizedBox(height: 12),
        // Display server-provided reservation and bill information only.
        // No client-side payment allocation or reservation mutation occurs here.
        ...TableDashboardDetails.readOnlySections(table,
          onTableReleased: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            _refresh();
          }),
        const SizedBox(height: 16),
        if (widget.allowedSections.contains('tables'))
          OutlinedButton.icon(
            icon: const Icon(Icons.room_service_outlined),
            label: const Text('View table service and cleaning tasks'),
            onPressed: () {
              final tableId = table['id'] ?? table['table_id'];
              if (tableId == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Table identifier unavailable; service tasks cannot be loaded.'),
                ));
                return;
              }
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => TableServiceTasksPanel(tableId: '$tableId'),
              ));
            },
          ),
        const SizedBox(height: 12),
        if (widget.allowedSections.contains('tables')) FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onOpenSection('tables');
          },
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open Tables Management'),
        ),
        const Text('Detailed order and split-payment records require authorized backend endpoints.'),
      ]),
    );
    if (MediaQuery.sizeOf(context).width < 900) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => detail));
    } else {
      showGeneralDialog<void>(
        context: context, barrierDismissible: true, barrierLabel: 'Close table details',
        pageBuilder: (dialogContext, _, __) => Align(
          alignment: Alignment.centerRight,
          child: Material(elevation: 16, child: SizedBox(
            width: 480, height: MediaQuery.sizeOf(dialogContext).height,
            child: detail,
          )),
        ),
      );
    }
  }

  Widget _metric(
      String title, String key, IconData icon, Map<String, dynamic> data,
      {bool money = false, String? section}) {
    if (!dashboardMetricIsVisible(
      allowedSections: widget.allowedSections,
      hasMetric: data.containsKey(key),
      section: section,
    )) return const SizedBox.shrink();
    final colorIndex = _cardColors[key];
    final accent = colorIndex == null ? Theme.of(context).colorScheme.primary
        : _palette[colorIndex];
    return Card(
        key: ValueKey<String>(key),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => const {'standing_cash_active_visits_iqd', 'pending_online_motel_unpaid_iqd'}.contains(key)
              ? _openUnpaidPaymentWorkflow(key)
              : _openMetricDetails(title, key, data[key], money: money, section: section),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(children: [
                    Icon(icon, color: accent),
                    const Spacer(),
                    if (_editingCards) PopupMenuButton<int>(
                      tooltip: 'Choose card color',
                      icon: const Icon(Icons.palette_outlined, size: 20),
                      onSelected: (value) => _changeCardColor(key, value),
                      itemBuilder: (_) => [
                        for (var i = 0; i < _palette.length; i++)
                          PopupMenuItem(value: i, child: Row(children: [
                            CircleAvatar(radius: 9, backgroundColor: _palette[i]),
                            const SizedBox(width: 12), Text('Color ${i + 1}'),
                          ])),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Text(title,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 5),
                  FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                          money ? _money(data[key]) : '${data[key] ?? '—'}',
                          maxLines: 1,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold))),
                  if (key == 'cash_collected_iqd') ...[
                    const SizedBox(height: 4),
                    Text('Cash only · payments can be refreshed or retried',
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                  if (true) ...[
                    const SizedBox(height: 4),
                    Text('View details →',
                        style: Theme.of(context).textTheme.labelSmall)
                  ],
                ],
              )),
        ));
  }

  // Live balance reporting requires an audited, permission-scoped RPC.
  // A migration now installs a fail-closed contract. It deliberately reports
  // incomplete until multi-method settlements and order-source mapping are verified.
  // Never fall back to cash-only reconciliation or infer balances from orders.
  Future<Map<String, dynamic>?> _loadLiveUnpaidBalances() async {
    if (Supabase.instance.client.auth.currentUser == null ||
        !widget.allowedSections.contains('payments_management')) return null;
    try {
      final raw = await Supabase.instance.client
          .rpc('gs_financial_live_unpaid_balances')
          .timeout(const Duration(seconds: 15));
      if (raw is! Map) return null;
      final result = Map<String, dynamic>.from(raw);
      // Keep an explicit incomplete contract so the two cards can explain
      // why numbers are absent. It must never be passed to a money widget.
      if (result['verified_complete'] == false) {
        return <String, dynamic>{
          'verified_complete': false,
          'status': result['status'] ==
                  'requires_canonical_settlement_reconciliation'
              ? 'requires_canonical_settlement_reconciliation'
              : 'incomplete_financial_coverage',
        };
      }
      // A complete report must certify BOTH amounts together. Never turn
      // incomplete, fractional, negative or non-finite values into numbers.
      // Ten explicit fail-closed checks across the Dashboard and linked
      // payment detail: no client-side arithmetic can certify a settlement.
      // D1: require a strict boolean certification (never truthy strings).
      if (result['verified_complete'] != true) return null;
      // D2-D3: both independent amount fields must be present and numeric.
      if (result['standing_cash_active_visits_iqd'] is! num ||
          result['pending_online_motel_unpaid_iqd'] is! num) return null;
      // D4: require a parseable server generation timestamp.
      final generated = DateTime.tryParse(result['generated_at']?.toString() ?? '');
      if (generated == null) return null;
      // D5: reject stale or future-dated financial snapshots (>5 minutes).
      final age = DateTime.now().toUtc().difference(generated.toUtc());
      if (age.isNegative || age > const Duration(minutes: 5)) return null;
      for (final key in ['standing_cash_active_visits_iqd',
                         'pending_online_motel_unpaid_iqd']) {
        final value = result[key] as num;
        if (!value.isFinite || value < 0 || value > 9007199254740991 ||
            value != value.truncateToDouble()) return null;
      }
      return result;
    } catch (_) {
      // Missing RPC, denied access and outages must remain unavailable.
      return null;
    }
  }

  // Payments Management rejects duplicate order identities and flags
  // cash-only arithmetic inconsistencies. These checks do not certify
  // all-method settlement, online/motel prepayments or live unpaid totals.
  // UI parity: these cards always use the real Flutter metric widget.
  // Their unavailable state is intentional until the backend certifies both.
  // The Payments Management panel offers guarded active-table CASH collection.
  // It does not certify all-method Standing Cash or Pending Payment totals.
  // Both Dashboard payment cards share the same authorized all-method RPC.
  // Never turn an unavailable amount into a misleading numeric zero.
  // Expose loading and an explicit retry, so staff can distinguish an
  // incomplete/denied report from a completed financial balance.
  Widget _liveUnpaidCard(String title, String key, IconData icon) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _liveUnpaidFuture,
      builder: (context, snapshot) {
        final live = snapshot.data;
        if (live?['verified_complete'] == true) {
          return _financialMetricCard(title, key, icon, live!, money: true);
        }
        final loading = snapshot.connectionState != ConnectionState.done;
        return Card(
          key: ValueKey<String>(key),
          child: InkWell(
            onTap: () => _openUnpaidPaymentWorkflow(key),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon),
                  const SizedBox(height: 8),
                  Text(title, maxLines: 2),
                  const SizedBox(height: 6),
                  Text(loading ? 'Checking verified balance…' : 'Amount unavailable',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(loading
                    ? 'Waiting for authorized financial reporting.'
                    : live?['status'] ==
                            'requires_canonical_settlement_reconciliation'
                        ? 'Backend confirms settlement reconciliation is incomplete. '
                          'Prepaid, credit, partial and source-linked allocations '
                          'must be verified. Not 0 IQD.'
                        : live?['verified_complete'] == false
                            ? 'Backend reports incomplete financial coverage. '
                              'Not 0 IQD.'
                            : 'No verified all-method total (access, connection '
                              'or invalid response). Not 0 IQD.',
                    maxLines: 5),
                  const SizedBox(height: 8),
                  if (!loading)
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _liveUnpaidFuture = _loadLiveUnpaidBalances();
                      }),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry amount'),
                    ),
                  const SizedBox(height: 4),
                  const Text('Open source details →'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  late Future<Map<String, dynamic>?> _liveUnpaidFuture =
      _loadLiveUnpaidBalances();

  // Financial cards are visible as unavailable until the authorized RPC
  // supplies the corresponding value. No invented balances or client sums.
  Widget _financialMetricCard(String title, String key, IconData icon,
      Map<String, dynamic> data, {bool money = true}) {
    if (data[key] is num) {
      return _metric(title, key, icon, data,
          money: money, section: 'payments_management');
    }
    return Card(
      key: ValueKey<String>(key),
      child: InkWell(
        onTap: () => const {'standing_cash_active_visits_iqd', 'pending_online_motel_unpaid_iqd'}.contains(key)
            ? _openUnpaidPaymentWorkflow(key)
            : _openMetricDetails(title, key, null,
                money: money, section: 'payments_management'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon),
              const SizedBox(height: 8),
              Text(title, maxLines: 2),
              const SizedBox(height: 6),
              const Text('Not available',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Requires verified all-method settlement reporting',
                  maxLines: 2),
              const SizedBox(height: 4),
              const Text('View details →'),
            ]),
        ),
      ),
    );
  }

  String _dayLabel(Object? value) {
    final text = value?.toString() ?? '';
    if (text.length >= 10) return text.substring(5, 10);
    return text.isEmpty ? '—' : text;
  }

  Widget _weekChart() {
    // A date switch can be queued behind an earlier in-flight request.
    // Do not show the old day's trend under the newly selected date while
    // waiting for the coordinated overview and trend refresh to begin.
    if (_loadingDay != null && _loadingDay != _dateString()) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Semantics(
            liveRegion: true,
            label: 'Weekly trend loading for the selected business day',
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Switching business day…')),
              ],
            ),
          ),
        ),
      );
    }
    return FutureBuilder<List<dynamic>>(
        future: _week,
        builder: (context, snapshot) {
          if (snapshot.hasError && !snapshot.hasData) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dashboardFailureMessage(snapshot.error!, weekly: true),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      button: true,
                      label: 'Retry loading the seven-day trend',
                      child: OutlinedButton.icon(
                        onPressed: _refreshInProgress ? null : _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry trend'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(snapshot.connectionState == ConnectionState.done
                    ? 'No authorized trend data'
                    : 'Loading seven-day trend…'),
              ),
            );
          }
          final points = snapshot.data!
              .map((entry) => Map<String, dynamic>.from(entry as Map))
              .toList();
          final maximum = points.fold<int>(1, (max, point) {
            final value = (point['orders'] as num?)?.toInt() ?? 0;
            return value > max ? value : max;
          });
          return Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Orders · Last 7 days',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text(
                          'Authorized table and motel orders only · Cash receipts are dated when received'),
                      const SizedBox(height: 16),
                      SizedBox(
                          height: 155,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final point in points)
                                Expanded(
                                    child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  child: Semantics(
                                    // One chart-bar announcement, not separate
                                    // order-count and abbreviated-date announcements.
                                    label: '${point['day']}: ${point['orders']} ${point['orders'] == 1 ? 'order' : 'orders'}',
                                    child: ExcludeSemantics(
                                      child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // Keep large, valid order counts inside
                                        // narrow seven-column iPhone chart cells.
                                        // The outer Semantics retains the full
                                        // unscaled value for screen readers.
                                        SizedBox(
                                          width: double.infinity,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text('${point['orders'] ?? 0}',
                                              maxLines: 1,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                            // A zero-order day must have no visible bar.
                                            // Previously every day received a
                                            // two-pixel minimum, incorrectly
                                            // suggesting activity on empty days.
                                            height: (point['orders'] as int) == 0
                                                ? 0
                                                : 90 *
                                                        ((point['orders'] as int) /
                                                            maximum) +
                                                    2,
                                            decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                borderRadius: const BorderRadius
                                                    .vertical(
                                                    top: Radius.circular(5)))),
                                        const SizedBox(height: 5),
                                        SizedBox(
                                          width: double.infinity,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(_dayLabel(point['day']),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall,
                                              maxLines: 1),
                                          ),
                                        ),
                                      ]),
                                    ),
                                  ),
                                ))
                            ],
                          )),
                      const SizedBox(height: 12),
                      for (final point in points)
                        if (point.containsKey('cash_iqd'))
                          Semantics(
                              // A single descriptive cash row avoids separate,
                              // ambiguous VoiceOver announcements for the date,
                              // order count, and receipt amount. A null amount
                              // is permission-hidden/unavailable, never zero.
                              label: '${point['day']}: ${point['orders']} ${point['orders'] == 1 ? 'order' : 'orders'}; '
                                  '${point['cash_iqd'] == null ? 'cash unavailable' : '${_money(point['cash_iqd'])} cash received'}',
                              child: ExcludeSemantics(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(children: [
                                    // Constrain the date/order label too: a large
                                    // count or accessibility text scale must not
                                    // wrap into an unexpectedly tall cash row.
                                    // The outer Semantics retains its full text.
                                    Expanded(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${point['day']}: ${point['orders']} ${point['orders'] == 1 ? 'order' : 'orders'}',
                                          maxLines: 1,
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Keep long authorized IQD values inside
                                    // narrow iPhone cash-breakdown rows. The
                                    // enclosing Semantics preserves the full
                                    // amount for assistive technologies.
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          _money(point['cash_iqd']),
                                          maxLines: 1,
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ),
                                    ),
                                  ]),
                                ),
                              ),
                            ),
                    ],
                  )));
        });
  }

  Map<String, dynamic> _authorizedInsightMetrics(
      Map<String, dynamic> data) {
    const sectionByMetric = <String, String>{
      'urgent_guest_requests': 'action_center',
      'overdue_service_orders': 'table_orders',
      'out_of_stock_count': 'products_inventory',
      'low_stock_count': 'products_inventory',
      'cash_reconciliation_discrepancies': 'payments_management',
      'open_maintenance_issues': 'maintenance',
      'pending_offline_sync': 'offline_mode_synchronization',
    };
    return <String, dynamic>{
      for (final entry in sectionByMetric.entries)
        if (dashboardMetricIsVisible(
          allowedSections: widget.allowedSections,
          hasMetric: data.containsKey(entry.key),
          section: entry.value,
        ))
          entry.key: data[entry.key],
    };
  }

  Widget _alertTile(
      String title, Object? count, IconData icon, String section) {
    if (!dashboardMetricIsVisible(
      allowedSections: widget.allowedSections,
      hasMetric: true,
      section: section,
    )) return const SizedBox.shrink();
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text('$title: ${count ?? '—'}'),
      onPressed: () => widget.onOpenSection(section),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: MediaQuery.sizeOf(context).width < 420
            ? const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w800))
            : const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text('Gelye Sherane', style: TextStyle(fontWeight: FontWeight.w800)), Text('Management Dashboard', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Color(0xFFE8D5A4)))]), actions: [
          SizedBox(
            width: MediaQuery.sizeOf(context).width < 420 ? 170 : 330,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(mainAxisSize: MainAxisSize.min, children: [

          if (MediaQuery.sizeOf(context).width < 420) const SizedBox(width: 2),
          if (widget.allowedSections.contains('dashboard'))
            IconButton(
              tooltip: 'My service notifications',
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) =>
                  const ServiceTaskNotificationInbox())),
            ),
          if (widget.allowedSections.contains('motel_orders'))
            IconButton(
              tooltip: 'Motel meal offers and scheduled deliveries',
              icon: const Icon(Icons.room_service),
              onPressed: () {
                final detail = const MotelMealOffersPanel();
                if (MediaQuery.sizeOf(context).width < 700) {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => detail));
                } else {
                  showGeneralDialog<void>(
                    context: context,
                    barrierDismissible: true,
                    barrierLabel: 'Close motel meal offers',
                    pageBuilder: (ctx, _, __) => Align(
                      alignment: Alignment.centerRight,
                      child: Material(elevation: 16, child: SizedBox(
                        width: 560, height: MediaQuery.sizeOf(ctx).height,
                        child: detail)),
                    ),
                  );
                }
              },
            ),
          if (widget.allowedSections.contains('dashboard'))
            IconButton(
              tooltip: 'Owner guest complimentary offers',
              icon: const Icon(Icons.workspace_premium_outlined),
              onPressed: () {
                final detail = const OwnerGuestOffersPanel();
                if (MediaQuery.sizeOf(context).width < 700) {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => detail));
                } else {
                  showGeneralDialog<void>(
                    context: context,
                    barrierDismissible: true,
                    barrierLabel: 'Close owner offers',
                    pageBuilder: (ctx, _, __) => Align(
                      alignment: Alignment.centerRight,
                      child: Material(elevation: 16, child: SizedBox(
                        width: 560, height: MediaQuery.sizeOf(ctx).height,
                        child: detail)),
                    ),
                  );
                }
              },
            ),
          if (widget.allowedSections.contains('dashboard'))
            IconButton(
              tooltip: 'Dashboard integration review',
              icon: const Icon(Icons.fact_check_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) =>
                  const DashboardIntegrationReview())),
            ),
          IconButton(tooltip: 'Dashboard filters', icon: const Icon(Icons.filter_alt_outlined), onPressed: _openDashboardFilters),
            IconButton(
              tooltip: _editingCards ? 'Finish editing cards' : 'Customize cards',
              onPressed: () => setState(() => _editingCards = !_editingCards),
              icon: Icon(_editingCards ? Icons.check : Icons.dashboard_customize_outlined)),
          IconButton(
              tooltip: 'Refresh live figures',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh)),
          IconButton(
              tooltip: _automatic
                  ? 'Pause automatic refresh'
                  : 'Resume automatic refresh',
              onPressed: () => setState(() => _automatic = !_automatic),
              icon: Icon(_automatic
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline))
              ]),
            ),
          ),
        ]),
        body: FutureBuilder<Map<String, dynamic>>(
            future: _overview,
            builder: (context, snapshot) {
              // The date picker can change the selected day while an older
              // request is still running. Do not display that request's
              // figures under the newly selected business-day heading.
              // _refresh() queues the new day and restores the overview.
              if (_loadingDay != null && _loadingDay != _dateString()) {
                return Center(
                  child: Semantics(
                    liveRegion: true,
                    label: 'Loading dashboard for the selected business day',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Switching business day…'),
                      ],
                    ),
                  ),
                );
              }
              return LayoutBuilder(builder: (context, bounds) {
                final wide = bounds.maxWidth >= 900;
                // Keep two metric columns on typical narrow iPhones while
                // retaining a single column for very small windows and large
                // accessibility text. Wider layouts retain existing behavior.
                final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                final cols = wide
                    ? 4
                    : bounds.maxWidth >= 650
                        ? 3
                        : bounds.maxWidth >= 340 && textScale <= 1.3
                            ? 2
                            : 1;
                return RefreshIndicator(
                    onRefresh: _refreshFromPull,
                    child: ListView(
                        padding: EdgeInsets.all(wide ? 24 : 12),
                        children: [
                          Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Business overview',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall),
                                      Text(
                                          'Supabase · Baghdad business dates · ${_automatic ? 'Auto-refresh every 30 seconds' : 'Auto-refresh paused'}'),
                                      if (_lastSuccessfulRefresh != null && _lastSuccessfulDay == _dateString())
                                        Text(
                                            'Last successful refresh: ${MaterialLocalizations.of(context).formatMediumDate(_lastSuccessfulRefresh!)} ${TimeOfDay.fromDateTime(_lastSuccessfulRefresh!).format(context)} (device time)',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                      if (_lastRefreshError != null)
                                        Text(_lastRefreshError!,
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error)),
                                    ]),
                                OutlinedButton.icon(
                                    onPressed: _pickDay,
                                    icon: const Icon(
                                        Icons.calendar_today_outlined),
                                    label: Text(
                                        '${_day.year}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}')),
                              ]),
                           const SizedBox(height: 8),
                           Wrap(spacing: 6, runSpacing: 6, children: [
                             OutlinedButton(onPressed: () => _selectQuickDay(-1), child: const Text('Yesterday')),
                             OutlinedButton(onPressed: () => _selectQuickDay(0), child: const Text('Today')),
                             OutlinedButton(onPressed: () => _periodNotAvailable('Last week'), child: const Text('Last week')),
                             OutlinedButton(onPressed: () => _periodNotAvailable('Last month'), child: const Text('Last month')),
                             OutlinedButton(onPressed: () => _periodNotAvailable('Tomorrow'), child: const Text('Tomorrow')),
                           ]),
                           const Text('Period totals and tomorrow forecasts require verified server support. Current figures show one Baghdad business day.'),
                           const SizedBox(height: 8),
                           const Text('User filter: current authorized account only. Employee-wide filters require server-side authorization.'),
                          const SizedBox(height: 14),
                          if (widget.allowedSections.contains('dashboard')) ...[
                            if (widget.allowedSections.contains('payments_management')) ...[
                              Card(child: ListTile(
                                leading: const Icon(Icons.verified_user_outlined),
                                title: const Text('Payment Confirmations'),
                                subtitle: const Text('Credit and online payments awaiting receiver verification'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _openPaymentConfirmations,
                              )),
                              const SizedBox(height: 8),
                            ],
                            if (widget.allowedSections.contains('security_access_control')) ...[
                              Card(child: ListTile(
                                leading: const Icon(Icons.manage_history),
                                title: const Text('System Audit & Employee History'),
                                subtitle: const Text('Protected employee actions and changes'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _openSystemAudit,
                              )),
                              const SizedBox(height: 8),
                            ],
                            GuestEngagementCards(onOpen: _openGuestEngagement),
                            const SizedBox(height: 8),
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.fact_check_outlined),
                                title: const Text('Guest & Product Reviews'),
                                subtitle: const Text('Read-only review preview · live review feed pending'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _openEngagementReview,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Retain usable authorized figures, but clearly disclose a
                          // failed refresh rather than presenting cached data as live.
                          if (snapshot.hasError && snapshot.hasData)
                            Semantics(
                              liveRegion: true,
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_outlined),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Text(
                                          'Refresh failed. Showing previously loaded Dashboard data; figures may be outdated.',
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Retry live Dashboard data',
                                        onPressed: _refresh,
                                        icon: const Icon(Icons.refresh),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (snapshot.connectionState != ConnectionState.done &&
                              !snapshot.hasData)
                            Semantics(
                                liveRegion: true,
                                label: 'Loading authorized Dashboard figures',
                                child: Padding(
                                    padding: EdgeInsets.all(30),
                                    child: Center(
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                          CircularProgressIndicator(),
                                          SizedBox(height: 12),
                                          Text('Loading live Dashboard data…'),
                                        ]))))
                          else if (snapshot.hasError && !snapshot.hasData)
                            Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(children: [
                                      const Icon(Icons.cloud_off_outlined,
                                          size: 40),
                                      const SizedBox(height: 10),
                                      Semantics(
                                        liveRegion: true,
                                        child: Text(
                                            'Live Dashboard unavailable. No figures are being estimated.')),
                                      const SizedBox(height: 6),
                                      const Text(
                                          'Check your connection and account permissions. If the problem continues, ask an administrator to verify the Dashboard backend.'),
                                      const SizedBox(height: 12),
                                      Semantics(
                                        button: true,
                                        label: 'Retry loading live Dashboard figures',
                                        child: OutlinedButton.icon(
                                          onPressed: _refresh,
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Retry live data'),
                                        ),
                                      ),
                                    ])))
                          else if (!snapshot.hasData || snapshot.data == null)
                            Semantics(
                              liveRegion: true,
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.info_outline, size: 40),
                                      const SizedBox(height: 10),
                                      const Text('No Dashboard data returned'),
                                      const SizedBox(height: 6),
                                      const Text('The Dashboard request completed without a data snapshot. Refresh to try again.'),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: _refresh,
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Retry live data'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else if (snapshot.data!.isEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.inbox_outlined, size: 40),
                                    const SizedBox(height: 10),
                                    const Text('Dashboard data is empty'),
                                    const SizedBox(height: 6),
                                    const Text('No authorized Dashboard figures were returned. Check access or refresh.'),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: _refresh,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retry live data'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else ...[
                            // Display a real client-side freshness timestamp only
                            // after an authorized non-empty snapshot is received.
                            // This is not the server's transaction timestamp.
                            if (_lastSuccessfulRefresh != null && _lastSuccessfulDay == _dateString())
                              Semantics(
                                label: 'Dashboard for selected business day ${_dateString()}. '
                                    'Last loaded on this device at '
                                    '${MaterialLocalizations.of(context).formatMediumDate(_lastSuccessfulRefresh!)} '
                                    '${TimeOfDay.fromDateTime(_lastSuccessfulRefresh!).format(context)}',
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Business day: ${_dateString()} (Baghdad)\n'
                                          'Last loaded on this device: '
                                          '${MaterialLocalizations.of(context).formatMediumDate(_lastSuccessfulRefresh!)} '
                                          '${TimeOfDay.fromDateTime(_lastSuccessfulRefresh!).format(context)}',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Builder(builder: (context) {
                              final data = snapshot.data!;
                              final cards = <Widget>[
                                _metric('Orders today', 'orders',
                                    Icons.receipt_long_outlined, data,
                                    section: 'table_orders'),
                                _metric('Active orders', 'active_orders',
                                    Icons.pending_actions_outlined, data,
                                    section: 'table_orders'),
                                _metric(
                                    'Order value (not collected)',
                                    'order_value_iqd',
                                    Icons.shopping_bag_outlined,
                                    data,
                                    money: true,
                                    section: 'payments_management'),
                                _metric('Recorded cash · retry receipts in Payments', 'cash_collected_iqd',
                                    Icons.payments_outlined, data,
                                    money: true,
                                    section: 'payments_management'),
                                _metric(
                                    'Outstanding order balances',
                                    'outstanding_iqd',
                                    Icons.account_balance_wallet_outlined,
                                    data,
                                    money: true,
                                    section: 'payments_management'),
                                // Finance batch: values are supplied ONLY by
                                // an authorized dashboard RPC. Missing fields
                                // remain explicitly unavailable, never zero.
                                if (widget.allowedSections.contains('payments_management')) ...[
                                  // Financial source readiness is reviewed in Payments Management.
                                  // Source binding and payment overlap counts are reviewed in Payments Management.
                                  // Schema presence alone never verifies settlement completeness.
                                  // Live balances are NOT collected cash or recognized revenue.
                                  // Keep unavailable until authorized, deduplicated backend
                                  // snapshots exist. Never derive these from cash-only RPCs.
                                  // Crosswalk-aware per-order source coverage is available in Payments Management.
                                  // Source evidence may overlap; do not add figures into a balance.
                                  // Source identity candidates and cross-order conflicts are reviewed in Payments Management.
                                  // Per-order all-method ledger preview is available from
                                  // Payments Management, but does not certify balances.
                                  // Canonical visit/reversal diagnostics (including orphan references)
                                  // are reviewed in Payments Management. Do not show a
                                  // live balance until all-method settlement is verified.
                                  // Reference amount consistency and motel UUID-to-legacy
                                  // bridge checks are available in Payments Management.
                                  // Never interpret missing bridge as prepaid settlement.
                                  _liveUnpaidCard('Standing Cash · active café guests', 'standing_cash_active_visits_iqd', Icons.table_restaurant_outlined),
                                  _liveUnpaidCard('Pending Payment · online & motel', 'pending_online_motel_unpaid_iqd', Icons.pending_actions_outlined),
                                  _financialMetricCard('Total Payments Received', 'total_payments_received_iqd', Icons.account_balance_outlined, data, money: true),
                                  _financialMetricCard('Total Expenses', 'total_expenses_iqd', Icons.receipt_long_outlined, data, money: true),
                                  _financialMetricCard('Net Profit', 'net_profit_iqd', Icons.trending_up_outlined, data, money: true),
                                  _financialMetricCard('Pending Payment Confirmations', 'pending_payment_confirmations_count', Icons.verified_outlined, data, money: false),
                                  _financialMetricCard('Refunds & Returns', 'refunds_returns_iqd', Icons.currency_exchange_outlined, data, money: true),
                                  _financialMetricCard('Cashier Balances', 'cashier_balances_iqd', Icons.person_outline, data, money: true),
                                  _financialMetricCard('Cash Handover', 'cash_handover_iqd', Icons.swap_horiz_outlined, data, money: true),
                                  _financialMetricCard('Customer Credit Balances', 'customer_credit_balances_iqd', Icons.credit_card_outlined, data, money: true),
                                  _financialMetricCard('Discounts & Complimentary Orders', 'discounts_complimentary_iqd', Icons.local_offer_outlined, data, money: true),
                                  _financialMetricCard('Payments by Method', 'payments_by_method_count', Icons.pie_chart_outline, data, money: false),
                                  _financialMetricCard('Cancelled & Voided Transactions', 'cancelled_voided_count', Icons.block_outlined, data, money: false),
                                  _financialMetricCard('Daily Cash Closing', 'daily_cash_closing_iqd', Icons.fact_check_outlined, data, money: true),
                                ],
                                _metric('Tourism orders', 'tourism_orders',
                                    Icons.travel_explore_outlined, data,
                                    section: 'table_orders'),
                                _metric('Kitchen queue', 'kitchen_queue',
                                    Icons.restaurant_outlined, data,
                                    section: 'kitchen'),
                                _metric('Motel orders', 'motel_orders',
                                    Icons.hotel_outlined, data,
                                    section: 'motel_orders'),
                                _metric('Occupied tables', 'occupied_tables',
                                    Icons.table_restaurant_outlined, data,
                                    section: 'tables'),
                                _metric('Total tables', 'total_tables',
                                    Icons.grid_view_outlined, data,
                                    section: 'tables'),
                                _metric('Seated guests', 'seated_guests',
                                    Icons.people_outline, data,
                                    section: 'tables'),
                                // Status cards are shown only when the authorized
                                // dashboard RPC supplies the corresponding metric.
                                for (final status in <(String, String, IconData, String)>[
                                  ('Table orders · Waiting', 'table_orders_waiting', Icons.hourglass_empty, 'table_orders'),
                                  ('Table orders · Preparing', 'table_orders_preparing', Icons.soup_kitchen_outlined, 'table_orders'),
                                  ('Table orders · Delivered', 'table_orders_delivered', Icons.task_alt_outlined, 'table_orders'),
                                  ('Motel orders · Waiting', 'motel_orders_waiting', Icons.hourglass_empty, 'motel_orders'),
                                  ('Motel orders · Preparing', 'motel_orders_preparing', Icons.soup_kitchen_outlined, 'motel_orders'),
                                  ('Motel orders · Delivered', 'motel_orders_delivered', Icons.task_alt_outlined, 'motel_orders'),
                                  ('Reserved · Not arrived', 'reservations_not_arrived', Icons.event_seat_outlined, 'tables'),
                                  ('Reservations · Arrived', 'reservations_arrived', Icons.how_to_reg_outlined, 'tables'),
                                  ('Reservations · Late', 'reservations_late', Icons.access_time_outlined, 'tables'),
                                  ('Reservations · No-show', 'reservations_no_show', Icons.event_busy_outlined, 'tables'),
                                  ('Upcoming reservations', 'reservations_upcoming', Icons.event_available_outlined, 'tables'),
                                ])
                                  if (widget.allowedSections.contains(status.$4))
                                    _metric(status.$1, status.$2, status.$3, data, section: status.$4),
                                // Upgrade 26: eight operational intelligence areas.
                                // Only display real, permission-scoped values
                                // supplied by gs_dashboard_overview. Missing
                                // backend metrics are intentionally not invented.
                                for (final area in <(String, String, IconData, String)>[
                                  ('Urgent actions', 'urgent_actions_count', Icons.notification_important_outlined, 'action_center'),
                                  ('Overdue service orders', 'overdue_service_orders', Icons.timer_outlined, 'table_orders'),
                                  ('Cash discrepancies · review ledger', 'cash_discrepancies_count', Icons.account_balance_wallet_outlined, 'payments_management'),
                                  ('Employees on duty', 'employees_on_duty', Icons.badge_outlined, 'employees'),
                                  ('Top product units sold', 'top_product_units_sold', Icons.trending_up_outlined, 'menu'),
                                  ('Table occupancy %', 'table_occupancy_percent', Icons.table_restaurant_outlined, 'tables'),
                                  ('Open maintenance issues', 'open_maintenance_issues', Icons.build_outlined, 'maintenance'),
                                  ('Pending offline sync items', 'pending_offline_sync_items', Icons.sync_problem_outlined, 'offline_mode_synchronization'),
                                ])
                                  if (widget.allowedSections.contains(area.$4) &&
                                      data[area.$2] is num)
                                    _metric(area.$1, area.$2, area.$3, data,
                                        section: area.$4),
                                      if (dashboardMetricIsVisible(
                                        allowedSections: widget.allowedSections,
                                        section: 'tables',
                                        hasMetric: data['customers_today'] is num,
                                      ))
                                  CustomerCountCard(
                                    title: 'Customers today',
                                    count: (data['customers_today'] as num).toInt(),
                                    onTap: () => _openMetricDetails(
                                      'Customers today', 'customers_today',
                                      data['customers_today'], money: false,
                                      section: 'tables'),
                                  ),
                                      if (dashboardMetricIsVisible(
                                        allowedSections: widget.allowedSections,
                                        section: 'table_orders',
                                        hasMetric: data['tourism_customers'] is num,
                                      ))
                                  CustomerCountCard(
                                    title: 'Tourism customers',
                                    count: (data['tourism_customers'] as num).toInt(),
                                    onTap: () => _openMetricDetails(
                                      'Tourism customers', 'tourism_customers',
                                      data['tourism_customers'], money: false,
                                      section: 'table_orders'),
                                  ),
                              ].where((widget) => widget is! SizedBox).toList();
                              final keyed = <String, Widget>{};
                              for (final card in cards) {
                                // All standard KPI cards have a stable ValueKey.
                                if (card.key is ValueKey<String>) {
                                  keyed[(card.key! as ValueKey<String>).value] = card;
                                }
                              }
                              final priority = _focusPriorities[_focusMode] ?? const <String>[];
                              final defaults = keyed.keys.toList()
                                ..sort((a, b) {
                                  final ai = priority.indexOf(a);
                                  final bi = priority.indexOf(b);
                                  if (ai == -1 && bi == -1) return 0;
                                  if (ai == -1) return 1;
                                  if (bi == -1) return -1;
                                  return ai.compareTo(bi);
                                });
                              // Employee overrides take precedence over mode defaults.
                              final orderedIds = [
                                ..._cardOrder.where(keyed.containsKey),
                                ...defaults.where((id) => !_cardOrder.contains(id)),
                              ];
                              final orderedCards = [
                                ...orderedIds.where((id) => !_hiddenCards.contains(id))
                                    .map((id) => (id, keyed[id]!)),
                              ];
                              return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Card(
                                        child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Row(children: [
                                              const Icon(
                                                  Icons.verified_user_outlined),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                  child: Text(
                                                      'Live data · Only metrics permitted for your account are returned. Cash does not include card or credit payments.',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall)),
                                            ]))),
                                    const SizedBox(height: 10),
                                    Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        const Text('Dashboard focus:'),
                                        DropdownButton<String>(
                                          value: _focusMode,
                                          items: _focusModes.entries.map((entry) => DropdownMenuItem<String>(
                                            value: entry.key, child: Text(entry.value))).toList(),
                                          onChanged: (mode) {
                                            if (mode == null) return;
                                            setState(() => _focusMode = mode);
                                            _saveCardPreferences();
                                          },
                                        ),
                                        const Text('Focus changes card order, not employee permissions.'),
                                      ]),
                                    const SizedBox(height: 10),
                                    Text('Key performance indicators',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                    const SizedBox(height: 8),
                                    if (_editingCards && orderedIds.isNotEmpty) ...[
                                      const Text('Drag or move KPI cards; set color, size, and visibility per card. Hiding a KPI never disables required alerts. Changes save on this device and sync to your signed-in account when the cloud preference service is available.'),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 260,
                                        child: ReorderableListView.builder(
                                          buildDefaultDragHandles: false,
                                          itemCount: orderedIds.length,
                                          onReorder: (oldIndex, newIndex) =>
                                              _reorderCards(oldIndex, newIndex, orderedIds),
                                          itemBuilder: (context, i) {
                                            final id = orderedIds[i];
                                            return Card(
                                              key: ValueKey<String>('editor_$id'),
                                              child: ListTile(
                                                dense: true,
                                                leading: ReorderableDragStartListener(
                                                  index: i,
                                                  child: const Icon(Icons.drag_handle,
                                                      semanticLabel: 'Drag to reorder'),
                                                ),
                                                title: Text(id.replaceAll('_', ' ')),
                                                subtitle: Text('Position ${i + 1} · ${_cardSizes[id] == 0 ? 'Compact' : _cardSizes[id] == 2 ? 'Large' : 'Regular'}'),
                                                trailing: SizedBox(width: 240, child: SingleChildScrollView(
                                                  scrollDirection: Axis.horizontal,
                                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                                    IconButton(
                                                      tooltip: 'Move earlier',
                                                      onPressed: i == 0 ? null : () =>
                                                          _moveCard(id, -1, orderedIds),
                                                      icon: const Icon(Icons.arrow_upward),
                                                    ),
                                                    IconButton(
                                                      tooltip: 'Move later',
                                                      onPressed: i == orderedIds.length - 1
                                                          ? null : () => _moveCard(id, 1, orderedIds),
                                                      icon: const Icon(Icons.arrow_downward),
                                                    ),
                                                    IconButton(
                                                      tooltip: _hiddenCards.contains(id) ? 'Show KPI' : 'Hide KPI',
                                                      onPressed: () => _setCardVisibility(id, _hiddenCards.contains(id)),
                                                      icon: Icon(_hiddenCards.contains(id)
                                                          ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                                    ),
                                                    PopupMenuButton<int>(
                                                      tooltip: 'Card size',
                                                      icon: const Icon(Icons.aspect_ratio_outlined),
                                                      onSelected: (size) => _changeCardSize(id, size),
                                                      itemBuilder: (_) => const [
                                                        PopupMenuItem(value: 0, child: Text('Compact')),
                                                        PopupMenuItem(value: 1, child: Text('Regular')),
                                                        PopupMenuItem(value: 2, child: Text('Large / full row')),
                                                      ],
                                                    ),
                                                    PopupMenuButton<int>(
                                                      tooltip: 'Change card color',
                                                      icon: const Icon(Icons.palette_outlined),
                                                      onSelected: (index) => _changeCardColor(id, index),
                                                      itemBuilder: (_) => [
                                                        for (var color = 0; color < _palette.length; color++)
                                                          PopupMenuItem<int>(
                                                            value: color,
                                                            child: Row(children: [
                                                              CircleAvatar(radius: 9,
                                                                  backgroundColor: _palette[color]),
                                                              const SizedBox(width: 10),
                                                              Text('Color ${color + 1}'),
                                                            ]),
                                                          ),
                                                      ],
                                                    ),
                                                  ])),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      TextButton.icon(onPressed: () {
                                        setState(() { _cardOrder = []; _cardColors.clear(); _cardSizes.clear(); _hiddenCards.clear(); });
                                        _saveCardPreferences();
                                      }, icon: const Icon(Icons.restart_alt), label: const Text('Reset layout, colors, sizes and visibility')),
                                    ],
                                    if (cards.isEmpty)
                                      const Text(
                                          'No dashboard metrics available for your permissions.')
                                    else
                                      LayoutBuilder(builder: (context, constraints) {
                                        const gap = 10.0;
                                        final availableWidth = constraints.maxWidth.isFinite
                                            ? constraints.maxWidth : MediaQuery.sizeOf(context).width - 24;
                                        final baseWidth = ((availableWidth - (cols - 1) * gap) / cols)
                                            .clamp(0.0, availableWidth);
                                        return Wrap(spacing: gap, runSpacing: gap, children: [
                                          for (final entry in orderedCards)
                                            SizedBox(
                                              width: _cardSizes[entry.$1] == 2
                                                  ? availableWidth : baseWidth,
                                              height: _cardSizes[entry.$1] == 0 ? 120
                                                  : _cardSizes[entry.$1] == 2 ? 175 : 155,
                                              child: entry.$2,
                                            ),
                                        ]);
                                      }),
                                    const SizedBox(height: 16),
                                    if (widget.allowedSections.contains('tables'))
                                      LiveTableMap(
                                        rows: data['table_map'] is List
                                            ? (data['table_map'] as List)
                                                .whereType<Map>()
                                                .map((row) => Map<String, dynamic>.from(row))
                                                .toList()
                                            : const <Map<String, dynamic>>[],
                                        onTableTap: (table) => _openTableDetails(table),
                                      ),
                                    const SizedBox(height: 16),
                                    _weekChart(),
                                    const SizedBox(height: 16),
                                    DashboardInsightsPanel(
                                      metrics: _authorizedInsightMetrics(data),
                                    ),
                                    const SizedBox(height: 16),
                                    Text('Action center',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                    const SizedBox(height: 8),
                                    Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          if (data
                                              .containsKey('low_stock_count'))
                                            _alertTile(
                                                'Low stock',
                                                data['low_stock_count'],
                                                Icons.inventory_2_outlined,
                                                'products_inventory'),
                                          if (data.containsKey(
                                              'out_of_stock_count'))
                                            _alertTile(
                                                'Out of stock',
                                                data['out_of_stock_count'],
                                                Icons.warning_amber_outlined,
                                                'products_inventory'),
                                          if (data.containsKey('kitchen_queue'))
                                            _alertTile(
                                                'Kitchen waiting',
                                                data['kitchen_queue'],
                                                Icons.restaurant_outlined,
                                                'kitchen'),
                                          if (data.containsKey('active_orders'))
                                            _alertTile(
                                                'Active orders',
                                                data['active_orders'],
                                                Icons.pending_actions_outlined,
                                                'table_orders'),
                                        ]),
                                    const SizedBox(height: 16),
                                    Card(
                                        child: Padding(
                                            padding: const EdgeInsets.all(14),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text('Accounting notes',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium),
                                                  const SizedBox(height: 6),
                                                  const Text(
                                                      'Order value represents orders created on the selected date, not payments. Cash collected represents cash received on that date, even for earlier orders. Outstanding balances apply to non-cancelled orders created on the selected date. Other payment channels are not included.'),
                                                ]))),
                                    const SizedBox(height: 16),
                                    // Upgrade 181: dedicated takeaway/delivery dashboard entry.
                                    // Uses existing Table Orders permission; no fabricated
                                    // revenue or completed-delivery figures are shown.
                                    if (widget.allowedSections.contains('table_orders'))
                                      Card(
                                        child: ListTile(
                                          leading: const Icon(Icons.takeout_dining_outlined),
                                          title: const Text('Takeaway & Delivery'),
                                          subtitle: const Text(
                                            'No-table pickup and delivery requests · Open Table Orders, then Takeaway & Delivery'),
                                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                          onTap: () => widget.onOpenSection('table_orders'),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Text('Operations',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                    const SizedBox(height: 8),
                                    Wrap(spacing: 8, runSpacing: 8, children: [
                                      for (final item
                                          in <(String, String, IconData)>[
                                        (
                                          'tables',
                                          'Tables',
                                          Icons.table_restaurant_outlined
                                        ),
                                        (
                                          'table_orders',
                                          'Table Orders',
                                          Icons.receipt_outlined
                                        ),
                                        (
                                          'kitchen',
                                          'Kitchen',
                                          Icons.soup_kitchen_outlined
                                        ),
                                        (
                                          'motel_orders',
                                          'Motel Orders',
                                          Icons.hotel_outlined
                                        ),
                                        (
                                          'menu',
                                          'Menu',
                                          Icons.menu_book_outlined
                                        ),
                                        (
                                          'products_inventory',
                                          'Inventory',
                                          Icons.inventory_2_outlined
                                        ),
                                        (
                                          'reports',
                                          'Reports',
                                          Icons.bar_chart_outlined
                                        ),
                                      ])
                                        if (widget.allowedSections
                                            .contains(item.$1))
                                          ActionChip(
                                              avatar: Icon(item.$3, size: 18),
                                              label: Text(item.$2),
                                              onPressed: () => widget
                                                  .onOpenSection(item.$1)),
                                    ]),
                                    const SizedBox(height: 20),
                                    Center(child: Column(children: [
                                      const Text('All rights reserved for Gelye Sherane Café & Restaurant', textAlign: TextAlign.center),
                                      const Text('Powered by Zanyar Sidqi', textAlign: TextAlign.center),
                                      const Text(
                                        'Version ${AppReleaseVersion.label}',
                                        textAlign: TextAlign.center,
                                      ),
                                    ])),
                                  ]);
                            }),
                          ],
                        ]));
              });
            }),
      );
}
