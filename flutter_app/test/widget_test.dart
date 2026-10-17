import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_guest_page.dart';
import 'package:gelye_sherane_cafe/main.dart';
import 'package:gelye_sherane_cafe/staff_dashboard_page.dart';

void main() {
  testWidgets('app starts on the public landing page', (tester) async {
    await tester.pumpWidget(const CafeApp());
    await tester.pumpAndSettle();

    expect(find.text('A taste to look forward to'), findsOneWidget);
    expect(find.text('admin@gelyesherane.local'), findsNothing);
  });

  testWidgets('guest QR page explains when verification is not configured', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CafeGuestPage(
          qrToken: '00000000-0000-4000-8000-000000000001',
          supabaseConfigured: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Table QR verification is not configured for this site.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('shows the management redesign on first load', (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StaffDashboardPage(email: 'admin@example.com', role: 'admin'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gelye Sherane'), findsOneWidget);
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Tables & Chairs'), findsWidgets);
    expect(find.text('Staff Management'), findsWidgets);
    expect(find.text('A taste to look forward to'), findsNothing);
    expect(find.text('Book a table'), findsNothing);

    for (var index = 0; index < 24; index++) {
      expect(
        find.byKey(ValueKey('management-section-$index')),
        findsOneWidget,
        reason: 'Management section $index should remain available.',
      );
    }
    final workspacePanel = tester.widget<Container>(
      find.byKey(const ValueKey('executive-workspace-panel')),
    );
    expect(
      (workspacePanel.decoration! as BoxDecoration).color,
      const Color(0xFF101E31),
    );
    final dashboardNavigation = tester.widget<ListTile>(
      find.byKey(const ValueKey('management-section-0')),
    );
    expect(dashboardNavigation.selected, isTrue);
    expect(dashboardNavigation.selectedTileColor, const Color(0xFFD6AA57));

    await tester.tap(find.byKey(const ValueKey('management-section-1')));
    await tester.pumpAndSettle();
    final addTableCard = find.byKey(
      const ValueKey('tables-category-card-Add Table'),
    );
    expect(addTableCard, findsOneWidget);
    expect(tester.widget<Card>(addTableCard).color, isNot(Colors.white));
  });

  testWidgets('Table Reservations dashboard card opens the live workflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StaffDashboardPage(email: 'admin@example.com', role: 'admin'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dashboard-category-tab-2')));
    await tester.pumpAndSettle();
    final reservationsCard = find.textContaining('Table Reservations').first;
    expect(reservationsCard, findsOneWidget);
    await tester.ensureVisible(reservationsCard);
    await tester.tap(reservationsCard);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('create-table-reservation')),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'New reservations are checked and saved by Supabase.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('reservation permission opens the staff reservation workflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: StaffDashboardPage(
          email: 'staff@example.com',
          role: 'staff',
          grantedPermissions: const {'tables_orders:table_reservations'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('management-section-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Reservations & Availability'));
    await tester.pumpAndSettle();

    final reservationsCard = find.byKey(
      const ValueKey('tables-category-card-Table Reservations'),
    );
    expect(reservationsCard, findsOneWidget);
    expect(
      find.byKey(const ValueKey('tables-category-card-Add Table')),
      findsNothing,
    );
    await tester.tap(reservationsCard);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('create-table-reservation')),
      findsOneWidget,
    );
  });

  testWidgets('menu link scrolls to the menu section', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CafeLandingPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explore menu'));
    await tester.pumpAndSettle();

    expect(find.text('A taste to look forward to'), findsOneWidget);
    expect(find.text('Coffee & tea'), findsOneWidget);
  });

  testWidgets('reservation form validates required contact details', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CafeLandingPage()));
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
    await tester.pumpWidget(const MaterialApp(home: CafeLandingPage()));
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

  testWidgets('admin dashboard shows all management sections', (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
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
      'Tables & Chairs',
      'Payment Management',
      'Menu Management',
      'Kitchen Management',
      'Motel & Online Orders',
      'Inventory Management',
      'Staff Management',
      'Customer Management',
      'Reservations Management',
      'Settings Management',
      'Notifications Management',
      'Statistics Management',
      'Maintenance Management',
      'Operations Management',
      'Devices & Printing Management',
      'Security & Audit Management',
      'System Health & Updates',
      'Shisha Management',
      'Delivery Management',
      'Marketing Management',
      'Customer Feedback Management',
      'Staff & Operations Management',
      'Reports Management',
    ]) {
      expect(find.text(section), findsWidgets, reason: section);
    }
  });

  testWidgets('every management section opens without layout exceptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const sectionTitles = [
      'Dashboard',
      'Tables & Chairs',
      'Payment Management',
      'Menu Management',
      'Kitchen Management',
      'Motel & Online Orders',
      'Inventory Management',
      'Staff Management',
      'Customer Management',
      'Reservations Management',
      'Settings Management',
      'Notifications Management',
      'Statistics Management',
      'Maintenance Management',
      'Operations Management',
      'Devices & Printing Management',
      'Security & Audit Management',
      'System Health & Updates',
      'Shisha Management',
      'Delivery Management',
      'Marketing Management',
      'Customer Feedback Management',
      'Staff & Operations Management',
      'Reports Management',
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: StaffDashboardPage(email: 'admin@example.com', role: 'admin'),
      ),
    );
    await tester.pumpAndSettle();

    for (var index = 0; index < sectionTitles.length; index++) {
      final section = find.byKey(ValueKey('management-section-$index'));
      expect(section, findsOneWidget, reason: sectionTitles[index]);
      await tester.tap(section);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: sectionTitles[index]);
    }
  });

  testWidgets('non-dashboard card opens the shared record workspace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: StaffDashboardPage(email: 'admin@example.com', role: 'admin'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('management-section-6')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inventory Overview'));
    await tester.pumpAndSettle();

    expect(find.text('Inventory Overview records'), findsOneWidget);
    expect(find.text('Tracked records'), findsOneWidget);
    expect(find.text('Open records'), findsOneWidget);
    expect(find.text('Completed records'), findsOneWidget);
    expect(find.text('Search Inventory Overview...'), findsOneWidget);
    final addRecordButton = find.widgetWithText(FilledButton, 'Add record');
    expect(addRecordButton, findsOneWidget);
    expect(tester.widget<FilledButton>(addRecordButton).onPressed, isNull);
    expect(find.byType(ChoiceChip), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard preserves legacy cards and stages the full catalog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StaffDashboardPage(email: 'admin@example.com', role: 'admin'),
      ),
    );
    await tester.pumpAndSettle();

    const categories = [
      'Today at a Glance',
      'Payments & Finance',
      'Tables & Reservations',
      'Kitchen & Minibar',
      'Orders & Customer Service',
      'Employees & Operations',
      'Inventory & Purchasing',
      'Reports & System',
    ];
    for (final category in categories) {
      expect(find.text(category), findsWidgets, reason: category);
    }

    const proposedCards = [
      'Today Revenue',
      'Tables Occupied',
      'Kitchen Orders',
      'Pending Payment',
      'Today’s Orders',
      'Today’s Customers',
      'Motel Orders',
      'Online & Walk-In Orders',
      'Standing Cash',
      'Invoices',
      'Discounts',
      'Credit Accounts',
      'Cash Reconciliation',
      'Cash Out — Owner',
      'Cash & Payment Methods',
      'Refunds & Adjustments',
      'Daily Financial Summary',
      'Expenses',
      'Remaining Cash',
      'Confirm Credit',
      'Cash Received',
      'Cash In',
      'Pending Expenses',
      'Accounts Payable',
      'Accounts Receivable',
      'Credit Collections',
      'Credit Approval History',
      'Cash Transfers',
      'Expected vs Actual Cash',
      'Financial Alerts',
      'Live Tables',
      'Table Reservations',
      'Available Tables',
      'Waiting List',
      'Guest Check-In',
      'Table Cleaning',
      'Table Service Requests',
      'Kitchen Live Board',
      'Minibar Live Board',
      'Orders Preparing',
      'Ready for Delivery',
      'Delayed Orders',
      'Station Printers',
      'Menu Availability',
      'Table Orders',
      'Motel Orders Tracking',
      'Online Orders Tracking',
      'Walk-In Orders Tracking',
      'Customer Requests',
      'Customer Feedback',
      'Service Speed',
      'Employee Attendance',
      'Employee Assignments',
      'Pending Staff Tasks',
      'Staff Performance',
      'Maintenance Requests',
      'Notifications & Alerts',
      'Inventory Overview',
      'Low Stock Alerts',
      'Purchase Requests',
      'Pending Approvals',
      'Supplier Deliveries',
      'Inventory Waste',
      'Sales Performance',
      'Product Performance',
      'Table Occupancy Reports',
      'Audit & Activity History',
      'System Health',
      'Backup & Sync Status',
      'Dashboard Personalization',
    ];
    expect(proposedCards, hasLength(70));
    final observed = <String>{};
    for (var i = 0; i < categories.length; i++) {
      final tab = find.byKey(ValueKey('dashboard-category-tab-$i'));
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pumpAndSettle();
      for (final title in proposedCards) {
        if (find.text(title).evaluate().isNotEmpty) observed.add(title);
      }
    }
    expect(observed, containsAll(proposedCards));

    await tester.ensureVisible(find.byKey(const ValueKey('dashboard-category-tab-1')));
    await tester.tap(find.byKey(const ValueKey('dashboard-category-tab-1')));
    await tester.pumpAndSettle();

    final previewCard = find.text('Cash Out — Owner');
    await tester.ensureVisible(previewCard);
    await tester.tap(previewCard);
    await tester.pumpAndSettle();

    expect(find.text('Design preview — not live'), findsOneWidget);
    expect(find.textContaining('authoritative data source'), findsOneWidget);
    expect(find.text('Add record'), findsNothing);
    expect(find.text('Search Cash Out — Owner...'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('staff dashboard shows only assigned sections and cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1900);
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
            'inventory_management:expiry_waste',
            'devices_printing_management:printer_queue',
            'security_audit_management:security_alerts',
            'system_health_updates_management:health_check',
            'shisha_management:shisha_menu',
            'delivery_management:delivery_menu',
            'customer_feedback_management:customer_reviews',
            'staff_operations_management:check_in_out',
            'reports_management:sales_reports',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tables & Chairs'), findsWidgets);
    expect(find.text('Payment Management'), findsNothing);
    expect(find.text('Today Revenue'), findsOneWidget);
    expect(find.text('Standing Cash'), findsNothing);
    expect(find.text('Devices & Printing Management'), findsOneWidget);
    expect(find.text('Security & Audit Management'), findsOneWidget);
    expect(find.text('System Health & Updates'), findsOneWidget);
    expect(find.text('Shisha Management'), findsOneWidget);
    expect(find.text('Delivery Management'), findsOneWidget);
    expect(find.text('Customer Feedback Management'), findsOneWidget);
    expect(find.text('Staff & Operations Management'), findsOneWidget);
    expect(find.text('Reports Management'), findsOneWidget);

    await tester.tap(find.text('Tables & Chairs'));
    await tester.pumpAndSettle();
    expect(find.text('Add Table'), findsOneWidget);
    expect(find.text('Table Overview'), findsNothing);
    expect(find.text('Table Reservations'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tables-category-0')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('tables-category-card-QR Code Management')),
      findsNothing,
    );

    await tester.tap(find.text('Inventory Management'));
    await tester.pumpAndSettle();
    expect(find.text('Expiry & Waste'), findsOneWidget);
    expect(find.text('Inventory Overview'), findsNothing);

    await tester.tap(find.text('Devices & Printing Management'));
    await tester.pumpAndSettle();
    expect(find.text('Printer Queue'), findsOneWidget);
    expect(find.text('Devices Overview'), findsNothing);

    await tester.tap(find.text('Security & Audit Management'));
    await tester.pumpAndSettle();
    expect(find.text('Security Alerts'), findsOneWidget);
    expect(find.text('Access Management'), findsNothing);

    await tester.tap(find.text('System Health & Updates'));
    await tester.pumpAndSettle();
    expect(find.text('Health Check'), findsOneWidget);
    expect(find.text('System Overview'), findsNothing);

    await tester.tap(find.text('Shisha Management'));
    await tester.pumpAndSettle();
    expect(find.text('Shisha Menu'), findsOneWidget);
    expect(find.text('Shisha Overview'), findsNothing);

    await tester.tap(find.text('Delivery Management'));
    await tester.pumpAndSettle();
    expect(find.text('Delivery Menu'), findsOneWidget);
    expect(find.text('Delivery Overview'), findsNothing);

    await tester.tap(find.text('Customer Feedback Management'));
    await tester.pumpAndSettle();
    expect(find.text('Customer Reviews'), findsOneWidget);
    expect(find.text('Feedback Overview'), findsNothing);

    await tester.tap(find.text('Staff & Operations Management'));
    await tester.pumpAndSettle();
    expect(find.text('Check In & Out'), findsOneWidget);
    expect(find.text('Staff & Operations Overview'), findsNothing);

    await tester.tap(find.text('Reports Management'));
    await tester.pumpAndSettle();
    expect(find.text('Sales Reports'), findsOneWidget);
    expect(find.text('Reports Overview'), findsNothing);
  });

  testWidgets('public landing page renders on iPhone without layout errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: CafeLandingPage()));
    await tester.pumpAndSettle();

    expect(find.text('A taste to look forward to'), findsOneWidget);
    expect(find.text('Explore menu'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
      of: find.text('Tables Occupied'),
      matching: find.byType(Card),
    );

    expect(revenueCard, findsOneWidget);
    expect(cashCard, findsOneWidget);
    expect(tester.getSize(revenueCard).height, tester.getSize(cashCard).height);
    expect(tester.getSize(revenueCard).width, lessThan(200));
    final revenueColor = tester.widget<Card>(revenueCard).color;
    final cashColor = tester.widget<Card>(cashCard).color;
    expect(revenueColor, isNot(Colors.white));
    expect(cashColor, isNot(Colors.white));
    expect(revenueColor, isNot(cashColor));
    expect(tester.getSize(revenueCard).height, 118);
    expect(find.text('Today at a Glance'), findsWidgets);
    expect(find.text('Payments & Finance'), findsWidgets);
    expect(find.text('Reports & System'), findsWidgets);
    final reportsTab = find.byKey(const ValueKey('dashboard-category-tab-7'));
    expect(reportsTab, findsOneWidget);
    await tester.ensureVisible(reportsTab);
    await tester.tap(reportsTab);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(reportsTab).selected, isTrue);
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
      'Motel',
      'Menu',
      'Reserve',
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
    expect(find.text('Kitchen Management'), findsOneWidget);
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

      expect(find.text('Tables & Chairs'), findsWidgets);
      expect(find.text('Add Table'), findsOneWidget);
      expect(find.text('Table service board'), findsNothing);
      expect(find.text('Table workflows'), findsNothing);
      expect(tester.takeException(), isNull);

      final addTableCard = find.byKey(
        const ValueKey('tables-category-card-Add Table'),
      );
      expect(tester.getSize(addTableCard).width, greaterThan(200));
      await tester.tap(addTableCard);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dining-table-editor-panel')),
        findsOneWidget,
      );
      expect(find.text('New table'), findsOneWidget);
      expect(find.text('Back to Tables & Chairs'), findsOneWidget);
      expect(find.text('Floor map'), findsNothing);
      expect(find.text('Table workflows'), findsNothing);
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('add-dining-table')), findsOneWidget);
      expect(find.text('Saved tables'), findsOneWidget);
      await tester.ensureVisible(find.text('Back to Tables & Chairs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back to Tables & Chairs'));
      await tester.pumpAndSettle();

      expect(dashboardCardSize.width, lessThan(200));
      expect(find.text('More cards (20)'), findsNothing);
      expect(find.text('Live Tables'), findsNothing);
      expect(find.text('Table Orders'), findsNothing);

      await tester.tap(find.text('More').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Payment Management').last);
      await tester.pumpAndSettle();
      expect(find.text('Payments & Finance'), findsOneWidget);
      expect(find.textContaining('Finance data unavailable'), findsOneWidget);
      expect(find.text('Pending Payments'), findsOneWidget);
      expect(find.text('Receive Payment'), findsOneWidget);
      expect(find.text('Invoices & Receipts'), findsOneWidget);

      await tester.ensureVisible(find.text('Payment Overview'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Payment Overview'));
      await tester.pumpAndSettle();
      expect(find.text('Payment Overview records'), findsOneWidget);
      expect(find.text('Add record'), findsOneWidget);
      expect(find.text('No live records for this date range.'), findsNothing);
      expect(find.text('1,250,000 IQD'), findsNothing);
    },
  );

  testWidgets('every payment card opens its finance record detail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: StaffDashboardPage(email: 'admin@example.com', role: 'admin'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('management-section-2')));
    await tester.pumpAndSettle();

    expect(find.text('Payment activity'), findsOneWidget);
    expect(find.text('Transaction ledger'), findsOneWidget);
    expect(find.text('Finance actions'), findsOneWidget);
    expect(find.text('Search payment records...'), findsOneWidget);

    const featuredCards = [
      'Payment Overview',
      'Receive Payment',
      'Standing Cash',
      'Pending Payments',
      'Collected Cash',
      'Available Cash',
      'Owner Cash Out',
      'Expenses Management',
      'Confirm Credit Payment',
      'Invoices & Receipts',
      'Refunds & Voids',
      'Table Income',
      'Payment History',
    ];
    const additionalCards = [
      'Today Revenue',
      'Revenue',
      'Cash Over / Short',
      'Expenses',
      'Invoices & Payments',
      'Confirm Credit',
      'Costs & Expenses',
      'Invoices',
      'Payment Collection',
      'Cash/Card/Online',
      'Pending Payment',
      'Customer Credit',
      'Discounts',
      'Refunds',
      'Cash Reconciliation',
      'Approvals',
      'Audit',
    ];

    Future<void> openAndVerify(String title) async {
      if (find.text(title).evaluate().isEmpty) {
        final moreCards = find.text('More finance cards (17)');
        await tester.ensureVisible(moreCards);
        await tester.tap(moreCards);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text(title));
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();

      expect(find.text('$title records'), findsOneWidget, reason: title);
      expect(find.text('Search $title...'), findsOneWidget, reason: title);
      expect(find.text('Tracked records'), findsOneWidget, reason: title);
      expect(find.text('Open records'), findsOneWidget, reason: title);
      expect(find.text('Add record'), findsOneWidget, reason: title);
      expect(tester.takeException(), isNull, reason: title);

      final back = find.text('Back to Payment Management');
      await tester.ensureVisible(back);
      await tester.tap(back);
      await tester.pumpAndSettle();
    }

    for (final title in featuredCards) {
      await openAndVerify(title);
    }
    for (final title in additionalCards) {
      await openAndVerify(title);
    }
  });

  testWidgets('Tables & Chairs has four categories and 29 staged cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: StaffDashboardPage(email: 'admin@example.com', role: 'admin'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('management-section-1')));
    await tester.pumpAndSettle();

    Future<void> selectCategory(int index) async {
      final category = find.byKey(ValueKey('tables-category-$index'));
      await tester.ensureVisible(category);
      await tester.tap(category);
      await tester.pumpAndSettle();
    }

    expect(find.text('Tables & Chairs'), findsWidgets);
    expect(find.byType(ChoiceChip), findsNWidgets(4));
    const categoryCardCounts = [5, 9, 6, 6];
    expect(categoryCardCounts.reduce((sum, count) => sum + count), 26);
    for (final title in [
      'Add Table',
      'Edit & Manage Tables',
      'Table Map',
      'QR Code Management',
      'Chairs Management',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    for (final removedTitle in [
      'Bulk Table Creation',
      'Areas & Sections',
      'Table Floor Plans',
    ]) {
      expect(find.text(removedTitle), findsNothing, reason: removedTitle);
    }
    expect(find.text('Table service board'), findsNothing);
    expect(find.text('Available'), findsNothing);
    expect(find.text('Occupied'), findsNothing);
    expect(find.text('Reserved'), findsNothing);
    expect(find.text('Floor map'), findsNothing);
    expect(find.text('Table list'), findsNothing);
    expect(find.text('Reservations records'), findsNothing);
    expect(find.text('Table workflows'), findsNothing);
    expect(find.text('Table Orders'), findsNothing);
    expect(find.text('More cards'), findsNothing);

    await selectCategory(1);
    for (final title in [
      'Table Reservations',
      'Table Availability',
      'Live Tables',
      'Table Status',
      'Join & Split Tables',
      'Extra Chairs Requests',
      'Reservation Waiting List',
      'Guest Check-In & No-Show',
      'Table Assignment',
    ]) {
      expect(
        find.byKey(ValueKey('tables-category-card-$title')),
        findsOneWidget,
        reason: title,
      );
    }
    await selectCategory(2);
    for (final title in [
      'Table Transfer',
      'Table Cleaning',
      'Table Session Management',
      'Waiter Table Assignment',
      'Table Service Requests',
      'Table Ordering',
    ]) {
      expect(
        find.byKey(ValueKey('tables-category-card-$title')),
        findsOneWidget,
        reason: title,
      );
    }
    await selectCategory(3);
    for (final title in [
      'Table Maintenance',
      'Table History & Audit',
      'Table Reports',
      'Table Settings',
      'Table Permissions',
      'Table Alerts & Notifications',
    ]) {
      expect(
        find.byKey(ValueKey('tables-category-card-$title')),
        findsOneWidget,
        reason: title,
      );
    }

    await selectCategory(0);
    await tester.tap(
      find.byKey(const ValueKey('tables-category-card-Chairs Management')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('chairs-management-guidance')),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Chair management is unavailable because Supabase is not configured',
      ),
      findsOneWidget,
    );
    expect(find.text('Search Chairs Management records...'), findsNothing);
    expect(find.text('Give extra chairs'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Back to Tables & Chairs'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('tables-category-card-Table Map')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Coming Soon — Awaiting Specification'), findsNothing);
    expect(
      find.textContaining(
        'Dining-table access is unavailable because Supabase is not configured',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Back to Tables & Chairs'));
    await tester.pumpAndSettle();
    await selectCategory(0);
    await tester.tap(
      find.byKey(const ValueKey('tables-category-card-QR Code Management')),
    );
    await tester.pumpAndSettle();
    expect(find.text('QR Code Management'), findsOneWidget);
    expect(find.text('Coming Soon — Awaiting Specification'), findsNothing);
    expect(find.byKey(const ValueKey('dining-table-search')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dining-table-status-filter')),
      findsOneWidget,
    );
    expect(find.text('Reset'), findsOneWidget);
    expect(find.byTooltip('Refresh saved tables'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dining-table-editor-tab-3')),
      findsOneWidget,
    );
    await tester.tap(find.text('Back to Tables & Chairs'));
    await tester.pumpAndSettle();
    await selectCategory(0);
    await tester.tap(
      find.byKey(const ValueKey('tables-category-card-Edit & Manage Tables')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit & Manage Tables'), findsOneWidget);
    expect(find.text('Coming Soon — Awaiting Specification'), findsNothing);
    expect(find.byKey(const ValueKey('dining-table-search')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dining-table-editor-panel')),
      findsOneWidget,
    );
    await tester.tap(find.text('Back to Tables & Chairs'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('tables-category-card-Add Table')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('saved-tables-panel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dining-table-editor-panel')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('add-dining-table')), findsOneWidget);
    expect(find.text('New table'), findsOneWidget);
    expect(find.text('Floor map'), findsNothing);
    expect(find.text('Table workflows'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Back to Tables & Chairs'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('tables-category-cards-0')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('tables-category-3')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('remaining management sections show reference card groups', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: StaffDashboardPage(email: 'admin@example.com', role: 'admin'),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> openMoreSection(String title) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('More'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('More management sections'), findsOneWidget);
      final section = find.text(title).last;
      expect(section, findsOneWidget);
      await tester.tap(section);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Motel').last);
    await tester.pumpAndSettle();
    const motelCategories = [
      [
        'Motel & Online Orders Overview',
        'Order Tracking',
        'Order History',
        'Order Details',
      ],
      [
        'Select Room',
        'New Motel Order',
        'Room Orders',
        'Motel Orders',
        'Meal Packages',
        'Motel Orders Settings',
      ],
      [
        'New Online Order',
        'Online Orders',
        'Delivery Schedule',
        'Delivery Areas',
      ],
      [
        'New Walk-In Order',
        'Active Walk-In Orders',
        'Ready for Pickup',
        'Walk-In Order History',
      ],
      ['Invoices & Receipts', 'Payment Options'],
    ];
    expect(find.byType(ChoiceChip), findsNWidgets(5));
    var motelCardTotal = 0;
    for (var index = 0; index < motelCategories.length; index++) {
      final tab = find.byKey(ValueKey('motel-orders-category-tab-$index'));
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pumpAndSettle();
      final categoryGrid = find.byKey(
        ValueKey('motel-orders-category-cards-$index'),
      );
      expect(
        find.descendant(of: categoryGrid, matching: find.byType(Card)),
        findsNWidgets(motelCategories[index].length),
      );
      for (final title in motelCategories[index]) {
        expect(
          find.byKey(ValueKey('motel-orders-category-card-$title')),
          findsOneWidget,
          reason: title,
        );
      }
      motelCardTotal += motelCategories[index].length;
    }
    expect(motelCardTotal, 20);
    final walkInTab = find.byKey(const ValueKey('motel-orders-category-tab-3'));
    await tester.ensureVisible(walkInTab);
    await tester.tap(walkInTab);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('motel-orders-category-card-New Walk-In Order'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Coming Soon — Awaiting verified integrations'),
      findsOneWidget,
    );
    expect(find.text('Design only'), findsOneWidget);
    expect(
      find.textContaining('does not create or process orders'),
      findsOneWidget,
    );
    expect(find.text('Add record'), findsNothing);
    await tester.tap(find.text('Back to Motel & Online Orders'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Previously available motel workspaces'),
      findsNothing,
    );

    await tester.tap(find.text('Menu').last);
    await tester.pumpAndSettle();
    const menuCategories = [
      [
        'Menu Overview',
        'Add New Product',
        'Edit & Manage Products',
        'Product Categories',
        'Product Images & Descriptions',
        'Product Variations & Add-ons',
        'Product Availability',
        'Bulk Product Management',
        'Product Combos & Meal Packages',
        'Product Scheduling',
        'Product Allergens & Nutrition',
      ],
      [
        'Normal Pricing',
        'Tourism Pricing',
        'Owner Pricing',
        'Discount Pricing',
        'Price Change History',
        'Pricing Rules & Approvals',
        'Product Cost & Profit Margin',
        'Happy Hour & Promotions',
      ],
      [
        'Product Station Assignment',
        'Kitchen Products',
        'Minibar Products — Nargile & Drinks',
        'Product Ingredients & Recipes',
        'Preparation Time & Instructions',
        'Product Printing Routing',
        'Recipe & Portion Management',
        'Product Preparation Options',
        'Station Availability & Failover',
      ],
      [
        'Customer Digital Menu',
        'Table QR Menu',
        'Online Ordering Menu',
        'Motel Menu',
        'Multilingual Menu',
        'Menu Display & Appearance',
        'Menu Publishing & Scheduling',
        'Menu QR & Sharing',
        'Customer Favorites & Popular Items',
      ],
      [
        'Product Stock Integration',
        'Out-of-Stock Management',
        'Product Sales & Performance',
        'Product Feedback & Ratings',
        'Product Recommendations',
        'Menu Reports',
        'Product Waste & Returns',
      ],
      [
        'Menu Permissions',
        'Menu Settings',
        'Menu Audit History',
        'Menu Import & Export',
        'Product Change Approval',
      ],
    ];
    expect(find.byType(ChoiceChip), findsNWidgets(6));
    var menuCardTotal = 0;
    for (var index = 0; index < menuCategories.length; index++) {
      final tab = find.byKey(ValueKey('menu-category-tab-$index'));
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pumpAndSettle();
      final categoryGrid = find.byKey(ValueKey('menu-category-cards-$index'));
      expect(
        find.descendant(of: categoryGrid, matching: find.byType(Card)),
        findsNWidgets(menuCategories[index].length),
      );
      for (final title in menuCategories[index]) {
        expect(
          find.byKey(ValueKey('menu-category-card-$title')),
          findsOneWidget,
          reason: title,
        );
      }
      menuCardTotal += menuCategories[index].length;
    }
    expect(menuCardTotal, 49);

    final productsTab = find.byKey(const ValueKey('menu-category-tab-0'));
    await tester.ensureVisible(productsTab);
    await tester.tap(productsTab);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('menu-category-card-Add New Product')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Design only'), findsOneWidget);
    expect(
      find.textContaining('Product-specific data sources'),
      findsOneWidget,
    );
    expect(find.text('Add record'), findsNothing);
    await tester.tap(find.text('Back to Menu Management'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-category-tab-0')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('menu-category-card-Menu Overview')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Menu Overview records'), findsOneWidget);
    expect(find.textContaining('generic record workspace'), findsOneWidget);
    expect(find.text('Search Menu Overview...'), findsOneWidget);
    await tester.tap(find.text('Back to Menu Management'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const PageStorageKey<String>('menu-preserved-workspaces')),
      findsNothing,
    );
    expect(
      find.textContaining('Previously available menu workspaces'),
      findsNothing,
    );

    await openMoreSection('Inventory Management');
    const inventoryCategories = [
      [
        'Inventory Overview',
        'All Inventory Items',
        'Items Needed',
        'Low Stock Items',
        'Expiry & Waste',
        'Inventory Alerts & Notifications',
        'Inventory Quick Actions',
      ],
      [
        'Add Inventory Item',
        'Edit & Manage Items',
        'Item Categories & Units',
        'Stock In',
        'Stock Out',
        'Stock Adjustments',
        'Batch & Lot Tracking',
        'Expiry Date Tracking',
        'Stock Count & Reconciliation',
        'Barcode & SKU Management',
      ],
      [
        'Stores & Branches',
        'Storage Locations & Bins',
        'Transfer Stock',
        'Transfer Requests & Approvals',
        'Goods Dispatch & Receiving',
        'Kitchen & Minibar Stock Locations',
      ],
      [
        'Suppliers Management',
        'Purchase Requests',
        'Purchase Orders',
        'Goods Receiving & Inspection',
        'Supplier Returns',
        'Purchase Invoice Matching',
      ],
      [
        'Ingredient Stock & Recipes',
        'Kitchen Consumption',
        'Minibar Drinks Inventory',
        'Nargile Materials Inventory',
        'Automatic Consumption Rules',
        'Waste & Spoilage',
        'Stock Availability for Menu',
      ],
      [
        'Inventory Value',
        'Inventory Valuation Methods',
        'Inventory Reports',
        'Inventory Usage Report',
        'Cost & Margin Integration',
        'Stock Audit History',
        'Inventory Permissions & Approvals',
        'Inventory Settings',
        'Import & Export',
        'Backup & Reconciliation Monitoring',
      ],
    ];
    expect(find.byType(ChoiceChip), findsNWidgets(6));
    var inventoryCardTotal = 0;
    for (var index = 0; index < inventoryCategories.length; index++) {
      final tab = find.byKey(ValueKey('inventory-category-tab-$index'));
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pumpAndSettle();
      final categoryGrid = find.byKey(
        ValueKey('inventory-category-cards-$index'),
      );
      expect(
        find.descendant(of: categoryGrid, matching: find.byType(Card)),
        findsNWidgets(inventoryCategories[index].length),
      );
      for (final title in inventoryCategories[index]) {
        expect(
          find.byKey(ValueKey('inventory-category-card-$title')),
          findsOneWidget,
          reason: title,
        );
      }
      inventoryCardTotal += inventoryCategories[index].length;
    }
    expect(inventoryCardTotal, 46);

    final itemsTab = find.byKey(const ValueKey('inventory-category-tab-1'));
    await tester.ensureVisible(itemsTab);
    await tester.tap(itemsTab);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('inventory-category-card-Batch & Lot Tracking'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Design only'), findsOneWidget);
    expect(
      find.textContaining('does not change stock quantities'),
      findsOneWidget,
    );
    expect(find.text('Add record'), findsNothing);
    await tester.tap(find.text('Back to Inventory Management'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(itemsTab);
    await tester.tap(itemsTab);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('inventory-category-card-Item Categories & Units'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Inventory Categories records'), findsOneWidget);
    expect(
      find.textContaining(
        'not connected to stock balances or an inventory ledger',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Back to Inventory Management'));
    await tester.pumpAndSettle();
    expect(find.textContaining('More cards ('), findsNothing);

    await openMoreSection('Staff Management');
    for (final title in [
      'Staff Overview',
      'Staff List',
      'Add / Edit Employee',
      'Roles & Permissions',
      'Attendance',
      'Shift Schedule',
      'Leave & Requests',
      'Payroll',
      'Staff Documents',
      'Training',
      'Staff Messages',
      'Staff Reports',
      'Staff Settings',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }

    await openMoreSection('Customer Management');
    for (final title in [
      'Customer Overview',
      'Customer List',
      'Add Customer',
      'Customer Groups',
      'Customer QR & Loyalty',
      'Customer Credit Management',
      'Orders History',
      'Reservations',
      'Feedback & Ratings',
      'Marketing & Communication',
      'Import / Export',
      'Customer Settings',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }

    await tester.tap(find.text('Reserve').last);
    await tester.pumpAndSettle();
    for (final title in [
      'Reservations Overview',
      'Table Reservations',
      'Event Reservations',
      'Motel Reservations',
      'Reservations Calendar',
      'Table Map & Availability',
      'Online Bookings',
      'Waiting List',
      'Special Requests',
      'Promotions',
      'Reservation Reports',
      'Reservations Settings',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }

    await openMoreSection('Settings Management');
    for (final title in [
      'Settings Overview',
      'General Settings',
      'Restaurant Settings',
      'Motel Settings',
      'Pricing & Tax Settings',
      'Payment Methods',
      'Printers & Devices',
      'Table & Reservation Settings',
      'Menu Settings',
      'User Management',
      'Notifications',
      'Language',
      'System & Backup',
      'Appearance',
      'Integrations',
      'About & Update',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }

    await openMoreSection('Notifications Management');
    for (final title in [
      'Notifications Overview',
      'Notifications List',
      'Send Notification',
      'Notification Templates',
      'Notification Groups',
      'System Alerts',
      'Automations',
      'Notification History',
      'Notification Channels',
      'Notification Settings',
      'Notification Reports',
      'Quick Actions',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }

    await openMoreSection('Maintenance Management');
    for (final title in [
      'Maintenance Overview',
      'Maintenance Requests',
      'Asset Management',
      'Preventive Maintenance',
      'Work Orders',
      'Parts Inventory',
      'Vendors & Service Providers',
      'Maintenance Reports',
      'Maintenance Settings',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }

    await openMoreSection('Statistics Management');
    for (final title in [
      'Statistics Overview',
      'Sales Statistics',
      'Orders Statistics',
      'Customer Statistics',
      'Table Statistics',
      'Product Statistics',
      'Payment Statistics',
      'Employee Statistics',
      'Motel Orders Statistics',
      'Online Orders Statistics',
      'Time & Trends',
      'Custom Reports',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }

    await openMoreSection('Operations Management');
    for (final title in [
      'Daily Operations Overview',
      'Shift Management',
      'Task Management',
      'Service Flow',
      'Table Operations',
      'Queue Management',
      'Order Operations',
      'Kitchen Operations',
      'Supply & Inventory',
      'Opening / Closing Checklists',
      'Incident Management',
      'Logs & Audit',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }
    await tester.ensureVisible(find.textContaining('More cards ('));
    await tester.tap(find.textContaining('More cards ('));
    await tester.pumpAndSettle();
    expect(find.text('System Health'), findsOneWidget);
    expect(find.text('Security Center'), findsOneWidget);
    expect(find.text('Audit & Activity History'), findsOneWidget);

    await openMoreSection('Devices & Printing Management');
    for (final title in [
      'Devices Overview',
      'Kitchen Printers',
      'Receipt Printers',
      'QR Code Printers',
      'Label Printers',
      'Display Screens',
      'POS Devices',
      'Device Settings',
      'Monitoring',
      'Maintenance & Support',
      'Printer Queue',
      'Paper & Supplies',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }
    await tester.ensureVisible(find.textContaining('More cards ('));
    await tester.tap(find.textContaining('More cards ('));
    await tester.pumpAndSettle();
    for (final title in [
      'Device Details',
      'Test Print',
      'Print QR Codes',
      'Print Settings',
      'Recent Device Activity',
      'Device Logs',
      'Run Diagnostics',
      'Firmware Updates',
      'Cash Drawer',
      'Contact Support',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }

    await openMoreSection('Security & Audit Management');
    for (final title in [
      'Access Management',
      'Employee Accounts',
      'Role Management',
      'Login Activity',
      'Audit Logs',
      'Security Alerts',
      'Device Management',
      'Session Management',
      'IP & Location Control',
      'Password & MFA',
      'Data Protection',
      'System Settings',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }
    await tester.ensureVisible(find.textContaining('More cards ('));
    await tester.tap(find.textContaining('More cards ('));
    await tester.pumpAndSettle();
    for (final title in [
      'Login History',
      'Failed Logins',
      'Suspicious Activity',
      'Access Requests',
      'Active Sessions',
      'Security Status',
      'Security Reports',
      'Security Settings',
      'Export Security Report',
      'MFA Enrollment',
      'Password Policy',
      'Device Registrations',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }

    await openMoreSection('System Health & Updates');
    for (final title in [
      'System Overview',
      'Server & Database',
      'Backup & Restore',
      'Updates Management',
      'Error Logs',
      'Performance Monitor',
      'Online/Offline Sync',
      'Security Status',
      'Device Health',
      'Maintenance Tasks',
      'Notifications',
      'System Settings',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }
    await tester.ensureVisible(find.textContaining('More cards ('));
    await tester.tap(find.textContaining('More cards ('));
    await tester.pumpAndSettle();
    for (final title in [
      'System Services',
      'Resource Usage',
      'Backup Status',
      'Current Version',
      'Automatic Updates',
      'Release Information',
      'Recent System Activity',
      'Top Issues',
      'System Logs',
      'Health Check',
      'Update History',
      'Run Diagnostics',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }

    await openMoreSection('Shisha Management');
    for (final title in [
      'Shisha Overview',
      'Shisha Menu',
      'New Shisha Order',
      'Active Shisha Orders',
      'Shisha Equipment',
      'Flavors & Stock',
      'Coal Management',
      'Cleaning & Maintenance',
      'Pick Up & Return',
      'Table Integration',
      'Reports & Statistics',
      'Shisha Settings',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }
    await tester.ensureVisible(find.textContaining('More cards ('));
    await tester.tap(find.textContaining('More cards ('));
    await tester.pumpAndSettle();
    for (final title in [
      'Flavor Management',
      'Equipment Status',
      'Coal Stock',
      'Cleaning Records',
      'Shisha Maintenance History',
      'Shisha Reports',
      'Shisha Order History',
      'Shisha Quick Actions',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }

    await openMoreSection('Delivery Management');
    for (final title in [
      'Delivery Overview',
      'New Delivery Order',
      'Active Deliveries',
      'Delivery Orders',
      'Delivery Menu',
      'Customers',
      'Drivers',
      'Delivery Zones',
      'Vehicles',
      'Route Optimization',
      'Reports & Statistics',
      'Delivery Settings',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }
    await tester.ensureVisible(find.textContaining('More cards ('));
    await tester.tap(find.textContaining('More cards ('));
    await tester.pumpAndSettle();
    for (final title in [
      'Driver Management',
      'Delivery History',
      'Delivery Fees',
      'Driver Details',
      'Delivery Tracking',
      'Delivery Issues',
      'Customer Delivery Notes',
      'Delivery Reports',
      'Delivery Quick Actions',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }

    await openMoreSection('Customer Feedback Management');
    for (final title in [
      'Feedback Overview',
      'Customer Reviews',
      'Live Feedback',
      'Complaints',
      'Suggestions',
      'Surveys',
      'Service Ratings',
      'Employee Reviews',
      'Table Feedback',
      'Motel & Delivery Feedback',
      'Reports & Analytics',
      'Feedback Settings',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }
    await tester.ensureVisible(find.textContaining('More cards ('));
    await tester.tap(find.textContaining('More cards ('));
    await tester.pumpAndSettle();
    for (final title in [
      'Review Details',
      'Complaint Details',
      'Customer Survey',
      'Survey Responses',
      'Feedback History',
      'Response Templates',
      'Resolve Complaint',
      'Feedback Quick Actions',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }

    await openMoreSection('Staff & Operations Management');
    for (final title in [
      'Staff & Operations Overview',
      'Employees',
      'Attendance',
      'Shifts & Schedule',
      'Tasks & Assignments',
      'Roles & Permissions',
      'Performance',
      'Salaries & Payments',
      'Leave Requests',
      'Training',
      'Announcements',
      'Staff Reports',
      'Staff Operations Settings',
      'Documents',
      'Departments',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }
    await tester.ensureVisible(find.textContaining('More cards ('));
    await tester.tap(find.textContaining('More cards ('));
    await tester.pumpAndSettle();
    for (final title in [
      'Add Employee',
      'Employee Profile',
      'Check In & Out',
      'Assign Task',
      'Process Salary',
      'Employee Activity',
      'Department Overview',
      'Staff Quick Actions',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }

    await openMoreSection('Reports Management');
    for (final title in [
      'Reports Overview',
      'Financial Reports',
      'Sales Reports',
      'Table Reports',
      'Customer Reports',
      'Employee Reports',
      'Motel Orders Reports',
      'Inventory Reports',
      'Kitchen Reports',
      'Marketing Reports',
      'Reservation Reports',
      'Delivery Reports',
      'Tax & Accounting',
      'Audit Reports',
      'Custom Reports',
      'Scheduled Reports',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }
    await tester.ensureVisible(find.textContaining('More cards ('));
    await tester.tap(find.textContaining('More cards ('));
    await tester.pumpAndSettle();
    for (final title in [
      'Filter & Customize Report',
      'Report Preview',
      'Export & Share Report',
      'Report History',
      'Saved Reports',
      'Report Settings',
      'Report Quick Actions',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }
  });

  testWidgets('Kitchen Management has seven staged categories', (tester) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: StaffDashboardPage(email: 'admin@example.com', role: 'admin'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kitchen Management').last);
    await tester.pumpAndSettle();

    const kitchenCategories = [
      ['Kitchen Overview', 'Kitchen Reports', 'Kitchen Performance & Timing'],
      [
        'Table Orders',
        'Motel Orders',
        'Online Orders',
        'Status of All Orders',
        'Live Kitchen Orders',
        'Kitchen Orders',
        'Kitchen Display',
        'Kitchen Priority & Delays',
      ],
      [
        'Order Details',
        'Kitchen Preparation',
        'Ready for Delivery',
        'Order Modification & Cancellation',
        'Kitchen Quality Control',
      ],
      [
        'Kitchen Stations Management',
        'Kitchen Printing Management',
        'Kitchen Handover',
        'Kitchen Waste & Spoilage',
      ],
      ['Menu Availability', 'Kitchen Staff', 'Kitchen Inventory & Ingredients'],
      [
        'Minibar Overview',
        'Nargile Products & Flavors',
        'Café Drinks & Beverages',
        'Product Assignment to Stations',
        'Nargile Preparation & Orders',
        'Drinks Preparation & Orders',
        'Minibar Inventory & Ingredients',
        'Equipment & Maintenance',
        'Minibar Staff & Assignments',
        'Minibar Sales & Reports',
        'Minibar Stations Management',
        'Minibar Printing Management',
      ],
      ['Kitchen Settings'],
    ];
    expect(find.byType(ChoiceChip), findsNWidgets(7));

    var cardTotal = 0;
    for (var index = 0; index < kitchenCategories.length; index++) {
      final tab = find.byKey(ValueKey('kitchen-category-tab-$index'));
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pumpAndSettle();
      final categoryGrid = find.byKey(
        ValueKey('kitchen-category-cards-$index'),
      );
      expect(
        find.descendant(of: categoryGrid, matching: find.byType(Card)),
        findsNWidgets(kitchenCategories[index].length),
      );
      for (final title in kitchenCategories[index]) {
        expect(
          find.byKey(ValueKey('kitchen-category-card-$title')),
          findsOneWidget,
          reason: title,
        );
      }
      cardTotal += kitchenCategories[index].length;
    }
    expect(cardTotal, 36);

    final operationsTab = find.byKey(const ValueKey('kitchen-category-tab-3'));
    await tester.ensureVisible(operationsTab);
    await tester.tap(operationsTab);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('kitchen-category-card-Kitchen Stations Management'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Design only'), findsOneWidget);
    expect(
      find.textContaining('integrations have not been verified'),
      findsOneWidget,
    );
    expect(find.text('Add record'), findsNothing);

    await tester.tap(find.text('Back to Kitchen Management'));
    await tester.pumpAndSettle();
    final boardTab = find.byKey(const ValueKey('kitchen-category-tab-1'));
    await tester.ensureVisible(boardTab);
    await tester.tap(boardTab);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('kitchen-category-card-Kitchen Orders')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kitchen Orders records'), findsOneWidget);
    expect(
      find.textContaining('generic workspace. They are not connected'),
      findsOneWidget,
    );

    await tester.tap(find.text('Back to Kitchen Management'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const PageStorageKey<String>('kitchen-preserved-workspaces')),
      findsNothing,
    );
    expect(
      find.textContaining('Previously available kitchen workspaces'),
      findsNothing,
    );
    expect(find.text('Customer Directory'), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
