import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_operational_report.dart';
import 'package:gelye_sherane_cafe/cafe_operations_workspace.dart';
import 'package:gelye_sherane_cafe/cafe_receipt_summary.dart';
import 'package:gelye_sherane_cafe/staff_dashboard_page.dart';

const columns = ['Transaction', 'Time (Baghdad)', 'Order', 'Kind', 'Method', 'Amount IQD', 'Reference'];
List<List<dynamic>> ledger() => [
  ['p1', '2026-10-17 12:00', 'o1', 'payment', 'cash', 10000, 'REF-A'],
  ['p2', '2026-10-17 12:01', 'o1', 'payment', 'manual_card', 5000, 'REF-B'],
  ['r1', '2026-10-17 12:02', 'o1', 'refund', 'cash', 2000, 'REF-C'],
];
Map<String, dynamic> data() => {'columns': columns, 'rows': ledger(), 'note': 'Original receipts are unchanged.'};
Widget host(CafeRpc rpc, {String account = 'a', String section = 'dashboard', String card = 'invoices'}) => MaterialApp(home: Scaffold(
  body: SingleChildScrollView(child: CafeOperationalReport(section: section, card: card, title: 'Invoices', account: account, rpc: rpc)),
));
void main() {
  test('receipt sums keep refunds separate and support exact string amounts', () {
    expect(cafeReceiptTotals(columns, ledger()), {'payments': BigInt.from(15000), 'refunds': BigInt.from(2000), 'net': BigInt.from(13000)});
    final rows = ledger()..[0][5] = '90071992547409910000';
    expect(cafeReceiptTotals(columns, rows)['net'], BigInt.parse('90071992547409913000'));
    expect(cafeReceiptTotals(columns, [])['net'], BigInt.zero);
    expect(cafeReceiptTotals(columns, [ledger().last])['net'], BigInt.from(-2000));
  });
  test('malformed, unknown, duplicate and unsafe receipts are rejected', () {
    for (final amount in [-1, 1.5, 'bad', null, 9007199254740992]) {
      final rows = ledger()..[0][5] = amount;
      expect(() => cafeReceiptTotals(columns, rows), throwsFormatException);
    }
    final unknown = ledger()..[0][3] = 'credit';
    expect(() => cafeReceiptTotals(columns, unknown), throwsFormatException);
    expect(() => cafeReceiptTotals(columns, [...ledger(), ledger().first]), throwsFormatException);
    expect(() => cafeReceiptTotals(['Amount IQD'], []), throwsFormatException);
  });
  testWidgets('receipt scope, method filters and search update selected totals', (tester) async {
    await tester.pumpWidget(host((name, params) async {
      expect(name, 'get_cafe_operational_report');
      expect(params['p_section'], 'dashboard');
      expect(params['p_card'], 'invoices');
      return data();
    }));
    await tester.pumpAndSettle();
    expect(find.textContaining('not tax invoices'), findsOneWidget);
    expect(find.textContaining('Net received: 13000 IQD'), findsOneWidget);
    final method = find.byKey(const ValueKey('report-filter-Method-null'));
    await tester.ensureVisible(method);
    await tester.tap(method);
    await tester.pumpAndSettle();
    await tester.tap(find.text('manual_card').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Net received: 5000 IQD'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.textContaining('Net received: 0 IQD'), findsOneWidget);
  });
  testWidgets('malformed receipt clears data and blocks export', (tester) async {
    await tester.pumpWidget(host((_, _) async => {'columns': columns, 'rows': [...ledger(), ledger().first]}));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load the report'), findsOneWidget);
    expect(find.byKey(const ValueKey('receipt-summary')), findsNothing);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Print / save PDF')).onPressed, isNull);
  });
  testWidgets('account change discards old receipt request', (tester) async {
    final pending = Completer<dynamic>();
    var calls = 0;
    Future<dynamic> rpc(String name, Map<String, dynamic> params) async => ++calls == 1 ? pending.future : {'columns': columns, 'rows': <List<dynamic>>[]};
    await tester.pumpWidget(host(rpc));
    await tester.pumpWidget(host(rpc, account: 'b'));
    await tester.pumpAndSettle();
    pending.complete(data());
    await tester.pumpAndSettle();
    expect(find.textContaining('Net received: 0 IQD'), findsOneWidget);
    expect(find.text('REF-A'), findsNothing);
  });
  testWidgets('all four invoice aliases preserve their own permission scope', (tester) async {
    for (final pair in [
      ['dashboard', 'invoices'], ['payment_management', 'invoices'],
      ['payment_management', 'invoices_receipts'], ['payment_management', 'invoices_payments'],
    ]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(host((_, params) async {
        expect(params['p_section'], pair[0]);
        expect(params['p_card'], pair[1]);
        return data();
      }, section: pair[0], card: pair[1]));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('receipt-summary')), findsOneWidget);
    }
    expect(operationalReportCards['payment_management'], containsAll(['Invoices', 'Invoices & Receipts', 'Invoices & Payments']));
  });
  testWidgets('dashboard invoice route opens report with assigned permission', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: StaffDashboardPage(email: 'staff@example.com', role: 'staff', grantedPermissions: {'dashboard:invoices'})));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('dashboard-search')), 'Invoices');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dashboard-category-tab-1')));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('dashboard-card-invoices'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    final report = tester.widget<CafeOperationalReport>(find.byType(CafeOperationalReport));
    expect(report.section, 'dashboard');
    expect(report.card, 'invoices');
    expect(report.account, 'staff@example.com');
  });
}
