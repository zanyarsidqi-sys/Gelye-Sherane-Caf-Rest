import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_cafe_rest/screens/dashboard/dashboard_focus.dart';

void main() {
  const allCards = <String>{
    'cash_collected_iqd',
    'outstanding_iqd',
    'orders',
    'active_orders',
    'occupied_tables',
    'seated_guests',
    'table_orders_waiting',
    'reservations_upcoming',
    'kitchen_queue',
    'motel_orders_preparing',
    'customers_today',
  };

  test('Manager focus retains every card already available to the account', () {
    final cards = dashboardCardOrderForFocus(
      focusMode: 'manager',
      availableCardIds: allCards,
      employeeOrder: const [],
    );
    expect(cards.toSet(), allCards);
  });

  test('Cashier focus selects payment cards rather than operational-only cards', () {
    final cards = dashboardCardOrderForFocus(
      focusMode: 'cashier',
      availableCardIds: allCards,
      employeeOrder: const [],
    );
    expect(cards, contains('cash_collected_iqd'));
    expect(cards, contains('outstanding_iqd'));
    expect(cards, isNot(contains('kitchen_queue')));
    expect(cards, isNot(contains('occupied_tables')));
  });

  test('Waiter and Kitchen focus switch to their operational card groups', () {
    final waiter = dashboardCardOrderForFocus(
      focusMode: 'waiter',
      availableCardIds: allCards,
      employeeOrder: const ['cash_collected_iqd', 'orders'],
    );
    final kitchen = dashboardCardOrderForFocus(
      focusMode: 'kitchen',
      availableCardIds: allCards,
      employeeOrder: const ['cash_collected_iqd', 'orders'],
    );

    expect(waiter, containsAll(['occupied_tables', 'seated_guests', 'reservations_upcoming']));
    expect(waiter, isNot(contains('cash_collected_iqd')));
    expect(kitchen, containsAll(['kitchen_queue', 'motel_orders_preparing']));
    expect(kitchen, isNot(contains('cash_collected_iqd')));
  });

  test('Focus cannot add a card that permissions did not provide', () {
    final cards = dashboardCardOrderForFocus(
      focusMode: 'waiter',
      availableCardIds: const ['cash_collected_iqd', 'active_orders'],
      employeeOrder: const ['cash_collected_iqd', 'active_orders'],
    );
    expect(cards, ['active_orders']);
  });
}
