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

  testWidgets('staff sign-in explains when Supabase is not configured', (
    tester,
  ) async {
    await tester.pumpWidget(const CafeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Staff sign in'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('not configured for this deployment'),
      findsOneWidget,
    );
  });

  testWidgets('staff dashboard opens its restaurant sections', (tester) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StaffDashboardPage(email: 'admin@example.com', role: 'admin'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Administrator dashboard'), findsOneWidget);
    for (final card in [
      'Today Revenue',
      'Standing Cash',
      'Pending Payment',
      'Today Orders',
      'Table Occupancy',
      'Kitchen Queue',
      'Motel Orders',
      'Tourism Customers',
      'Reservations',
      'Customer Requests',
      'Takeaway & Delivery',
      'Attendance',
      'Cash Reconciliation',
      'Product Performance',
      'Service Speed',
      'Feedback',
      'Maintenance',
      'System Health',
      'Audit & Activity',
      'Personalization',
    ]) {
      expect(find.text(card), findsOneWidget);
    }

    expect(find.text('Not connected'), findsNWidgets(20));
    for (final destination in [
      'Home',
      'Tables',
      'Kitchen',
      'Payments',
      'More',
    ]) {
      expect(find.text(destination), findsWidgets);
    }

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    for (final section in [
      'Customer Management',
      'Statistics Management',
      'Employee Management',
      'Maintenance Management',
      'Notifications Management',
      'Settings Management',
      'Operations Management',
    ]) {
      expect(find.text(section), findsOneWidget);
    }
    await tester.tap(find.text('Employee Management'));
    await tester.pumpAndSettle();
    expect(find.text('Staff Directory'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Today Revenue'));
    await tester.pumpAndSettle();
    expect(
      find.text('Details for Today Revenue in Dashboard.'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'live data source, permissions, and operational actions',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Back to Dashboard'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation menu'));
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
      expect(find.text(section), findsOneWidget);
    }

    for (final section in [
      ('Dashboard', 20),
      ('Tables & Orders', 14),
      ('Payment Management', 13),
      ('Kitchen Management', 14),
      ('Customer Management', 13),
      ('Statistics Management', 12),
      ('Employee Management', 12),
      ('Maintenance Management', 10),
      ('Notifications Management', 11),
      ('Settings Management', 12),
      ('Operations Management', 10),
    ]) {
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(section.$1));
      await tester.pumpAndSettle();
      expect(find.text('Not connected'), findsNWidgets(section.$2));
    }

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tables & Orders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Table Overview'));
    await tester.pumpAndSettle();
    expect(
      find.text('Details for Table Overview in Tables & Orders.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Add staff user'));
    await tester.pumpAndSettle();
    expect(find.text('Add staff user'), findsOneWidget);
    expect(find.text('New staff email'), findsOneWidget);
    expect(find.text('Initial password (12+ characters)'), findsOneWidget);
  });

  testWidgets('wide staff dashboard keeps all eleven sections in its sidebar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
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
      expect(find.text(section), findsOneWidget);
    }
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('staff sees only assigned sections and cards', (tester) async {
    tester.view.physicalSize = const Size(500, 1200);
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
            'customer_management:customer_directory',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today Revenue'), findsOneWidget);
    expect(find.text('Standing Cash'), findsNothing);
    expect(find.text('Tables'), findsNWidgets(2));
    expect(find.text('Kitchen'), findsNothing);
    expect(find.text('Payments'), findsNothing);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Customer Management'), findsOneWidget);
    expect(find.text('Statistics Management'), findsNothing);

    await tester.tap(find.text('Customer Management'));
    await tester.pumpAndSettle();
    expect(find.text('Customer Directory'), findsOneWidget);
    expect(find.text('Motel Orders'), findsNothing);
  });

  testWidgets('staff permissions load failures show Dashboard only', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StaffDashboardPage(
          email: 'staff@example.com',
          role: 'staff',
          permissionsLoadError: 'permission table unavailable',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Staff dashboard'), findsOneWidget);
    expect(find.text('Tables & Orders'), findsNothing);
    expect(
      find.textContaining(
        'Dashboard is open, but no additional sections or cards are shown',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Dashboard cards are unavailable until permissions can be loaded.',
      ),
      findsOneWidget,
    );
  });
}
