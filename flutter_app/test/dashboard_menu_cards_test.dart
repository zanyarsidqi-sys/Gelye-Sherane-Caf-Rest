import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_dashboard_menu.dart';
import 'package:gelye_sherane_cafe/cafe_menu_workspace.dart';
import 'package:gelye_sherane_cafe/staff_dashboard_page.dart';
import 'catalog_orders_test.dart' show MenuStore;

const tea = CafeMenuItem(id: 'tea', name: 'Tea', category: 'Drinks',
  description: 'Fresh tea', priceIqd: 1000, tourismPriceIqd: 1500,
  ownerPriceIqd: 0, available: true, stationNames: ['Minibar']);
const soup = CafeMenuItem(id: 'soup', name: 'Soup', category: 'Food',
  description: '', priceIqd: 5000, available: false, stationNames: ['Kitchen']);

class DeferredMenu extends MenuStore {
  DeferredMenu(this.result);
  final Future<List<CafeMenuItem>> result;
  @override
  Future<List<CafeMenuItem>> load() => result;
}
Widget screen(CafeMenuStore store, {String title = 'Menu', bool rtl = false}) =>
  MaterialApp(home: Scaffold(body: Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: SingleChildScrollView(child: CafeDashboardMenu(title: title, store: store)),
  )));

void main() {
  testWidgets('phone RTL preserves free owner price and missing price labels without edit actions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(screen(MenuStore()..rows.addAll([tea,soup]), rtl: true));
    await tester.pumpAndSettle();
    expect(find.text('Owner: 0 IQD'), findsOneWidget);
    expect(find.text('Owner: Not recorded'), findsOneWidget);
    expect(find.text('Tourism: Not recorded'), findsOneWidget);
    expect(find.text('Add product'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category availability and station search intersect and clear restores all', (tester) async {
    await tester.pumpWidget(screen(MenuStore()..rows.addAll([tea,soup])));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-category-')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-availability-All')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Available').last);
    await tester.pumpAndSettle();
    expect(find.text('0 matching products · 2 loaded'), findsOneWidget);
    expect(find.text('Available: 1 · Unavailable: 1 · all loaded products'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'minibar');
    await tester.pumpAndSettle();
    expect(find.text('Tea'), findsOneWidget);
    expect(find.text('Soup'), findsNothing);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('2 matching products · 2 loaded'), findsOneWidget);
  });

  testWidgets('failed refresh removes stale products and retry recovers', (tester) async {
    final store = MenuStore()..rows.add(tea);
    await tester.pumpWidget(screen(store));
    await tester.pumpAndSettle();
    store.fail = true;
    await tester.tap(find.text('Refresh products'));
    await tester.pumpAndSettle();
    expect(find.text('Tea'), findsNothing);
    expect(find.textContaining('Could not load products.'), findsOneWidget);
    store.fail = false;
    await tester.tap(find.text('Refresh products'));
    await tester.pumpAndSettle();
    expect(find.text('Tea'), findsOneWidget);
  });

  testWidgets('late previous store response cannot overwrite new card data', (tester) async {
    final old = Completer<List<CafeMenuItem>>(), current = Completer<List<CafeMenuItem>>();
    await tester.pumpWidget(screen(DeferredMenu(old.future)));
    await tester.pumpWidget(screen(DeferredMenu(current.future), title: 'Menu Availability'));
    current.complete([soup]);
    await tester.pumpAndSettle();
    old.complete([tea]);
    await tester.pumpAndSettle();
    expect(find.text('Soup'), findsOneWidget);
    expect(find.text('Tea'), findsNothing);
  });

  testWidgets('both Dashboard menu entry cards open their connected views', (tester) async {
    tester.view.physicalSize = const Size(1440, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final title in dashboardMenuCards) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const MaterialApp(home: StaffDashboardPage(
        email: 'review@example.com', role: 'admin', grantedPermissions: {},
      )));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('dashboard-search')), title);
      await tester.pumpAndSettle();
      final card = find.byKey(ValueKey('dashboard-card-${title.toLowerCase().replaceAll(' ', '_')}'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(CafeDashboardMenu), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
