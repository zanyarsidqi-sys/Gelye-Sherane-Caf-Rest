import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/staff_dashboard_page.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    bool staff = false,
    bool mobile = false,
  }) async {
    tester.view.physicalSize = mobile
        ? const Size(390, 844)
        : const Size(1440, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: StaffDashboardPage(
          email: 'review@example.com',
          role: staff ? 'staff' : 'admin',
          grantedPermissions: staff
              ? const {'dashboard:today_revenue'}
              : const {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('category selection shows only the selected category', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Today Revenue'), findsOneWidget);
    expect(find.text('Standing Cash'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('dashboard-category-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('Standing Cash'), findsOneWidget);
    expect(find.text('Today Revenue'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('dashboard-category-tab-0')));
    await tester.pumpAndSettle();
    expect(find.text('Today Revenue'), findsOneWidget);
    expect(find.text('Standing Cash'), findsNothing);
  });
  testWidgets('Favorites navigation returns to Dashboard on phone', (
    tester,
  ) async {
    await open(tester, mobile: true);
    await tester.tap(find.byTooltip('Favorites'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('favorites-picker')), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard-search')), findsNothing);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dashboard-search')), findsOneWidget);
    expect(find.byKey(const ValueKey('favorites-picker')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('dashboard search filters cards and clears back to the catalog', (
    tester,
  ) async {
    await open(tester);
    final search = find.byKey(const ValueKey('dashboard-search'));
    await tester.enterText(search, 'Today Revenue');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('dashboard-card-today_revenue')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-card-kitchen_orders')),
      findsNothing,
    );
    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('dashboard-card-kitchen_orders')),
      findsOneWidget,
    );
  });
  testWidgets('search cannot reveal unassigned dashboard cards', (
    tester,
  ) async {
    await open(tester, staff: true);
    await tester.enterText(
      find.byKey(const ValueKey('dashboard-search')),
      'Kitchen',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No assigned dashboard cards match your search.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-card-kitchen_orders')),
      findsNothing,
    );
  });
  testWidgets(
    'dashboard search fits a phone and identifies Baghdad reporting time',
    (tester) async {
      await open(tester, mobile: true);
      final search = find.byKey(const ValueKey('dashboard-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Reservations');
      await tester.pumpAndSettle();
      expect(find.textContaining('Baghdad time'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
