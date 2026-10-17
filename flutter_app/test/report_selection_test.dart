import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_operational_report.dart';
import 'package:gelye_sherane_cafe/cafe_report_selection.dart';

const columns = ['Order', 'Source', 'Status', 'Mode', 'Total IQD'];
final rows = <List<dynamic>>[
  ['A', 'table', 'ready', 'normal', 900],
  ['B', 'online', 'received', 'tourism', 10000],
  ['C', 'online', 'ready', 'owner', 0],
  ['D', 'online', 'ready', 'normal', null],
  ['E', 'table', 'ready', 'normal', 900],
];

Widget screen({String card = 'today_orders', bool rtl = false,
  List<String> headers = columns, List<List<dynamic>>? records}) =>
  MaterialApp(home: Scaffold(body: Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: SingleChildScrollView(child: CafeOperationalReport(
      section: 'dashboard', card: card, title: 'Today Orders',
      rpc: (name, params) async => {'columns': headers, 'rows': records ?? rows, 'note': 'Test records'},
    )),
  )));

Future<void> choose(WidgetTester tester, String column, String value) async {
  final finder = find.byWidgetPredicate((w) => w is DropdownButtonFormField<String> &&
      w.key.toString().contains('report-filter-$column-'));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

void main() {
  test('source status mode and search intersect without altering originals', () {
    final selected = selectCafeReportRows(columns: columns, rows: rows, query: ' c ',
      filters: {'Source': 'online', 'Status': 'ready', 'Mode': 'owner'});
    expect(selected, [rows[2]]);
    selected[0][0] = 'changed';
    expect(rows[2][0], 'C');
    expect(cafeReportOptions(columns, rows, 'Source'), ['online', 'table']);
    expect(cafeReportOptions(columns, rows, 'Missing'), isEmpty);
  });

  test('numeric sorting is stable, preserves zero, and keeps unknown last', () {
    final asc = selectCafeReportRows(columns: columns, rows: rows, sortColumn: 4);
    final desc = selectCafeReportRows(columns: columns, rows: rows, sortColumn: 4, ascending: false);
    expect(asc.map((r) => r[0]), ['C', 'A', 'E', 'B', 'D']);
    expect(desc.map((r) => r[0]), ['B', 'A', 'E', 'C', 'D']);
    expect(rows.map((r) => r[0]), ['A', 'B', 'C', 'D', 'E']);
  });

  testWidgets('combined filters and clear restore loaded records on phone RTL', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(screen(rtl: true));
    await tester.pumpAndSettle();
    await choose(tester, 'Source', 'online');
    await choose(tester, 'Status', 'ready');
    await choose(tester, 'Mode', 'owner');
    expect(find.text('1 matching records'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('B'), findsNothing);
    await tester.ensureVisible(find.text('Clear filters'));
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('5 matching records'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter mismatch has distinct message and resets on card switch', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await choose(tester, 'Source', 'table');
    await choose(tester, 'Status', 'received');
    expect(find.textContaining('No records match these filters.'), findsOneWidget);
    await tester.pumpWidget(screen(card: 'kitchen_orders'));
    await tester.pumpAndSettle();
    expect(find.text('5 matching records'), findsOneWidget);
    expect(find.textContaining('No records match these filters.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports without categorical columns keep sorting and no invented filters', (tester) async {
    await tester.pumpWidget(screen(headers: ['Product', 'Quantity served'],
      records: [['Tea', 10], ['Coffee', 2]]));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
    expect(find.text('2 matching records'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
