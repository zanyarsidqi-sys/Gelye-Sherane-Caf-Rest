import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_menu_workspace.dart';
import 'package:gelye_sherane_cafe/cafe_orders_workspace.dart';

class MenuStore implements CafeMenuStore {
  @override
  Future<List<Map<String,dynamic>>> stations() async => [{'id':'kitchen','name':'Kitchen','active':true},{'id':'minibar','name':'Minibar','active':true}];
  final rows = <CafeMenuItem>[];
  bool fail = false;
  @override
  Future<List<CafeMenuItem>> load() async {
    if (fail) throw StateError('offline');
    return rows;
  }

  @override
  Future<void> save({
    String? id,
    required String name,
    required String category,
    required String description,
    required int priceIqd,
    required int tourismPriceIqd,
    required int ownerPriceIqd,
    required List<String> stationIds,
    required bool available,
  }) async {
    rows.add(
      CafeMenuItem(
        id: 'item',
        name: name,
        category: category,
        description: description,
        priceIqd: priceIqd,
        tourismPriceIqd: tourismPriceIqd,
        ownerPriceIqd: ownerPriceIqd,
        stationIds: stationIds,
        available: available,
      ),
    );
  }
}

class OrderStore implements CafeOrderStore {
  String status = 'received';
  bool fail = false;
  @override
  Future<List<Map<String, dynamic>>> load() async => [
    {
      'id': 'order',
      'table_name': 'Table 1',
      'area': 'Main',
      'status': status,
      'total_iqd': 5000,
      'notes': '',
      'items': [
        {'name': 'Tea', 'quantity': 2, 'unit_price_iqd': 2500},
      ],
    },
  ];
  @override
  Future<void> transition(String id, String next) async {
    if (fail) throw StateError('offline');
    status = next;
  }
}

void main() {
  Future<void> show(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'product validation prevents invalid prices and saves a valid product',
    (tester) async {
      final store = MenuStore();
      await show(
        tester,
        CafeMenuWorkspace(store: store, canCreate: true, canEdit: true),
      );
      await tester.tap(find.text('Add product'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Product name'),
        'Tea',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Category'),
        'Drinks',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Normal price IQD'),
        '-1',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Tourism price IQD'), '3500');
      await tester.enterText(find.widgetWithText(TextFormField, 'Owner price IQD'), '1500');
      await tester.tap(find.text('Save product'));
      await tester.pumpAndSettle();
      expect(store.rows, isEmpty);
      await tester.ensureVisible(find.text('Kitchen'));
      await tester.tap(find.text('Kitchen'));
      await tester.ensureVisible(find.text('Minibar'));
      await tester.tap(find.text('Minibar'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Normal price IQD'),
        '2500',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Tourism price IQD'), '3500');
      await tester.enterText(find.widgetWithText(TextFormField, 'Owner price IQD'), '1500');
      await tester.tap(find.text('Save product'));
      await tester.pumpAndSettle();
      expect(store.rows.single.priceIqd, 2500);
      expect(store.rows.single.tourismPriceIqd, 3500);
      expect(store.rows.single.ownerPriceIqd, 1500);
      expect(store.rows.single.stationIds, containsAll(['kitchen','minibar']));
      expect(find.text('Tea'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('catalog load errors do not appear as empty products', (
    tester,
  ) async {
    await show(
      tester,
      CafeMenuWorkspace(
        store: MenuStore()..fail = true,
        canCreate: true,
        canEdit: true,
      ),
    );
    expect(find.textContaining('Could not load products'), findsOneWidget);
    expect(find.text('0 products'), findsNothing);
  });
  testWidgets('read-only product view has no mutation actions', (tester) async {
    await show(
      tester,
      CafeMenuWorkspace(store: MenuStore(), canCreate: false, canEdit: false),
    );
    expect(find.text('Add product'), findsNothing);
  });
  testWidgets('order board advances preparation and asks before cancelling', (
    tester,
  ) async {
    final store = OrderStore();
    await show(tester, CafeOrdersWorkspace(store: store));
    await tester.tap(find.text('Start preparation'));
    await tester.pumpAndSettle();
    expect(store.status, 'preparing');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep order'));
    await tester.pumpAndSettle();
    expect(store.status, 'preparing');
    await tester.tap(find.text('Mark ready'));
    await tester.pumpAndSettle();
    expect(store.status, 'ready');
    expect(find.text('Cancel'), findsNothing);
  });
  testWidgets(
    'failed transition requires refresh instead of displaying success',
    (tester) async {
      final store = OrderStore()..fail = true;
      await show(tester, CafeOrdersWorkspace(store: store));
      await tester.tap(find.text('Start preparation'));
      await tester.pumpAndSettle();
      expect(store.status, 'received');
      expect(
        find.textContaining('Update could not be confirmed'),
        findsOneWidget,
      );
      expect(find.text('Start preparation'), findsNothing);
    },
  );
}
