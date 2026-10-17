import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_dashboard_tables.dart';
import 'package:gelye_sherane_cafe/cafe_operations_workspace.dart';
import 'package:gelye_sherane_cafe/staff_dashboard_page.dart';

Map<String, dynamic> table(String id, String status, {String? visit, List<dynamic> requests = const []}) => {
  'id': id, 'name': 'Table $id', 'area': 'Garden', 'status': status,
  'pricing_mode': 'normal', 'visit_id': visit, 'seats': 4,
  'payment_status': 'Paid — Still Seated', 'requests': requests,
};
Widget screen(CafeRpc rpc, {String title = 'Live Tables', bool rtl = false}) =>
  MaterialApp(home: Scaffold(body: Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: SingleChildScrollView(child: CafeDashboardTables(title: title, rpc: rpc)),
  )));

void main() {
  test('six scopes preserve occupied paid visits and exclude unknown availability', () {
    final paid = table('P', 'available', visit: 'active');
    final clean = table('C', 'cleaning');
    final available = table('A', 'available');
    final unknown = table('U', 'maintenance');
    final service = table('S', 'occupied', requests: [
      {'status': 'open'}, {'status': 'completed'},
    ]);
    expect(dashboardTableMatches('Tables Occupied', paid), isTrue);
    expect(dashboardTableMatches('Available Tables', paid), isFalse);
    expect(dashboardTableMatches('Available Tables', unknown), isFalse);
    expect(dashboardTableMatches('Available Tables', available), isTrue);
    expect(dashboardTableMatches('Table Cleaning', clean), isTrue);
    expect(dashboardTableMatches('Cleaning Needed', clean), isTrue);
    expect(dashboardTableMatches('Live Tables', unknown), isTrue);
    expect(dashboardTableMatches('Table Service Requests', service), isTrue);
    expect(dashboardOpenRequests(service), hasLength(1));
  });

  testWidgets('read-only phone RTL details preserve unknown guest count and search reset', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <String>[];
    await tester.pumpWidget(screen((name, params) async {
      calls.add(name);
      return {'tables': [table('P', 'occupied', visit: 'active')]};
    }, rtl: true));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Table P'));
    await tester.tap(find.text('Table P'));
    await tester.pumpAndSettle();
    expect(find.text('Guests: Unknown'), findsOneWidget);
    expect(find.text('Payment status: Paid — Still Seated'), findsOneWidget);
    expect(find.textContaining('Visit started: —'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('Table P'), findsNothing);
    await tester.ensureVisible(find.text('Clear filters'));
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Table P'), findsOneWidget);
    expect(calls, ['get_cafe_table_overview']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed refresh removes stale records and retry recovers', (tester) async {
    var count = 0;
    await tester.pumpWidget(screen((name, params) async {
      if (++count == 2) throw StateError('denied');
      return {'tables': [table('A', 'available')]};
    }));
    await tester.pumpAndSettle();
    expect(find.text('Table A'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Table A'), findsNothing);
    expect(find.textContaining('Could not load tables.'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Table A'), findsOneWidget);
  });

  testWidgets('late old-card read cannot overwrite current table snapshot', (tester) async {
    final old = Completer<dynamic>(), current = Completer<dynamic>();
    var calls = 0;
    Future<dynamic> rpc(String name, Map<String,dynamic> params) => ++calls == 1 ? old.future : current.future;
    await tester.pumpWidget(screen(rpc));
    await tester.pumpWidget(screen(rpc, title: 'Cleaning Needed'));
    current.complete({'tables': [table('NEW', 'cleaning')]});
    await tester.pumpAndSettle();
    old.complete({'tables': [table('OLD', 'cleaning')]});
    await tester.pumpAndSettle();
    expect(find.text('Table NEW'), findsOneWidget);
    expect(find.text('Table OLD'), findsNothing);
  });

  testWidgets('malformed data fails closed without claiming available tables', (tester) async {
    await tester.pumpWidget(screen((name, params) async => {
      'tables': [{'id': 'bad', 'status': 'available'}],
    }));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load tables.'), findsOneWidget);
    expect(find.textContaining('matching tables'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all six actual Dashboard entry cards open the connected workspace', (tester) async {
    tester.view.physicalSize = const Size(1440, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final title in dashboardTableCards) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const MaterialApp(home: StaffDashboardPage(
        email: 'review@example.com', role: 'admin', grantedPermissions: {},
      )));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('dashboard-search')), title);
      await tester.pumpAndSettle();
      final slug = title.toLowerCase().replaceAll(' ', '_');
      final entry = find.byKey(ValueKey('dashboard-card-$slug'));
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(CafeDashboardTables), findsOneWidget, reason: title);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('unassigned table card stays hidden in Dashboard search', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StaffDashboardPage(
      email: 'review@example.com', role: 'staff',
      grantedPermissions: {'dashboard:today_revenue'},
    )));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('dashboard-search')), 'Live Tables');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dashboard-card-live_tables')), findsNothing);
    expect(find.byType(CafeDashboardTables), findsNothing);
  });
}
