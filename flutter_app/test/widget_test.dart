import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/main.dart';
import 'package:gelye_sherane_cafe/staff_dashboard_page.dart';

void main() {
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
    expect(find.text('Tables & Orders'), findsWidgets);
    expect(find.text('Staff Management'), findsWidgets);
    expect(find.text('A taste to look forward to'), findsNothing);
    expect(find.text('Book a table'), findsNothing);
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
      'Tables & Orders',
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
      'Tables & Orders',
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

    expect(find.text('Tables & Orders'), findsOneWidget);
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

    await tester.tap(find.text('Tables & Orders'));
    await tester.pumpAndSettle();
    expect(find.text('Table Overview'), findsOneWidget);
    expect(find.text('Visual Table Map'), findsNothing);

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
      of: find.text('Standing Cash'),
      matching: find.byType(Card),
    );

    expect(revenueCard, findsOneWidget);
    expect(cashCard, findsOneWidget);
    expect(tester.getSize(revenueCard).height, tester.getSize(cashCard).height);
    expect(tester.getSize(revenueCard).width, lessThan(200));
    expect(tester.widget<Card>(revenueCard).color, Colors.white);
    expect(tester.widget<Card>(cashCard).color, Colors.white);
    expect(tester.getSize(revenueCard).height, 118);
    expect(find.text('Today at a glance'), findsOneWidget);
    expect(find.text('Payments & Finance'), findsOneWidget);
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

      expect(find.text('Table service board'), findsOneWidget);
      expect(find.text('Table workflows'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Open Live Tables'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Live Tables'));
      await tester.pumpAndSettle();
      expect(find.text('Search Live Tables records...'), findsOneWidget);
      expect(find.text('Tracked records'), findsOneWidget);
      expect(find.text('Table service board'), findsNothing);
      await tester.ensureVisible(find.text('Back to Tables & Orders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back to Tables & Orders'));
      await tester.pumpAndSettle();

      expect(dashboardCardSize.width, lessThan(200));
      for (final title in [
        'Live Tables',
        'Add / Edit Tables',
        'Table Map',
        'Table Orders',
        'Chairs Management',
        'Table QR Codes',
        'Customer QR Ordering',
        'Table Reservations',
        'Join / Transfer Tables',
        'Table Payments',
        'Pricing Modes',
        'Table Service Requests',
        'Table Checkout & Cleaning',
        'Table History',
        'Table Settings',
        'Table Availability',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      final tableCard = find.ancestor(
        of: find.text('Live Tables'),
        matching: find.byType(Card),
      );
      expect(tester.getSize(tableCard).width, greaterThan(100));
      expect(tester.getSize(tableCard).width, lessThan(150));
      expect(
        find.text('Live table records and current status'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('More cards (20)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('More cards (20)'));
      await tester.pumpAndSettle();
      expect(find.text('Table Overview'), findsOneWidget);
      await tester.tap(find.text('More cards (20)'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Live Tables'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Live Tables'));
      await tester.pumpAndSettle();
      expect(find.text('Tracked records'), findsOneWidget);
      expect(find.text('Open records'), findsOneWidget);
      expect(find.textContaining('Supabase is not configured'), findsWidgets);
      expect(find.text('Search Live Tables records...'), findsOneWidget);
      expect(find.text('Add record'), findsOneWidget);

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
    for (final title in [
      'Motel & Online Orders Overview',
      'Select Room',
      'New Motel Order',
      'New Online Order',
      'Room Orders',
      'Motel Orders',
      'Online Orders',
      'Order Tracking',
      'Order History',
      'Meal Packages',
      'Delivery Schedule',
      'Invoices & Receipts',
      'Delivery Areas',
      'Payment Options',
      'Motel Orders Settings',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }

    await tester.tap(find.text('Menu').last);
    await tester.pumpAndSettle();
    for (final title in [
      'Menu Overview',
      'All Products',
      'Add / Edit Product',
      'Categories Management',
      'Menu Settings',
      'Kitchen View',
      'Menu Pricing',
      'Menu Preview',
      'Ingredients & Inventory',
      'Bulk Import',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    await tester.ensureVisible(find.textContaining('More cards ('));
    await tester.tap(find.textContaining('More cards ('));
    await tester.pumpAndSettle();
    for (final title in [
      'Menu Management',
      'Inventory & Stock',
      'Nargile Management',
      'Preparation Time',
      'Kitchen Devices',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }

    await openMoreSection('Kitchen Management');
    for (final title in [
      'Kitchen Overview',
      'Live Kitchen Orders',
      'Order Details',
      'Kitchen Preparation',
      'Ready for Delivery',
      'Kitchen Display',
      'Menu Availability',
      'Kitchen Staff',
      'Kitchen Reports',
      'Kitchen Settings',
      'Kitchen Orders',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    await tester.ensureVisible(find.textContaining('More cards ('));
    await tester.tap(find.textContaining('More cards ('));
    await tester.pumpAndSettle();
    for (final title in [
      'Table Orders',
      'Online Orders',
      'Motel Orders',
      'Takeaway & Delivery',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }

    await openMoreSection('Inventory Management');
    for (final title in [
      'Inventory Overview',
      'All Inventory Items',
      'Stock In',
      'Stock Out',
      'Transfer Stock',
      'Stock Adjustments',
      'Inventory Count',
      'Low Stock Items',
      'Expiry & Waste',
      'Inventory Value',
      'Search & Barcode',
      'Inventory Reports',
      'Suppliers Management',
      'Inventory Settings',
      'Sync & Backup',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }
    await tester.ensureVisible(find.textContaining('More cards ('));
    await tester.tap(find.textContaining('More cards ('));
    await tester.pumpAndSettle();
    for (final title in [
      'Add / Edit Inventory Item',
      'Inventory Categories',
      'Purchase Orders',
      'Inventory Usage Report',
      'Stock Alerts',
      'Inventory History',
      'Inventory Quick Actions',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }

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
