import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_staff_performance.dart';
import 'package:gelye_sherane_cafe/cafe_operations_workspace.dart';
import 'package:gelye_sherane_cafe/staff_dashboard_page.dart';

Map<String, dynamic> session(String id, String staff, String name, int seconds, {bool open = false}) => {
  'id': id, 'staff_id': staff, 'employee_name': name, 'version': 1,
  'clocked_in_at': '2026-10-17T00:00:00Z',
  'clocked_out_at': open ? null : '2026-10-17T02:00:00Z', 'period_seconds': seconds,
};
Map<String, dynamic> data() => {
  'rows': [session('a', 's1', 'Same Name', 3600), session('b', 's1', 'Same Name', 1800, open: true), session('c', 's2', 'Same Name', 60)],
  'events': <dynamic>[], 'total_count': 3, 'truncated': false, 'active': null,
  'server_time': '2026-10-17T10:00:00Z', 'can_admin': true,
};
Widget host(CafeRpc rpc, {String account = 'a'}) => MaterialApp(home: Scaffold(body: SingleChildScrollView(
  child: CafeStaffPerformance(account: account, rpc: rpc),
)));
void main() {
  test('group by identity, sum server-clipped time and keep open sessions separate', () {
    final result = cafeAttendanceSummary(data());
    expect(result.length, 2);
    expect(result.first['seconds'], 5400);
    expect(result.first['open'], 1);
    expect(result.first['closed'], 1);
    expect(result.last['seconds'], 60);
    expect(cafeRecordedDuration(5401), '1h 30m 1s');
  });
  test('reject duplicates, invalid coverage and negative or excessive duration', () {
    final duplicate = data();
    duplicate['rows'][1]['id'] = 'a';
    expect(() => cafeAttendanceSummary(duplicate), throwsFormatException);
    final coverage = data()..['total_count'] = 2;
    expect(() => cafeAttendanceSummary(coverage), throwsFormatException);
    for (final seconds in [-1, 31 * 86400 + 1]) {
      final invalid = data(); invalid['rows'][0]['period_seconds'] = seconds;
      expect(() => cafeAttendanceSummary(invalid), throwsFormatException);
    }
  });
  testWidgets('date presets use attendance read scope and summary searches staff identity', (tester) async {
    final calls = <Map<String, dynamic>>[];
    await tester.pumpWidget(host((name, params) async {
      expect(name, 'get_cafe_people_workspace'); expect(params['p_kind'], 'attendance');
      calls.add(params); return data();
    }));
    await tester.pumpAndSettle();
    expect(calls.first['p_from'], calls.first['p_to']);
    await tester.tap(find.text('Last 7 days')); await tester.pumpAndSettle();
    expect(DateTime.parse(calls.last['p_to']).difference(DateTime.parse(calls.last['p_from'])).inDays, 6);
    await tester.enterText(find.byType(TextField), 's2'); await tester.pumpAndSettle();
    expect(find.textContaining('Recorded: 0h 1m 0s'), findsOneWidget);
    expect(find.textContaining('Recorded: 1h 30m 0s'), findsNothing);
  });
  testWidgets('truncated data is visibly incomplete; errors remove stale measures', (tester) async {
    var fail = false;
    await tester.pumpWidget(host((_, _) async {
      if (fail) throw StateError('denied');
      return data()..['total_count'] = 501..['truncated'] = true;
    }));
    await tester.pumpAndSettle();
    expect(find.textContaining('Incomplete period'), findsOneWidget);
    fail = true; await tester.tap(find.text('Refresh')); await tester.pumpAndSettle();
    expect(find.textContaining('Recorded:'), findsNothing);
    expect(find.textContaining('Could not load attendance measures'), findsOneWidget);
  });
  testWidgets('account change ignores an older response', (tester) async {
    final pending = Completer<dynamic>(); var calls = 0;
    Future<dynamic> rpc(String name, Map<String, dynamic> params) async => ++calls == 1 ? pending.future :
      (data()..['rows'] = <dynamic>[]..['total_count'] = 0);
    await tester.pumpWidget(host(rpc));
    await tester.pumpWidget(host(rpc, account: 'b')); await tester.pumpAndSettle();
    pending.complete(data()); await tester.pumpAndSettle();
    expect(find.text('No matching recorded attendance.'), findsOneWidget);
    expect(find.text('Same Name'), findsNothing);
  });
  testWidgets('mobile RTL session detail fits without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: Directionality(
      textDirection: TextDirection.rtl, child: CafeStaffPerformance(account: 'a', rpc: (_, _) async => data()),
    )))));
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('attendance-summary-s1'));
    await tester.ensureVisible(tile); await tester.tap(tile); await tester.pumpAndSettle();
    expect(find.text('Still open at snapshot'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('performance card alone never grants attendance access', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    for (final allowed in [false, true]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: StaffDashboardPage(email: 'staff@example.com', role: 'staff',
        grantedPermissions: {'dashboard:staff_performance', if (allowed) 'dashboard:attendance'},
      )));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('dashboard-search')), 'Staff Performance');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dashboard-category-tab-5'))); await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('dashboard-card-staff_performance'));
      await tester.ensureVisible(card); await tester.tap(card); await tester.pumpAndSettle();
      expect(find.byType(CafeStaffPerformance), allowed ? findsOneWidget : findsNothing);
      if (!allowed) expect(find.text('Attendance access has not been assigned.'), findsOneWidget);
    }
  });
}
