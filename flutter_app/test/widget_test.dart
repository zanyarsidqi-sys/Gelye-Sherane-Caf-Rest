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
      MaterialApp(
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
      MaterialApp(
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

  testWidgets('dashboard shows compact grouped cards on iPhone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: StaffDashboardPage(
          email: 'staff@example.com',
          role: 'staff',
          grantedPermissions: {
            'dashboard:today_revenue',
            'dashboard:standing_cash',
            'dashboard:tables_occupied',
            'dashboard:reports',
            'dashboard:security',
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
    expect(tester.getSize(revenueCard).width, lessThan(150));
    expect(tester.widget<Card>(revenueCard).color, isNot(Colors.white));
    expect(tester.widget<Card>(cashCard).color, isNot(Colors.white));
    expect(tester.getSize(revenueCard).height, 118);
    expect(find.text('Payments & Finance'), findsOneWidget);
    expect(find.text('Tables & Reservations'), findsOneWidget);
    expect(find.text('Reports, Settings & Security'), findsOneWidget);
    expect(find.textContaining('· Today'), findsOneWidget);
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
      MaterialApp(
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

  testWidgets(
    'dashboard summary and finance section use responsive card layouts',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
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
      expect(dashboardCardSize.width, lessThan(150));
      expect(tester.getSize(sectionCard).width, greaterThan(340));

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Payments'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Payments & Finance'), findsOneWidget);
      expect(find.textContaining('Finance data unavailable'), findsOneWidget);
      expect(find.text('Pending Payments'), findsOneWidget);

      await tester.tap(find.text('Today Revenue'));
      await tester.pumpAndSettle();
      expect(find.text('Today Revenue records'), findsOneWidget);
      expect(find.text('Add record'), findsOneWidget);
      expect(find.text('No live records for this date range.'), findsNothing);
      expect(find.text('1,250,000 IQD'), findsNothing);
    },
  );

  testWidgets('employee workspace explains the department-first setup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: StaffDashboardPage(email: 'admin@example.com', role: 'admin'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Employee workspace'));
    await tester.pumpAndSettle();

    expect(find.text('Employee workspace'), findsOneWidget);
    expect(find.text('Departments'), findsOneWidget);
    expect(find.text('Permission profiles'), findsOneWidget);
    expect(find.text('Staff accounts'), findsOneWidget);
    expect(find.text('Add department'), findsOneWidget);
    expect(find.text('Create permission profile'), findsOneWidget);
    expect(find.text('Add staff account'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Add department'),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Create permission profile'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Add staff account'),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.text(
        'Supabase is not configured for employee management in this deployment.',
      ),
      findsOneWidget,
    );
  });
}
