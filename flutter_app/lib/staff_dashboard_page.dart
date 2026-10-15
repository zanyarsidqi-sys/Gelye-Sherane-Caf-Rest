import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cafe_workspace_repository.dart';

const _navy = Color(0xFF09243A);
const _deepNavy = Color(0xFF061A2B);
const _gold = Color(0xFFD6AA57);
const _ink = Color(0xFF182B3A);
const _muted = Color(0xFF677582);

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
);
const _supabaseExpectedProjectRef = String.fromEnvironment(
  'SUPABASE_EXPECTED_PROJECT_REF',
);

String _permissionSlug(String label) => label
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');

const _featuredSectionCards = {
  1: [
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
  ],
  2: [
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
  ],
  3: [
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
  ],
  4: [
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
  ],
  5: [
    'Motel & Online Orders Overview',
    'Select Room',
    'New Motel Order',
    'New Online Order',
    'Room Orders',
    'Motel Orders',
    'Online Orders',
    'Order Details',
    'Order Tracking',
    'Order History',
    'Meal Packages',
    'Delivery Schedule',
    'Invoices & Receipts',
    'Delivery Areas',
    'Payment Options',
    'Motel Orders Settings',
  ],
  6: [
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
  ],
  7: [
    'Staff Overview',
    'Staff List',
    'Add / Edit Employee',
    'Roles & Permissions',
    'Attendance',
    'Shift Schedule',
    'Leave & Requests',
    'Payroll',
    'Performance',
    'Staff Documents',
    'Training',
    'Staff Messages',
    'Staff Reports',
    'Staff Settings',
  ],
  8: [
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
  ],
  9: [
    'Reservations Overview',
    'Table Reservations',
    'Event Reservations',
    'Motel Reservations',
    'Reservations Calendar',
    'Table Map & Availability',
    'Online Bookings',
    'Customer List',
    'Waiting List',
    'Special Requests',
    'Promotions',
    'Reservation Reports',
    'Reservations Settings',
  ],
  10: [
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
  ],
  11: [
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
  ],
  12: [
    'Maintenance Overview',
    'Maintenance Requests',
    'Asset Management',
    'Preventive Maintenance',
    'Work Orders',
    'Parts Inventory',
    'Vendors & Service Providers',
    'Maintenance Reports',
    'Maintenance Settings',
  ],
  13: [
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
  ],
  14: [
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
  ],
  15: [
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
  ],
  16: [
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
  ],
  17: [
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
  ],
  18: [
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
  ],
  19: [
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
  ],
  20: [
    'Marketing Overview',
    'Campaigns',
    'Promotions',
    'Coupons',
    'Loyalty Program',
    'Customer Segments',
    'Announcements',
    'Social Media',
    'Email & SMS',
    'Customer Feedback',
    'Advertising',
    'Reports & Statistics',
    'Marketing Settings',
    'Templates',
    'Marketing Budget',
  ],
  21: [
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
  ],
  22: [
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
  ],
  23: [
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
  ],
};

const _sectionCardDescriptions = {
  'Payment Overview': 'Payment totals and recent transaction records',
  'Receive Payment': 'Record an incoming payment',
  'Standing Cash': 'Cash balance records',
  'Pending Payments': 'Payments waiting for confirmation',
  'Collected Cash': 'Collected payment records',
  'Available Cash': 'Available register cash records',
  'Owner Cash Out': 'Owner cash withdrawal records',
  'Expenses Management': 'Business expense records',
  'Confirm Credit Payment': 'Review and confirm credit payment records',
  'Invoices & Receipts': 'View, print and resend invoice records',
  'Refunds & Voids': 'Refund and cancellation records',
  'Table Income': 'Income records associated with tables',
  'Payment History': 'Search saved payment history records',
  'Live Tables': 'Live table records and current status',
  'Add / Edit Tables': 'Create and update table records',
  'Table Map': 'View and manage table map records',
  'Table Orders': 'Orders for occupied tables',
  'Chairs Management': 'Add, remove and arrange chairs',
  'Table QR Codes': 'Generate and manage table QR records',
  'Customer QR Ordering': 'Customer ordering records via QR',
  'Table Reservations': 'Bookings and table arrivals',
  'Join / Transfer Tables': 'Table joins and transfer records',
  'Table Payments': 'Payments and balances recorded for tables',
  'Pricing Modes': 'Normal, tourism and owner pricing records',
  'Table Service Requests': 'Extra chairs, tissues and service requests',
  'Table Checkout & Cleaning': 'Checkout, payment and cleaning records',
  'Table History': 'Table order and payment activity',
  'Table Settings': 'Table areas, types, capacity and configuration',
  'Table Availability': 'Availability and occupancy records',
  'Kitchen Orders': 'All kitchen orders and status',
  'Online Orders': 'Orders from website and app',
  'Motel Orders': 'Orders from motel guests',
  'Takeaway & Delivery': 'Pickup and delivery orders',
  'Menu Overview': 'Products, categories and menu availability',
  'All Products': 'Search saved product records',
  'Add / Edit Product': 'Create or update product records',
  'Categories Management': 'Manage menu category records',
  'Menu Settings': 'Menu language, pricing and display settings',
  'Kitchen View': 'Live kitchen menu records',
  'Menu Management': 'Products, prices and availability',
  'Inventory & Stock': 'Stock quantities and alerts',
  'Nargile Management': 'Shisha orders and preparation',
  'Preparation Time': 'Kitchen speed and delayed orders',
  'Kitchen Devices': 'Printers, displays and device status',
  'Menu Pricing': 'Normal, tourism, owner and discount prices',
  'Menu Preview': 'Preview saved menu content',
  'Ingredients & Inventory': 'Ingredient quantities and stock alerts',
  'Bulk Import': 'Review imported product records',
  'Kitchen Overview': 'Kitchen order and preparation summary',
  'Live Kitchen Orders': 'Track saved kitchen order records',
  'Order Details': 'Review order items and status records',
  'Kitchen Preparation': 'Track preparation status records',
  'Ready for Delivery': 'View orders marked ready for delivery',
  'Kitchen Display': 'Kitchen display and order records',
  'Menu Availability': 'Review kitchen menu availability records',
  'Kitchen Staff': 'Kitchen staffing and shift records',
  'Kitchen Reports': 'Kitchen performance records and reports',
  'Kitchen Settings': 'Kitchen stations, devices and workflow settings',
  'Staff Overview': 'Staff totals, attendance and upcoming shift records',
  'Staff List': 'Search and manage staff directory records',
  'Add / Edit Employee': 'Create or update staff profile records',
  'Roles & Permissions': 'Role and access-profile records',
  'Shift Schedule': 'Plan staff shifts and availability',
  'Leave & Requests': 'Review leave and staff request records',
  'Payroll': 'Payroll input and salary records',
  'Performance': 'Staff performance and review records',
  'Staff Documents': 'Contracts, IDs and training documents',
  'Training': 'Staff training and certification records',
  'Staff Messages': 'Staff communication records',
  'Staff Reports': 'Attendance and employee reports',
  'Staff Settings': 'Staff workspace configuration',
  'Inventory Overview': 'Stock, usage and reorder summary',
  'All Inventory Items': 'Search saved inventory item records',
  'Add / Edit Inventory Item': 'Create or update inventory records',
  'Inventory Categories': 'Group ingredients and supply records',
  'Stock In': 'Record received inventory',
  'Stock Out': 'Record usage, waste or stock transfers',
  'Low Stock Items': 'Review items below their reorder level',
  'Purchase Orders': 'Track supplier purchase records',
  'Suppliers Management': 'Manage supplier contact records',
  'Inventory Reports': 'Review inventory value and usage reports',
  'Inventory Settings': 'Configure units, alerts and inventory rules',
  'Inventory Usage Report': 'Review saved stock usage records',
  'Inventory Count': 'Record inventory verification counts',
  'Transfer Stock': 'Track inventory transfers',
  'Stock Adjustments': 'Record stock corrections and count adjustments',
  'Expiry & Waste': 'Track product expiry, spoilage and waste records',
  'Inventory Value': 'Review saved inventory cost and valuation records',
  'Search & Barcode': 'Search saved inventory and barcode records',
  'Sync & Backup': 'Track inventory synchronization and backup records',
  'Inventory Quick Actions': 'Quick access to common stock workflows',
  'Stock Alerts': 'Review saved low-stock alerts',
  'Inventory History': 'Search stock movement records',
  'Motel & Online Orders Overview':
      'Room, online, pickup and delivery order records',
  'Select Room': 'Review room availability records',
  'New Motel Order': 'Create a motel order record',
  'New Online Order': 'Create an online order record',
  'Room Orders': 'Orders associated with rooms',
  'Order Tracking': 'Track saved delivery status records',
  'Order History': 'Search previous order records',
  'Meal Packages': 'Manage guest meal package records',
  'Delivery Schedule': 'Plan delivery time and route records',
  'Delivery Areas': 'Manage delivery zone records',
  'Payment Options': 'Configure available payment method records',
  'Motel Orders Settings': 'Configure motel ordering preferences',
  'Customer Overview': 'Customer totals, loyalty and credit summary',
  'Customer List': 'Search saved customer profile records',
  'Add Customer': 'Create a customer profile record',
  'Customer Groups': 'Manage family, company and tourism groups',
  'Customer QR & Loyalty': 'Customer QR codes, points and reward records',
  'Customer Credit Management': 'Review credit limits and balance records',
  'Orders History': 'Search customer order history records',
  'Feedback & Ratings': 'Review saved customer feedback',
  'Marketing & Communication': 'Manage campaign and communication records',
  'Import / Export': 'Review customer import and export records',
  'Customer Settings': 'Configure customer workspace preferences',
  'Reservations Overview': 'Reservation counts, calendar and pending requests',
  'Event Reservations': 'Manage event booking records',
  'Motel Reservations': 'Manage motel room reservation records',
  'Reservations Calendar': 'View reservation calendar records',
  'Table Map & Availability': 'Review table availability for reservations',
  'Online Bookings': 'Manage online reservation requests',
  'Waiting List': 'Manage guest waiting list records',
  'Special Requests': 'Track guest requirements and reservation notes',
  'Promotions': 'Manage reservation and marketing promotion records',
  'Reservation Reports': 'Review reservation and booking reports',
  'Reservations Settings': 'Configure reservation rules and preferences',
  'Settings Overview': 'Cafe configuration, devices, security and preferences',
  'General Settings': 'Configure cafe details, hours, timezone and currency',
  'Restaurant Settings': 'Manage restaurant identity and service preferences',
  'Motel Settings': 'Configure motel rooms and guest ordering preferences',
  'Pricing & Tax Settings': 'Manage pricing modes, taxes and service charges',
  'Payment Methods': 'Configure accepted payment method records',
  'Printers & Devices': 'Manage printers and connected devices',
  'Table & Reservation Settings': 'Configure table layout and booking rules',
  'User Management': 'Manage staff roles and access permissions',
  'Notifications': 'Configure notification channels and preferences',
  'Language': 'Manage language and translation preferences',
  'System & Backup': 'Manage backup, sync and system preferences',
  'Appearance': 'Configure themes and screen display options',
  'Integrations': 'Manage external service connection settings',
  'About & Update': 'View app version and update information',
  'Notifications Overview':
      'Unread, action-needed and system notification summary',
  'Notifications List': 'Review and filter saved notification records',
  'Send Notification': 'Create a staff or customer notification record',
  'Notification Templates': 'Manage reusable notification message templates',
  'Notification Groups': 'Organize notification recipients into groups',
  'System Alerts': 'Review saved system warning and alert records',
  'Automations': 'Manage notification automation rules',
  'Notification History': 'Search sent and received notification records',
  'Notification Channels': 'Configure in-app, email, SMS and push channels',
  'Notification Settings': 'Configure notification preferences and quiet hours',
  'Notification Reports': 'Review notification delivery and activity reports',
  'Quick Actions': 'Quick access to common notification tasks',
  'Maintenance Overview': 'Assets, active jobs and maintenance status summary',
  'Maintenance Requests': 'Create and manage maintenance request records',
  'Asset Management': 'Manage equipment and asset records',
  'Preventive Maintenance': 'Schedule recurring maintenance records',
  'Work Orders': 'Track maintenance work, assignments and progress',
  'Parts Inventory': 'Manage spare parts and maintenance supplies',
  'Vendors & Service Providers': 'Manage maintenance vendor records',
  'Maintenance Reports': 'Review maintenance costs and performance records',
  'Maintenance Settings': 'Configure maintenance priorities and preferences',
  'Daily Operations Overview':
      'Live status, tasks and service activity records',
  'Shift Management': 'Manage shifts and staff on-duty records',
  'Task Management': 'Create and track daily operations tasks',
  'Service Flow': 'Review dine-in, takeaway and delivery flow records',
  'Table Operations': 'Monitor table service and occupancy records',
  'Queue Management': 'Manage guest and order queue records',
  'Order Operations': 'Track order handling and delivery records',
  'Kitchen Operations': 'Monitor preparation and kitchen status records',
  'Supply & Inventory': 'Review supply usage and inventory records',
  'Opening / Closing Checklists': 'Track opening and closing checklist records',
  'Incident Management': 'Record incidents and operational follow-up',
  'Logs & Audit': 'Review system and staff activity audit records',
  'Statistics Overview': 'Business performance summary across saved records',
  'Sales Statistics': 'Review recorded revenue and sales trends',
  'Orders Statistics': 'Review saved order totals and status',
  'Customer Statistics': 'Review saved customer activity records',
  'Table Statistics': 'Review table occupancy and service records',
  'Product Statistics': 'Review recorded product performance',
  'Payment Statistics': 'Review saved payment method records',
  'Employee Statistics': 'Review staff attendance and performance records',
  'Motel Orders Statistics': 'Review saved room order records',
  'Online Orders Statistics': 'Review saved online order records',
  'Time & Trends': 'Compare saved business records across time periods',
  'Custom Reports': 'Build reports from saved workspace records',
  'Devices Overview': 'Device inventory and saved connection status records',
  'Kitchen Printers': 'Manage kitchen printer and routing records',
  'Receipt Printers': 'Manage customer receipt printer records',
  'QR Code Printers': 'Manage table QR printing records',
  'Label Printers': 'Manage product and label printer records',
  'Display Screens': 'Manage kitchen and service display records',
  'POS Devices': 'Manage cashier terminal and connected device records',
  'Device Settings': 'Configure saved device and printer preferences',
  'Monitoring': 'Review device status and diagnostic records',
  'Maintenance & Support': 'Track device service and support records',
  'Device Details': 'Review a device profile, settings and activity records',
  'Test Print': 'Record printer test and configuration checks',
  'Print QR Codes': 'Prepare table QR code print records',
  'Print Settings': 'Configure saved layouts, labels and print preferences',
  'Printer Queue': 'Track queued and completed print job records',
  'Paper & Supplies': 'Track printer paper and supply inventory records',
  'Recent Device Activity': 'Review recent printer and device activity records',
  'Device Logs': 'Search saved device event and error records',
  'Run Diagnostics': 'Record device, application and service diagnostic checks',
  'Firmware Updates': 'Track planned device firmware update records',
  'Cash Drawer': 'Track POS cash drawer configuration and test records',
  'Contact Support': 'Record device support requests and follow-up',
  'Access Management': 'Review access grants and permission records',
  'Employee Accounts': 'Review staff account administration records',
  'Role Management': 'Manage saved role and access profile records',
  'Login Activity': 'Review saved sign-in activity records',
  'Audit Logs': 'Review workspace change and audit records',
  'Security Alerts': 'Track security alert and follow-up records',
  'Device Management': 'Manage registered device and approval records',
  'Session Management': 'Review session activity and access records',
  'IP & Location Control': 'Track saved network and location policy records',
  'Password & MFA': 'Manage password policy and MFA administration records',
  'Data Protection': 'Review backup, retention and protection records',
  'System Settings': 'Configure saved security workspace preferences',
  'Login History': 'Search saved login history records',
  'Failed Logins': 'Review recorded failed sign-in events',
  'Suspicious Activity': 'Track suspicious activity and review records',
  'Access Requests': 'Review pending access request records',
  'Active Sessions': 'Review saved active session records',
  'Security Reports': 'Review security and audit report records',
  'Security Settings': 'Configure saved security preferences',
  'Export Security Report': 'Track security report export requests',
  'MFA Enrollment': 'Track staff MFA enrollment follow-up records',
  'Password Policy': 'Record password policy configuration',
  'Device Registrations': 'Review device registration records',
  'System Overview': 'Review manually entered system status records',
  'Server & Database': 'Track server and database check records',
  'Updates Management': 'Track software update and release records',
  'Error Logs': 'Search saved system error and issue records',
  'Performance Monitor': 'Review recorded performance measurements',
  'Online/Offline Sync': 'Track synchronization and connectivity records',
  'Security Status': 'Review manually recorded security status checks',
  'Device Health': 'Track device condition and health check records',
  'Maintenance Tasks': 'Manage system maintenance task records',
  'System Services': 'Track service status and availability check records',
  'Resource Usage': 'Record CPU, memory, storage and network measurements',
  'Backup Status': 'Review saved backup completion and schedule records',
  'Current Version': 'Track installed and available version records',
  'Automatic Updates': 'Manage saved automatic update preference records',
  'Release Information': 'Review software release and change records',
  'Recent System Activity': 'Review saved system activity records',
  'Top Issues': 'Track reported system issues and resolution status',
  'System Logs': 'Search saved system event records',
  'Health Check': 'Record service and application health checks',
  'Update History': 'Review saved update history records',
  'Shisha Overview': 'Review saved shisha order and equipment records',
  'Shisha Menu': 'Manage shisha flavor, price and availability records',
  'New Shisha Order': 'Create a shisha order record for a table',
  'Active Shisha Orders': 'Track shisha order preparation and service records',
  'Shisha Equipment': 'Manage saved shisha pipe and equipment records',
  'Flavors & Stock': 'Track shisha flavor inventory and stock records',
  'Coal Management': 'Track coal types, quantities and usage records',
  'Cleaning & Maintenance':
      'Record shisha equipment cleaning and service tasks',
  'Pick Up & Return': 'Track equipment pickup and return records',
  'Table Integration': 'Associate shisha service records with table records',
  'Shisha Settings': 'Configure saved shisha service preferences',
  'Flavor Management': 'Create and update shisha flavor records',
  'Equipment Status': 'Review saved shisha equipment status records',
  'Coal Stock': 'Review saved coal inventory records',
  'Cleaning Records': 'Search saved shisha equipment cleaning records',
  'Shisha Maintenance History':
      'Search saved shisha equipment maintenance records',
  'Shisha Reports': 'Review saved shisha sales and service records',
  'Shisha Order History': 'Search saved shisha order history records',
  'Shisha Quick Actions': 'Quick access to common shisha service records',
  'Delivery Overview': 'Review saved delivery order and driver records',
  'New Delivery Order': 'Create a delivery order record',
  'Active Deliveries': 'Track saved delivery and status records',
  'Delivery Orders': 'Search saved delivery order records',
  'Delivery Menu': 'Manage menu items available for delivery',
  'Drivers': 'Manage delivery driver profile records',
  'Delivery Zones': 'Manage saved delivery area and zone records',
  'Vehicles': 'Manage delivery vehicle and assignment records',
  'Route Optimization': 'Track planned delivery route records',
  'Delivery Settings': 'Configure saved delivery service preferences',
  'Driver Management': 'Manage saved driver and assignment records',
  'Delivery History': 'Search completed and cancelled delivery records',
  'Delivery Fees': 'Track delivery fee and pricing records',
  'Driver Details': 'Review saved driver contact and performance records',
  'Delivery Tracking': 'Review saved delivery progress records',
  'Delivery Issues': 'Track delivery delay and customer issue records',
  'Customer Delivery Notes': 'Save delivery instructions and customer notes',
  'Delivery Reports': 'Review saved delivery order and driver records',
  'Delivery Quick Actions': 'Quick access to common delivery records',
  'Marketing Overview': 'Review saved campaign and customer activity records',
  'Campaigns': 'Create and track marketing campaign records',
  'Coupons': 'Create and track coupon and QR promotion records',
  'Loyalty Program': 'Manage loyalty points and reward records',
  'Customer Segments': 'Group customer records for campaign targeting',
  'Announcements': 'Prepare and track announcement records',
  'Social Media': 'Track social media content and post records',
  'Email & SMS': 'Prepare email and SMS campaign records',
  'Customer Feedback': 'Review saved customer feedback and rating records',
  'Advertising': 'Track advertising plans and channel records',
  'Marketing Settings': 'Configure saved marketing preferences',
  'Templates': 'Manage reusable campaign message and design records',
  'Marketing Budget': 'Track planned and recorded marketing budget entries',
  'Campaign History': 'Review saved campaign activity records',
  'Campaign Calendar': 'Plan campaign date and schedule records',
  'Campaign Audiences': 'Review customer groups selected for campaigns',
  'Campaign Performance': 'Review saved campaign performance records',
  'Marketing Channels': 'Manage campaign channel and distribution records',
  'Marketing Reports': 'Review saved marketing activity records',
  'Create Campaign': 'Start a marketing campaign record',
  'Promotion Preview': 'Review saved promotion content before publishing',
  'Reports Overview': 'Review available report and saved report records',
  'Financial Reports': 'Review saved financial summary report records',
  'Sales Reports': 'Review saved sales report definitions and records',
  'Table Reports': 'Review saved table usage and service report records',
  'Customer Reports': 'Review customer activity report records',
  'Employee Reports':
      'Review employee attendance and performance report records',
  'Motel Orders Reports': 'Review saved motel order report records',
  'Tax & Accounting': 'Track tax, accounting and reconciliation report records',
  'Audit Reports': 'Review saved audit and activity report records',
  'Scheduled Reports': 'Manage scheduled report request records',
  'Filter & Customize Report': 'Save report filters and customization records',
  'Report Preview': 'Review saved report preview records',
  'Export & Share Report': 'Track report export and sharing requests',
  'Report History': 'Search saved report generation history',
  'Saved Reports': 'Manage saved report definitions',
  'Report Settings': 'Configure saved reporting preferences',
  'Report Quick Actions': 'Quick access to common report records',
  'Feedback Overview': 'Review saved ratings, comments and complaint records',
  'Customer Reviews': 'Review saved customer rating and comment records',
  'Live Feedback': 'Review recently saved customer feedback records',
  'Complaints': 'Track customer complaints and resolution records',
  'Suggestions': 'Review customer ideas and improvement records',
  'Surveys': 'Manage customer survey and questionnaire records',
  'Service Ratings': 'Review saved food, staff and service rating records',
  'Employee Reviews': 'Review staff feedback and recognition records',
  'Table Feedback': 'Review guest feedback linked to table records',
  'Motel & Delivery Feedback':
      'Review motel guest and delivery feedback records',
  'Feedback Settings': 'Configure saved feedback workspace preferences',
  'Review Details': 'Review a saved customer rating and response record',
  'Complaint Details':
      'Track complaint assignment, notes and resolution records',
  'Customer Survey': 'Manage customer survey question and response records',
  'Survey Responses': 'Review saved survey response records',
  'Feedback History': 'Search saved feedback and response history',
  'Response Templates': 'Manage reusable customer response records',
  'Resolve Complaint': 'Record a complaint resolution and follow-up',
  'Feedback Quick Actions': 'Quick access to common feedback records',
  'Staff & Operations Overview':
      'Review saved employee, attendance and shift records',
  'Employees': 'Search saved employee directory records',
  'Shifts & Schedule': 'Plan staff shifts and schedule records',
  'Tasks & Assignments': 'Create and track staff task assignments',
  'Salaries & Payments': 'Track payroll input and salary payment records',
  'Leave Requests': 'Review employee leave and absence request records',
  'Staff Operations Settings': 'Configure saved staff operations preferences',
  'Documents': 'Track employee contract, identity and training documents',
  'Departments': 'Manage staff department and team records',
  'Add Employee': 'Create a staff directory record',
  'Employee Profile': 'Review saved employee profile and work information',
  'Check In & Out': 'Record employee attendance check-in and check-out',
  'Assign Task': 'Assign a saved task to a staff member',
  'Process Salary': 'Record payroll processing notes and salary status',
  'Employee Activity': 'Review saved staff activity records',
  'Department Overview': 'Review staff department and team records',
  'Staff Quick Actions': 'Quick access to common staff records',
  'Reports & Analytics': 'Sales, orders and performance reports',
  'System Health': 'Service status and system alerts',
  'Security Center': 'MFA and security monitoring',
  'Permissions & Roles': 'Employee roles and access control',
  'Audit & Activity History': 'Track staff system activity',
  'Backup & Restore': 'Track saved backup and recovery records',
  'Offline & Sync': 'Pending synchronization and errors',
  'System Updates': 'App version and release management',
  'Settings & Configuration': 'Restaurant settings and preferences',
  'Devices & Printers': 'Manage connected devices',
};

String _staffFunctionFailure(FunctionException exception) {
  final details = exception.details;
  final serverMessage = details is Map ? details['error'] : null;
  if (serverMessage is String && serverMessage.isNotEmpty) {
    return serverMessage;
  }
  if (exception.status == 0) {
    return 'No response was received from the staff management service. Check the '
        'internet connection and confirm that this Edge Function is deployed '
        'to the selected Supabase project.';
  }
  if (exception.status == 404) {
    return 'The staff management Edge Function is not deployed to this '
        'Supabase project.';
  }
  return 'The staff management request failed (HTTP ${exception.status}).';
}

bool get _hasValidSupabaseConfiguration {
  final uri = Uri.tryParse(_supabaseUrl);
  return uri != null &&
      RegExp(r'^[a-z0-9]{20}$').hasMatch(_supabaseExpectedProjectRef) &&
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      uri.port == 443 &&
      uri.host == '$_supabaseExpectedProjectRef.supabase.co' &&
      (uri.path.isEmpty || uri.path == '/') &&
      uri.query.isEmpty &&
      uri.fragment.isEmpty &&
      _supabasePublishableKey.isNotEmpty;
}

class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({
    required this.email,
    required this.role,
    this.grantedPermissions = const {},
    this.permissionsLoadError,
    super.key,
  });

  final String email;
  final String role;
  final Set<String> grantedPermissions;
  final String? permissionsLoadError;

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  static const _sections = [
    (
      key: 'dashboard',
      icon: Icons.dashboard_outlined,
      title: 'Dashboard',
      description: 'Live overview of your restaurant operations.',
    ),
    (
      key: 'tables_orders',
      icon: Icons.table_restaurant_outlined,
      title: 'Tables & Orders',
      description: 'Table occupancy, orders, reservations and QR actions.',
    ),
    (
      key: 'payment_management',
      icon: Icons.payments_outlined,
      title: 'Payment Management',
      description: 'Payments, pending balances, refunds and reconciliation.',
    ),
    (
      key: 'kitchen_management',
      icon: Icons.soup_kitchen_outlined,
      title: 'Menu Management',
      description:
          'Products, categories, pricing, ingredients and availability.',
    ),
    (
      key: 'customer_management',
      icon: Icons.people_outline,
      title: 'Kitchen Management',
      description: 'Live kitchen orders, preparation, delivery and staff.',
    ),
    (
      key: 'motel_online_orders',
      icon: Icons.hotel_outlined,
      title: 'Motel & Online Orders',
      description: 'Room orders, online orders, packages and deliveries.',
    ),
    (
      key: 'inventory_management',
      icon: Icons.inventory_2_outlined,
      title: 'Inventory Management',
      description: 'Ingredients, stock movements, suppliers and purchasing.',
    ),
    (
      key: 'employee_management',
      icon: Icons.badge_outlined,
      title: 'Staff Management',
      description: 'Staff accounts, departments, permissions and attendance.',
    ),
    (
      key: 'customer_directory_management',
      icon: Icons.people_outline,
      title: 'Customer Management',
      description:
          'Customer profiles, loyalty, groups, credit and communication.',
    ),
    (
      key: 'reservations_management',
      icon: Icons.calendar_month_outlined,
      title: 'Reservations Management',
      description:
          'Table, event and motel reservations, calendars and requests.',
    ),
    (
      key: 'settings_management',
      icon: Icons.settings_outlined,
      title: 'Settings Management',
      description: 'Cafe configuration, preferences and system settings.',
    ),
    (
      key: 'notifications_management',
      icon: Icons.notifications_none_outlined,
      title: 'Notifications Management',
      description: 'Send, receive and manage all system notifications.',
    ),
    (
      key: 'maintenance_management',
      icon: Icons.build_outlined,
      title: 'Maintenance Management',
      description: 'Equipment, maintenance alerts and repair history.',
    ),
    (
      key: 'operations_management',
      icon: Icons.tune_outlined,
      title: 'Operations Management',
      description: 'System health, audit history and operational controls.',
    ),
    (
      key: 'statistics_management',
      icon: Icons.query_stats_outlined,
      title: 'Statistics Management',
      description: 'Revenue, product performance and service metrics.',
    ),
    (
      key: 'devices_printing_management',
      icon: Icons.print_outlined,
      title: 'Devices & Printing Management',
      description: 'Printers, QR codes, display screens, POS devices and print settings.',
    ),
    (
      key: 'security_audit_management',
      icon: Icons.security_outlined,
      title: 'Security & Audit Management',
      description: 'Access, accounts, audit activity, alerts and security policy records.',
    ),
    (
      key: 'system_health_updates_management',
      icon: Icons.monitor_heart_outlined,
      title: 'System Health & Updates',
      description: 'System status, backups, releases, performance and maintenance records.',
    ),
    (
      key: 'shisha_management',
      icon: Icons.smoking_rooms_outlined,
      title: 'Shisha Management',
      description: 'Shisha orders, flavors, equipment, coal, cleaning and table service.',
    ),
    (
      key: 'delivery_management',
      icon: Icons.delivery_dining_outlined,
      title: 'Delivery Management',
      description: 'Delivery orders, drivers, zones, vehicles and route planning records.',
    ),
    (
      key: 'marketing_management',
      icon: Icons.campaign_outlined,
      title: 'Marketing Management',
      description: 'Campaigns, promotions, customer segments, loyalty and marketing reports.',
    ),
    (
      key: 'customer_feedback_management',
      icon: Icons.reviews_outlined,
      title: 'Customer Feedback Management',
      description: 'Customer reviews, complaints, suggestions, surveys and service ratings.',
    ),
    (
      key: 'staff_operations_management',
      icon: Icons.groups_2_outlined,
      title: 'Staff & Operations Management',
      description: 'Employees, attendance, schedules, assignments, payroll and departments.',
    ),
    (
      key: 'reports_management',
      icon: Icons.assessment_outlined,
      title: 'Reports Management',
      description: 'Business, financial, operational, audit and scheduled report records.',
    ),
  ];

  static const _subcards = [
    [
      'Today Revenue',
      'Standing Cash',
      'Pending Payment',
      'Invoices',
      'Discounts',
      'Credit Accounts',
      'Tables Occupied',
      'Table Map',
      'Cleaning Needed',
      'Guests Today',
      'Today Orders',
      'Kitchen Orders',
      'Menu',
      'Low Stock',
      'Nargile Orders',
      'Table Occupancy',
      'Kitchen Queue',
      'Motel Orders',
      'Online Orders',
      'Tourism Customers',
      'Reservations',
      'Customer Requests',
      'Takeaway & Delivery',
      'Attendance',
      'Customers',
      'Employees',
      'Tasks',
      'Events',
      'Cash Reconciliation',
      'Product Performance',
      'Service Speed',
      'Feedback',
      'Maintenance',
      'Reports',
      'Security',
      'Backup',
      'Offline Mode',
      'System Health',
      'Audit & Activity',
      'Personalization',
    ],
    [
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
      'Current Customers',
      'Active Tables',
      "Today's Customers",
      "Today's Tables",
      'Table Status',
      'Waiting List',
      'Table Cleaning',
      'Table Requests',
      'Table Performance',
      'Table Overview',
      'Visual Table Map',
      'Add/Edit Tables & Chairs',
      'QR Generate/Print/Revoke',
      'Customer QR Screen',
      'Join/Transfer',
      'Split Bills',
      'Pay for Others',
      'Cleaning',
      'Extra Chairs',
      'Reservations',
    ],
    [
      'Today Revenue',
      'Revenue',
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
    ],
    [
      'Menu Overview',
      'All Products',
      'Add / Edit Product',
      'Categories Management',
      'Menu Settings',
      'Kitchen View',
      'Menu Management',
      'Inventory & Stock',
      'Nargile Management',
      'Preparation Time',
      'Kitchen Devices',
      'Menu Pricing',
      'Menu Preview',
      'Ingredients & Inventory',
      'Bulk Import',
      'Kitchen Queue',
      'Stations',
      'Menu Categories',
      'Add/Edit Products',
      'Modifiers',
      'Price Rules',
      'Available/Out of Stock',
      'Inventory',
      'Purchasing',
      'Suppliers',
      'Nargile',
      'Recipes',
      'Printers',
      'Revisions',
    ],
    [
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
      'Table Orders',
      'Online Orders',
      'Motel Orders',
      'Takeaway & Delivery',
      'Customer Requests',
      'Customer Directory',
      'Takeaway',
      'Delivery',
      'QR Customer Ordering',
      'Credit Profile',
      'Requests',
      'Feedback',
      'Meal Packages',
      'Delivery Schedule',
      'History',
      'Events',
    ],
    [
      'Motel & Online Orders Overview',
      'Select Room',
      'New Motel Order',
      'New Online Order',
      'Room Orders',
      'Motel Orders',
      'Online Orders',
      'Order Details',
      'Order Tracking',
      'Order History',
      'Meal Packages',
      'Delivery Schedule',
      'Invoices & Receipts',
      'Delivery Areas',
      'Payment Options',
      'Motel Orders Settings',
    ],
    [
      'Inventory Overview',
      'All Inventory Items',
      'Add / Edit Inventory Item',
      'Inventory Categories',
      'Stock In',
      'Stock Out',
      'Transfer Stock',
      'Stock Adjustments',
      'Inventory Count',
      'Low Stock Items',
      'Expiry & Waste',
      'Inventory Value',
      'Search & Barcode',
      'Purchase Orders',
      'Suppliers Management',
      'Inventory Reports',
      'Inventory Settings',
      'Sync & Backup',
      'Inventory Usage Report',
      'Stock Alerts',
      'Inventory History',
      'Inventory Quick Actions',
    ],
    [
      'Staff Overview',
      'Staff List',
      'Add / Edit Employee',
      'Roles & Permissions',
      'Attendance',
      'Shift Schedule',
      'Leave & Requests',
      'Payroll',
      'Performance',
      'Staff Documents',
      'Training',
      'Staff Messages',
      'Staff Reports',
      'Staff Settings',
      'Permissions & Roles',
      'Staff Directory',
      'Invite/Create Staff',
      'Roles',
      'Permissions',
      'Shifts',
      'Tasks',
      'MFA',
      'Account Status',
      'Activity',
      'Payroll Inputs',
    ],
    [
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
    ],
    [
      'Reservations Overview',
      'Table Reservations',
      'Event Reservations',
      'Motel Reservations',
      'Reservations Calendar',
      'Table Map & Availability',
      'Online Bookings',
      'Customer List',
      'Waiting List',
      'Special Requests',
      'Promotions',
      'Reservation Reports',
      'Reservations Settings',
    ],
    [
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
      'Settings & Configuration',
      'Backup & Restore',
      'Offline & Sync',
      'System Updates',
      'Devices & Printers',
      'General',
      'Device Layout',
      'Appearance/Dark Mode',
      'Dictionary & Languages',
      'Invoice Designer',
      'Website',
      'Offline Sync',
      'Security',
      'Publishing',
      'Health',
      'Test/Real Mode',
    ],
    [
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
      'Action Center',
      'Orders',
      'Kitchen',
      'Payments',
      'Requests',
      'Tasks',
      'Reservations',
      'Security',
      'Printer/Offline',
      'History',
      'Acknowledgments',
    ],
    [
      'Maintenance Overview',
      'Maintenance Requests',
      'Asset Management',
      'Preventive Maintenance',
      'Work Orders',
      'Parts Inventory',
      'Vendors & Service Providers',
      'Maintenance Reports',
      'Maintenance Settings',
      'Faults',
      'Equipment',
      'Cleaning',
      'Preventive Schedule',
      'Assignments',
      'Priorities',
      'Repair Cost',
      'Evidence',
      'Completion',
      'History',
    ],
    [
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
      'System Health',
      'Security Center',
      'Audit & Activity History',
      'Opening Checklist',
      'Shift Handover',
      'Closing Checklist',
      'Department Status',
      'Work Assignments',
      'Approvals',
      'Incidents',
      'Outstanding Tasks',
      'Operations History',
      'Events',
    ],
    [
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
      'Reports & Analytics',
      'Revenue Reports',
      'Cost & Profit',
      'Sales Analytics',
      'Product Performance',
      'Occupancy',
      'Tourism',
      'Employee KPIs',
      'Kitchen Speed',
      'Feedback',
      'Outstanding Balances',
      'Exports',
      'Comparisons',
    ],
    [
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
      'Device Details',
      'Test Print',
      'Print QR Codes',
      'Print Settings',
      'Printer Queue',
      'Paper & Supplies',
      'Recent Device Activity',
      'Device Logs',
      'Run Diagnostics',
      'Firmware Updates',
      'Cash Drawer',
      'Contact Support',
    ],
    [
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
    ],
    [
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
    ],
    [
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
      'Flavor Management',
      'Equipment Status',
      'Coal Stock',
      'Cleaning Records',
      'Shisha Maintenance History',
      'Shisha Reports',
      'Shisha Order History',
      'Shisha Quick Actions',
    ],
    [
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
      'Driver Management',
      'Delivery History',
      'Delivery Fees',
      'Driver Details',
      'Delivery Tracking',
      'Delivery Issues',
      'Customer Delivery Notes',
      'Delivery Reports',
      'Delivery Quick Actions',
    ],
    [
      'Marketing Overview',
      'Campaigns',
      'Promotions',
      'Coupons',
      'Loyalty Program',
      'Customer Segments',
      'Announcements',
      'Social Media',
      'Email & SMS',
      'Customer Feedback',
      'Advertising',
      'Reports & Statistics',
      'Marketing Settings',
      'Templates',
      'Marketing Budget',
      'Campaign History',
      'Campaign Calendar',
      'Campaign Audiences',
      'Campaign Performance',
      'Marketing Channels',
      'Marketing Reports',
      'Create Campaign',
      'Promotion Preview',
    ],
    [
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
      'Review Details',
      'Complaint Details',
      'Customer Survey',
      'Survey Responses',
      'Feedback History',
      'Response Templates',
      'Resolve Complaint',
      'Feedback Quick Actions',
    ],
    [
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
      'Add Employee',
      'Employee Profile',
      'Check In & Out',
      'Assign Task',
      'Process Salary',
      'Employee Activity',
      'Department Overview',
      'Staff Quick Actions',
    ],
    [
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
      'Filter & Customize Report',
      'Report Preview',
      'Export & Share Report',
      'Report History',
      'Saved Reports',
      'Report Settings',
      'Report Quick Actions',
    ],
  ];

  bool _hasSectionAccess(int sectionIndex) {
    if (widget.role == 'admin' || sectionIndex == 0) return true;
    return _visibleSubcards(sectionIndex).isNotEmpty;
  }

  List<int> get _visibleSectionIndices => [
    for (var index = 0; index < _sections.length; index++)
      if (_hasSectionAccess(index)) index,
  ];

  List<String> _visibleSubcards(int sectionIndex) {
    final sectionKey = _sections[sectionIndex].key;
    if (widget.role == 'admin' ||
        widget.grantedPermissions.contains('$sectionKey:*')) {
      return _subcards[sectionIndex];
    }
    return _subcards[sectionIndex]
        .where(
          (subcard) => widget.grantedPermissions.contains(
            '$sectionKey:${_permissionSlug(subcard)}',
          ),
        )
        .toList(growable: false);
  }

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  int _selectedIndex = 0;
  String? _selectedSubcard;
  bool _isSigningOut = false;
  String? _signOutError;
  CafeWorkspaceRepository? _workspaceRepository;
  RealtimeChannel? _workspaceChannel;
  List<CafeWorkspaceRecord> _workspaceRecords = const [];
  bool _isLoadingRecords = true;
  bool _isFetchingRecords = false;
  String? _workspaceError;
  List<Map<String, dynamic>> _staffDepartments = const [];
  List<Map<String, dynamic>> _staffPermissionProfiles = const [];
  List<Map<String, dynamic>> _staffMembers = const [];
  bool _isLoadingEmployeeData = false;
  String? _employeeManagementError;
  DateTime _selectedReportDate = DateTime.now();
  String _selectedDateRange = 'Today';
  String _financeStatusFilter = 'All';
  String _financeSearch = '';
  String _tableStatusFilter = 'All';
  String _tableSearch = '';
  String _workspaceStatusFilter = 'All';
  String _workspaceSearch = '';

  @override
  void initState() {
    super.initState();
    unawaited(_connectWorkspace());
    if (widget.role == 'admin') {
      unawaited(_loadEmployeeManagement());
    }
  }

  @override
  void dispose() {
    final channel = _workspaceChannel;
    final repository = _workspaceRepository;
    if (channel != null && repository != null) {
      unawaited(repository.removeChannel(channel));
    }
    super.dispose();
  }

  Future<void> _connectWorkspace() async {
    if (!_hasValidSupabaseConfiguration) {
      if (!mounted) return;
      setState(() {
        _isLoadingRecords = false;
        _workspaceError =
            'Supabase is not configured with a valid project URL and key.';
      });
      return;
    }
    try {
      final repository = CafeWorkspaceRepository(Supabase.instance.client);
      _workspaceRepository = repository;
      _workspaceChannel = repository.subscribe(() {
        unawaited(_loadWorkspaceRecords());
      });
      await _loadWorkspaceRecords();
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        _isLoadingRecords = false;
        _workspaceError = 'Supabase is not configured for this app: $exception';
      });
    }
  }

  Future<void> _loadWorkspaceRecords() async {
    final repository = _workspaceRepository;
    if (repository == null || _isFetchingRecords) return;
    _isFetchingRecords = true;
    if (mounted) {
      setState(() {
        _isLoadingRecords = true;
        _workspaceError = null;
      });
    }
    try {
      final records = await repository.fetchRecords();
      if (!mounted) return;
      setState(() {
        _workspaceRecords = records;
        _workspaceError = null;
      });
    } on PostgrestException catch (exception) {
      if (!mounted) return;
      setState(() {
        _workspaceError =
            'Live records could not be loaded (${exception.code ?? 'unknown'}): '
            '${exception.message}';
      });
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        _workspaceError = 'Live records could not be loaded: $exception';
      });
    } finally {
      _isFetchingRecords = false;
      if (mounted) setState(() => _isLoadingRecords = false);
    }
  }

  List<CafeWorkspaceRecord> _recordsFor(String sectionKey, String subcardKey) =>
      _workspaceRecords
          .where(
            (record) =>
                record.sectionKey == sectionKey &&
                record.subcardKey == subcardKey,
          )
          .toList(growable: false);

  List<CafeWorkspaceRecord> _recordsInSelectedRange(
    Iterable<CafeWorkspaceRecord> records,
  ) {
    final selectedDay = DateTime(
      _selectedReportDate.year,
      _selectedReportDate.month,
      _selectedReportDate.day,
    );
    final start = switch (_selectedDateRange) {
      'Yesterday' => selectedDay.subtract(const Duration(days: 1)),
      'This Week' => selectedDay.subtract(
        Duration(days: selectedDay.weekday - 1),
      ),
      'This Month' => DateTime(selectedDay.year, selectedDay.month),
      'This Year' => DateTime(selectedDay.year),
      _ => selectedDay,
    };
    final end = switch (_selectedDateRange) {
      'This Week' => start.add(const Duration(days: 7)),
      'This Month' => DateTime(start.year, start.month + 1),
      'This Year' => DateTime(start.year + 1),
      _ => start.add(const Duration(days: 1)),
    };
    return records
        .where(
          (record) =>
              !record.createdAt.isBefore(start) &&
              record.createdAt.isBefore(end),
        )
        .toList(growable: false);
  }

  String _connectionLabel(String sectionKey, String subcardKey) {
    if (_workspaceError != null) return 'Unavailable';
    if (_isLoadingRecords) return 'Connecting...';
    final count = _recordsFor(sectionKey, subcardKey).length;
    return count == 0
        ? 'Connected · no records'
        : 'Connected · $count record${count == 1 ? '' : 's'}';
  }

  Future<Map<String, dynamic>> _callStaffFunction(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    if (!_hasValidSupabaseConfiguration) {
      throw const FormatException(
        'Supabase is not configured for employee management.',
      );
    }
    final response = await Supabase.instance.client.functions.invoke(
      'create-staff-user',
      body: {'action': action, ...payload},
    );
    if (response.data is! Map) {
      throw const FormatException(
        'The staff management service returned an invalid response.',
      );
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<void> _loadEmployeeManagement() async {
    if (!mounted || _isLoadingEmployeeData) return;
    if (!_hasValidSupabaseConfiguration) {
      setState(() {
        _employeeManagementError = 'Supabase is not configured for employee management in this deployment.';
      });
      return;
    }
    setState(() {
      _isLoadingEmployeeData = true;
      _employeeManagementError = null;
    });
    try {
      final result = await _callStaffFunction('list-management');
      if (!mounted) return;
      setState(() {
        _staffDepartments = _mapList(result['departments']);
        _staffPermissionProfiles = _mapList(result['permission_profiles']);
        _staffMembers = _mapList(result['staff']);
      });
    } on FunctionException catch (exception) {
      if (!mounted) return;
      setState(
        () => _employeeManagementError = _staffFunctionFailure(exception),
      );
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        _employeeManagementError =
            'Could not load employee management data: $exception';
      });
    } finally {
      if (mounted) setState(() => _isLoadingEmployeeData = false);
    }
  }

  Future<void> _createWorkspaceRecord(
    ({String key, IconData icon, String title, String description}) section,
    String subcard,
  ) async {
    final repository = _workspaceRepository;
    if (repository == null) {
      setState(() {
        _workspaceError = 'The live Supabase service is not available.';
      });
      return;
    }

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final detailsController = TextEditingController();
    final amountController = TextEditingController();
    var error = '';
    var submitting = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add $subcard record'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a title'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: detailsController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Details',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount (optional, IQD)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      return double.tryParse(value.trim()) == null
                          ? 'Enter a valid amount'
                          : null;
                    },
                  ),
                  if (error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _AuthErrorMessage(error),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        submitting = true;
                        error = '';
                      });
                      try {
                        await repository.createRecord(
                          sectionKey: section.key,
                          subcardKey: _permissionSlug(subcard),
                          title: titleController.text.trim(),
                          details: detailsController.text.trim(),
                          amount: amountController.text.trim().isEmpty
                              ? null
                              : double.parse(amountController.text.trim()),
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } on Exception catch (exception) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            error = _workspaceWriteFailure(exception);
                            submitting = false;
                          });
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save record'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    detailsController.dispose();
    amountController.dispose();
    if (result == true) await _loadWorkspaceRecords();
  }

  String _workspaceWriteFailure(Exception exception) {
    if (exception is PostgrestException && exception.code == '42501') {
      return 'Supabase blocked this save with row-level security (42501); '
          'the record was not saved. Server reported: ${exception.message}. '
          'Verify this account has completed authenticator verification '
          '(AAL2), its staff profile has the correct role, any required '
          'section/card permission is assigned, and the reported table/schema '
          'matches this deployed app. If these checks pass, the production '
          'RLS policy needs a targeted correction. Do not disable RLS.';
    }
    if (exception is PostgrestException) {
      return 'Record was not saved (${exception.code ?? 'unknown'}): '
          '${exception.message}';
    }
    return 'Record was not saved. Check the connection and account access, '
        'then retry. $exception';
  }

  Future<void> _updateRecordStatus(
    CafeWorkspaceRecord record,
    String status,
  ) async {
    final repository = _workspaceRepository;
    if (repository == null) return;
    try {
      await repository.updateStatus(recordId: record.id, status: status);
      await _loadWorkspaceRecords();
    } on Exception catch (exception) {
      if (mounted) {
        setState(() {
          _workspaceError = 'Could not update this record: $exception';
        });
      }
    }
  }

  Future<void> _deleteWorkspaceRecord(CafeWorkspaceRecord record) async {
    final repository = _workspaceRepository;
    if (repository == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text('Delete "${record.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repository.deleteRecord(record.id);
      await _loadWorkspaceRecords();
    } on Exception catch (exception) {
      if (mounted) {
        setState(() {
          _workspaceError = 'Could not delete this record: $exception';
        });
      }
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
      _signOutError = null;
    });
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) Navigator.of(context).pop();
    } on AuthException {
      if (mounted) {
        setState(() {
          _signOutError = 'Sign-out failed. Please try again.';
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _signOutError =
              'Could not reach the sign-in service. Check your connection.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  Future<void> _openMoreSections() async {
    const primarySections = {0, 1, 3, 5, 9};
    final moreSections = _visibleSectionIndices
        .where((index) => !primarySections.contains(index))
        .toList(growable: false);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'More management sections',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
            if (moreSections.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Text('No additional management sections are assigned.'),
              ),
            for (final index in moreSections)
              ListTile(
                leading: Icon(_sections[index].icon, color: _navy),
                title: Text(_sections[index].title),
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                    _selectedSubcard = null;
                  });
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDepartment({Map<String, dynamic>? department}) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(
      text: department?['name'] as String? ?? '',
    );
    var saving = false;
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            department == null ? 'Add department' : 'Edit department',
          ),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Department name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a department name'
                        : null,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    _AuthErrorMessage(error!),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await _callStaffFunction('save-department', {
                          if (department != null) 'id': department['id'],
                          'name': controller.text.trim(),
                        });
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } on FunctionException catch (exception) {
                        if (dialogContext.mounted) {
                          setDialogState(
                            () => error = _staffFunctionFailure(exception),
                          );
                        }
                      } on Exception catch (exception) {
                        if (dialogContext.mounted) {
                          setDialogState(
                            () =>
                                error = 'Could not save department: $exception',
                          );
                        }
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save department'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (saved == true) await _loadEmployeeManagement();
  }

  Future<void> _savePermissionProfile({
    Map<String, dynamic>? permissionProfile,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: permissionProfile?['name'] as String? ?? '',
    );
    final selectedPermissions = <String, Set<String>>{};
    final grants = permissionProfile?['permissions'];
    if (grants is List) {
      for (final grant in grants.whereType<Map>()) {
        final sectionKey = grant['section_key'];
        final subcardKey = grant['subcard_key'];
        if (sectionKey is String && subcardKey is String) {
          selectedPermissions
              .putIfAbsent(sectionKey, () => <String>{})
              .add(subcardKey);
        }
      }
    }
    String? selectedDepartmentId =
        permissionProfile?['department_id'] as String? ??
        (_staffDepartments.isEmpty
            ? null
            : _staffDepartments.first['id'] as String?);
    var saving = false;
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            if (!formKey.currentState!.validate()) return;
            if (selectedDepartmentId == null) {
              setDialogState(() => error = 'Create a department first.');
              return;
            }
            final permissions = [
              for (final entry in selectedPermissions.entries)
                for (final subcardKey in entry.value)
                  {'section_key': entry.key, 'subcard_key': subcardKey},
            ];
            if (permissions.isEmpty) {
              setDialogState(
                () => error = 'Select at least one section or card.',
              );
              return;
            }
            setDialogState(() {
              saving = true;
              error = null;
            });
            try {
              await _callStaffFunction('save-permission-profile', {
                if (permissionProfile != null) 'id': permissionProfile['id'],
                'department_id': selectedDepartmentId,
                'name': nameController.text.trim(),
                'permissions': permissions,
              });
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            } on FunctionException catch (exception) {
              if (dialogContext.mounted) {
                setDialogState(() => error = _staffFunctionFailure(exception));
              }
            } on Exception catch (exception) {
              if (dialogContext.mounted) {
                setDialogState(
                  () => error = 'Could not save permission profile: $exception',
                );
              }
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => saving = false);
              }
            }
          }

          final dialogHeight = MediaQuery.sizeOf(context).height;
          final contentHeight = (dialogHeight * 0.78).clamp(320.0, 680.0);
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: SizedBox(
              width: 560,
              height: contentHeight,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            permissionProfile == null
                                ? 'Create permission profile'
                                : 'Edit permission profile',
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Save a reusable set of section and card access.',
                            style: TextStyle(color: _muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Form(
                      key: formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          TextFormField(
                            controller: nameController,
                            maxLength: 80,
                            decoration: const InputDecoration(
                              labelText: 'Permission profile name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter a profile name'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: selectedDepartmentId,
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final department in _staffDepartments)
                                DropdownMenuItem(
                                  value: department['id'] as String,
                                  child: Text(department['name'] as String),
                                ),
                            ],
                            onChanged: saving
                                ? null
                                : (value) => setDialogState(
                                    () => selectedDepartmentId = value,
                                  ),
                            validator: (value) =>
                                value == null ? 'Choose a department' : null,
                          ),
                          const SizedBox(height: 12),
                          for (
                            var index = 0;
                            index < _StaffDashboardPageState._sections.length;
                            index++
                          )
                            _buildStaffPermissionSection(
                              index,
                              selectedPermissions,
                              setDialogState,
                              saving,
                              titlePrefix: index == 0
                                  ? 'Dashboard cards'
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: _AuthErrorMessage(error!),
                    ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: saving
                              ? null
                              : () => Navigator.of(dialogContext).pop(false),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: saving ? null : submit,
                          child: Text(
                            saving ? 'Saving…' : 'Save permission profile',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    nameController.dispose();
    if (saved == true) await _loadEmployeeManagement();
  }

  Future<void> _addStaffUser() async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    String? departmentId;
    String? permissionProfileId;
    var saving = false;
    String? error;
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final availableProfiles = _staffPermissionProfiles
              .where((profile) => profile['department_id'] == departmentId)
              .toList(growable: false);
          if (!availableProfiles.any(
            (profile) => profile['id'] == permissionProfileId,
          )) {
            permissionProfileId = null;
          }
          Future<void> submit() async {
            if (!formKey.currentState!.validate()) return;
            setDialogState(() {
              saving = true;
              error = null;
            });
            try {
              final result = await _callStaffFunction('create-staff-user', {
                'email': emailController.text.trim(),
                'password': passwordController.text,
                'department_id': departmentId,
                'permission_profile_id': permissionProfileId,
              });
              if (result['permissions_saved'] != true) {
                throw const FormatException(
                  'The service did not confirm saving staff permissions.',
                );
              }
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            } on FunctionException catch (exception) {
              if (dialogContext.mounted) {
                setDialogState(() => error = _staffFunctionFailure(exception));
              }
            } on AuthException {
              if (dialogContext.mounted) {
                setDialogState(
                  () => error = 'Your sign-in has expired. Sign in again.',
                );
              }
            } on Exception catch (exception) {
              if (dialogContext.mounted) {
                setDialogState(
                  () => error = 'Could not create staff account: $exception',
                );
              }
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => saving = false);
              }
            }
          }

          return AlertDialog(
            title: const Text('Add staff account'),
            content: SizedBox(
              width: 460,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Staff email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          return email.contains('@') && email.contains('.')
                              ? null
                              : 'Enter a valid email address';
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Initial password (12+ characters)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.length < 12
                            ? 'Use at least 12 characters'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: departmentId,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final department in _staffDepartments)
                            DropdownMenuItem(
                              value: department['id'] as String,
                              child: Text(department['name'] as String),
                            ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) => setDialogState(() {
                                departmentId = value;
                                permissionProfileId = null;
                              }),
                        validator: (value) =>
                            value == null ? 'Choose a department' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: permissionProfileId,
                        decoration: const InputDecoration(
                          labelText: 'Permission profile',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final profile in availableProfiles)
                            DropdownMenuItem(
                              value: profile['id'] as String,
                              child: Text(profile['name'] as String),
                            ),
                        ],
                        onChanged: saving || departmentId == null
                            ? null
                            : (value) => setDialogState(
                                () => permissionProfileId = value,
                              ),
                        validator: (value) => value == null
                            ? 'Create and choose a permission profile'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'Create a department and permission profile first. '
                          'The account will receive that profile’s access.',
                          style: TextStyle(color: _muted, height: 1.4),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        _AuthErrorMessage(error!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving ? null : submit,
                child: Text(saving ? 'Creating…' : 'Create staff account'),
              ),
            ],
          );
        },
      ),
    );
    final createdEmail = emailController.text.trim();
    emailController.dispose();
    passwordController.dispose();
    if (created == true && context.mounted) {
      await _loadEmployeeManagement();
      messenger.showSnackBar(
        SnackBar(content: Text('Staff account created for $createdEmail.')),
      );
    }
  }

  Future<void> _editStaffAccess(Map<String, dynamic> member) async {
    String? departmentId = member['department_id'] as String?;
    String? permissionProfileId = member['permission_profile_id'] as String?;
    var saving = false;
    String? error;
    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final availableProfiles = _staffPermissionProfiles
              .where((profile) => profile['department_id'] == departmentId)
              .toList(growable: false);
          if (!availableProfiles.any(
            (profile) => profile['id'] == permissionProfileId,
          )) {
            permissionProfileId = null;
          }
          return AlertDialog(
            title: Text('Edit access · ${member['email']}'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: departmentId,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final department in _staffDepartments)
                        DropdownMenuItem(
                          value: department['id'] as String,
                          child: Text(department['name'] as String),
                        ),
                    ],
                    onChanged: saving
                        ? null
                        : (value) => setDialogState(() {
                            departmentId = value;
                            permissionProfileId = null;
                          }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: permissionProfileId,
                    decoration: const InputDecoration(
                      labelText: 'Permission profile',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final profile in availableProfiles)
                        DropdownMenuItem(
                          value: profile['id'] as String,
                          child: Text(profile['name'] as String),
                        ),
                    ],
                    onChanged: saving || departmentId == null
                        ? null
                        : (value) =>
                              setDialogState(() => permissionProfileId = value),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    _AuthErrorMessage(error!),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (departmentId == null ||
                            permissionProfileId == null) {
                          setDialogState(
                            () => error =
                                'Choose a department and permission profile.',
                          );
                          return;
                        }
                        setDialogState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await _callStaffFunction('update-staff-access', {
                            'user_id': member['user_id'],
                            'department_id': departmentId,
                            'permission_profile_id': permissionProfileId,
                          });
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        } on FunctionException catch (exception) {
                          if (dialogContext.mounted) {
                            setDialogState(
                              () => error = _staffFunctionFailure(exception),
                            );
                          }
                        } on Exception catch (exception) {
                          if (dialogContext.mounted) {
                            setDialogState(
                              () => error =
                                  'Could not update staff access: $exception',
                            );
                          }
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() => saving = false);
                          }
                        }
                      },
                child: Text(saving ? 'Saving…' : 'Save access'),
              ),
            ],
          );
        },
      ),
    );
    if (updated == true) await _loadEmployeeManagement();
  }

  Widget _buildStaffPermissionSection(
    int sectionIndex,
    Map<String, Set<String>> selectedPermissions,
    StateSetter setDialogState,
    bool isSubmitting, {
    String? titlePrefix,
  }) {
    final section = _StaffDashboardPageState._sections[sectionIndex];
    final selected = selectedPermissions[section.key] ?? <String>{};
    final allSelected = selected.contains('*');
    final subcards = _StaffDashboardPageState._subcards[sectionIndex];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE4EAF1)),
      ),
      child: ExpansionTile(
        key: PageStorageKey('staff-permission-${section.key}'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          titlePrefix ?? section.title,
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          allSelected
              ? 'All cards'
              : selected.isEmpty
              ? 'No access assigned'
              : '${selected.length} card(s) selected',
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        children: [
          CheckboxListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            activeColor: const Color(0xFF2463EB),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('All section cards'),
            value: allSelected,
            onChanged: isSubmitting
                ? null
                : (checked) => setDialogState(() {
                    if (checked == true) {
                      selectedPermissions[section.key] = {'*'};
                    } else {
                      selectedPermissions.remove(section.key);
                    }
                  }),
          ),
          for (final subcard in subcards)
            CheckboxListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              activeColor: const Color(0xFF2463EB),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(subcard),
              value: allSelected || selected.contains(_permissionSlug(subcard)),
              onChanged: isSubmitting || allSelected
                  ? null
                  : (checked) => setDialogState(() {
                      final sectionSelection = selectedPermissions.putIfAbsent(
                        section.key,
                        () => <String>{},
                      );
                      final subcardKey = _permissionSlug(subcard);
                      if (checked == true) {
                        sectionSelection.add(subcardKey);
                      } else {
                        sectionSelection.remove(subcardKey);
                      }
                      if (sectionSelection.isEmpty) {
                        selectedPermissions.remove(section.key);
                      }
                    }),
            ),
        ],
      ),
    );
  }

  Widget _employeeManagementPanel() {
    String departmentName(Object? id) {
      for (final department in _staffDepartments) {
        if (department['id'] == id) return department['name'] as String;
      }
      return 'No department';
    }

    String permissionProfileName(Object? id) {
      for (final profile in _staffPermissionProfiles) {
        if (profile['id'] == id) return profile['name'] as String;
      }
      return 'No permission profile';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Employee workspace',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Set up departments and reusable access profiles first, then create '
          'staff accounts. You can change a staff member’s department and '
          'permissions at any time.',
          style: TextStyle(color: _muted, height: 1.5),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => _saveDepartment(),
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Add department'),
            ),
            OutlinedButton.icon(
              onPressed: _staffDepartments.isEmpty
                  ? null
                  : () => _savePermissionProfile(),
              icon: const Icon(Icons.checklist_outlined),
              label: const Text('Create permission profile'),
            ),
            OutlinedButton.icon(
              onPressed:
                  _staffDepartments.isEmpty || _staffPermissionProfiles.isEmpty
                  ? null
                  : _addStaffUser,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add staff account'),
            ),
            IconButton(
              tooltip: 'Refresh employee management',
              onPressed: _isLoadingEmployeeData
                  ? null
                  : () => unawaited(_loadEmployeeManagement()),
              icon: _isLoadingEmployeeData
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_employeeManagementError != null) ...[
          const SizedBox(height: 12),
          _AuthErrorMessage(_employeeManagementError!),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: _isLoadingEmployeeData
                  ? null
                  : () => unawaited(_loadEmployeeManagement()),
              child: const Text('Retry loading employee data'),
            ),
          ),
        ],
        if (_isLoadingEmployeeData &&
            _staffDepartments.isEmpty &&
            _employeeManagementError == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        const SizedBox(height: 12),
        _employeeGroupHeading(
          'Departments',
          '${_staffDepartments.length} department(s)',
        ),
        if (_staffDepartments.isEmpty)
          _employeeEmptyHint(
            'No departments yet. Add a department before creating a '
            'permission profile or staff account.',
          ),
        for (final department in _staffDepartments)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.apartment_outlined),
              ),
              title: Text(department['name'] as String),
              subtitle: Text(
                '${_staffPermissionProfiles.where((profile) => profile['department_id'] == department['id']).length} permission profile(s)',
              ),
              trailing: IconButton(
                tooltip: 'Edit ${department['name']}',
                onPressed: () => _saveDepartment(department: department),
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          ),
        const SizedBox(height: 18),
        _employeeGroupHeading(
          'Permission profiles',
          '${_staffPermissionProfiles.length} profile(s)',
        ),
        if (_staffDepartments.isNotEmpty && _staffPermissionProfiles.isEmpty)
          _employeeEmptyHint(
            'Create a profile for each role or access level, such as “Cashier” '
            'or “Kitchen staff”. Choose exactly which sections and cards it '
            'can open.',
          ),
        for (final profile in _staffPermissionProfiles)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.admin_panel_settings_outlined),
              ),
              title: Text(profile['name'] as String),
              subtitle: Text(
                '${departmentName(profile['department_id'])} · '
                '${(profile['permissions'] as List? ?? const []).length} access grant(s)',
              ),
              trailing: IconButton(
                tooltip: 'Edit ${profile['name']}',
                onPressed: () =>
                    _savePermissionProfile(permissionProfile: profile),
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          ),
        const SizedBox(height: 18),
        _employeeGroupHeading(
          'Staff accounts',
          '${_staffMembers.length} account(s)',
        ),
        if (_staffMembers.isEmpty)
          _employeeEmptyHint(
            _staffPermissionProfiles.isEmpty
                ? 'Create a department and permission profile before adding '
                      'your first staff account.'
                : 'No staff accounts have been created yet.',
          ),
        for (final member in _staffMembers)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(member['email'] as String? ?? 'Staff account'),
              subtitle: Text(
                '${departmentName(member['department_id'])} · '
                '${permissionProfileName(member['permission_profile_id'])}',
              ),
              trailing: IconButton(
                tooltip: 'Edit staff access',
                onPressed:
                    _staffDepartments.isEmpty ||
                        _staffPermissionProfiles.isEmpty
                    ? null
                    : () => _editStaffAccess(member),
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          ),
      ],
    );
  }

  Widget _employeeGroupHeading(String title, String count) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        Text(count, style: const TextStyle(color: _muted, fontSize: 12)),
      ],
    ),
  );

  Widget _employeeEmptyHint(String text) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE5EAF0)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: const TextStyle(color: _muted, height: 1.45)),
  );

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F7FB),
      drawer: Drawer(child: _navigationPanel()),
      bottomNavigationBar: isWide ? null : _mobileNavigationBar(),
      appBar: isWide
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: _ink,
              surfaceTintColor: Colors.white,
              elevation: 0,
              shape: const Border(bottom: BorderSide(color: Color(0xFFE4EAF1))),
              title: MediaQuery.sizeOf(context).width < 600
                  ? const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Gelye Sherane',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Café & Restaurant · Management',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFD8E2F0),
                          ),
                        ),
                      ],
                    )
                  : const Text('Gelye Sherane · Management System'),
              actions: [
                IconButton(
                  tooltip: 'Refresh live records',
                  onPressed: _isLoadingRecords
                      ? null
                      : () => unawaited(_loadWorkspaceRecords()),
                  icon: _isLoadingRecords
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh),
                ),
                if (_hasSectionAccess(11))
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () => setState(() {
                      _selectedIndex = 11;
                      _selectedSubcard = null;
                    }),
                    icon: const Icon(Icons.notifications_none_outlined),
                  ),
                if (widget.role == 'admin')
                  IconButton(
                    tooltip: 'Employee workspace',
                    onPressed: () => setState(() {
                      _selectedIndex = 7;
                      _selectedSubcard = null;
                    }),
                    icon: const Icon(Icons.groups_outlined),
                  ),
                if (MediaQuery.sizeOf(context).width >= 600)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: Text(
                        '${widget.email} · ${widget.role == 'admin' ? 'Admin' : 'Staff'}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: _isSigningOut ? null : _signOut,
                  icon: _isSigningOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.logout),
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showSidebar = constraints.maxWidth >= 760;
          final sectionContent = _sectionContent(_selectedIndex);
          if (showSidebar) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 248, child: _navigationPanel()),
                Expanded(
                  child: Column(
                    children: [
                      _desktopTopbar(),
                      Expanded(child: _contentArea(sectionContent)),
                    ],
                  ),
                ),
              ],
            );
          }
          return _contentArea(sectionContent);
        },
      ),
    );
  }

  Widget _desktopTopbar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE4EAF1))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            if (constraints.maxWidth >= 600) ...[
              const Text('Workspace', style: TextStyle(color: _muted)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.chevron_right, color: Color(0xFF9AA6B5)),
              ),
            ],
            Expanded(
              child: Text(
                _sections[_selectedIndex].title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (constraints.maxWidth >= 760)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Icon(
                      _workspaceError == null
                          ? Icons.circle
                          : Icons.error_outline,
                      size: 8,
                      color: _workspaceError == null
                          ? const Color(0xFF16814A)
                          : const Color(0xFFB42318),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _workspaceError == null ? 'Live data' : 'Unavailable',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            IconButton(
              tooltip: 'Refresh live records',
              onPressed: _isLoadingRecords
                  ? null
                  : () => unawaited(_loadWorkspaceRecords()),
              icon: const Icon(Icons.refresh),
            ),
            if (_hasSectionAccess(11))
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => setState(() {
                  _selectedIndex = 11;
                  _selectedSubcard = null;
                }),
                icon: const Icon(Icons.notifications_none_outlined),
              ),
            if (widget.role == 'admin' && constraints.maxWidth >= 600)
              IconButton(
                tooltip: 'Employee workspace',
                onPressed: () => setState(() {
                  _selectedIndex = 7;
                  _selectedSubcard = null;
                }),
                icon: const Icon(Icons.groups_outlined),
              ),
            if (constraints.maxWidth >= 960)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${widget.email} · ${widget.role == 'admin' ? 'Admin' : 'Staff'}',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ),
            IconButton(
              tooltip: 'Sign out',
              onPressed: _isSigningOut ? null : _signOut,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileNavigationBar() {
    const primarySections = [0, 1, 5, 3, 9];
    final visiblePrimary = primarySections
        .where(_hasSectionAccess)
        .toList(growable: false);
    final selectedPrimary = visiblePrimary.indexOf(_selectedIndex);
    final moreDestination = visiblePrimary.length;
    return SafeArea(
      top: false,
      child: NavigationBar(
        selectedIndex: selectedPrimary < 0 ? moreDestination : selectedPrimary,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE7F0FF),
        destinations: [
          for (final sectionIndex in visiblePrimary)
            NavigationDestination(
              icon: Icon(_primarySectionIcon(sectionIndex, selected: false)),
              selectedIcon: Icon(
                _primarySectionIcon(sectionIndex, selected: true),
              ),
              label: _primarySectionLabel(sectionIndex),
            ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
        onDestinationSelected: (destination) {
          if (destination == moreDestination) {
            _openMoreSections();
            return;
          }
          setState(() {
            _selectedIndex = visiblePrimary[destination];
            _selectedSubcard = null;
          });
        },
      ),
    );
  }

  String _primarySectionLabel(int sectionIndex) => switch (sectionIndex) {
    0 => 'Home',
    1 => 'Tables',
    3 => 'Menu',
    5 => 'Motel',
    9 => 'Reserve',
    _ => _sections[sectionIndex].title,
  };

  IconData _primarySectionIcon(int sectionIndex, {required bool selected}) =>
      switch (sectionIndex) {
        0 => selected ? Icons.home : Icons.home_outlined,
        1 =>
          selected ? Icons.table_restaurant : Icons.table_restaurant_outlined,
        3 => selected ? Icons.restaurant_menu : Icons.restaurant_menu_outlined,
        5 => selected ? Icons.hotel : Icons.hotel_outlined,
        9 => selected ? Icons.event : Icons.event_outlined,
        _ => _sections[sectionIndex].icon,
      };

  Widget _navigationPanel() {
    return Material(
      color: _deepNavy,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 12, 18),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _gold,
                    foregroundColor: _deepNavy,
                    radius: 21,
                    child: Text(
                      'G',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gelye Sherane',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'CAFÉ & RESTAURANT',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFFD5B77C),
                            fontSize: 9,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Text(
                'MANAGEMENT SECTIONS',
                style: TextStyle(
                  color: Color(0xFFD5B77C),
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _visibleSectionIndices.length,
                itemBuilder: (context, visibleIndex) {
                  final index = _visibleSectionIndices[visibleIndex];
                  final section = _sections[index];
                  final selected = index == _selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    child: ListTile(
                      key: ValueKey('management-section-$index'),
                      selected: selected,
                      selectedTileColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Icon(
                        section.icon,
                        color: selected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.68),
                      ),
                      title: Text(
                        section.title,
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: selected ? 1 : 0.84,
                          ),
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                          _selectedSubcard = null;
                        });
                        _scaffoldKey.currentState?.closeDrawer();
                      },
                    ),
                  );
                },
              ),
            ),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${widget.email}\n${widget.role == 'admin' ? 'Administrator' : 'Staff'}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contentArea(Widget content) {
    return SelectionArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_signOutError != null) ...[
                  _AuthErrorMessage(_signOutError!),
                  const SizedBox(height: 16),
                ],
                content,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionContent(int index) {
    final section = _sections[index];
    final subcard = _selectedSubcard;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (subcard != null)
          TextButton.icon(
            onPressed: () => setState(() => _selectedSubcard = null),
            icon: const Icon(Icons.arrow_back),
            label: Text('Back to ${section.title}'),
          ),
        if (index != 0) _sectionPageHeading(section, subcard),
        if (index != 0) const SizedBox(height: 16),
        if (index != 0 && index != 2) const SizedBox(height: 20),
        if (widget.permissionsLoadError != null)
          _AuthErrorMessage(
            'Could not load section permissions. Dashboard is open, but no '
            'additional sections or cards are shown: ${widget.permissionsLoadError}',
          )
        else if (widget.role == 'staff' && widget.grantedPermissions.isEmpty)
          const _AuthErrorMessage(
            'No additional sections or dashboard cards are assigned yet. '
            'Ask an administrator to update this account.',
          ),
        if (widget.permissionsLoadError != null ||
            (widget.role == 'staff' && widget.grantedPermissions.isEmpty))
          const SizedBox(height: 16),
        if (index == 1 && subcard == null) ...[
          _workspaceConnectionBanner(),
          const SizedBox(height: 12),
          _tablesWorkflowPanel(section, index),
          const SizedBox(height: 16),
        ],
        if (index == 7 && widget.role == 'admin' && subcard == null) ...[
          _sectionSubcardGrid(index),
          const SizedBox(height: 16),
          _employeeManagementPanel(),
        ] else if (index == 2 && subcard != null)
          _financeDetail(section, subcard)
        else if (index == 1 && subcard != null)
          _tableManagementDetail(section, subcard)
        else if (subcard == null)
          _sectionSubcardGrid(index)
        else
          _subcardDetail(section, subcard),
        const SizedBox(height: 20),
        Text(
          'Signed in as ${widget.email}',
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _sectionPageHeading(
    ({String key, IconData icon, String title, String description}) section,
    String? subcard,
  ) {
    final description = subcard == null
        ? section.description
        : _sectionCardDescriptions[subcard] ??
              'Live workspace records for $subcard.';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF3FB),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            subcard == null ? section.icon : _metricIcon(subcard, section.icon),
            color: const Color(0xFF4166A3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subcard == null
                    ? 'MANAGEMENT / ${section.title}'
                    : section.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF2463EB),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subcard ??
                    (section.key == 'payment_management'
                        ? 'Payments & Finance'
                        : section.title),
                style: TextStyle(
                  color: _navy,
                  fontSize: MediaQuery.sizeOf(context).width < 600 ? 23 : 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(color: _muted, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _workspaceStatusBadge(),
      ],
    );
  }

  Widget _workspaceStatusBadge() {
    final color = _workspaceError == null
        ? const Color(0xFF16814A)
        : const Color(0xFFB42318);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _workspaceError == null ? Icons.circle : Icons.error_outline,
            size: 8,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            _workspaceError == null ? 'Live' : 'Unavailable',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceConnectionBanner() {
    final connected = _workspaceError == null && !_isLoadingRecords;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4EAF1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            connected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            color: connected
                ? const Color(0xFF16814A)
                : const Color(0xFFB9670C),
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _isLoadingRecords
                  ? 'Connecting to live Supabase records...'
                  : _workspaceError ??
                        'Connected to live Supabase records. Updates sync '
                            'automatically across authorized sections.',
              style: const TextStyle(color: _muted, height: 1.4, fontSize: 12),
            ),
          ),
          if (_workspaceError != null)
            TextButton(
              onPressed: () => unawaited(_loadWorkspaceRecords()),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  Widget _tablesWorkflowPanel(
    ({String key, IconData icon, String title, String description}) section,
    int sectionIndex,
  ) {
    final visibleCards = _visibleSubcards(sectionIndex);
    final records = _workspaceRecords
        .where((record) => record.sectionKey == section.key)
        .toList(growable: false);
    final openCount = records.where((record) => record.status == 'open').length;
    final progressCount = records
        .where((record) => record.status == 'in_progress')
        .length;
    final completedCount = records
        .where((record) => record.status == 'completed')
        .length;

    Widget lane(String status, String title, Color color) {
      final laneRecords = records
          .where((record) => record.status == status)
          .take(3)
          .toList(growable: false);
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFD),
          border: Border.all(color: const Color(0xFFE4EAF1)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${records.where((record) => record.status == status).length}',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const Divider(height: 14),
            if (_isLoadingRecords)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_workspaceError != null)
              const Text(
                'Records unavailable',
                style: TextStyle(color: _muted, fontSize: 10),
              )
            else if (laneRecords.isEmpty)
              Text(
                'No ${title.toLowerCase()} records',
                style: const TextStyle(color: _muted, fontSize: 10),
              )
            else
              for (final record in laneRecords)
                _sectionWorkflowRecord(record, sectionIndex, visibleCards),
          ],
        ),
      );
    }

    final workflowStage = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE4EAF1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Table service board',
                        style: TextStyle(
                          color: _navy,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Table, order and reservation records · no sample data',
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                _workspaceStatusBadge(),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _workflowCount('Open', openCount, const Color(0xFFB9670C)),
                _workflowCount(
                  'In progress',
                  progressCount,
                  const Color(0xFF2463EB),
                ),
                _workflowCount(
                  'Completed',
                  completedCount,
                  const Color(0xFF16814A),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final lanes = [
                  lane('open', 'Open', const Color(0xFFB9670C)),
                  lane('in_progress', 'In progress', const Color(0xFF2463EB)),
                  lane('completed', 'Completed', const Color(0xFF16814A)),
                ];
                if (constraints.maxWidth < 460) {
                  return Column(
                    children: [
                      for (var index = 0; index < lanes.length; index++) ...[
                        if (index > 0) const SizedBox(height: 8),
                        lanes[index],
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < lanes.length; index++) ...[
                      if (index > 0) const SizedBox(width: 8),
                      Expanded(child: lanes[index]),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );

    final workflowActions = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE4EAF1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Table workflows',
              style: TextStyle(
                color: _navy,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Open a table, order or reservation workspace',
              style: TextStyle(color: _muted, fontSize: 11),
            ),
            const SizedBox(height: 10),
            if (visibleCards.isEmpty)
              const Text(
                'No card actions are assigned.',
                style: TextStyle(color: _muted, fontSize: 12),
              )
            else
              for (final title in visibleCards.take(5))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _metricIcon(title, section.icon),
                    color: const Color(0xFF4166A3),
                    size: 19,
                  ),
                  title: Text(
                    'Open $title',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => setState(() {
                    _workspaceSearch = '';
                    _workspaceStatusFilter = 'All';
                    _selectedSubcard = title;
                  }),
                ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: [
              workflowStage,
              const SizedBox(height: 10),
              workflowActions,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: workflowStage),
            const SizedBox(width: 12),
            SizedBox(
              width: constraints.maxWidth < 760 ? 220 : 280,
              child: workflowActions,
            ),
          ],
        );
      },
    );
  }

  Widget _workflowCount(String label, int count, Color accent) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xFFE4EAF1)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
      ],
    ),
  );

  Widget _sectionWorkflowRecord(
    CafeWorkspaceRecord record,
    int sectionIndex,
    List<String> visibleCards,
  ) {
    String? cardTitle;
    for (final title in visibleCards) {
      if (_permissionSlug(title) == record.subcardKey) {
        cardTitle = title;
        break;
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: cardTitle == null
              ? null
              : () => setState(() => _selectedSubcard = cardTitle),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2463EB),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        cardTitle ?? _sections[sectionIndex].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: _muted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionSubcardGrid(int sectionIndex) {
    if (sectionIndex == 0) return _dashboardLayout();
    final visibleSubcards = _visibleSubcards(sectionIndex);
    if (visibleSubcards.isEmpty) {
      return const Text(
        'No cards in this section are assigned to this account.',
      );
    }
    if (sectionIndex == 2) {
      return _paymentManagementOverview(visibleSubcards);
    }
    final featuredCards = _featuredSectionCards[sectionIndex];
    if (featuredCards != null) {
      final primaryCards = visibleSubcards
          .where(featuredCards.contains)
          .toList(growable: false);
      final additionalCards = visibleSubcards
          .where((title) => !featuredCards.contains(title))
          .toList(growable: false);
      if (primaryCards.isNotEmpty && additionalCards.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _managementCardGrid(
              sectionIndex: sectionIndex,
              titles: primaryCards,
              minimumColumns: sectionIndex == 1 ? 3 : null,
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                key: PageStorageKey<String>('section-more-cards-$sectionIndex'),
                title: Text('More cards (${additionalCards.length})'),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  _managementCardGrid(
                    sectionIndex: sectionIndex,
                    titles: additionalCards,
                  ),
                ],
              ),
            ),
          ],
        );
      }
      if (primaryCards.isNotEmpty) {
        return _managementCardGrid(
          sectionIndex: sectionIndex,
          titles: primaryCards,
          minimumColumns: sectionIndex == 1 ? 3 : null,
        );
      }
    }
    return _managementCardGrid(
      sectionIndex: sectionIndex,
      titles: visibleSubcards,
      minimumColumns: sectionIndex == 1 ? 3 : null,
    );
  }

  Widget _managementCardGrid({
    required int sectionIndex,
    required List<String> titles,
    int? minimumColumns,
    String? revenueCard,
    double? revenue,
    bool revenueUnavailable = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final responsiveColumns = constraints.maxWidth >= 1120
            ? 4
            : constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 600
            ? 2
            : 1;
        final columnCount = minimumColumns == null
            ? responsiveColumns
            : responsiveColumns < minimumColumns
            ? minimumColumns
            : responsiveColumns;
        final cardWidth =
            (constraints.maxWidth - (columnCount - 1) * 12) / columnCount;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final title in titles)
              SizedBox(
                width: cardWidth,
                child: _managementCard(
                  sectionIndex,
                  title,
                  revenue: title == revenueCard ? revenue : null,
                  revenueUnavailable:
                      title == revenueCard && revenueUnavailable,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _dashboardLayout() {
    final assignedCards = _visibleSubcards(0);
    const glanceCandidates = [
      'Today Revenue',
      'Tables Occupied',
      'Kitchen Orders',
      'Pending Payment',
    ];
    final glanceCards = glanceCandidates
        .where(assignedCards.contains)
        .toList(growable: false);
    if (assignedCards.isEmpty) {
      return Text(
        widget.permissionsLoadError == null
            ? 'No dashboard cards are assigned to this account.'
            : 'Dashboard cards are unavailable until permissions can be loaded.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final pageHeading = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Operational overview',
                  style: TextStyle(
                    color: Color(0xFF2463EB),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'A clear view of today’s service, team and priorities.',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            );
            final pageActions = Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _isLoadingRecords
                      ? null
                      : () => unawaited(_loadWorkspaceRecords()),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE4EAF1)),
                  ),
                ),
                _dateRangeControls(),
              ],
            );
            if (constraints.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  pageHeading,
                  const SizedBox(height: 12),
                  pageActions,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: pageHeading),
                pageActions,
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        if (glanceCards.isNotEmpty) ...[
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today at a glance',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Values are based only on saved workspace records.',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) => _compactMetricGrid(
              sectionIndex: 0,
              titles: glanceCards,
              height: constraints.maxWidth < 520 ? 118 : 150,
            ),
          ),
          const SizedBox(height: 16),
        ],
        for (final group in _dashboardGroups)
          _dashboardGroup(
            group,
            assignedCards
                .where(
                  (title) =>
                      group.cards.contains(title) &&
                      !glanceCards.contains(title),
                )
                .toList(growable: false),
          ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1DD),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                _workspaceError == null
                    ? Icons.cloud_done_outlined
                    : Icons.warning_amber_rounded,
                color: _workspaceError == null
                    ? const Color(0xFF27753A)
                    : const Color(0xFF9A5B00),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _workspaceError ??
                      'Live records are shared across the workspace. '
                          'No card processor is connected.',
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Quick Links',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final link in [
              (
                label: 'Tables',
                index: 1,
                icon: Icons.table_restaurant_outlined,
              ),
              (label: 'Menu', index: 3, icon: Icons.restaurant_menu_outlined),
              (label: 'Payments', index: 2, icon: Icons.payments_outlined),
            ].where((link) => _hasSectionAccess(link.index)))
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _selectedIndex = link.index;
                  _selectedSubcard = null;
                }),
                icon: Icon(link.icon),
                label: Text(link.label),
              ),
          ],
        ),
      ],
    );
  }

  static const _dashboardGroups = [
    (
      title: 'Payments & Finance',
      icon: Icons.payments_outlined,
      tint: Color(0xFFDDF7EC),
      iconColor: Color(0xFF138052),
      cards: [
        'Today Revenue',
        'Standing Cash',
        'Pending Payment',
        'Invoices',
        'Discounts',
        'Credit Accounts',
        'Cash Reconciliation',
      ],
    ),
    (
      title: 'Tables & Reservations',
      icon: Icons.table_restaurant_outlined,
      tint: Color(0xFFE5EEFF),
      iconColor: Color(0xFF2463D3),
      cards: [
        'Tables Occupied',
        'Table Map',
        'Reservations',
        'Cleaning Needed',
        'Service Speed',
        'Guests Today',
        'Table Occupancy',
      ],
    ),
    (
      title: 'Kitchen & Orders',
      icon: Icons.soup_kitchen_outlined,
      tint: Color(0xFFFFEBD1),
      iconColor: Color(0xFFB75B11),
      cards: [
        'Kitchen Orders',
        'Menu',
        'Low Stock',
        'Nargile Orders',
        'Motel Orders',
        'Online Orders',
        'Today Orders',
        'Kitchen Queue',
        'Takeaway & Delivery',
      ],
    ),
    (
      title: 'Management & Operations',
      icon: Icons.groups_outlined,
      tint: Color(0xFFF0E4FF),
      iconColor: Color(0xFF7638BC),
      cards: [
        'Customers',
        'Employees',
        'Tasks',
        'Events',
        'Feedback',
        'Maintenance',
        'Tourism Customers',
        'Customer Requests',
        'Attendance',
      ],
    ),
    (
      title: 'Reports, Settings & Security',
      icon: Icons.bar_chart_outlined,
      tint: Color(0xFFDFF5F6),
      iconColor: Color(0xFF117D84),
      cards: [
        'Reports',
        'Security',
        'Backup',
        'Offline Mode',
        'System Health',
        'Audit & Activity',
        'Product Performance',
        'Personalization',
      ],
    ),
  ];

  Widget _dashboardGroup(
    ({
      String title,
      IconData icon,
      Color tint,
      Color iconColor,
      List<String> cards,
    })
    group,
    List<String> visibleCards,
  ) {
    if (visibleCards.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1209243A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: group.tint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(group.icon, color: group.iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  group.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'See all (${visibleCards.length})',
                style: TextStyle(
                  color: group.iconColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          children: [
            _compactMetricGrid(
              sectionIndex: 0,
              titles: visibleCards,
              height: 118,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateRangeControls() {
    final dateLabel =
        '${_selectedReportDate.day}/${_selectedReportDate.month}/${_selectedReportDate.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedReportDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null && mounted) {
              setState(() {
                _selectedReportDate = date;
                _selectedDateRange = 'Today';
              });
            }
          },
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          label: Text('$dateLabel · $_selectedDateRange'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _ink,
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFE3E8F0)),
          ),
        ),
        const SizedBox(height: 9),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final range in const [
                'Today',
                'Yesterday',
                'This Week',
                'This Month',
                'This Year',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    label: Text(range),
                    selected: _selectedDateRange == range,
                    onSelected: (_) =>
                        setState(() => _selectedDateRange = range),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _paymentManagementOverview(List<String> titles) {
    const featuredFinanceCards = [
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
    final featuredCards = [
      for (final title in featuredFinanceCards)
        if (titles.contains(title)) title,
    ];
    final additionalCards = titles
        .where((title) => !featuredFinanceCards.contains(title))
        .toList(growable: false);
    final allRecords = _recordsInSelectedRange(
      _workspaceRecords.where(
        (record) => record.sectionKey == 'payment_management',
      ),
    );
    final recordedAmounts = allRecords
        .where((record) => record.amount != null)
        .fold<double>(0, (total, record) => total + record.amount!);
    final openCount = allRecords
        .where(
          (record) => record.status == 'open' || record.status == 'in_progress',
        )
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dateRangeControls(),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF4FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD4E6FA)),
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_done_outlined, color: Color(0xFF2570B8)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _workspaceError != null
                      ? 'Finance data unavailable: $_workspaceError'
                      : _isLoadingRecords
                      ? 'Loading finance records…'
                      : '${allRecords.length} tracked record(s) · $openCount open · '
                            '${allRecords.any((record) => record.amount != null) ? '${recordedAmounts.toStringAsFixed(0)} IQD' : '—'} recorded',
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _workspaceError == null
                      ? const Color(0xFFDDF7EC)
                      : const Color(0xFFFFE8E6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _workspaceError == null ? 'Live' : 'Unavailable',
                  style: TextStyle(
                    color: _workspaceError == null
                        ? const Color(0xFF138052)
                        : const Color(0xFFB42318),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _compactMetricGrid(sectionIndex: 2, titles: featuredCards, height: 150),
        if (additionalCards.isNotEmpty) ...[
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              title: Text('More finance cards (${additionalCards.length})'),
              childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              children: [
                _compactMetricGrid(
                  sectionIndex: 2,
                  titles: additionalCards,
                  height: 150,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _compactMetricGrid({
    required int sectionIndex,
    required List<String> titles,
    required double height,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 820
            ? 2
            : constraints.maxWidth < 1120
            ? 3
            : 4;
        final spacing = 8.0;
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var index = 0; index < titles.length; index++)
              SizedBox(
                width: width,
                height: height,
                child: _compactMetricCard(
                  sectionIndex: sectionIndex,
                  title: titles[index],
                  index: index,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _compactMetricCard({
    required int sectionIndex,
    required String title,
    required int index,
  }) {
    const palette = (background: Colors.white, accent: Color(0xFF2463EB));
    final section = _sections[sectionIndex];
    final records = _recordsInSelectedRange(
      _recordsFor(section.key, _permissionSlug(title)),
    );
    final amountRecords = records.where((record) => record.amount != null);
    final recordedAmount = amountRecords.fold<double>(
      0,
      (total, record) => total + record.amount!,
    );
    final currency = amountRecords.isEmpty
        ? 'IQD'
        : amountRecords.first.currency;
    final unavailable = _workspaceError != null;
    final isLoading = _isLoadingRecords;
    final primary = unavailable
        ? '—'
        : isLoading
        ? '…'
        : records.isEmpty
        ? '—'
        : amountRecords.isNotEmpty
        ? '${recordedAmount.toStringAsFixed(0)} $currency'
        : '${records.length}';
    final supporting = unavailable
        ? 'Unavailable'
        : isLoading
        ? 'Loading live data'
        : records.isEmpty
        ? 'No records'
        : amountRecords.isNotEmpty
        ? '${records.length} tracked record(s)'
        : records.length == 1
        ? '1 tracked record'
        : 'Tracked records';
    return Card(
      margin: EdgeInsets.zero,
      color: palette.background,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE4EAF1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() {
          if (sectionIndex == 2) {
            _financeSearch = '';
            _financeStatusFilter = 'All';
          } else if (sectionIndex == 1) {
            _tableSearch = '';
            _tableStatusFilter = 'All';
          }
          _selectedSubcard = title;
        }),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF3FB),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      _metricIcon(title, section.icon),
                      color: palette.accent,
                      size: 18,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: palette.accent, size: 19),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                primary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unavailable ? _muted : palette.accent,
                  fontSize: sectionIndex == 0 ? 14 : 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                supporting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _metricIcon(String title, IconData fallback) => switch (title) {
    'Payment Overview' || 'Payment History' => Icons.receipt_long_outlined,
    'Receive Payment' || 'Owner Cash Out' => Icons.payments_outlined,
    'Expenses Management' => Icons.account_balance_wallet_outlined,
    'Confirm Credit Payment' || 'Confirm Credit' => Icons.credit_score_outlined,
    'Invoices & Receipts' ||
    'Invoices' ||
    'Invoices & Payments' => Icons.receipt_long_outlined,
    'Refunds & Voids' => Icons.undo_rounded,
    'Today Revenue' || 'Revenue' => Icons.bar_chart_rounded,
    'Standing Cash' ||
    'Available Cash' => Icons.account_balance_wallet_outlined,
    'Pending Payment' || 'Pending Payments' => Icons.schedule_rounded,
    'Collected Cash' || 'Cash/Card/Online' => Icons.payments_outlined,
    'Cash Over / Short' => Icons.balance_outlined,
    'Discounts' => Icons.sell_outlined,
    'Credit Accounts' || 'Confirm Credit' => Icons.credit_score_outlined,
    'Tables Occupied' ||
    'Table Occupancy' ||
    'Live Tables' ||
    'Table Availability' => Icons.table_restaurant_outlined,
    'Current Customers' || 'Customers' => Icons.people_outline,
    'Active Tables' || "Today's Tables" => Icons.table_restaurant_outlined,
    "Today's Customers" => Icons.groups_outlined,
    'Table Status' => Icons.grid_view_rounded,
    'Table Map' || 'Visual Table Map' => Icons.map_outlined,
    'Add / Edit Tables' || 'Add/Edit Tables & Chairs' => Icons.add_box_outlined,
    'Chairs Management' || 'Extra Chairs' => Icons.chair_alt_outlined,
    'Table QR Codes' || 'QR Generate/Print/Revoke' => Icons.qr_code_2_outlined,
    'Customer QR Ordering' ||
    'Customer QR Screen' => Icons.qr_code_scanner_outlined,
    'Reservations' || 'Table Reservations' => Icons.calendar_month_outlined,
    'Waiting List' => Icons.access_time_outlined,
    'Cleaning Needed' ||
    'Cleaning' ||
    'Table Cleaning' ||
    'Table Checkout & Cleaning' => Icons.cleaning_services_outlined,
    'Table Requests' ||
    'Table Service Requests' => Icons.notifications_active_outlined,
    'Table Performance' || 'Service Speed' => Icons.bar_chart_rounded,
    'Join / Transfer Tables' || 'Join/Transfer' => Icons.swap_horiz_rounded,
    'Table Payments' ||
    'Split Bills' ||
    'Pay for Others' => Icons.payments_outlined,
    'Table History' => Icons.history_outlined,
    'Table Settings' => Icons.settings_outlined,
    'Kitchen Orders' ||
    'Kitchen Queue' ||
    'Table Orders' => Icons.soup_kitchen_outlined,
    'Kitchen Overview' ||
    'Live Kitchen Orders' ||
    'Kitchen Display' => Icons.soup_kitchen_outlined,
    'Kitchen Preparation' || 'Preparation Time' => Icons.timer_outlined,
    'Ready for Delivery' => Icons.delivery_dining_outlined,
    'Kitchen Staff' => Icons.badge_outlined,
    'Kitchen Reports' => Icons.query_stats_outlined,
    'Kitchen Settings' || 'Menu Settings' => Icons.settings_outlined,
    'Menu Overview' ||
    'Menu' ||
    'Menu Categories' ||
    'Categories Management' ||
    'Menu Management' => Icons.restaurant_menu_outlined,
    'All Products' ||
    'Add / Edit Product' ||
    'Ingredients & Inventory' ||
    'Bulk Import' => Icons.inventory_2_outlined,
    'Menu Pricing' || 'Pricing Modes' => Icons.price_change_outlined,
    'Menu Preview' || 'Kitchen View' => Icons.visibility_outlined,
    'Motel & Online Orders Overview' ||
    'Select Room' ||
    'Room Orders' => Icons.hotel_outlined,
    'New Motel Order' ||
    'New Online Order' ||
    'Order Details' => Icons.add_shopping_cart_outlined,
    'Order Tracking' ||
    'Order History' ||
    'Delivery Schedule' => Icons.local_shipping_outlined,
    'Meal Packages' => Icons.restaurant_menu_outlined,
    'Delivery Areas' => Icons.map_outlined,
    'Payment Options' => Icons.payments_outlined,
    'Inventory Overview' ||
    'All Inventory Items' ||
    'Inventory Categories' ||
    'Inventory Count' ||
    'Inventory History' => Icons.inventory_2_outlined,
    'Add / Edit Inventory Item' || 'Stock In' => Icons.add_box_outlined,
    'Stock Out' ||
    'Low Stock Items' ||
    'Stock Alerts' => Icons.warning_amber_outlined,
    'Purchase Orders' => Icons.shopping_cart_outlined,
    'Suppliers Management' => Icons.local_shipping_outlined,
    'Transfer Stock' => Icons.swap_horiz_outlined,
    'Inventory Reports' ||
    'Inventory Usage Report' => Icons.query_stats_outlined,
    'Inventory Settings' => Icons.settings_outlined,
    'Staff Overview' ||
    'Staff List' ||
    'Add / Edit Employee' => Icons.badge_outlined,
    'Customer Overview' ||
    'Customer List' ||
    'Add Customer' ||
    'Customer Groups' ||
    'Customer QR & Loyalty' => Icons.people_outline,
    'Customer Credit Management' => Icons.credit_score_outlined,
    'Orders History' => Icons.history_outlined,
    'Reservations Overview' ||
    'Event Reservations' ||
    'Motel Reservations' ||
    'Reservations Calendar' ||
    'Online Bookings' ||
    'Waiting List' => Icons.calendar_month_outlined,
    'Table Map & Availability' => Icons.map_outlined,
    'Special Requests' => Icons.notifications_active_outlined,
    'Reservation Reports' => Icons.query_stats_outlined,
    'Reservations Settings' => Icons.settings_outlined,
    'Settings Overview' ||
    'General Settings' ||
    'Restaurant Settings' ||
    'Motel Settings' ||
    'Pricing & Tax Settings' ||
    'Payment Methods' ||
    'Printers & Devices' ||
    'Table & Reservation Settings' ||
    'User Management' ||
    'Notification Settings' ||
    'System & Backup' ||
    'Appearance' ||
    'Integrations' ||
    'About & Update' => Icons.settings_outlined,
    'Notifications Overview' ||
    'Notifications List' ||
    'Notification History' ||
    'System Alerts' => Icons.notifications_none_outlined,
    'Send Notification' ||
    'Notification Templates' ||
    'Notification Groups' ||
    'Automations' ||
    'Notification Channels' ||
    'Notification Reports' ||
    'Quick Actions' => Icons.campaign_outlined,
    'Maintenance Overview' ||
    'Asset Management' ||
    'Work Orders' ||
    'Maintenance Requests' => Icons.build_outlined,
    'Preventive Maintenance' => Icons.event_repeat_outlined,
    'Parts Inventory' => Icons.inventory_2_outlined,
    'Vendors & Service Providers' => Icons.handyman_outlined,
    'Maintenance Reports' => Icons.query_stats_outlined,
    'Maintenance Settings' => Icons.settings_outlined,
    'Daily Operations Overview' ||
    'Table Operations' => Icons.dashboard_customize_outlined,
    'Shift Management' => Icons.schedule_outlined,
    'Task Management' => Icons.task_alt_outlined,
    'Service Flow' || 'Queue Management' => Icons.timeline_outlined,
    'Order Operations' => Icons.receipt_long_outlined,
    'Kitchen Operations' => Icons.soup_kitchen_outlined,
    'Supply & Inventory' => Icons.inventory_2_outlined,
    'Opening / Closing Checklists' => Icons.checklist_outlined,
    'Incident Management' => Icons.report_problem_outlined,
    'Logs & Audit' => Icons.history_outlined,
    'Statistics Overview' ||
    'Sales Statistics' ||
    'Orders Statistics' ||
    'Customer Statistics' ||
    'Table Statistics' ||
    'Product Statistics' ||
    'Payment Statistics' ||
    'Employee Statistics' ||
    'Motel Orders Statistics' ||
    'Online Orders Statistics' ||
    'Time & Trends' ||
    'Custom Reports' => Icons.query_stats_outlined,
    'Low Stock' ||
    'Inventory' ||
    'Inventory & Stock' => Icons.inventory_2_outlined,
    'Nargile Management' || 'Nargile' => Icons.smoking_rooms_outlined,
    'Kitchen Devices' || 'Devices & Printers' => Icons.print_outlined,
    'Online Orders' => Icons.language_outlined,
    'Motel Orders' => Icons.hotel_outlined,
    'Takeaway & Delivery' => Icons.delivery_dining_outlined,
    'Reports & Analytics' => Icons.query_stats_outlined,
    'System Health' => Icons.monitor_heart_outlined,
    'Security Center' => Icons.shield_outlined,
    'Permissions & Roles' => Icons.admin_panel_settings_outlined,
    'Audit & Activity History' => Icons.history_outlined,
    'Backup & Restore' => Icons.backup_outlined,
    'Offline & Sync' => Icons.sync_outlined,
    'System Updates' => Icons.system_update_alt_outlined,
    'Settings & Configuration' => Icons.settings_outlined,
    'Customers' || 'Customer Directory' => Icons.people_outline,
    'Employees' || 'Staff Directory' => Icons.badge_outlined,
    'Tasks' => Icons.task_alt_outlined,
    'Events' => Icons.event_outlined,
    'Reports' || 'Revenue Reports' => Icons.query_stats_outlined,
    'Security' => Icons.shield_outlined,
    'Backup' => Icons.backup_outlined,
    'Offline Mode' => Icons.wifi_off_outlined,
    'Expenses' || 'Costs & Expenses' => Icons.receipt_long_outlined,
    'Refunds & Voids' || 'Refunds' => Icons.undo_rounded,
    'Table Income' => Icons.table_restaurant_outlined,
    _ => fallback,
  };

  Widget _tableManagementDetail(
    ({String key, IconData icon, String title, String description}) section,
    String subcard,
  ) {
    final subcardKey = _permissionSlug(subcard);
    final records = _recordsFor(section.key, subcardKey);
    final canManage =
        widget.role == 'admin' ||
        widget.grantedPermissions.contains('${section.key}:*') ||
        widget.grantedPermissions.contains('${section.key}:$subcardKey');
    final statusCounts = {
      'open': records.where((record) => record.status == 'open').length,
      'in_progress': records
          .where((record) => record.status == 'in_progress')
          .length,
      'completed': records
          .where((record) => record.status == 'completed')
          .length,
    };
    final query = _tableSearch.trim().toLowerCase();
    final filteredRecords = records
        .where((record) {
          final matchesStatus =
              _tableStatusFilter == 'All' ||
              record.status ==
                  _tableStatusFilter.toLowerCase().replaceAll(' ', '_');
          final matchesSearch =
              query.isEmpty ||
              record.title.toLowerCase().contains(query) ||
              record.details.toLowerCase().contains(query);
          return matchesStatus && matchesSearch;
        })
        .toList(growable: false);
    final description =
        _sectionCardDescriptions[subcard] ??
        'Table-management workspace records for $subcard.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF4FF),
            border: Border.all(color: const Color(0xFFD4E6FA)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                _workspaceError == null
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                color: const Color(0xFF2463D3),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _workspaceError ??
                      'Tracked records for this card only. '
                          'No sample table data is shown.',
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 420 ? 1 : 3;
            final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _tableSummaryCard(
                  width: width,
                  label: 'Tracked records',
                  value: _isLoadingRecords ? '…' : '${records.length}',
                  icon: Icons.table_restaurant_outlined,
                  color: const Color(0xFF2463D3),
                ),
                _tableSummaryCard(
                  width: width,
                  label: 'Open records',
                  value: _isLoadingRecords ? '…' : '${statusCounts['open']}',
                  icon: Icons.schedule_outlined,
                  color: const Color(0xFFD07813),
                ),
                _tableSummaryCard(
                  width: width,
                  label: 'Completed records',
                  value: _isLoadingRecords
                      ? '…'
                      : '${statusCounts['completed']}',
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF16814A),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (value) => setState(() => _tableSearch = value),
          decoration: InputDecoration(
            hintText: 'Search $subcard records...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE1E7EF)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final status in const [
                'All',
                'Open',
                'In progress',
                'Completed',
                'Cancelled',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(status),
                    selected: _tableStatusFilter == status,
                    onSelected: (_) =>
                        setState(() => _tableStatusFilter = status),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                description,
                style: const TextStyle(color: _muted, height: 1.4),
              ),
            ),
            if (canManage)
              FilledButton.icon(
                onPressed: _isLoadingRecords || _workspaceError != null
                    ? null
                    : () => _createWorkspaceRecord(section, subcard),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add record'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_workspaceError != null)
          _AuthErrorMessage(_workspaceError!)
        else if (_isLoadingRecords)
          const Center(child: CircularProgressIndicator())
        else if (filteredRecords.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Center(
              child: Text(
                records.isEmpty
                    ? 'No saved records for this card yet.'
                    : 'No records match the current search or status filter.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted),
              ),
            ),
          )
        else
          for (final record in filteredRecords)
            _workspaceRecordTile(record, canManage: canManage),
      ],
    );
  }

  Widget _tableSummaryCard({
    required double width,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(color: _muted)),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _financeDetail(
    ({String key, IconData icon, String title, String description}) section,
    String subcard,
  ) {
    final subcardKey = _permissionSlug(subcard);
    final canManage =
        widget.role == 'admin' ||
        widget.grantedPermissions.contains('${section.key}:*') ||
        widget.grantedPermissions.contains('${section.key}:$subcardKey');
    final records = _recordsInSelectedRange(
      _recordsFor(section.key, subcardKey),
    );
    final matchingRecords = records
        .where((record) {
          final matchesStatus =
              _financeStatusFilter == 'All' ||
              record.status ==
                  _financeStatusFilter.toLowerCase().replaceAll(' ', '_');
          final query = _financeSearch.trim().toLowerCase();
          final matchesQuery =
              query.isEmpty ||
              record.title.toLowerCase().contains(query) ||
              record.details.toLowerCase().contains(query);
          return matchesStatus && matchesQuery;
        })
        .toList(growable: false);
    final amountRecords = records.where((record) => record.amount != null);
    final amountTotal = amountRecords.fold<double>(
      0,
      (total, record) => total + record.amount!,
    );
    final openCount = records
        .where(
          (record) => record.status == 'open' || record.status == 'in_progress',
        )
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _dateRangeControls()),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: _workspaceError == null
                    ? const Color(0xFFE1F6EA)
                    : const Color(0xFFFFE8E6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _workspaceError == null ? '● Live' : 'Unavailable',
                style: TextStyle(
                  color: _workspaceError == null
                      ? const Color(0xFF167344)
                      : const Color(0xFFB42318),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _financeSummaryCard(
              icon: Icons.receipt_long_outlined,
              label: 'Tracked records',
              value: _isLoadingRecords ? '…' : '${records.length}',
              tint: const Color(0xFFEAF2FF),
              accent: const Color(0xFF2563D9),
            ),
            _financeSummaryCard(
              icon: Icons.payments_outlined,
              label: 'Recorded amount',
              value: amountRecords.isEmpty
                  ? '—'
                  : '${amountTotal.toStringAsFixed(0)} ${amountRecords.first.currency}',
              tint: const Color(0xFFE8F8EF),
              accent: const Color(0xFF16814A),
            ),
            _financeSummaryCard(
              icon: Icons.schedule_outlined,
              label: 'Open records',
              value: '$openCount',
              tint: const Color(0xFFFFF2D8),
              accent: const Color(0xFFB9670C),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE1E7EF)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$subcard records',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (canManage)
                    FilledButton.icon(
                      onPressed: _isLoadingRecords || _workspaceError != null
                          ? null
                          : () => _createWorkspaceRecord(section, subcard),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add record'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (value) => setState(() => _financeSearch = value),
                decoration: InputDecoration(
                  hintText: 'Search $subcard...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF6F8FB),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final status in const [
                      'All',
                      'Open',
                      'In progress',
                      'Completed',
                      'Cancelled',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(status),
                          selected: _financeStatusFilter == status,
                          onSelected: (_) =>
                              setState(() => _financeStatusFilter = status),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              if (_workspaceError != null)
                _AuthErrorMessage(_workspaceError!)
              else if (_isLoadingRecords)
                const Center(child: CircularProgressIndicator())
              else if (matchingRecords.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 34,
                          color: Colors.blueGrey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          records.isEmpty
                              ? 'No live records for this date range.'
                              : 'No records match these filters.',
                          style: const TextStyle(color: _muted),
                        ),
                        if (canManage && records.isEmpty) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Add a record to begin tracking this card.',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                for (final record in matchingRecords)
                  _financeRecordTile(record, canManage: canManage),
              if (amountRecords.isNotEmpty) ...[
                const Divider(height: 22),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    'Tracked amount total · ${amountTotal.toStringAsFixed(0)} ${amountRecords.first.currency}',
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              const Text(
                'Totals include only records saved in this workspace. They are '
                'not reconciled against a payment provider or cash register.',
                style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _financeSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color tint,
    required Color accent,
  }) => Container(
    width: 150,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withValues(alpha: 0.12)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: accent, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: accent,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 2,
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _financeRecordTile(
    CafeWorkspaceRecord record, {
    required bool canManage,
  }) {
    final statusColor = switch (record.status) {
      'completed' => const Color(0xFF16814A),
      'cancelled' => const Color(0xFFB42318),
      'in_progress' => const Color(0xFF2563D9),
      _ => const Color(0xFFB9670C),
    };
    return Container(
      key: ValueKey('finance-record-${record.id}'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFDFE),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE6EBF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: Color(0xFF2563D9),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Updated ${record.updatedAt.toLocal().toString().substring(0, 16)}',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (record.amount != null)
                Text(
                  '${record.amount!.toStringAsFixed(0)} ${record.currency}',
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (canManage)
                PopupMenuButton<String>(
                  tooltip: 'Record actions',
                  onSelected: (action) {
                    if (action == 'delete') {
                      unawaited(_deleteWorkspaceRecord(record));
                    } else {
                      unawaited(_updateRecordStatus(record, action));
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'open', child: Text('Mark open')),
                    PopupMenuItem(
                      value: 'in_progress',
                      child: Text('Mark in progress'),
                    ),
                    PopupMenuItem(
                      value: 'completed',
                      child: Text('Mark completed'),
                    ),
                    PopupMenuItem(
                      value: 'cancelled',
                      child: Text('Mark cancelled'),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete record'),
                    ),
                  ],
                ),
            ],
          ),
          if (record.details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(record.details, style: const TextStyle(color: _muted)),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              record.status.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _managementCard(
    int sectionIndex,
    String title, {
    double? revenue,
    bool revenueUnavailable = false,
  }) {
    final section = _sections[sectionIndex];
    final isRevenueCard = sectionIndex == 0 && title == _subcards.first.first;
    final subcardKey = _permissionSlug(title);
    final records = _recordsFor(section.key, subcardKey);
    const palette = (background: Colors.white, accent: Color(0xFF2463EB));
    final recordCountLabel = _isLoadingRecords
        ? 'Connecting...'
        : _workspaceError != null
        ? 'Unavailable'
        : records.isEmpty
        ? sectionIndex == 1
              ? '0 records'
              : '0 tracked records'
        : '${records.length} ${sectionIndex == 1 ? 'records' : 'record${records.length == 1 ? '' : 's'}'}';
    final primaryText = isRevenueCard
        ? revenueUnavailable
              ? '— IQD'
              : '${revenue!.toStringAsFixed(0)} IQD'
        : recordCountLabel;
    final secondaryText = isRevenueCard
        ? revenueUnavailable
              ? _connectionLabel(section.key, subcardKey)
              : 'Tracked records only · excludes unrecorded sales'
        : _sectionCardDescriptions[title] ?? 'Live Supabase records';
    return SizedBox(
      height: 176,
      child: Card(
        margin: EdgeInsets.zero,
        color: palette.background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE4EAF1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() {
            _tableSearch = '';
            _tableStatusFilter = 'All';
            _workspaceSearch = '';
            _workspaceStatusFilter = 'All';
            _selectedSubcard = title;
          }),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF3FB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _metricIcon(title, section.icon),
                        color: palette.accent,
                        size: 19,
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Icon(
                          Icons.chevron_right,
                          color: palette.accent,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  maxLines: sectionIndex == 1 ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _ink,
                    fontSize: sectionIndex == 1 ? 12 : 14,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  secondaryText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  primaryText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: revenueUnavailable && isRevenueCard
                        ? _muted
                        : palette.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _subcardDetail(
    ({String key, IconData icon, String title, String description}) section,
    String subcard,
  ) {
    final subcardKey = _permissionSlug(subcard);
    final records = _recordsFor(section.key, subcardKey);
    final canManage =
        widget.role == 'admin' ||
        widget.grantedPermissions.contains('${section.key}:*') ||
        widget.grantedPermissions.contains('${section.key}:$subcardKey');
    final query = _workspaceSearch.trim().toLowerCase();
    final filteredRecords = records
        .where((record) {
          final matchesStatus =
              _workspaceStatusFilter == 'All' ||
              record.status ==
                  _workspaceStatusFilter.toLowerCase().replaceAll(' ', '_');
          final matchesSearch =
              query.isEmpty ||
              record.title.toLowerCase().contains(query) ||
              record.details.toLowerCase().contains(query);
          return matchesStatus && matchesSearch;
        })
        .toList(growable: false);
    final openCount = records
        .where(
          (record) => record.status == 'open' || record.status == 'in_progress',
        )
        .length;
    final completedCount = records
        .where((record) => record.status == 'completed')
        .length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4EAF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(section.icon, color: const Color(0xFF4166A3), size: 22),
          const SizedBox(height: 8),
          Text(
            '$subcard records',
            style: const TextStyle(
              color: _navy,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _workspaceError ??
                'Live Supabase records for this card. Records and status '
                    'changes are visible to users authorized for this card.',
            style: const TextStyle(color: _muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (canManage)
                FilledButton.icon(
                  onPressed: _isLoadingRecords || _workspaceError != null
                      ? null
                      : () => _createWorkspaceRecord(section, subcard),
                  icon: const Icon(Icons.add),
                  label: const Text('Add record'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _financeSummaryCard(
                icon: section.icon,
                label: 'Tracked records',
                value: _isLoadingRecords ? '…' : '${records.length}',
                tint: Colors.white,
                accent: const Color(0xFF4166A3),
              ),
              _financeSummaryCard(
                icon: Icons.schedule_outlined,
                label: 'Open records',
                value: _isLoadingRecords ? '…' : '$openCount',
                tint: Colors.white,
                accent: const Color(0xFFB9670C),
              ),
              _financeSummaryCard(
                icon: Icons.check_circle_outline,
                label: 'Completed records',
                value: _isLoadingRecords ? '…' : '$completedCount',
                tint: Colors.white,
                accent: const Color(0xFF16814A),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => setState(() => _workspaceSearch = value),
            decoration: InputDecoration(
              hintText: 'Search $subcard...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFFF6F8FB),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final status in const [
                  'All',
                  'Open',
                  'In progress',
                  'Completed',
                  'Cancelled',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: _workspaceStatusFilter == status,
                      onSelected: (_) =>
                          setState(() => _workspaceStatusFilter = status),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_workspaceError != null)
            _AuthErrorMessage(_workspaceError!)
          else if (_isLoadingRecords)
            const Center(child: CircularProgressIndicator())
          else if (filteredRecords.isEmpty)
            const Text(
              'No records match this card and its current filters.',
              style: TextStyle(color: _muted),
            )
          else
            for (final record in filteredRecords)
              _workspaceRecordTile(record, canManage: canManage),
        ],
      ),
    );
  }

  Widget _workspaceRecordTile(
    CafeWorkspaceRecord record, {
    required bool canManage,
  }) {
    return Card(
      key: ValueKey('workspace-record-${record.id}'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (record.amount != null)
                  Text(
                    '${record.amount!.toStringAsFixed(2)} ${record.currency}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                if (canManage)
                  IconButton(
                    tooltip: 'Delete ${record.title}',
                    onPressed: () => _deleteWorkspaceRecord(record),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            if (record.details.isNotEmpty) Text(record.details),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Updated ${record.updatedAt.toLocal().toString().substring(0, 16)}',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
                if (canManage)
                  DropdownButton<String>(
                    value: record.status,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'open', child: Text('Open')),
                      DropdownMenuItem(
                        value: 'in_progress',
                        child: Text('In progress'),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Completed'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text('Cancelled'),
                      ),
                    ],
                    onChanged: (status) {
                      if (status != null && status != record.status) {
                        unawaited(_updateRecordStatus(record, status));
                      }
                    },
                  )
                else
                  Chip(label: Text(record.status.replaceAll('_', ' '))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StaffSignInDialog extends StatefulWidget {
  const StaffSignInDialog({
    required this.supabaseConfigured,
    required this.supabaseConfigurationProvided,
    super.key,
  });

  final bool supabaseConfigured;
  final bool supabaseConfigurationProvided;

  @override
  State<StaffSignInDialog> createState() => _StaffSignInDialogState();
}

class _StaffSignInDialogState extends State<StaffSignInDialog> {
  final _formKey = GlobalKey<FormState>();
  final _mfaFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mfaCodeController = TextEditingController();
  String? _error;
  String? _mfaFactorId;
  String? _mfaEnrollmentSecret;
  bool? _isAdmin;
  bool _mfaPending = false;
  bool _isLoadingRole = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (_signedInEmail != null) {
      unawaited(_continueAuthenticatedSession());
    }
  }

  String? get _signedInEmail => widget.supabaseConfigured
      ? Supabase.instance.client.auth.currentUser?.email
      : null;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _mfaCodeController.dispose();
    super.dispose();
  }

  Future<void> _continueAuthenticatedSession() async {
    final auth = Supabase.instance.client.auth;
    final assurance = auth.mfa.getAuthenticatorAssuranceLevel();
    if (assurance.currentLevel == AuthenticatorAssuranceLevels.aal2) {
      if (mounted) setState(() => _mfaPending = false);
      await _loadStaffRole();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _mfaPending = true;
      _error = null;
    });
    try {
      final factors = await auth.mfa.listFactors();
      if (factors.totp.isNotEmpty) {
        setState(() => _mfaFactorId = factors.totp.first.id);
      } else {
        final enrollment = await auth.mfa.enroll(
          factorType: FactorType.totp,
          issuer: 'Gelye Sherane Cafe',
          friendlyName: 'Gelye Sherane staff sign-in',
        );
        final totp = enrollment.totp;
        if (totp == null) {
          throw const AuthException(
            'Supabase did not return authenticator enrollment details.',
          );
        }
        if (!mounted) return;
        setState(() {
          _mfaFactorId = enrollment.id;
          _mfaEnrollmentSecret = totp.secret;
        });
      }
    } on AuthException {
      if (mounted) {
        setState(() {
          _error =
              'Could not set up authenticator verification. Check that '
              'authenticator-app MFA is enabled for this Supabase project.';
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _error =
              'Could not reach the authenticator service. Check your '
              'connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _verifyMfaCode() async {
    if (!_mfaFormKey.currentState!.validate()) return;
    final factorId = _mfaFactorId;
    if (factorId == null) {
      setState(() {
        _error = 'Authenticator setup is missing. Sign out and sign in again.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.mfa.challengeAndVerify(
        factorId: factorId,
        code: _mfaCodeController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _mfaFactorId = null;
        _mfaEnrollmentSecret = null;
        _mfaPending = false;
        _mfaCodeController.clear();
      });
      await _loadStaffRole();
    } on AuthException {
      if (mounted) {
        setState(() {
          _error =
              'That authenticator code was not accepted. Enter the current '
              'six-digit code and try again.';
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _error =
              'Could not verify the authenticator code. Check your '
              'connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _loadStaffRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingRole = true;
      _isAdmin = null;
      _error = null;
    });
    try {
      final profile = await Supabase.instance.client
          .from('staff_profiles')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();

      if (profile == null) {
        if (!mounted) return;
        setState(() {
          _error =
              'No staff profile exists for this account. Run the staff '
              'migration and admin bootstrap SQL in the Supabase project '
              'configured for this site.';
        });
        return;
      }

      if (!mounted) return;
      final role = profile['role'];
      if (role is! String || (role != 'admin' && role != 'staff')) {
        setState(() {
          _error = 'This account does not have a valid staff role.';
        });
        return;
      }
      final grantedPermissions = <String>{};
      String? permissionsLoadError;
      if (role == 'staff') {
        try {
          final permissionRows = await Supabase.instance.client
              .from('staff_permissions')
              .select('section_key, subcard_key')
              .eq('user_id', user.id);
          for (final row in permissionRows) {
            final sectionKey = row['section_key'];
            final subcardKey = row['subcard_key'];
            if (sectionKey is! String || subcardKey is! String) {
              throw const FormatException(
                'The permission service returned an invalid grant.',
              );
            }
            grantedPermissions.add('$sectionKey:$subcardKey');
          }
        } on PostgrestException catch (exception) {
          permissionsLoadError =
              '(${exception.code ?? 'unknown'}): ${exception.message}';
          grantedPermissions.clear();
        } on Exception catch (exception) {
          permissionsLoadError = exception.toString();
          grantedPermissions.clear();
        }
      }

      if (!mounted) return;
      setState(() {
        _isAdmin = role == 'admin';
      });
      await Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) => StaffDashboardPage(
            email: user.email ?? '',
            role: role,
            grantedPermissions: grantedPermissions,
            permissionsLoadError: permissionsLoadError,
          ),
        ),
        (route) => route.isFirst,
      );
    } on PostgrestException catch (exception) {
      if (mounted) {
        setState(() {
          _error =
              'Could not load staff permissions from Supabase '
              '(${exception.code ?? 'unknown'}): ${exception.message}';
        });
      }
    } on Exception catch (exception) {
      if (mounted) {
        setState(() {
          _error = 'Could not open the staff dashboard: $exception';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingRole = false);
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (response.session == null || response.user == null) {
        setState(() {
          _error = 'Sign-in did not create an authenticated session.';
        });
      } else {
        setState(() {});
        await _continueAuthenticatedSession();
      }
    } on AuthException {
      if (mounted) {
        setState(() {
          _error =
              'Sign-in or authenticator setup failed. Check your credentials '
              'and MFA settings, then try again.';
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _error = 'Could not reach the sign-in service. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        setState(() {
          _isAdmin = null;
          _error = null;
          _mfaFactorId = null;
          _mfaEnrollmentSecret = null;
          _mfaPending = false;
          _mfaCodeController.clear();
        });
      }
    } on AuthException {
      if (mounted) {
        setState(() {
          _error = 'Sign-out failed. Please try again.';
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _error = 'Could not reach the sign-in service. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedInEmail = _signedInEmail;
    return AlertDialog(
      icon: const Icon(Icons.lock_outline, color: _gold),
      title: Text(signedInEmail == null ? 'Staff sign in' : 'Staff account'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: !widget.supabaseConfigured
              ? _configurationMessage()
              : signedInEmail != null
              ? _mfaPending
                    ? _mfaFactorId != null
                          ? _mfaVerificationForm()
                          : _mfaSetupError()
                    : _signedInContent(signedInEmail)
              : _signInForm(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : _mfaPending
              ? _signOut
              : () => Navigator.of(context).pop(),
          child: Text(
            signedInEmail == null
                ? 'Close'
                : _mfaPending
                ? 'Sign out'
                : 'Done',
          ),
        ),
        if (widget.supabaseConfigured &&
            signedInEmail != null &&
            _mfaPending &&
            _mfaFactorId != null)
          FilledButton(
            onPressed: _isSubmitting ? null : _verifyMfaCode,
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verify code'),
          ),
        if (widget.supabaseConfigured && signedInEmail != null && !_mfaPending)
          FilledButton(
            onPressed: _isSubmitting ? null : _signOut,
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign out'),
          ),
        if (widget.supabaseConfigured && signedInEmail == null)
          FilledButton(
            onPressed: _isSubmitting ? null : _signIn,
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign in'),
          ),
      ],
    );
  }

  Widget _configurationMessage() {
    final message = widget.supabaseConfigurationProvided
        ? 'Supabase configuration is incomplete or does not match the approved '
              'project. Check the deployment variables before signing in.'
        : 'Staff sign-in is not configured for this deployment yet. Add the '
              'Supabase project URL, expected project reference, and publishable '
              'key to the deployment settings.';
    return Text(message, style: const TextStyle(height: 1.5));
  }

  Widget _signedInContent(String email) {
    if (_isLoadingRole) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Signed in as $email.'),
        const SizedBox(height: 12),
        if (_isAdmin == true) ...[
          const Text(
            'Administrator access',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            'Create staff accounts from the management workspace so you can '
            'assign their section and card permissions.',
            style: TextStyle(color: _muted, height: 1.45),
          ),
        ] else
          const Text(
            'This account does not have an administrator role. The first '
            'administrator must be assigned by the project owner.',
            style: TextStyle(color: _muted, height: 1.45),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _AuthErrorMessage(_error!),
        ],
      ],
    );
  }

  Widget _mfaVerificationForm() {
    return Form(
      key: _mfaFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _mfaEnrollmentSecret == null
                ? 'Enter the current code from your authenticator app.'
                : 'Add this account to an authenticator app, then enter its '
                      'current code to finish setup.',
            style: const TextStyle(color: _muted, height: 1.45),
          ),
          if (_mfaEnrollmentSecret case final secret?) ...[
            const SizedBox(height: 12),
            const Text(
              'Account setup key',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            SelectableText(secret),
            const SizedBox(height: 8),
            const Text(
              'Keep this setup key private. After setup, use the rotating '
              'six-digit code from your authenticator app.',
              style: TextStyle(color: _muted, height: 1.4),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _mfaCodeController,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Authenticator code',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.security),
              counterText: '',
            ),
            validator: (value) =>
                value == null || !RegExp(r'^\d{6}$').hasMatch(value.trim())
                ? 'Enter the six-digit authenticator code'
                : null,
            onFieldSubmitted: (_) => _isSubmitting ? null : _verifyMfaCode(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _AuthErrorMessage(_error!),
          ],
        ],
      ),
    );
  }

  Widget _mfaSetupError() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Authenticator verification is required before staff access. The '
          'authenticator setup could not be prepared. Sign out and try again.',
          style: TextStyle(color: _muted, height: 1.45),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _AuthErrorMessage(_error!),
        ],
      ],
    );
  }

  Widget _signInForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Use your staff account to continue.',
              style: TextStyle(color: _muted, height: 1.4),
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _emailController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Staff email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (!email.contains('@') || !email.contains('.')) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.password_outlined),
            ),
            validator: (value) =>
                value == null || value.isEmpty ? 'Enter your password' : null,
            onFieldSubmitted: (_) => _isSubmitting ? null : _signIn(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _AuthErrorMessage(_error!),
          ],
        ],
      ),
    );
  }
}

class _AuthErrorMessage extends StatelessWidget {
  const _AuthErrorMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }
}
