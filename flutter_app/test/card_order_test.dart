import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_card_order.dart';
import 'package:gelye_sherane_cafe/favorites_page.dart';

class MemoryOrders implements FavoritesStorage {
  final data = <String, List<String>>{};
  bool fail = false;
  Completer<List<String>>? delayed;
  @override
  Future<List<String>> read(String account) async {
    if (fail) throw Exception('storage');
    if (delayed != null) return delayed!.future;
    return List.of(data[account] ?? []);
  }

  @override
  Future<void> write(String account, List<String> ids) async {
    data[account] = List.of(ids);
  }
}

Widget host(
  MemoryOrders store, {
  String account = 'a',
  String scope = 'one',
  List<String> cards = const ['One', 'Two', 'Three'],
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: CafeCardOrder(
        account: account,
        scope: scope,
        titles: cards,
        storage: store,
        builder: (ordered) =>
            Text(ordered.join(','), key: const ValueKey('actual-order')),
      ),
    ),
  ),
);

void main() {
  test('merge retains hidden slots and appends newly permitted cards', () {
    expect(
      mergeCafeCardOrder(['a', 'hidden', 'b'], ['a', 'b', 'new'], [
        'b',
        'new',
        'a',
      ]),
      ['b', 'hidden', 'new', 'a'],
    );
    expect(orderedCafeCards(['hidden', 'b', 'b', 'a'], ['a', 'b', 'new']), [
      'b',
      'a',
      'new',
    ]);
  });
  testWidgets(
    'arrows reorder real cards, survive reopen, and isolate category and account',
    (tester) async {
      final store = MemoryOrders();
      await tester.pumpWidget(host(store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arrange cards'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('card-later-One')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done arranging'));
      await tester.pumpAndSettle();
      expect(find.text('Two,One,Three'), findsOneWidget);
      await tester.pumpWidget(host(store, scope: 'two'));
      await tester.pumpAndSettle();
      expect(find.text('One,Two,Three'), findsOneWidget);
      await tester.pumpWidget(host(store, account: 'other'));
      await tester.pumpAndSettle();
      expect(find.text('One,Two,Three'), findsOneWidget);
      await tester.pumpWidget(host(store));
      await tester.pumpAndSettle();
      expect(find.text('Two,One,Three'), findsOneWidget);
    },
  );
  testWidgets(
    'drag reorder callback changes order while hidden cards remain stored',
    (tester) async {
      final store = MemoryOrders()
        ..data['a:card-order:v1:one'] = ['One', 'Hidden', 'Two', 'Three'];
      await tester.pumpWidget(host(store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arrange cards'));
      await tester.pumpAndSettle();
      final list = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      list.onReorder(0, 3);
      await tester.pumpAndSettle();
      expect(store.data['a:card-order:v1:one'], [
        'Two',
        'Hidden',
        'Three',
        'One',
      ]);
      expect(find.text('Hidden'), findsNothing);
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(3));
    },
  );
  testWidgets('failed read disables writes and keeps usable default cards', (
    tester,
  ) async {
    final store = MemoryOrders()..fail = true;
    await tester.pumpWidget(host(store));
    await tester.pumpAndSettle();
    expect(find.text('One,Two,Three'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Arrange cards'),
          )
          .onPressed,
      isNull,
    );
    store.fail = false;
    await tester.tap(find.text('Retry card order'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Arrange cards'),
          )
          .onPressed,
      isNotNull,
    );
  });
  testWidgets('late prior account reads cannot reorder the new account', (
    tester,
  ) async {
    final store = MemoryOrders()..delayed = Completer<List<String>>();
    final delayed = store.delayed!;
    await tester.pumpWidget(host(store));
    await tester.pump();
    store.delayed = null;
    await tester.pumpWidget(host(store, account: 'other'));
    await tester.pumpAndSettle();
    delayed.complete(['Three', 'Two', 'One']);
    await tester.pumpAndSettle();
    expect(find.text('One,Two,Three'), findsOneWidget);
  });
  testWidgets('reset requires confirmation and affects only this category', (
    tester,
  ) async {
    final store = MemoryOrders()
      ..data['a:card-order:v1:one'] = ['Three', 'Two', 'One']
      ..data['a:card-order:v1:two'] = ['Two', 'One'];
    await tester.pumpWidget(host(store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arrange cards'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset order'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reset order'));
    await tester.pumpAndSettle();
    expect(store.data['a:card-order:v1:one'], isEmpty);
    expect(store.data['a:card-order:v1:two'], ['Two', 'One']);
  });
}
