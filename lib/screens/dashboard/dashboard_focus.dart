const dashboardFocusModes = <String, String>{
  'manager': 'Manager',
  'cashier': 'Cashier',
  'waiter': 'Waiter',
  'kitchen': 'Kitchen',
};

// null means show every card the server already authorized for the employee.
// These presets only narrow that authorized set; they never grant data access.
const dashboardFocusCardSets = <String, Set<String>?>{
  'manager': null,
  'cashier': <String>{
    'orders',
    'active_orders',
    'order_value_iqd',
    'cash_collected_iqd',
    'outstanding_iqd',
    'standing_cash_active_visits_iqd',
    'pending_online_motel_unpaid_iqd',
    'total_payments_received_iqd',
    'total_expenses_iqd',
    'net_profit_iqd',
    'pending_payment_confirmations_count',
    'refunds_returns_iqd',
    'cashier_balances_iqd',
    'cash_handover_iqd',
    'customer_credit_balances_iqd',
    'discounts_complimentary_iqd',
    'payments_by_method_count',
    'cancelled_voided_count',
    'daily_cash_closing_iqd',
    'cash_discrepancies_count',
    'pending_offline_sync_items',
    'urgent_actions_count',
  },
  'waiter': <String>{
    'orders',
    'active_orders',
    'tourism_orders',
    'occupied_tables',
    'total_tables',
    'seated_guests',
    'table_orders_waiting',
    'table_orders_preparing',
    'table_orders_delivered',
    'reservations_not_arrived',
    'reservations_arrived',
    'reservations_late',
    'reservations_no_show',
    'reservations_upcoming',
    'urgent_actions_count',
    'overdue_service_orders',
    'table_occupancy_percent',
    'customers_today',
    'tourism_customers',
    'top_product_units_sold',
  },
  'kitchen': <String>{
    'orders',
    'active_orders',
    'kitchen_queue',
    'tourism_orders',
    'motel_orders',
    'table_orders_waiting',
    'table_orders_preparing',
    'table_orders_delivered',
    'motel_orders_waiting',
    'motel_orders_preparing',
    'motel_orders_delivered',
    'urgent_actions_count',
    'overdue_service_orders',
    'top_product_units_sold',
    'pending_offline_sync_items',
  },
};

const dashboardFocusPriorities = <String, List<String>>{
  'manager': [
    'urgent_actions_count',
    'orders',
    'active_orders',
    'cash_collected_iqd',
    'outstanding_iqd',
    'occupied_tables',
    'kitchen_queue',
    'net_profit_iqd',
  ],
  'cashier': [
    'outstanding_iqd',
    'cash_collected_iqd',
    'standing_cash_active_visits_iqd',
    'pending_online_motel_unpaid_iqd',
    'pending_payment_confirmations_count',
    'daily_cash_closing_iqd',
    'cashier_balances_iqd',
    'cash_handover_iqd',
    'orders',
    'active_orders',
    'order_value_iqd',
  ],
  'waiter': [
    'active_orders',
    'table_orders_waiting',
    'table_orders_preparing',
    'occupied_tables',
    'seated_guests',
    'reservations_upcoming',
    'orders',
    'tourism_orders',
    'tourism_customers',
    'customers_today',
  ],
  'kitchen': [
    'kitchen_queue',
    'table_orders_waiting',
    'table_orders_preparing',
    'motel_orders_waiting',
    'motel_orders_preparing',
    'active_orders',
    'orders',
    'motel_orders',
    'tourism_orders',
    'overdue_service_orders',
  ],
};

List<String> dashboardCardOrderForFocus({
  required String focusMode,
  required Iterable<String> availableCardIds,
  required Iterable<String> employeeOrder,
}) {
  final available = availableCardIds.toSet();
  final mode = dashboardFocusModes.containsKey(focusMode) ? focusMode : 'manager';
  final focusSet = dashboardFocusCardSets[mode];
  final eligible = focusSet == null
      ? available
      : available.intersection(focusSet);
  final ordered = <String>[];
  final seen = <String>{};

  for (final id in employeeOrder) {
    if (eligible.contains(id) && seen.add(id)) ordered.add(id);
  }

  final priority = dashboardFocusPriorities[mode] ?? const <String>[];
  final remaining = eligible.where((id) => !seen.contains(id)).toList()
    ..sort((a, b) {
      final ai = priority.indexOf(a);
      final bi = priority.indexOf(b);
      if (ai != -1 || bi != -1) {
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        final comparedPriority = ai.compareTo(bi);
        if (comparedPriority != 0) return comparedPriority;
      }
      return a.compareTo(b);
    });
  ordered.addAll(remaining);
  return ordered;
}
