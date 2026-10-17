import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/staff_dashboard_page.dart';
import 'package:gelye_sherane_cafe/cafe_table_overview.dart';

Future<void> openDashboard(WidgetTester tester, String title, {bool admin = true}) async {
  tester.view.physicalSize = const Size(1440, 1800);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(MaterialApp(home: StaffDashboardPage(
    email: 'review@example.com', role: admin ? 'admin' : 'staff',
    grantedPermissions: admin ? const {} : {
      'dashboard:reservations', 'dashboard:guest_check_in',
    },
  )));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('dashboard-search')), title);
  await tester.pumpAndSettle();
  final entry = find.byKey(ValueKey('dashboard-card-${title.toLowerCase().replaceAll(' ', '_')}'));
  await tester.ensureVisible(entry);
  await tester.tap(entry);
  await tester.pumpAndSettle();
}

Map<String,dynamic> snapshot({bool arrived = false, bool capability = true}) => {
  'server_time': '2026-10-17T12:00:00Z',
  'capabilities': {'arrived': capability},
  'tables': [{
    'id': 't1', 'name': 'Table 1', 'area': 'Garden', 'seats': 4,
    'status': 'reserved', 'pricing_mode': 'normal', 'requests': [],
    'reservation': {'id': 'r1', 'starts_at': '2026-10-17T12:00:00Z',
      'party_size': 3, 'arrived_at': arrived ? '2026-10-17T12:00:00Z' : null},
  }],
};
Widget overview(Future<dynamic> Function(String,Map<String,dynamic>) rpc) =>
  MaterialApp(home: Scaffold(body: SingleChildScrollView(child: Directionality(
    textDirection: TextDirection.rtl,
    child: CafeTableOverview(title: 'Guest Check-In', executiveStyle: true,
      initialStatus: 'Reserved', rpc: rpc, onQr: (_) async {}),
  ))));

void main() {
  testWidgets('Reservations opens existing booking workspace', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openDashboard(tester, 'Reservations');
    expect(find.byKey(const ValueKey('table-reservation-search')), findsOneWidget);
    expect(find.text('Design preview — not live'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Guest Check-In opens executive arrival workflow with reserved scope', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openDashboard(tester, 'Guest Check-In');
    final view = tester.widget<CafeTableOverview>(find.byType(CafeTableOverview));
    expect(view.initialStatus, 'Reserved');
    expect(view.executiveStyle, isTrue);
    expect(view.title, 'Guest Check-In');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Dashboard permission alone cannot enter reservation or arrival workflows', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openDashboard(tester, 'Reservations', admin: false);
    expect(find.text('Table Reservations access has not been assigned.'), findsOneWidget);
    expect(find.byKey(const ValueKey('table-reservation-search')), findsNothing);
    await openDashboard(tester, 'Guest Check-In', admin: false);
    expect(find.text('Guest Check-In & No-Show access has not been assigned.'), findsOneWidget);
    expect(find.byType(CafeTableOverview), findsNothing);
  });

  testWidgets('arrival requires confirmation and sends existing server command once', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var arrived = false;
    final commands = <Map<String,dynamic>>[];
    await tester.pumpWidget(overview((name, params) async {
      if (name == 'perform_cafe_table_action') {
        commands.add(params);
        arrived = true;
        return {'ok': true};
      }
      expect(name, 'get_cafe_table_overview');
      return snapshot(arrived: arrived);
    }));
    await tester.pumpAndSettle();
    final action = find.widgetWithText(OutlinedButton, 'Arrived');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(commands, isEmpty);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(commands, hasLength(1));
    expect(commands.single['p_action'], 'arrived');
    expect(commands.single['p_table_id'], 't1');
    expect(commands.single['p_data'], {'reservation_id': 'r1'});
    expect(commands.single['p_request_id'], isNotEmpty);
    expect(find.text('Table 1'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('server capability disables arrival and no-show actions', (tester) async {
    await tester.pumpWidget(overview((name,params) async => snapshot(capability: false)));
    await tester.pumpAndSettle();
    for (final label in ['Arrived', 'No-show']) {
      final button = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, label));
      expect(button.onPressed, isNull);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
