import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/main.dart';

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
        home: StaffDashboardPage(
          email: 'admin@example.com',
          role: 'admin',
        ),
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
}
