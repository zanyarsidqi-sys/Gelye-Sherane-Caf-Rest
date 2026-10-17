import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_system_health.dart';
import 'package:gelye_sherane_cafe/cafe_operations_workspace.dart';
import 'package:gelye_sherane_cafe/staff_dashboard_page.dart';

Widget host({bool tables = true, bool inventory = false, String account = 'a', CafeRpc? rpc}) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: CafeSystemHealth(
    account: account, tables: tables, inventory: inventory, rpc: rpc,
  ))),
);
Map<String, dynamic> response() => {'server_time': '2026-10-17T10:00:00Z', 'tables': [], 'items': []};
Future<void> check(WidgetTester tester) async {
  await tester.tap(find.text('Check services'));
  await tester.pumpAndSettle();
}
void main() {
  testWidgets('manual authorized checks only, no business content rendered', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(host(rpc: (name, params) async {
      calls.add(name);
      expect(params, isEmpty);
      return {...response(), 'customer_name': 'Private Guest'};
    }));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    await check(tester);
    expect(calls, ['get_cafe_table_overview']);
    expect(find.textContaining('Read succeeded'), findsOneWidget);
    expect(find.text('Private Guest'), findsNothing);
    expect(find.textContaining('access has not been assigned'), findsOneWidget);
  });
  testWidgets('independent failures and fresh retry remove stale successes', (tester) async {
    var fail = false;
    await tester.pumpWidget(host(inventory: true, rpc: (name, params) async {
      if (name.contains('inventory')) {
        expect(params, {'p_card': 'low_stock_alerts', 'p_query': ''});
        throw Exception('private server details');
      }
      if (fail) throw Exception('private server details');
      return response();
    }));
    await check(tester);
    expect(find.textContaining('Read succeeded'), findsOneWidget);
    expect(find.textContaining('Read failed'), findsOneWidget);
    fail = true;
    await check(tester);
    expect(find.textContaining('Read succeeded'), findsNothing);
    expect(find.textContaining('Read failed'), findsNWidgets(2));
    expect(find.textContaining('private server details'), findsNothing);
  });
  testWidgets('malformed responses and missing configuration are not healthy', (tester) async {
    await tester.pumpWidget(host(rpc: (_, _) async => {'tables': []}));
    await check(tester);
    expect(find.textContaining('Unexpected response'), findsOneWidget);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await check(tester);
    expect(find.textContaining('connection is not configured'), findsOneWidget);
  });
  testWidgets('timeout is bounded and late completion cannot report success', (tester) async {
    final pending = Completer<dynamic>();
    await tester.pumpWidget(host(rpc: (_, _) => pending.future));
    await tester.tap(find.text('Check services'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(find.textContaining('Timed out after 10 seconds'), findsOneWidget);
    pending.complete(response());
    await tester.pumpAndSettle();
    expect(find.textContaining('Read succeeded'), findsNothing);
  });
  testWidgets('account or permission changes invalidate pending results', (tester) async {
    final pending = Completer<dynamic>();
    Future<dynamic> rpc(String name, Map<String, dynamic> params) => pending.future;
    await tester.pumpWidget(host(rpc: rpc));
    await tester.tap(find.text('Check services'));
    await tester.pump();
    await tester.pumpWidget(host(account: 'b', tables: false, rpc: rpc));
    pending.complete(response());
    await tester.pumpAndSettle();
    expect(find.textContaining('Read succeeded'), findsNothing);
    expect(find.textContaining('access has not been assigned'), findsNWidgets(2));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });
  testWidgets('mobile RTL fits and unknown backup status remains explicit', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: Directionality(textDirection: TextDirection.rtl, child:
        CafeSystemHealth(account: 'a', tables: true, inventory: true, rpc: (_, _) async => response())),
    ))));
    await check(tester);
    expect(find.textContaining('Backup and sync status are unverified'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('dashboard route preserves underlying service permissions', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: StaffDashboardPage(
      email: 'staff@example.com', role: 'staff',
      grantedPermissions: {'dashboard:system_health'},
    )));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('dashboard-search')), 'System Health');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dashboard-category-tab-7')));
    await tester.pumpAndSettle();
    final entry = find.byKey(const ValueKey('dashboard-card-system_health'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    final screen = tester.widget<CafeSystemHealth>(find.byType(CafeSystemHealth));
    expect(screen.tables, false);
    expect(screen.inventory, false);
    expect(tester.takeException(), isNull);
  });
}
