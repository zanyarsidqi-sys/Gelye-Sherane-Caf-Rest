import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/favorites_page.dart';
import 'package:gelye_sherane_cafe/staff_dashboard_page.dart';

class MemoryStorage implements FavoritesStorage {
  List<String> ids = [];
  @override
  Future<List<String>> read(String account) async => List.of(ids);
  @override
  Future<void> write(String account, List<String> values) async => ids = values;
}

void main() {
  testWidgets('favorites live inside Dashboard and survive category navigation', (tester) async {
    tester.view.physicalSize = const Size(1440, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = MemoryStorage()..ids = ['dashboard:Today Revenue'];
    await tester.pumpWidget(MaterialApp(home: StaffDashboardPage(
      email: 'staff@example.com', role: 'staff', favoritesStorage: storage,
      grantedPermissions: const {'dashboard:today_revenue', 'dashboard:standing_cash', 'payment_management:receive_payment'},
    )));
    await tester.pumpAndSettle();
    expect(find.text('Today at a Glance'), findsNothing);
    expect(find.byKey(const ValueKey('management-favorites')), findsNothing);
    expect(find.text('Today Revenue'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('favorites-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favorite-payment_management:Receive Payment')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favorites-picker')));
    await tester.pumpAndSettle();
    expect(find.text('Receive Payment'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dashboard-category-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('Receive Payment'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('dashboard-category-tab-0')));
    await tester.pumpAndSettle();
    expect(find.text('Receive Payment'), findsOneWidget);
    expect(find.text('Connected workflow'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('favorite-open-payment_management:Receive Payment')));
    await tester.pumpAndSettle();
    expect(find.text('Order payments'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
