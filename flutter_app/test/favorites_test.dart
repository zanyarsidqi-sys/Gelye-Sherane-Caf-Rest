import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/favorites_page.dart';

class MemoryFavorites implements FavoritesStorage {
  final data = <String, List<String>>{};
  bool failRead = false, failWrite = false;
  @override
  Future<List<String>> read(String account) async {
    if (failRead) throw StateError('read');
    return List.of(data[account] ?? []);
  }

  @override
  Future<void> write(String account, List<String> ids) async {
    if (failWrite) throw StateError('write');
    data[account] = List.of(ids);
  }
}

void main() {
  const cards = [
    FavoriteCardEntry(
      id: 'dashboard:Orders',
      section: 'Dashboard',
      title: 'Orders',
    ),
    FavoriteCardEntry(
      id: 'kitchen:Orders',
      section: 'Kitchen',
      title: 'Orders',
    ),
  ];
  Future<void> open(
    WidgetTester tester,
    MemoryFavorites storage, {
    String account = 'a',
    ValueChanged<FavoriteCardEntry>? onOpen,
  }) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FavoritesPage(
              key: ValueKey(account),
              account: account,
              cards: cards,
              storage: storage,
              onOpen: onOpen ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('favorites add across sections persist open and remove', (
    tester,
  ) async {
    final storage = MemoryFavorites();
    String? opened;
    await open(tester, storage, onOpen: (card) => opened = card.id);
    await tester.tap(find.byKey(const ValueKey('favorites-picker')));
    await tester.pumpAndSettle();
    for (final card in cards) {
      await tester.tap(find.byKey(ValueKey('favorite-${card.id}')));
      await tester.pumpAndSettle();
    }
    expect(storage.data['a'], containsAll(cards.map((e) => e.id)));
    await tester.tap(find.byKey(const ValueKey('favorites-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kitchen'));
    expect(opened, 'kitchen:Orders');
    await tester.pumpWidget(const SizedBox());
    await open(tester, storage);
    expect(find.text('Orders'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('favorite-dashboard:Orders')));
    await tester.pumpAndSettle();
    expect(storage.data['a'], ['kitchen:Orders']);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'accounts are separate and inaccessible saved cards stay hidden',
    (tester) async {
      final storage = MemoryFavorites()
        ..data['a'] = ['dashboard:Orders', 'secret:Cash'];
      await open(tester, storage);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Cash'), findsNothing);
      await open(tester, storage, account: 'b');
      expect(find.text('Orders'), findsNothing);
      expect(storage.data['a'], contains('secret:Cash'));
    },
  );
  testWidgets('cards open immediately while the add picker is still open', (tester) async {
    final storage = MemoryFavorites();
    String? opened;
    await open(tester, storage, onOpen: (card) => opened = card.id);
    await tester.tap(find.byKey(const ValueKey('favorites-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favorite-kitchen:Orders')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kitchen'));
    expect(opened, 'kitchen:Orders');
    expect(storage.data['a'], ['kitchen:Orders']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('storage failures do not report a successful change', (
    tester,
  ) async {
    final storage = MemoryFavorites()..failRead = true;
    await open(tester, storage);
    expect(find.textContaining('Could not load favorites'), findsOneWidget);
    storage.failRead = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favorites-picker')));
    await tester.pumpAndSettle();
    storage.failWrite = true;
    await tester.tap(find.byKey(const ValueKey('favorite-dashboard:Orders')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not confirm'), findsOneWidget);
    expect(storage.data, isEmpty);
  });
}
