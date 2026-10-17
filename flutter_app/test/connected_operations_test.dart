import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_operations_workspace.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    CafeRpc rpc, {
    bool payments = false,
    bool create = true,
  }) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CafeOperationsWorkspace(
              source: 'motel',
              canCreate: create,
              payments: payments,
              rpc: rpc,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('order retry keeps request and payload unchanged', (
    tester,
  ) async {
    final requests = <Map<String, dynamic>>[];
    await open(tester, (name, params) async {
      if (name == 'list_cafe_staff_orders') return <Map<String, dynamic>>[];
      if (name == 'get_cafe_priced_order_catalog') {
        return {
          'products': [
            {'id': 'p', 'name': 'Tea', 'price_iqd': 1000},
          ],
          'tables': [],
        };
      }
      requests.add(Map.of(params));
      if (requests.length == 1) throw StateError('response lost');
      return {'id': 'order'};
    });
    await tester.tap(find.text('New order'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Room reference'),
      'Room 8',
    );
    await tester.tap(find.byTooltip('Add Tea'));
    await tester.pumpAndSettle();
    expect(find.text('Total: 1000 IQD'), findsOneWidget);
    await tester.tap(find.text('Place order'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Save could not be confirmed'), findsOneWidget);
    await tester.tap(find.text('Retry same order'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
    expect(requests[0], requests[1]);
    expect(requests[0]['p_destination'], 'Room 8');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'manual card needs a reference and failed payment retries safely',
    (tester) async {
      final requests = <Map<String, dynamic>>[];
      await open(tester, (name, params) async {
        if (name == 'list_cafe_payment_balances') {
          return [
            {
              'id': 'o',
              'table_name': 'Room 2',
              'status': 'received',
              'total_iqd': 5000,
              'paid_iqd': 1000,
              'payments': [],
            },
          ];
        }
        requests.add(Map.of(params));
        throw StateError('response lost');
      }, payments: true);
      await tester.tap(find.text('Record payment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Card — already paid on terminal').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount (IQD)'),
        '5000',
      );
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount (IQD)'),
        '4000',
      );
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextField, 'Terminal reference'),
        'Terminal 8',
      );
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry same record'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(requests[0], requests[1]);
      expect(requests[0]['p_method'], 'manual_card');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('read-only payments hide capture and refund controls', (
    tester,
  ) async {
    await open(
      tester,
      (name, params) async => [
        {
          'id': 'o',
          'table_name': 'Room 2',
          'status': 'received',
          'total_iqd': 5000,
          'paid_iqd': 0,
          'payments': [],
        },
      ],
      payments: true,
      create: false,
    );
    expect(find.text('Record payment'), findsNothing);
    expect(find.text('Refund'), findsNothing);
  });
  testWidgets('failed load never reports an empty successful order list', (
    tester,
  ) async {
    await open(tester, (name, params) async => throw StateError('offline'));
    expect(find.textContaining('Could not load records'), findsOneWidget);
    expect(find.text('No matching orders.'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'New order'))
          .onPressed,
      isNull,
    );
  });
}
