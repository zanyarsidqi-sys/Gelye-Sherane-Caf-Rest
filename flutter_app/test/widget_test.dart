import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/main.dart';
import 'package:gelye_sherane_cafe/staff_dashboard_page.dart';

void main() {
  testWidgets('shows the cafe landing page without the management showcase', (
    tester,
  ) async {
    await tester.pumpWidget(const CafeApp());
    await tester.pumpAndSettle();

    expect(find.text('Gelye Sherane'), findsNWidgets(2));
    expect(find.text('Gelye Sherane\nCafé & Restaurant'), findsOneWidget);
    expect(find.text('A taste to look forward to'), findsOneWidget);
    expect(find.text('Dashboard Management'), findsNothing);
    expect(find.text('BUILT AROUND HOSPITALITY'), findsNothing);
    expect(find.text('A thoughtful cafe, well run'), findsNothing);
  });

  testWidgets('menu link scrolls to the menu section', (tester) async {
    await tester.pumpWidget(const CafeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explore menu'));
    await tester.pumpAndSettle();

    expect(find.text('A taste to look forward to'), findsOneWidget);
    expect(find.text('Coffee & tea'), findsOneWidget);
  });

  testWidgets('reservation form validates required contact details', (
    tester,
  ) async {
    await tester.pumpWidget(const CafeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Book a table').first);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Plan your visit'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('Enter a valid phone number'), findsOneWidget);
  });

  testWidgets('staff sign-in explains when Supabase is not configured', (
    tester,
  ) async {
    await tester.pumpWidget(const CafeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Staff sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Staff sign in'), findsOneWidget);
    expect(
      find.textContaining('not configured for this deployment'),
      findsOneWidget,
    );
  });

  testWidgets('admin dashboard shows all 11 management sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StaffDashboardPage(email: 'admin@example.com', role: 'admin'),
      ),
    );
    await tester.pumpAndSettle();

    for (final section in [
      'Dashboard',
      'Tables & Orders',
      'Payment Management',
      'Kitchen Management',
      'Customer Management',
      'Statistics Management',
      'Employee Management',
      'Maintenance Management',
      'Notifications Management',
      'Settings Management',
      'Operations Management',
    ]) {
      expect(find.text(section), findsWidgets, reason: section);
    }
  });

  testWidgets('staff dashboard shows only assigned sections and cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StaffDashboardPage(
          email: 'staff@example.com',
          role: 'staff',
          grantedPermissions: {
            'dashboard:today_revenue',
            'tables_orders:table_overview',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tables & Orders'), findsOneWidget);
    expect(find.text('Payment Management'), findsNothing);
    expect(find.text('Today Revenue'), findsOneWidget);
    expect(find.text('Standing Cash'), findsNothing);

    await tester.tap(find.text('Tables & Orders'));
    await tester.pumpAndSettle();
    expect(find.text('Table Overview'), findsOneWidget);
    expect(find.text('Visual Table Map'), findsNothing);
  });

  testWidgets('dashboard cards share one responsive design on iPhone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StaffDashboardPage(
          email: 'staff@example.com',
          role: 'staff',
          grantedPermissions: {
            'dashboard:today_revenue',
            'dashboard:standing_cash',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final revenueCard = find.ancestor(
      of: find.text('Today Revenue'),
      matching: find.byType(Card),
    );
    final cashCard = find.ancestor(
      of: find.text('Standing Cash'),
      matching: find.byType(Card),
    );

    expect(revenueCard, findsOneWidget);
    expect(cashCard, findsOneWidget);
    expect(tester.getSize(revenueCard), tester.getSize(cashCard));
    expect(tester.getSize(revenueCard).width, greaterThan(340));
    expect(
      tester.widget<Card>(revenueCard).color,
      tester.widget<Card>(cashCard).color,
    );
    expect(tester.getSize(revenueCard).height, 176);
    expect(find.text('Café & Restaurant · Management'), findsOneWidget);
  });

  testWidgets('iPhone navigation keeps key sections and exposes More', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StaffDashboardPage(email: 'admin@example.com', role: 'admin'),
      ),
    );
    await tester.pumpAndSettle();

    for (final destination in [
      'Home',
      'Tables',
      'Kitchen',
      'Payments',
      'More',
    ]) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(destination),
        ),
        findsOneWidget,
        reason: destination,
      );
    }

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('More management sections'), findsOneWidget);
    expect(find.text('Customer Management'), findsOneWidget);
  });

  testWidgets('Dashboard and section cards share the same iPhone layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StaffDashboardPage(email: 'admin@example.com', role: 'admin'),
      ),
    );
    await tester.pumpAndSettle();

    final dashboardCard = find.ancestor(
      of: find.text('Today Revenue'),
      matching: find.byType(Card),
    );
    final dashboardCardSize = tester.getSize(dashboardCard);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Tables'),
      ),
    );
    await tester.pumpAndSettle();

    final sectionCard = find.ancestor(
      of: find.text('Table Overview'),
      matching: find.byType(Card),
    );
    expect(sectionCard, findsOneWidget);
    expect(tester.getSize(sectionCard), dashboardCardSize);
  });

  testWidgets('staff permission dialog fits on an iPhone-sized screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StaffDashboardPage(email: 'admin@example.com', role: 'admin'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add staff user'));
    await tester.pumpAndSettle();

    final dialogSurface = find.descendant(
      of: find.byType(Dialog),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Material && widget.color == const Color(0xFFFFFEFB),
      ),
    );
    final dialogRect = tester.getRect(dialogSurface);
    expect(dialogRect.width, lessThanOrEqualTo(390));
    expect(dialogRect.height, lessThan(820));
    expect(find.text('New staff email'), findsOneWidget);
    expect(find.text('Initial password (12+ characters)'), findsOneWidget);
    expect(find.text('Create staff account'), findsOneWidget);

    final permissionList = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(ListView),
    );
    for (
      var attempt = 0;
      attempt < 8 && find.text('Operations Management').evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(permissionList, const Offset(0, -320));
      await tester.pumpAndSettle();
    }
    expect(find.text('Operations Management'), findsOneWidget);
    await tester.tap(find.text('Operations Management'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Closing Checklist'));
    expect(find.text('Closing Checklist'), findsOneWidget);
  });
}
