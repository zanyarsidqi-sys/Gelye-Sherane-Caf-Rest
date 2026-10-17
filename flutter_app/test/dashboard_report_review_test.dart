import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_operational_report.dart';
import 'package:gelye_sherane_cafe/cafe_operations_workspace.dart';
import 'package:gelye_sherane_cafe/workspace_reporting.dart';

Map<String, dynamic> report(String value) => {
  'columns': ['Reference', 'Amount IQD'], 'rows': [[value, 3500]],
  'note': 'Recorded receipts',
};

Widget screen(CafeRpc rpc, {String card = 'today_revenue', WorkspaceReportRange? range, bool rtl = false}) =>
  MaterialApp(home: Scaffold(body: Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: SingleChildScrollView(child: CafeOperationalReport(
      section: 'dashboard', card: card, title: 'Today Revenue',
      initialRange: range, rpc: rpc,
    )),
  )));

void main() {
  testWidgets('Dashboard exclusive UTC period becomes inclusive Baghdad dates', (tester) async {
    final requests = <Map<String, dynamic>>[];
    await tester.pumpWidget(screen((name, params) async {
      expect(name, 'get_cafe_operational_report');
      requests.add(params);
      return report('FEB');
    }, range: WorkspaceReportRange.forSelection(DateTime(2024, 2, 15), 'This Month')));
    await tester.pumpAndSettle();
    expect(requests.single['p_section'], 'dashboard');
    expect(requests.single['p_card'], 'today_revenue');
    expect(requests.single['p_from'], '2024-02-01');
    expect(requests.single['p_to'], '2024-02-29');
    expect(tester.takeException(), isNull);
  });

  testWidgets('late previous-card response cannot overwrite current card', (tester) async {
    final old = Completer<dynamic>();
    final current = Completer<dynamic>();
    Future<dynamic> rpc(String name, Map<String, dynamic> params) =>
      params['p_card'] == 'today_revenue' ? old.future : current.future;
    await tester.pumpWidget(screen(rpc));
    await tester.pumpWidget(screen(rpc, card: 'pending_payment'));
    current.complete(report('CURRENT'));
    await tester.pumpAndSettle();
    old.complete(report('OLD'));
    await tester.pumpAndSettle();
    expect(find.text('CURRENT'), findsOneWidget);
    expect(find.text('OLD'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed refresh hides stale rows and disables printing', (tester) async {
    var calls = 0;
    await tester.pumpWidget(screen((name, params) async {
      if (++calls > 1) throw StateError('denied');
      return report('STALE');
    }));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('STALE'), findsNothing);
    expect(find.textContaining('Could not load the report.'), findsOneWidget);
    final printButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Print / save PDF'));
    expect(printButton.onPressed, isNull);
  });

  testWidgets('phone RTL uses readable labeled records and keeps search working', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(screen((name, params) async => report('INV-42'), rtl: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-mobile-records')), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
    expect(find.text('INV-42'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();
    expect(find.text('INV-42'), findsNothing);
    expect(find.text('0 matching records'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('malformed server rows show retryable error instead of crashing', (tester) async {
    await tester.pumpWidget(screen((name, params) async => {
      'columns': ['One'], 'rows': [['extra', 'cell']], 'note': 'Bad response',
    }));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load the report.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
