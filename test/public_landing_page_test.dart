import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/shared/gelye_professional_theme.dart';
import '../lib/shared/public_landing_page.dart';

void main() {
  testWidgets('landing page exposes customer and employee actions', (
    tester,
  ) async {
    var menuOpens = 0;
    var reservationsOpen = 0;
    var ordersOpen = 0;
    var staffOpen = 0;
    var stationOpen = 0;
    var themeToggles = 0;

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: GelyeProfessionalTheme.light,
        home: PublicLandingPage(
          isDark: false,
          onToggleTheme: () => themeToggles++,
          onStaffLogin: () => staffOpen++,
          onStationPos: () => stationOpen++,
          onOpenMenu: () => menuOpens++,
          onReserveTable: () => reservationsOpen++,
          onOrderOnline: () => ordersOpen++,
          contactLoader: () async => const {
            'business_name': 'Gelye Sherane Café & Rest',
            'phone': '+964 700 000 0000',
            'email': 'hello@example.test',
            'address': 'Test address',
            'opening_hours': 'Daily, 9:00–22:00',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Staff login'), findsOneWidget);
    expect(find.text('Station POS'), findsOneWidget);
    expect(find.byKey(const ValueKey('landing-menu-cta')), findsOneWidget);
    expect(find.text('Reservations'), findsOneWidget);
    expect(find.text('Online ordering'), findsOneWidget);
    expect(find.text('Contact & hours'), findsOneWidget);
    expect(find.text('+964 700 000 0000'), findsOneWidget);
    expect(find.text('hello@example.test'), findsOneWidget);

    await tester.tap(find.text('Staff login'));
    await tester.tap(find.text('Station POS'));
    await tester.tap(find.byTooltip('Toggle theme'));
    await tester.tap(find.byKey(const ValueKey('landing-menu-cta')));
    await tester.ensureVisible(find.text('Reservations'));
    await tester.tap(find.text('Reservations'));
    await tester.ensureVisible(find.text('Online ordering'));
    await tester.tap(find.text('Online ordering'));
    await tester.pump();

    expect(staffOpen, 1);
    expect(stationOpen, 1);
    expect(themeToggles, 1);
    expect(menuOpens, 1);
    expect(reservationsOpen, 1);
    expect(ordersOpen, 1);
  });

  testWidgets('landing page stays laid out when contact loading fails', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: GelyeProfessionalTheme.light,
        home: PublicLandingPage(
          isDark: false,
          onToggleTheme: () {},
          onStaffLogin: () {},
          onStationPos: () {},
          onOpenMenu: () {},
          onReserveTable: () {},
          onOrderOnline: () {},
          contactLoader: () async {
            throw StateError('Contact service unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Contact details are temporarily unavailable.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
