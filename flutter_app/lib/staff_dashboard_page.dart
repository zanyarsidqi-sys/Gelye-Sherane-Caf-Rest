import 'cafe_inventory_workspace.dart';
import 'cafe_people_workspace.dart';
import 'cafe_staff_tasks.dart';
import 'cafe_report_library.dart';
import 'cafe_table_maintenance.dart';
import 'cafe_dashboard_employees.dart';
import 'cafe_service_speed.dart';
import 'cafe_reservation_filters.dart';
import 'cafe_dashboard_fulfilment.dart';
import 'cafe_waiting_list.dart';
import 'cafe_customer_number.dart';
import 'cafe_finance_surface.dart';
import 'cafe_dashboard_menu.dart';
import 'cafe_dashboard_tables.dart';
import 'cafe_language.dart';
import 'cafe_menu_assets.dart';
import 'dart:async';
import 'workspace_reporting.dart';
import 'favorites_page.dart';
import 'cafe_menu_workspace.dart';
import 'cafe_station_workspace.dart';
import 'cafe_operations_workspace.dart';
import 'cafe_table_overview.dart';
import 'cafe_operational_report.dart';
import 'cafe_cash_workspace.dart';
import 'cafe_expense_workspace.dart';
import 'expense_evidence.dart';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cafe_request_id.dart';
import 'cafe_workspace_repository.dart';
import 'cafe_dining_table_repository.dart';
import 'cafe_table_reservation_repository.dart';
import 'cafe_table_chair_repository.dart';

const _navy = Color(0xFF12253F);
const _deepNavy = Color(0xFF0B1728);
const _gold = Color(0xFFD6AA57);
const _ink = Color(0xFF18283F);
const _muted = Color(0xFF61718A);
const _executiveSurface = Color(0xFF14243A);
const _executiveBorder = Color(0xFF30435A);
const _executiveText = Color(0xFFF6F2E9);
const _executiveMuted = Color(0xFFB7C2D1);
const _executiveWorkspacePanel = Color(0xFF101E31);

const _executiveCardPalettes = <({Color background, Color accent})>[
  (background: Color(0xFF162A43), accent: Color(0xFF60A5FA)),
  (background: Color(0xFF251C38), accent: Color(0xFFC084FC)),
  (background: Color(0xFF173329), accent: Color(0xFF34D399)),
  (background: Color(0xFF382819), accent: Color(0xFFFB923C)),
  (background: Color(0xFF39212A), accent: Color(0xFFF87171)),
  (background: Color(0xFF14343A), accent: Color(0xFF2DD4BF)),
];

({Color background, Color accent}) _executiveCardPalette(int index) =>
    _executiveCardPalettes[index % _executiveCardPalettes.length];

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

const _tablesChairsCategories = [
  (
    title: 'Table Management',
    cards: [
      'Add Table',
      'Edit & Manage Tables',
      'Table Map',
      'QR Code Management',
      'Chairs Management',
    ],
  ),
  (
    title: 'Reservations & Availability',
    cards: [
      'Table Reservations',
      'Table Availability',
      'Live Tables',
      'Table Status',
      'Join & Split Tables',
      'Extra Chairs Requests',
      'Reservation Waiting List',
      'Guest Check-In & No-Show',
      'Table Assignment',
    ],
  ),
  (
    title: 'Customer Service',
    cards: [
      'Table Transfer',
      'Table Cleaning',
      'Table Session Management',
      'Waiter Table Assignment',
      'Table Service Requests',
      'Table Ordering',
    ],
  ),
  (
    title: 'Administration',
    cards: [
      'Table Maintenance',
      'Table History & Audit',
      'Table Reports',
      'Table Settings',
      'Table Permissions',
      'Table Alerts & Notifications',
    ],
  ),
];

const _menuManagementCategories = [
  (
    title: 'Menu & Products',
    icon: Icons.restaurant_menu_outlined,
    cards: [
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
  ),
  (
    title: 'Pricing & Discounts',
    icon: Icons.price_change_outlined,
    cards: [
      'Normal Pricing',
      'Tourism Pricing',
      'Owner Pricing',
      'Discount Pricing',
      'Price Change History',
      'Pricing Rules & Approvals',
      'Product Cost & Profit Margin',
      'Happy Hour & Promotions',
    ],
  ),
  (
    title: 'Kitchen & Minibar Integration',
    icon: Icons.soup_kitchen_outlined,
    cards: [
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
  ),
  (
    title: 'Digital Menu',
    icon: Icons.qr_code_2_outlined,
    cards: [
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
  ),
  (
    title: 'Inventory & Performance',
    icon: Icons.inventory_2_outlined,
    cards: [
      'Product Stock Integration',
      'Out-of-Stock Management',
      'Product Sales & Performance',
      'Product Feedback & Ratings',
      'Product Recommendations',
      'Menu Reports',
      'Product Waste & Returns',
    ],
  ),
  (
    title: 'Administration',
    icon: Icons.admin_panel_settings_outlined,
    cards: [
      'Menu Permissions',
      'Menu Settings',
      'Menu Audit History',
      'Menu Import & Export',
      'Product Change Approval',
    ],
  ),
];

const _kitchenManagementCategories = [
  (
    title: 'Kitchen Overview',
    icon: Icons.dashboard_outlined,
    cards: [
      'Kitchen Overview',
      'Kitchen Reports',
      'Kitchen Performance & Timing',
    ],
  ),
  (
    title: 'Live Kitchen Board',
    icon: Icons.view_kanban_outlined,
    cards: [
      'Table Orders',
      'Motel Orders',
      'Online Orders',
      'Status of All Orders',
      'Live Kitchen Orders',
      'Kitchen Orders',
      'Kitchen Display',
      'Kitchen Priority & Delays',
    ],
  ),
  (
    title: 'Orders & Preparation',
    icon: Icons.soup_kitchen_outlined,
    cards: [
      'Order Details',
      'Kitchen Preparation',
      'Ready for Delivery',
      'Order Modification & Cancellation',
      'Kitchen Quality Control',
    ],
  ),
  (
    title: 'Kitchen Operations',
    icon: Icons.settings_outlined,
    cards: [
      'Kitchen Stations Management',
      'Kitchen Printing Management',
      'Kitchen Handover',
      'Kitchen Waste & Spoilage',
    ],
  ),
  (
    title: 'Menu & Staff',
    icon: Icons.restaurant_menu_outlined,
    cards: [
      'Menu Availability',
      'Kitchen Staff',
      'Kitchen Inventory & Ingredients',
    ],
  ),
  (
    title: 'Minibar Management',
    icon: Icons.local_cafe_outlined,
    cards: [
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
  ),
  (
    title: 'Administration',
    icon: Icons.admin_panel_settings_outlined,
    cards: ['Kitchen Settings'],
  ),
];

const _kitchenCardPurposes = <String, String>{
  'Kitchen Overview': 'View kitchen workload, order status and exceptions.',
  'Kitchen Reports': 'Review authorized historical kitchen performance.',
  'Kitchen Performance & Timing':
      'Measure defined preparation and handover intervals.',
  'Table Orders': 'Kitchen view of food items from table orders.',
  'Motel Orders': 'Kitchen view of eligible motel food orders.',
  'Online Orders': 'Kitchen view of eligible online food orders.',
  'Status of All Orders':
      'Search kitchen orders by source, station and status.',
  'Live Kitchen Orders': 'Monitor the active kitchen queue.',
  'Kitchen Orders': 'Review kitchen order history and ticket details.',
  'Kitchen Display': 'Touch-friendly display for kitchen order work.',
  'Kitchen Priority & Delays': 'Review priority, delay and escalation records.',
  'Order Details': 'Review order items, notes and revision history.',
  'Kitchen Preparation': 'Track kitchen preparation and item readiness.',
  'Ready for Delivery': 'Review completed items awaiting handover.',
  'Order Modification & Cancellation':
      'Review authorized order changes and cancellations.',
  'Kitchen Quality Control': 'Record kitchen quality checks and rework.',
  'Kitchen Stations Management': 'Manage kitchen preparation stations.',
  'Kitchen Printing Management':
      'Configure and monitor kitchen ticket routing.',
  'Kitchen Handover': 'Record ready-item pickup and handover.',
  'Kitchen Waste & Spoilage': 'Record waste and spoilage for review.',
  'Menu Availability': 'Review kitchen item availability.',
  'Kitchen Staff': 'Review kitchen staff and station assignments.',
  'Kitchen Inventory & Ingredients': 'Review kitchen ingredient availability.',
  'Minibar Overview': 'View minibar workload for drinks and Nargile.',
  'Nargile Products & Flavors': 'Manage minibar Nargile product options.',
  'Café Drinks & Beverages': 'Manage café beverage options.',
  'Product Assignment to Stations': 'Assign eligible products to stations.',
  'Nargile Preparation & Orders': 'Track Nargile preparation and handover.',
  'Drinks Preparation & Orders': 'Track beverage preparation and handover.',
  'Minibar Inventory & Ingredients':
      'Review minibar ingredients and inventory links.',
  'Equipment & Maintenance': 'Track minibar equipment and maintenance.',
  'Minibar Staff & Assignments': 'Review minibar staff and assignments.',
  'Minibar Sales & Reports': 'Review authorized minibar sales reports.',
  'Minibar Stations Management': 'Manage minibar preparation stations.',
  'Minibar Printing Management':
      'Configure and monitor minibar ticket routing.',
  'Kitchen Settings': 'Review kitchen workflow configuration.',
};

const _motelOrdersCategories = [
  (
    title: 'Overview',
    icon: Icons.dashboard_outlined,
    cards: [
      'Motel & Online Orders Overview',
      'Order Tracking',
      'Order History',
      'Order Details',
    ],
  ),
  (
    title: 'Motel Orders',
    icon: Icons.hotel_outlined,
    cards: [
      'Select Room',
      'New Motel Order',
      'Room Orders',
      'Motel Orders',
      'Meal Packages',
      'Motel Orders Settings',
    ],
  ),
  (
    title: 'Online Orders',
    icon: Icons.language_outlined,
    cards: [
      'New Online Order',
      'Online Orders',
      'Delivery Schedule',
      'Delivery Areas',
    ],
  ),
  (
    title: 'Walk-In Orders',
    icon: Icons.shopping_bag_outlined,
    cards: [
      'New Walk-In Order',
      'Active Walk-In Orders',
      'Ready for Pickup',
      'Walk-In Order History',
    ],
  ),
  (
    title: 'Payments & Administration',
    icon: Icons.receipt_long_outlined,
    cards: ['Invoices & Receipts', 'Payment Options'],
  ),
];

const _motelOrderPurposes = <String, String>{
  'Motel & Online Orders Overview':
      'Review saved motel, online and walk-in order records.',
  'Order Tracking': 'Search existing order records and their saved statuses.',
  'Order History': 'Review saved order history records.',
  'Order Details': 'Review saved order detail records.',
  'Select Room': 'Review room availability records.',
  'New Motel Order': 'Create a motel order record.',
  'Room Orders': 'Review order records associated with rooms.',
  'Motel Orders': 'Review motel-origin order records.',
  'Meal Packages': 'Review motel meal package records.',
  'Motel Orders Settings': 'Review motel order setting records.',
  'New Online Order': 'Create an online order record.',
  'Online Orders': 'Review online-origin order records.',
  'Delivery Schedule': 'Review delivery schedule records.',
  'Delivery Areas': 'Review delivery area records.',
  'New Walk-In Order':
      'Create a priced counter order without a table or room.',
  'Active Walk-In Orders': 'Track active counter orders and preparation.',
  'Ready for Pickup': 'View prepared counter orders and confirm handover.',
  'Walk-In Order History': 'Search recent counter orders, including served and cancelled orders.',
  'Invoices & Receipts': 'Review saved invoice and receipt records.',
  'Payment Options': 'Review saved payment option records.',
};

const _inventoryManagementCategories = [
  (
    title: 'Overview & Monitoring',
    icon: Icons.monitor_heart_outlined,
    cards: [
      'Inventory Overview',
      'All Inventory Items',
      'Items Needed',
      'Low Stock Items',
      'Expiry & Waste',
      'Inventory Alerts & Notifications',
      'Inventory Quick Actions',
    ],
  ),
  (
    title: 'Items & Stock',
    icon: Icons.inventory_2_outlined,
    cards: [
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
  ),
  (
    title: 'Locations & Transfers',
    icon: Icons.warehouse_outlined,
    cards: [
      'Stores & Branches',
      'Storage Locations & Bins',
      'Transfer Stock',
      'Transfer Requests & Approvals',
      'Goods Dispatch & Receiving',
      'Kitchen & Minibar Stock Locations',
    ],
  ),
  (
    title: 'Purchasing & Suppliers',
    icon: Icons.local_shipping_outlined,
    cards: [
      'Suppliers Management',
      'Purchase Requests',
      'Purchase Orders',
      'Goods Receiving & Inspection',
      'Supplier Returns',
      'Purchase Invoice Matching',
    ],
  ),
  (
    title: 'Kitchen & Minibar Integration',
    icon: Icons.soup_kitchen_outlined,
    cards: [
      'Ingredient Stock & Recipes',
      'Kitchen Consumption',
      'Minibar Drinks Inventory',
      'Nargile Materials Inventory',
      'Automatic Consumption Rules',
      'Waste & Spoilage',
      'Stock Availability for Menu',
    ],
  ),
  (
    title: 'Value, Reports & Administration',
    icon: Icons.assessment_outlined,
    cards: [
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
  ),
];

const _inventoryCardPurposes = <String, String>{
  'Inventory Overview': 'Design preview for stock and reorder monitoring.',
  'All Inventory Items': 'Design preview for searchable item records.',
  'Items Needed': 'Review items that may need replenishment.',
  'Low Stock Items': 'Review items below configured reorder levels.',
  'Expiry & Waste': 'Review batch expiry and waste records.',
  'Inventory Alerts & Notifications':
      'Design preview for inventory alerts and notification rules.',
  'Inventory Quick Actions': 'Open existing quick-action record workspace.',
  'Add Inventory Item': 'Design preview for adding a catalog item.',
  'Edit & Manage Items': 'Design preview for managing inventory items.',
  'Item Categories & Units':
      'Review item category and measurement-unit records.',
  'Stock In': 'Design preview for receiving stock into an inventory location.',
  'Stock Out': 'Design preview for authorized stock removal.',
  'Stock Adjustments': 'Design preview for reviewed stock adjustments.',
  'Batch & Lot Tracking': 'Design preview for batch and lot traceability.',
  'Expiry Date Tracking': 'Review existing expiry and waste records.',
  'Stock Count & Reconciliation': 'Review existing inventory count records.',
  'Barcode & SKU Management': 'Review existing search and barcode records.',
  'Stores & Branches': 'Design preview for inventory stores and branches.',
  'Storage Locations & Bins': 'Design preview for storage locations and bins.',
  'Transfer Stock': 'Design preview for inter-location stock transfers.',
  'Transfer Requests & Approvals':
      'Design preview for controlled transfer approvals.',
  'Goods Dispatch & Receiving':
      'Design preview for dispatch and goods receiving.',
  'Kitchen & Minibar Stock Locations':
      'Design preview for kitchen and minibar stock locations.',
  'Suppliers Management': 'Review existing supplier record workspace.',
  'Purchase Requests': 'Design preview for purchase requests.',
  'Purchase Orders': 'Review existing purchase-order record workspace.',
  'Goods Receiving & Inspection':
      'Design preview for supplier delivery inspections.',
  'Supplier Returns': 'Design preview for supplier return records.',
  'Purchase Invoice Matching':
      'Design preview for matching purchase documents.',
  'Ingredient Stock & Recipes':
      'Design preview for ingredient and recipe stock links.',
  'Kitchen Consumption':
      'Design preview for approved kitchen stock consumption.',
  'Minibar Drinks Inventory': 'Design preview for minibar beverage inventory.',
  'Nargile Materials Inventory':
      'Design preview for Nargile material inventory.',
  'Automatic Consumption Rules':
      'Design preview for recipe-based stock consumption rules.',
  'Waste & Spoilage': 'Design preview for authorized waste records.',
  'Stock Availability for Menu':
      'Design preview for menu stock availability integration.',
  'Inventory Value': 'Review existing inventory value record workspace.',
  'Inventory Valuation Methods':
      'Design preview for approved valuation methods.',
  'Inventory Reports': 'Review existing inventory report records.',
  'Inventory Usage Report': 'Review existing inventory usage report records.',
  'Cost & Margin Integration':
      'Design preview for cost and margin integration.',
  'Stock Audit History': 'Review existing inventory history records.',
  'Inventory Permissions & Approvals':
      'Design preview for inventory access and approval rules.',
  'Inventory Settings': 'Review existing inventory setting records.',
  'Import & Export': 'Design preview for authorized inventory data exchange.',
  'Backup & Reconciliation Monitoring':
      'Review existing sync and backup records.',
};

const _inventoryCardRouteTitles = <String, String>{
  'Inventory Overview': 'Inventory Overview',
  'All Inventory Items': 'All Inventory Items',
  'Low Stock Items': 'Low Stock Items',
  'Expiry & Waste': 'Expiry & Waste',
  'Inventory Alerts & Notifications': 'Stock Alerts',
  'Inventory Quick Actions': 'Inventory Quick Actions',
  'Add Inventory Item': 'Add / Edit Inventory Item',
  'Edit & Manage Items': 'Add / Edit Inventory Item',
  'Item Categories & Units': 'Inventory Categories',
  'Stock In': 'Stock In',
  'Stock Out': 'Stock Out',
  'Stock Adjustments': 'Stock Adjustments',
  'Expiry Date Tracking': 'Expiry & Waste',
  'Waste & Spoilage': 'Expiry & Waste',
  'Stock Count & Reconciliation': 'Inventory Count',
  'Barcode & SKU Management': 'Search & Barcode',
  'Transfer Stock': 'Transfer Stock',
  'Suppliers Management': 'Suppliers Management',
  'Purchase Orders': 'Purchase Orders',
  'Inventory Value': 'Inventory Value',
  'Inventory Reports': 'Inventory Reports',
  'Inventory Usage Report': 'Inventory Usage Report',
  'Stock Audit History': 'Inventory History',
  'Inventory Settings': 'Inventory Settings',
  'Backup & Reconciliation Monitoring': 'Sync & Backup',
};

const _menuCardPurposes = <String, String>{
  'Menu Overview': 'Search saved products, categories, IQD prices and availability.',
  'Add New Product': 'Add a product name, category, description, base IQD price and availability.',
  'Edit & Manage Products': 'Search and edit saved products. Existing order prices stay unchanged.',
  'Product Categories': 'Find products by category and update a category in the product editor.',
  'Product Images & Descriptions': 'Manage optimized product images, alt text, translations and publication readiness.',
  'Product Variations & Add-ons': 'Manage size, flavor, extras, required choices, price deltas and min/max selections.',
  'Product Availability': 'Use the product editor to make products available or unavailable for new orders.',
  'Bulk Product Management': 'Preview, validate and approve bulk category, availability, station or pricing edits.',
  'Product Combos & Meal Packages': 'Define bundles with component quantities, allowed substitutions, price rules and inventory decomposition.',
  'Product Scheduling':
      'Set availability by date, weekday, time window, season and timezone.',
  'Product Allergens & Nutrition': 'Maintain verified allergens, ingredient warnings, dietary tags and optional nutritional values.',
  'Normal Pricing': 'Edit base prices in IQD. New orders use the saved price.',
  'Tourism Pricing': 'Manage tourism prices applied to eligible orders, including motel orders.',
  'Owner Pricing':
      'Manage owner-specific price mode with authorization and audit.',
  'Discount Pricing':
      'Manage authorized fixed-amount and percentage discounts and precedence.',
  'Price Change History': 'Show before/after prices, effective time, actor, approval and impacted channels.',
  'Pricing Rules & Approvals': 'Define pricing permissions, approval thresholds, rounding and conflict resolution.',
  'Product Cost & Profit Margin': 'Compute cost and gross margin from versioned verified inputs without treating estimates as settled financial data.',
  'Happy Hour & Promotions': 'Schedule eligible promotions, exclusions, caps, stacking restrictions and expiry.',
  'Product Station Assignment':
      'Route product line items to an active authorized preparation station.',
  'Kitchen Products': 'Manage food items prepared by kitchen stations.',
  'Minibar Products — Nargile & Drinks': 'Manage only Nargile/shisha and café drinks for dedicated minibar stations.',
  'Product Ingredients & Recipes':
      'Maintain ingredient links and recipe reference records.',
  'Preparation Time & Instructions':
      'Maintain item preparation instructions and estimated time per station.',
  'Product Printing Routing': 'Map new/revised order tickets to station-specific printers and safe retry queues.',
  'Recipe & Portion Management': 'Define exact ingredient quantities, yield, portion size and approved recipe revisions.',
  'Product Preparation Options': 'Define choices such as cooking preference, sugar, drink size and Nargile flavor.',
  'Station Availability & Failover': 'Handle unavailable stations using approved rerouting or pause selling; never silently send to an unsuitable station.',
  'Customer Digital Menu': 'Public product browsing, item detail, pricing, cart and channel-specific eligibility.',
  'Table QR Menu': 'Open table-bound customer menu with validated table context; no privileged access in QR payload.',
  'Online Ordering Menu':
      'Expose eligible online delivery/takeaway items and availability.',
  'Motel Menu': 'Expose eligible motel items and tourism pricing; preserve prepaid versus pay-on-delivery handling.',
  'Multilingual Menu': 'Support English, Arabic and Kurdish translations, fallbacks and RTL layout.',
  'Menu Display & Appearance': 'Configure category order, product tiles, images, badges and responsive design.',
  'Menu Publishing & Scheduling':
      'Stage, preview, approve and schedule menu releases per channel.',
  'Menu QR & Sharing': 'Provide general menu share links and QR distinct from table-specific QR.',
  'Customer Favorites & Popular Items': 'Use opt-in customer favorites and verified eligible sales metrics; no invented rankings.',
  'Product Stock Integration': 'Connect recipes and product sellability to inventory stock and movements.',
  'Out-of-Stock Management': 'Detect and handle shortages; support manual overrides with authorization.',
  'Product Sales & Performance': 'Analyze item sales, quantities, mix and performance from settled/eligible order records.',
  'Product Feedback & Ratings':
      'Collect and moderate product ratings and feedback.',
  'Product Recommendations': 'Capture staff and customer suggestions, review decisions and completion status.',
  'Menu Reports': 'Provide filterable and exportable operational and financial menu reports.',
  'Product Waste & Returns': 'Track waste, returns, reasons, approvals and links to inventory and financial reconciliation.',
  'Menu Permissions': 'Manage role-scoped view/edit/approve/publish permissions enforced server-side.',
  'Menu Settings':
      'Configure defaults, currency, language, channel rules and validations.',
  'Menu Audit History':
      'Immutable actor/time/before-after audit views for sensitive actions.',
  'Menu Import & Export': 'Validated import preview, error reports and safe exports without exposing secrets.',
  'Product Change Approval': 'Queue sensitive product changes for authorized review before activation.',
};

const _featuredSectionCards = {
  1: ['Add Table'],
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
  'Add Table': 'Create and manage saved dining tables',
  'Add / Edit Tables': 'Create and update table records',
  'Table Map': 'View and manage table map records',
  'Table Orders': 'Orders for occupied tables',
  'Chairs Management':
      'Track spare chairs, protect guest seating, and move chairs safely',
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
    this.favoritesStorage,
    super.key,
  });

  final String email;
  final String role;
  final Set<String> grantedPermissions;
  final String? permissionsLoadError;
  final FavoritesStorage? favoritesStorage;

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  static const _navigationGroups = [
    (title: 'Operations', indices: [0, 24, 1, 3, 4, 5, 6]),
    (title: 'Finance', indices: [2, 14, 23]),
    (title: 'People & Service', indices: [7, 8, 9, 12, 13, 18, 19, 20, 21, 22]),
    (title: 'Administration', indices: [10, 11, 15, 16, 17]),
  ];

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
      title: 'Tables & Chairs',
      description: 'Create and manage the restaurant dining tables.',
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
    (
      key: 'table_overview',
      icon: Icons.grid_view_rounded,
      title: 'Table Overview',
      description: 'Live tables, visits, service requests and bills.',
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
      'Unpaid Expenses',
      'Expense Payments',
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
    ['Table Overview'],
  ];

  bool _hasSectionAccess(int sectionIndex) {
    if (widget.role == 'admin' || sectionIndex == 0) return true;
    if (sectionIndex == 24) return _canAccessTablesCard('Table Overview');
    return _visibleSubcards(sectionIndex).isNotEmpty;
  }

  List<int> get _visibleSectionIndices => [
    for (var index = 0; index < _sections.length; index++)
      if (_hasSectionAccess(index)) index,
  ];

  static List<String> _allSectionCards(int sectionIndex) {
    if (sectionIndex == 1) {
      return <String>{for(final category in _tablesChairsCategories) ...category.cards}.toList(growable:false);
    }
    return sectionIndex == 0
        ? <String>{
            for (final group in _dashboardGroups) ...group.cards,
            ..._subcards[sectionIndex],
          }.toList(growable: false)
        : sectionIndex == 3
        ? <String>{
            for (final category in _menuManagementCategories) ...category.cards,
            ..._subcards[sectionIndex],
          }.toList(growable: false)
        : sectionIndex == 4
        ? <String>{
            for (final category in _kitchenManagementCategories)
              ...category.cards,
            ..._subcards[sectionIndex],
          }.toList(growable: false)
        : sectionIndex == 5
        ? <String>{
            for (final category in _motelOrdersCategories) ...category.cards,
            ..._subcards[sectionIndex],
          }.toList(growable: false)
        : sectionIndex == 6
        ? <String>{
            for (final category in _inventoryManagementCategories)
              ...category.cards,
            ..._subcards[sectionIndex],
          }.toList(growable: false)
        : _subcards[sectionIndex];
  }

  List<String> _visibleSubcards(int sectionIndex) {
    if (sectionIndex == 24) return _hasSectionAccess(24) ? ['Table Overview'] : [];
    final sectionKey = _sections[sectionIndex].key;
    if (sectionIndex == 1) {
      return _tablesChairsCategories
          .expand((category) => category.cards)
          .where(_canAccessTablesCard)
          .toList(growable: false);
    }
    final sectionSubcards = _allSectionCards(sectionIndex);
    if (widget.role == 'admin' ||
        widget.grantedPermissions.contains('$sectionKey:*')) {
      return sectionSubcards;
    }
    if (sectionIndex == 6) {
      bool hasCardPermission(String title) => widget.grantedPermissions
          .contains('$sectionKey:${_permissionSlug(title)}');
      return sectionSubcards
          .where((title) {
            final legacyTitle = _inventoryCardRouteTitles[title];
            return hasCardPermission(title) ||
                (legacyTitle != null && hasCardPermission(legacyTitle));
          })
          .toList(growable: false);
    }
    return sectionSubcards
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
  int _selectedTablesCategory = 0;
  final _diningTablePanelFormKey = GlobalKey<FormState>();
  final _diningTablePanelNameController = TextEditingController();
  final _diningTablePanelAreaController = TextEditingController();
  final _diningTablePanelSeatsController = TextEditingController();
  String? _selectedDiningTablePanelId;
  bool _diningTablePanelIsNew = true;
  bool _isSavingDiningTablePanel = false;
  bool _diningTablePanelOnMobile = false;
  bool _diningTablePanelShowMap = false;
  bool _isEditingDiningTableMap = false;
  bool _isSavingDiningTableMap = false;
  int _diningTableEditorTab = 0;
  String _diningTablePanelPricingMode = 'normal';
  String? _diningTablePanelError;
  int _selectedMenuCategory = 0;
  String _menuCardSearch = '';
  int _selectedKitchenCategory = 0;
  String _kitchenCardSearch = '';
  int _selectedMotelOrdersCategory = 0;
  int _selectedInventoryCategory = 0;
  String _inventoryCardSearch = '';
  int _selectedDashboardCategory = 0;
  final List<GlobalKey> _dashboardCategoryKeys = List.generate(
    8,
    (_) => GlobalKey(),
  );
  bool _isSigningOut = false;
  String? _signOutError;
  CafeWorkspaceRepository? _workspaceRepository;
  RealtimeChannel? _workspaceChannel;
  CafeDiningTableRepository? _diningTableRepository;
  RealtimeChannel? _diningTableChannel;
  CafeTableReservationRepository? _tableReservationRepository;
  RealtimeChannel? _tableReservationChannel;
  CafeTableChairRepository? _chairRepository;
  List<CafeDiningTable> _diningTables = const [];
  List<CafeTableReservation> _tableReservations = const [];
  CafeChairManagementSnapshot? _chairManagement;
  bool _isLoadingDiningTables = true;
  bool _isFetchingDiningTables = false;
  bool _isLoadingTableReservations = true;
  bool _isFetchingTableReservations = false;
  bool _isLoadingChairManagement = true;
  bool _isFetchingChairManagement = false;
  String? _diningTableError;
  String? _tableReservationsError;
  String? _chairManagementError;
  final _diningTableMapKey = GlobalKey();
  final _diningTableMapTransformationController = TransformationController();
  final Map<String, CafeDiningTable> _diningTableMapSnapshot = {};
  final Map<String, (double, double)> _diningTableMapDraftPositions = {};
  String? _diningTableMapRequestId;
  List<CafeWorkspaceRecord> _workspaceRecords = const [];
  bool _isLoadingRecords = true;
  bool _isFetchingRecords = false;
  String? _workspaceError;
  List<Map<String, dynamic>> _staffDepartments = const [];
  List<Map<String, dynamic>> _staffPermissionProfiles = const [];
  List<Map<String, dynamic>> _staffMembers = const [];
  bool _isLoadingEmployeeData = false;
  String? _employeeManagementError;
  DateTime _selectedReportDate = baghdadCalendarDate(DateTime.now());
  String _dashboardSearch = '';
  String _selectedDateRange = 'Today';
  String _financeStatusFilter = 'All';
  String _financeSearch = '';
  String _tableStatusFilter = 'All';
  String _tableSearch = '';
  int _diningTableListPage = 0;
  int _diningTableListPageSize = 10;
  String _reservationStatusFilter = 'All';
  String _reservationSearch = '';
  String _reservationTimeFilter = 'All dates';
  String _tableWorkspaceView = 'Floor map';
  String _selectedDiningTableArea = 'All areas';
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
    final diningTableChannel = _diningTableChannel;
    final diningTableRepository = _diningTableRepository;
    if (diningTableChannel != null && diningTableRepository != null) {
      unawaited(diningTableRepository.removeChannel(diningTableChannel));
    }
    final reservationChannel = _tableReservationChannel;
    final reservationRepository = _tableReservationRepository;
    if (reservationChannel != null && reservationRepository != null) {
      unawaited(reservationRepository.removeChannel(reservationChannel));
    }
    _diningTablePanelNameController.dispose();
    _diningTablePanelAreaController.dispose();
    _diningTablePanelSeatsController.dispose();
    _diningTableMapTransformationController.dispose();
    super.dispose();
  }

  Future<void> _connectWorkspace() async {
    if (!_hasValidSupabaseConfiguration) {
      if (!mounted) return;
      setState(() {
        _isLoadingRecords = false;
        _isLoadingDiningTables = false;
        _isLoadingTableReservations = false;
        _isLoadingChairManagement = false;
        _workspaceError =
            'Supabase is not configured with a valid project URL and key.';
        _diningTableError =
            'Dining-table access is unavailable because Supabase is not '
            'configured for this app.';
        _tableReservationsError =
            'Table reservations are unavailable because Supabase is not '
            'configured for this app.';
        _chairManagementError =
            'Chair management is unavailable because Supabase is not '
            'configured for this app.';
      });
      return;
    }
    try {
      final repository = CafeWorkspaceRepository(Supabase.instance.client);
      _workspaceRepository = repository;
      _workspaceChannel = repository.subscribe(() {
        unawaited(_loadWorkspaceRecords());
      });
      final diningTableRepository = CafeDiningTableRepository(
        Supabase.instance.client,
      );
      _diningTableRepository = diningTableRepository;
      _diningTableChannel = diningTableRepository.subscribe(() {
        unawaited(_loadDiningTables());
        if (_canManageChairs) unawaited(_loadChairManagement());
      });
      if (_canViewTableReservations) {
        final reservationRepository = CafeTableReservationRepository(
          Supabase.instance.client,
        );
        _tableReservationRepository = reservationRepository;
        _tableReservationChannel = reservationRepository.subscribe(() {
          unawaited(_loadTableReservations());
        });
      } else {
        _isLoadingTableReservations = false;
      }
      if (_canManageChairs) {
        _chairRepository = CafeTableChairRepository(Supabase.instance.client);
      } else {
        _isLoadingChairManagement = false;
      }
      await _loadWorkspaceRecords();
      await _loadDiningTables();
      if (_canManageChairs) await _loadChairManagement();
      if (_canViewTableReservations) await _loadTableReservations();
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        _isLoadingRecords = false;
        _workspaceError = 'Supabase is not configured for this app: $exception';
      });
    }
  }

  Future<void> _loadDiningTables() async {
    final repository = _diningTableRepository;
    if (repository == null || _isFetchingDiningTables) return;
    _isFetchingDiningTables = true;
    if (mounted) {
      setState(() {
        _isLoadingDiningTables = true;
        _diningTableError = null;
      });
    }

    try {
      final tables = await repository.fetchTables();
      if (!mounted) return;
      setState(() {
        _diningTables = tables;
        _diningTableError = null;
      });
    } on PostgrestException catch (exception) {
      if (!mounted) return;
      setState(() {
        _diningTableError = _diningTableFailure(exception);
      });
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        _diningTableError = 'Dining tables could not be loaded: $exception';
      });
    } finally {
      _isFetchingDiningTables = false;
      if (mounted) setState(() => _isLoadingDiningTables = false);
    }
  }

  Future<void> _loadChairManagement() async {
    final repository = _chairRepository;
    if (repository == null || _isFetchingChairManagement) return;
    _isFetchingChairManagement = true;
    if (mounted) {
      setState(() {
        _isLoadingChairManagement = true;
        _chairManagementError = null;
      });
    }
    try {
      final snapshot = await repository.fetchManagement();
      if (!mounted) return;
      setState(() {
        _chairManagement = snapshot;
        _chairManagementError = null;
      });
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        _chairManagementError =
            'Could not load chair data: ${_diningTableFailure(exception)}';
      });
    } finally {
      _isFetchingChairManagement = false;
      if (mounted) {
        setState(() => _isLoadingChairManagement = false);
      }
    }
  }

  Future<void> _loadTableReservations() async {
    final repository = _tableReservationRepository;
    if (repository == null || _isFetchingTableReservations) return;
    _isFetchingTableReservations = true;
    if (mounted) {
      setState(() {
        _isLoadingTableReservations = true;
        _tableReservationsError = null;
      });
    }
    try {
      final reservations = await repository.fetchReservations();
      if (!mounted) return;
      setState(() {
        _tableReservations = reservations;
        _tableReservationsError = null;
      });
    } on PostgrestException catch (exception) {
      if (!mounted) return;
      setState(() {
        _tableReservationsError =
            exception.code == '42P01' || exception.code == 'PGRST205'
            ? 'Table reservation storage is not installed in this environment. '
                  'Apply the cafe_table_reservations staging migration first.'
            : 'Table reservations could not be loaded '
                  '(${exception.code ?? 'unknown'}): ${exception.message}';
      });
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        _tableReservationsError =
            'Table reservations could not be loaded: $exception';
      });
    } finally {
      _isFetchingTableReservations = false;
      if (mounted) setState(() => _isLoadingTableReservations = false);
    }
  }

  String _diningTableFailure(Exception exception) {
    if (exception is PostgrestException) {
      if (exception.code == '40001') {
        return 'The table list or layout changed while you were editing. '
            'Discard the draft to reload the latest saved map, then try again.';
      }
      if (exception.code == '22023') {
        return exception.message;
      }
      if (exception.code == '42P01' || exception.code == 'PGRST205') {
        return 'Dining-table storage is not installed in Supabase. Apply the '
            'cafe_dining_tables migration before using the floor map.';
      }
      if (exception.code == '23505') {
        return 'A table with that name already exists in this area.';
      }
      if (exception.code == '42501') {
        final assurance = Supabase.instance.client.auth.mfa
            .getAuthenticatorAssuranceLevel()
            .currentLevel
            .toString()
            .split('.')
            .last;
        final serverMessage = exception.message.trim();
        if (assurance != 'aal2' ||
            serverMessage.contains('Authenticator verification')) {
          return 'This session needs authenticator verification (AAL2) '
              'before it can access dining tables. Sign in again, complete '
              'the authenticator prompt, then retry. If a table was already '
              'saved, do not add it again.';
        }
        final details = exception.details;
        final hint = exception.hint;
        return 'Supabase denied this AAL2 dining-table request (42501). '
            'Dashboard role: ${widget.role}. The database reports: '
            '$serverMessage. Verify that the production staff profile and '
            'table permission match this account; do not add the table again.'
            '${details == null ? '' : ' Details: $details'}'
            '${hint == null ? '' : ' Hint: $hint'}';
      }
      return 'Dining-table request failed (${exception.code ?? 'unknown'}): '
          '${exception.message}';
    }
    return 'Dining-table request failed: $exception';
  }

  Future<bool> _reauthenticateDiningTableSession() async {
    final auth = Supabase.instance.client.auth;
    if (auth.currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: CafeText('Sign in again to load this table QR.')),
        );
      }
      return false;
    }
    if (auth.mfa.getAuthenticatorAssuranceLevel().currentLevel ==
        AuthenticatorAssuranceLevels.aal2) {
      return true;
    }

    late final AuthMFAListFactorsResponse factors;
    try {
      factors = await auth.mfa.listFactors();
    } on AuthException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: CafeText(
              'Could not load authenticator factors: ${exception.message}',
            ),
          ),
        );
      }
      return false;
    } on Exception catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: CafeText('Could not load authenticator factors: $exception'),
          ),
        );
      }
      return false;
    }
    if (!mounted) return false;
    if (factors.totp.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: CafeText(
              'Set up an authenticator for this staff account, then retry the QR.',
            ),
          ),
        );
      }
      return false;
    }

    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController();
    var isVerifying = false;
    var error = '';
    final verified = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const CafeText('Verify staff session'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CafeText(
                  'Enter the current six-digit code from your authenticator '
                  'app to load this table QR.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: codeController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    label: CafeText('Authenticator code'),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Enter the six-digit authenticator code',
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _AuthErrorMessage(error),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isVerifying
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: const CafeText('Cancel'),
            ),
            FilledButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        isVerifying = true;
                        error = '';
                      });
                      try {
                        await auth.mfa.challengeAndVerify(
                          factorId: factors.totp.first.id,
                          code: codeController.text.trim(),
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } on AuthException catch (exception) {
                        setDialogState(() {
                          error = exception.message;
                          isVerifying = false;
                        });
                      } on Exception catch (exception) {
                        setDialogState(() {
                          error =
                              'Authenticator verification failed: $exception';
                          isVerifying = false;
                        });
                      }
                    },
              child: isVerifying
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const CafeText('Verify & load QR'),
            ),
          ],
        ),
      ),
    );
    codeController.dispose();
    return verified == true &&
        auth.mfa.getAuthenticatorAssuranceLevel().currentLevel ==
            AuthenticatorAssuranceLevels.aal2;
  }

  bool get _canManageDiningTables =>
      widget.role == 'admin' ||
      widget.grantedPermissions.contains('tables_orders:*') ||
      widget.grantedPermissions.contains('tables_orders:add_edit_tables');

  bool get _canViewDiningTables =>
      widget.role == 'admin' ||
      widget.grantedPermissions.contains('tables_orders:*') ||
      const {
        'tables_orders:add_edit_tables',
        'tables_orders:live_tables',
        'tables_orders:table_overview',
        'tables_orders:table_map',
        'tables_orders:visual_table_map',
        'tables_orders:table_availability',
        'tables_orders:active_tables',
        'tables_orders:table_status',
      }.any(widget.grantedPermissions.contains);

  bool get _canManageTableReservations =>
      widget.role == 'admin' ||
      widget.grantedPermissions.contains('tables_orders:*') ||
      widget.grantedPermissions.contains('tables_orders:table_reservations');

  bool get _canViewTableReservations => _canManageTableReservations;

  bool get _canManageChairs =>
      widget.role == 'admin' ||
      widget.grantedPermissions.contains('tables_orders:*') ||
      widget.grantedPermissions.contains('tables_orders:chairs_management');

  bool _canAccessTablesCard(String title) {
    if (widget.role == 'admin' ||
        widget.grantedPermissions.contains('tables_orders:*')) {
      return true;
    }
    return switch (title) {
      'Add Table' ||
      'Edit & Manage Tables' ||
      'Table Map' => _canViewDiningTables,
      'QR Code Management' => _canManageDiningTables,
      'Chairs Management' => _canManageChairs,
      'Table Reservations' => _canViewTableReservations,
      'Table Availability' => widget.grantedPermissions.contains(
        'tables_orders:table_availability',
      ),
      'Live Tables' => widget.grantedPermissions.contains(
        'tables_orders:live_tables',
      ),
      'Table Status' => widget.grantedPermissions.contains(
        'tables_orders:table_status',
      ),
      _ => widget.grantedPermissions.contains(
        'tables_orders:${_permissionSlug(title)}',
      ),
    };
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
    final range = WorkspaceReportRange.forSelection(_selectedReportDate, _selectedDateRange);
    return records
        .where(
          (record) => range.contains(record.createdAt),
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
    String subcard, {
    CafeWorkspaceRecord? record,
  }) async {
    final repository = _workspaceRepository;
    if (repository == null) {
      setState(() {
        _workspaceError = 'The live Supabase service is not available.';
      });
      return;
    }

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: record?.title ?? '');
    final detailsController = TextEditingController(
      text: record?.details ?? '',
    );
    final amountController = TextEditingController(
      text: record?.amount?.toString() ?? '',
    );
    final isTableReservation =
        section.key == 'tables_orders' &&
        const {
          'reservations',
          'table_reservations',
        }.contains(_permissionSlug(subcard));
    var selectedTableId = record?.metadata['table_id'] as String? ?? '';
    var error = '';
    var submitting = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(record == null ? 'Add $subcard record' : 'Edit record'),
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
                      label: CafeText('Title'),
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
                      label: CafeText('Details'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (isTableReservation) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTableId,
                      decoration: const InputDecoration(
                        label: CafeText('Dining table'),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: CafeText('No table selected'),
                        ),
                        for (final table in _diningTables)
                          DropdownMenuItem(
                            value: table.id,
                            child: CafeText('${table.name} · ${table.area}'),
                          ),
                      ],
                      onChanged: (tableId) {
                        setDialogState(() => selectedTableId = tableId ?? '');
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      label: CafeText('Amount (optional, IQD)'),
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
              child: const CafeText('Cancel'),
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
                        final title = titleController.text.trim();
                        final details = detailsController.text.trim();
                        final amount = amountController.text.trim().isEmpty
                            ? null
                            : double.parse(amountController.text.trim());
                        final metadata = Map<String, dynamic>.from(
                          record?.metadata ?? const {},
                        );
                        if (isTableReservation) {
                          final selectedTable = _diningTables
                              .where((table) => table.id == selectedTableId)
                              .firstOrNull;
                          if (selectedTable == null) {
                            metadata.remove('table_id');
                            metadata.remove('table_name');
                            metadata.remove('table_area');
                          } else {
                            metadata['table_id'] = selectedTable.id;
                            metadata['table_name'] = selectedTable.name;
                            metadata['table_area'] = selectedTable.area;
                          }
                        }
                        if (record == null) {
                          await repository.createRecord(
                            sectionKey: section.key,
                            subcardKey: _permissionSlug(subcard),
                            title: title,
                            details: details,
                            amount: amount,
                            metadata: metadata,
                          );
                        } else {
                          await repository.updateRecord(
                            recordId: record.id,
                            title: title,
                            details: details,
                            amount: amount,
                            metadata: metadata,
                          );
                        }
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
                  : Text(record == null ? 'Save record' : 'Save changes'),
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

  (double, double) _nextDiningTablePosition() {
    for (var index = 0; index < 30; index++) {
      final x = 0.1 + (index % 6) * 0.16;
      final y = 0.12 + (index ~/ 6) * 0.19;
      final isOccupied = _diningTables.any(
        (table) => (table.x - x).abs() < 0.13 && (table.y - y).abs() < 0.13,
      );
      if (!isOccupied) return (x, y);
    }
    return (0.5, 0.5);
  }

  void _startDiningTablePanelDraft() {
    setState(() {
      _selectedDiningTablePanelId = null;
      _diningTablePanelIsNew = true;
      _diningTablePanelNameController.clear();
      _diningTablePanelAreaController.text = 'Main';
      _diningTablePanelSeatsController.text = '4';
      _diningTablePanelPricingMode = 'normal';
      _diningTablePanelError = null;
      _diningTableEditorTab = 0;
      _diningTablePanelOnMobile = true;
      _diningTablePanelShowMap = false;
    });
  }

  void _selectDiningTableInPanel(CafeDiningTable table) {
    setState(() {
      _selectedDiningTablePanelId = table.id;
      _diningTablePanelIsNew = false;
      _diningTablePanelNameController.text = table.name;
      _diningTablePanelAreaController.text = table.area;
      _diningTablePanelSeatsController.text = '${table.seats}';
      _diningTablePanelPricingMode = table.pricingMode;
      _diningTablePanelError = null;
      _diningTableEditorTab = 0;
      _diningTablePanelOnMobile = true;
      _diningTablePanelShowMap = false;
    });
  }

  Future<void> _saveDiningTablePanel({required bool addAnother}) async {
    final form = _diningTablePanelFormKey.currentState;
    if (form != null) {
      if (!form.validate()) return;
    } else {
      final seats = int.tryParse(_diningTablePanelSeatsController.text.trim());
      if (_diningTablePanelNameController.text.trim().isEmpty ||
          _diningTablePanelAreaController.text.trim().isEmpty ||
          seats == null ||
          seats < 1 ||
          seats > 100) {
        setState(() {
          _diningTablePanelError =
              'Complete the table name, area, and seat capacity in Basic Info '
              'before saving.';
        });
        return;
      }
    }
    final repository = _diningTableRepository;
    if (repository == null) {
      setState(() {
        _diningTablePanelError =
            'Table storage is unavailable. Check the connection and retry.';
      });
      return;
    }
    setState(() {
      _isSavingDiningTablePanel = true;
      _diningTablePanelError = null;
    });
    try {
      CafeDiningTable saved;
      if (_diningTablePanelIsNew) {
        final position = _nextDiningTablePosition();
        saved = await repository.createTable(
          name: _diningTablePanelNameController.text,
          area: _diningTablePanelAreaController.text,
          seats: int.parse(_diningTablePanelSeatsController.text.trim()),
          x: position.$1,
          y: position.$2,
          pricingMode: _diningTablePanelPricingMode,
        );
      } else {
        final id = _selectedDiningTablePanelId;
        if (id == null) {
          throw StateError('Select a saved table before saving changes.');
        }
        await repository.updateTable(
          id: id,
          name: _diningTablePanelNameController.text,
          area: _diningTablePanelAreaController.text,
          seats: int.parse(_diningTablePanelSeatsController.text.trim()),
          pricingMode: _diningTablePanelPricingMode,
        );
        final refreshed = await repository.fetchTables();
        saved = refreshed.singleWhere((item) => item.id == id);
      }
      if (!mounted) return;
      setState(() {
        _diningTables =
            [
              for (final item in _diningTables)
                if (item.id != saved.id) item,
              saved,
            ]..sort((left, right) {
              final areaOrder = left.area.compareTo(right.area);
              return areaOrder != 0
                  ? areaOrder
                  : left.name.compareTo(right.name);
            });
        _selectedDiningTableArea = 'All areas';
        _isSavingDiningTablePanel = false;
        _diningTablePanelError = null;
        if (_diningTablePanelIsNew && addAnother) {
          _selectedDiningTablePanelId = null;
          _diningTablePanelIsNew = true;
          _diningTablePanelNameController.clear();
          _diningTablePanelAreaController.text = saved.area;
          _diningTablePanelSeatsController.text = '4';
          _diningTablePanelPricingMode = 'normal';
        } else {
          _selectedDiningTablePanelId = saved.id;
          _diningTablePanelIsNew = false;
          _diningTablePanelNameController.text = saved.name;
          _diningTablePanelAreaController.text = saved.area;
          _diningTablePanelSeatsController.text = '${saved.seats}';
          _diningTablePanelPricingMode = saved.pricingMode;
        }
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _diningTablePanelIsNew
                  ? '${saved.name} saved. Add the next table.'
                  : '${saved.name} saved.',
            ),
          ),
        );
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        _isSavingDiningTablePanel = false;
        _diningTablePanelError = _diningTableFailure(exception);
      });
    }
  }

  Future<void> _showDiningTableForm({CafeDiningTable? table}) async {
    final repository = _diningTableRepository;
    if (repository == null) {
      setState(() {
        _diningTableError = 'The live Supabase service is not available.';
      });
      return;
    }
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: table?.name ?? '');
    final areaController = TextEditingController(text: table?.area ?? 'Main');
    final seatsController = TextEditingController(text: '${table?.seats ?? 4}');
    final messenger = ScaffoldMessenger.of(context);
    CafeDiningTable? createdDiningTable;
    var error = '';
    var isSaving = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(table == null ? 'Add dining table' : 'Edit dining table'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      label: CafeText('Table name or number'),
                      hintText: 'For example, Table 1',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a table name or number'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: areaController,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      label: CafeText('Area'),
                      hintText: 'For example, Main Hall or Patio',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter an area'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: seatsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      label: CafeText('Seats'),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final seats = int.tryParse(value?.trim() ?? '');
                      return seats == null || seats < 1 || seats > 100
                          ? 'Enter a seat count between 1 and 100'
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
              onPressed: isSaving
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: const CafeText('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        isSaving = true;
                        error = '';
                      });
                      try {
                        final seats = int.parse(seatsController.text.trim());
                        if (table == null) {
                          final position = _nextDiningTablePosition();
                          createdDiningTable = await repository.createTable(
                            name: nameController.text,
                            area: areaController.text,
                            seats: seats,
                            x: position.$1,
                            y: position.$2,
                            pricingMode: table?.pricingMode ?? 'normal',
                          );
                        } else {
                          await repository.updateTable(
                            id: table.id,
                            name: nameController.text,
                            area: areaController.text,
                            seats: seats,
                            pricingMode: table.pricingMode,
                          );
                        }
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                        if (table == null &&
                            createdDiningTable != null &&
                            mounted) {
                          setState(() {
                            _diningTables =
                                [..._diningTables, createdDiningTable!]
                                  ..sort((left, right) {
                                    final areaOrder = left.area.compareTo(
                                      right.area,
                                    );
                                    return areaOrder != 0
                                        ? areaOrder
                                        : left.name.compareTo(right.name);
                                  });
                            _selectedDiningTableArea = 'All areas';
                            _diningTableError = null;
                            _isLoadingDiningTables = false;
                          });
                          messenger
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: CafeText(
                                  '${createdDiningTable!.name} added to the floor plan.',
                                ),
                              ),
                            );
                        }
                      } on Exception catch (exception) {
                        if (!dialogContext.mounted) return;
                        if (exception is PostgrestException &&
                            exception.code == '23505') {
                          try {
                            final tables = await repository.fetchTables();
                            if (!mounted || !dialogContext.mounted) return;
                            setState(() {
                              _diningTables = tables;
                              _selectedDiningTableArea = 'All areas';
                              _diningTableError = null;
                              _isLoadingDiningTables = false;
                            });
                            setDialogState(() {
                              error =
                                  'A table with that name already exists in '
                                  '${areaController.text.trim()}. The saved '
                                  'table list has been refreshed; close this '
                                  'window to see it.';
                              isSaving = false;
                            });
                          } on Exception catch (refreshException) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              error =
                                  'That table already exists, but the saved '
                                  'table list could not be refreshed: '
                                  '${_diningTableFailure(refreshException)}';
                              isSaving = false;
                            });
                          }
                        } else {
                          setDialogState(() {
                            error = _diningTableFailure(exception);
                            isSaving = false;
                          });
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(table == null ? 'Add table' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    areaController.dispose();
    seatsController.dispose();
    if (saved == true) {
      await _loadDiningTables();
      if (_canManageChairs) await _loadChairManagement();
    }
    if (saved == true && createdDiningTable != null) {
      await _showDiningTableQr(createdDiningTable!);
    }
  }

  Future<void> _showDiningTableQr(CafeDiningTable table) async {
    final repository = _diningTableRepository;
    if (repository == null) return;
    final assurance = Supabase.instance.client.auth.mfa
        .getAuthenticatorAssuranceLevel();
    if (assurance.currentLevel != AuthenticatorAssuranceLevels.aal2) {
      final verified = await _reauthenticateDiningTableSession();
      if (!verified || !mounted) return;
    }
    String token;
    try {
      token = await repository.fetchQrToken(table.id);
    } on Exception catch (exception) {
      if (!mounted) return;
      final requiresMfa =
          exception is PostgrestException &&
          exception.code == '42501' &&
          Supabase.instance.client.auth.mfa
                  .getAuthenticatorAssuranceLevel()
                  .currentLevel !=
              AuthenticatorAssuranceLevels.aal2;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: CafeText(
            '${table.name} is still saved, but its QR could not be loaded. '
            'Do not add the table again. ${_diningTableFailure(exception)}',
          ),
          action: requiresMfa
              ? SnackBarAction(
                  label: 'Verify session',
                  onPressed: () =>
                      unawaited(_retryDiningTableQrAfterVerification(table)),
                )
              : null,
        ),
      );
      return;
    }
    if (!mounted) return;

    var isRegenerating = false;
    var isPrinting = false;
    String? qrError;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final qrUrl = Uri.base
              .replace(
                queryParameters: {...Uri.base.queryParameters, 'table': token},
                fragment: '',
              )
              .toString();
          return AlertDialog(
            title: CafeText('${table.name} QR code'),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CafeText(
                    'Gelye Sherane Café & Restaurant',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  QrImageView(
                    data: qrUrl,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                  ),
                  CafeText('Scan to open the menu for ${table.name}.'),
                  if (qrError != null) ...[
                    const SizedBox(height: 8),
                    Text(qrError!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: isPrinting || isRegenerating
                    ? null
                    : () async {
                        setDialogState(() {
                          isPrinting = true;
                          qrError = null;
                        });
                        try {
                          final document = _diningTableQrPdf(table, qrUrl);
                          await Printing.layoutPdf(
                            onLayout: (_) => document.save(),
                          );
                        } on Exception catch (exception) {
                          if (!dialogContext.mounted) return;
                          setDialogState(
                            () => qrError =
                                'QR printing failed. The table is still saved. '
                                '$exception',
                          );
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() => isPrinting = false);
                          }
                        }
                      },
                icon: const Icon(Icons.print_outlined),
                label: Text(isPrinting ? 'Preparing…' : 'Print'),
              ),
              TextButton.icon(
                onPressed: isPrinting || isRegenerating
                    ? null
                    : () async {
                        setDialogState(() {
                          isPrinting = true;
                          qrError = null;
                        });
                        try {
                          final document = _diningTableQrPdf(table, qrUrl);
                          await Printing.sharePdf(
                            bytes: await document.save(),
                            filename:
                                '${table.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}_QR.pdf',
                          );
                        } on Exception catch (exception) {
                          if (!dialogContext.mounted) return;
                          setDialogState(
                            () => qrError =
                                'PDF download failed. The table is still '
                                'saved. $exception',
                          );
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() => isPrinting = false);
                          }
                        }
                      },
                icon: const Icon(Icons.download_outlined),
                label: const CafeText('PDF'),
              ),
              TextButton(
                onPressed: isRegenerating || isPrinting
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const CafeText('Close'),
              ),
              TextButton(
                onPressed: isRegenerating || isPrinting
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: dialogContext,
                          builder: (confirmContext) => AlertDialog(
                            title: const CafeText('Regenerate table QR?'),
                            content: const CafeText(
                              'The current QR will stop working. Replace '
                              'printed copies with the new code.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(confirmContext).pop(false),
                                child: const CafeText('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(confirmContext).pop(true),
                                child: const CafeText('Regenerate'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !dialogContext.mounted) {
                          return;
                        }
                        setDialogState(() {
                          isRegenerating = true;
                          qrError = null;
                        });
                        try {
                          final updatedToken = await repository
                              .regenerateQrToken(table.id);
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            token = updatedToken;
                            isRegenerating = false;
                          });
                        } on Exception catch (exception) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            qrError = _diningTableFailure(exception);
                            isRegenerating = false;
                          });
                        }
                      },
                child: Text(isRegenerating ? 'Regenerating…' : 'Regenerate QR'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _retryDiningTableQrAfterVerification(
    CafeDiningTable table,
  ) async {
    if (await _reauthenticateDiningTableSession() && mounted) {
      await _showDiningTableQr(table);
    }
  }

  pw.Document _diningTableQrPdf(CafeDiningTable table, String url) {
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat.a6,
        build: (_) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'Gelye Sherane Cafe & Restaurant',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                table.name,
                style: const pw.TextStyle(fontSize: 20),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 18),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: url,
                width: 200,
                height: 200,
              ),
              pw.SizedBox(height: 12),
              pw.Text('Scan to view the menu and order'),
            ],
          ),
        ),
      ),
    );
    return document;
  }

  Future<void> _confirmDeleteDiningTable(CafeDiningTable table) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const CafeText('Delete dining table?'),
        content: CafeText(
          'Delete ${table.name} from ${table.area}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const CafeText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const CafeText('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;
    final repository = _diningTableRepository;
    if (repository == null) return;
    try {
      await repository.deleteTable(table.id);
      await _loadDiningTables();
      if (_canManageChairs) await _loadChairManagement();
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() => _diningTableError = _diningTableFailure(exception));
    }
  }

  Future<void> _updateDiningTableStatus(
    CafeDiningTable table,
    String status,
  ) async {
    final repository = _diningTableRepository;
    if (repository == null) return;
    try {
      await repository.updateStatus(id: table.id, status: status);
      await _loadDiningTables();
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() => _diningTableError = _diningTableFailure(exception));
    }
  }

  List<CafeWorkspaceRecord> _reservationsForTable(CafeDiningTable table) =>
      _workspaceRecords
          .where(
            (record) =>
                record.sectionKey == 'tables_orders' &&
                const {
                  'reservations',
                  'table_reservations',
                }.contains(record.subcardKey) &&
                record.metadata['table_id'] == table.id,
          )
          .toList(growable: false);

  Future<void> _showDiningTableDetails(CafeDiningTable table) async {
    final reservations = _reservationsForTable(table);
    var selectedStatus = table.status;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(table.name),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CafeText('Area: ${table.area}'),
                    CafeText('Seats: ${table.seats}'),
                    if (_canManageDiningTables) ...[
                      OutlinedButton.icon(
                        onPressed: () => _showDiningTableQr(table),
                        icon: const Icon(Icons.qr_code_2),
                        label: const CafeText('View table QR'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        decoration: const InputDecoration(
                          label: CafeText('Table status'),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final status
                              in CafeDiningTableRepository.statuses)
                            DropdownMenuItem(
                              value: status,
                              child: Text(_diningTableStatusLabel(status)),
                            ),
                        ],
                        onChanged: (status) {
                          if (status == null || status == selectedStatus) {
                            return;
                          }
                          setDialogState(() => selectedStatus = status);
                          unawaited(_updateDiningTableStatus(table, status));
                        },
                      ),
                    ] else
                      CafeText('Status: ${_diningTableStatusLabel(table.status)}'),
                    const SizedBox(height: 16),
                    const CafeText(
                      'Reservations',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    if (reservations.isEmpty)
                      const CafeText(
                        'No reservations are linked to this table.',
                        style: TextStyle(color: _muted),
                      )
                    else
                      for (final reservation in reservations)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(reservation.title),
                          subtitle: Text(
                            [
                              if (reservation.details.isNotEmpty)
                                reservation.details,
                              'Status: ${reservation.status.replaceAll('_', ' ')}',
                            ].join('\n'),
                          ),
                        ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const CafeText('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _startDiningTableMapEdit() {
    if (!_canManageDiningTables || _diningTables.isEmpty) return;
    if (_diningTables.any((table) => table.updatedAt == null)) {
      setState(() {
        _diningTableError =
            'Map editing needs current table update timestamps. Refresh the '
            'saved tables before entering edit mode.';
      });
      return;
    }
    setState(() {
      _diningTableMapSnapshot
        ..clear()
        ..addEntries(_diningTables.map((table) => MapEntry(table.id, table)));
      _diningTableMapDraftPositions.clear();
      _diningTableMapRequestId = null;
      _isEditingDiningTableMap = true;
      _diningTableError = null;
    });
  }

  Future<void> _discardDiningTableMapEdit() async {
    setState(() {
      _isEditingDiningTableMap = false;
      _isSavingDiningTableMap = false;
      _diningTableMapSnapshot.clear();
      _diningTableMapDraftPositions.clear();
      _diningTableMapRequestId = null;
      _diningTableError = null;
      _diningTableMapTransformationController.value =
          _diningTableMapTransformationController.value.clone()..setIdentity();
    });
    await _loadDiningTables();
  }

  Future<void> _saveDiningTableMapEdit() async {
    if (!_isEditingDiningTableMap || _isSavingDiningTableMap) return;
    final repository = _diningTableRepository;
    if (repository == null) {
      setState(() {
        _diningTableError =
            'Table storage is unavailable. Check the connection and retry.';
      });
      return;
    }
    final currentTableIds = _diningTables.map((table) => table.id).toSet();
    if (_diningTableMapSnapshot.length != _diningTables.length ||
        !_diningTableMapSnapshot.keys.every(currentTableIds.contains)) {
      setState(() {
        _diningTableError =
            'The saved table list changed while the map was open. Discard '
            'the draft to reload before saving.';
      });
      return;
    }
    final changes = _diningTableMapSnapshot.values
        .map((table) {
          final position =
              _diningTableMapDraftPositions[table.id] ?? (table.x, table.y);
          final updatedAt = table.updatedAt;
          if (updatedAt == null) {
            throw StateError('A saved table is missing its update timestamp.');
          }
          return CafeDiningTableMapChange(
            id: table.id,
            expectedUpdatedAt: updatedAt,
            expectedX: table.x,
            expectedY: table.y,
            x: position.$1,
            y: position.$2,
          );
        })
        .toList(growable: false);
    setState(() {
      _isSavingDiningTableMap = true;
      _diningTableError = null;
    });
    try {
      await repository.saveMapLayout(
        requestId: _diningTableMapRequestId ??= newCafeRequestId(),
        changes: changes,
      );
      final tables = await repository.fetchTables();
      if (!mounted) return;
      setState(() {
        _diningTables = tables;
        _isEditingDiningTableMap = false;
        _isSavingDiningTableMap = false;
        _diningTableMapSnapshot.clear();
        _diningTableMapDraftPositions.clear();
        _diningTableMapRequestId = null;
        _diningTableError = null;
      });
    } on PostgrestException catch (exception) {
      if (!mounted) return;
      setState(() {
        _isSavingDiningTableMap = false;
        _diningTableError = _diningTableFailure(exception);
      });
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        _isSavingDiningTableMap = false;
        _diningTableError =
            'Map save could not be confirmed. Keep this draft open and retry; '
            'the same request ID will be reused. $exception';
      });
    }
  }

  (double, double) _diningTableMapPosition(CafeDiningTable table) {
    final draft = _diningTableMapDraftPositions[table.id];
    if (draft != null) return draft;
    final snapshot = _diningTableMapSnapshot[table.id];
    return snapshot == null ? (table.x, table.y) : (snapshot.x, snapshot.y);
  }

  void _nudgeDiningTableMapPosition(
    CafeDiningTable table,
    double dx,
    double dy,
  ) {
    if (!_isEditingDiningTableMap || _isSavingDiningTableMap) return;
    final position = _diningTableMapPosition(table);
    final xMargin =
        CafeDiningTableRepository.mapTableWidth /
        CafeDiningTableRepository.mapCanvasWidth /
        2;
    final yMargin =
        CafeDiningTableRepository.mapTableHeight /
        CafeDiningTableRepository.mapCanvasHeight /
        2;
    setState(() {
      _diningTableMapDraftPositions[table.id] = (
        (position.$1 + dx).clamp(xMargin, 1 - xMargin).toDouble(),
        (position.$2 + dy).clamp(yMargin, 1 - yMargin).toDouble(),
      );
    });
  }

  void _moveDiningTable(CafeDiningTable table, DraggableDetails details) {
    if (!_isEditingDiningTableMap || _isSavingDiningTableMap) return;
    final renderObject = _diningTableMapKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return;
    final mapSize = renderObject.size;
    final center = renderObject.globalToLocal(
      details.offset +
          Offset(
            CafeDiningTableRepository.mapTableWidth / 2,
            CafeDiningTableRepository.mapTableHeight / 2,
          ),
    );
    final xMargin = CafeDiningTableRepository.mapTableWidth / mapSize.width / 2;
    final yMargin =
        CafeDiningTableRepository.mapTableHeight / mapSize.height / 2;
    setState(() {
      _diningTableMapDraftPositions[table.id] = (
        (center.dx / mapSize.width).clamp(xMargin, 1 - xMargin).toDouble(),
        (center.dy / mapSize.height).clamp(yMargin, 1 - yMargin).toDouble(),
      );
    });
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
        title: const CafeText('Delete record?'),
        content: CafeText('Delete "${record.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const CafeText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const CafeText('Delete'),
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
              child: CafeText(
                'More management sections',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _executiveText,
                ),
              ),
            ),
            if (moreSections.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: CafeText('No additional management sections are assigned.'),
              ),
            for (final index in moreSections)
              ListTile(
                leading: Icon(_sections[index].icon, color: _navy),
                title: CafeText(_sections[index].title),
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
                      label: CafeText('Department name'),
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
              child: const CafeText('Cancel'),
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
                              color: Color(0xFF1D2C43),
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const CafeText(
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
                              label: CafeText('Permission profile name'),
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
                              label: CafeText('Department'),
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
                          Wrap(spacing: 8, children: [
                            OutlinedButton(
                              onPressed: saving ? null : () => setDialogState(() {
                                selectedPermissions.clear();
                                for (final section in _StaffDashboardPageState._sections) {
                                  selectedPermissions[section.key] = {'*'};
                                }
                                error = null;
                              }),
                              child: const CafeText('Select all cards'),
                            ),
                            TextButton(
                              onPressed: saving ? null : () => setDialogState(() => selectedPermissions.clear()),
                              child: const CafeText('Clear selection'),
                            ),
                          ]),
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
                          child: const CafeText('Cancel'),
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
            title: const CafeText('Add staff account'),
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
                          label: CafeText('Staff email'),
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
                          label: CafeText('Initial password (12+ characters)'),
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
                          label: CafeText('Department'),
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
                          label: CafeText('Permission profile'),
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
                        child: CafeText(
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
                child: const CafeText('Cancel'),
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
        SnackBar(content: CafeText('Staff account created for $createdEmail.')),
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
            title: CafeText('Edit access · ${member['email']}'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: departmentId,
                    decoration: const InputDecoration(
                      label: CafeText('Department'),
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
                      label: CafeText('Permission profile'),
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
                child: const CafeText('Cancel'),
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
    final subcards = _allSectionCards(sectionIndex);
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
            activeColor: const Color(0xFF9A6A1D),
            controlAffinity: ListTileControlAffinity.leading,
            title: const CafeText('All section cards'),
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
              title: CafeText(subcard),
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
        const CafeText(
          'Employee workspace',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const CafeText(
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
              label: const CafeText('Add department'),
            ),
            OutlinedButton.icon(
              onPressed: _staffDepartments.isEmpty
                  ? null
                  : () => _savePermissionProfile(),
              icon: const Icon(Icons.checklist_outlined),
              label: const CafeText('Create permission profile'),
            ),
            OutlinedButton.icon(
              onPressed:
                  _staffDepartments.isEmpty || _staffPermissionProfiles.isEmpty
                  ? null
                  : _addStaffUser,
              icon: const Icon(Icons.person_add_alt_1),
              label: const CafeText('Add staff account'),
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
              child: const CafeText('Retry loading employee data'),
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
              subtitle: CafeText(
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
              subtitle: CafeText(
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
              subtitle: CafeText(
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
          child: CafeText(
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
    final baseTheme = Theme.of(context);
    final executiveTheme = baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: _gold,
        onPrimary: _deepNavy,
        secondary: _gold,
        onSecondary: _deepNavy,
        secondaryContainer: _gold,
        onSecondaryContainer: _deepNavy,
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: const Color(0xFFEDE8DC),
        selectedColor: _gold,
        checkmarkColor: _deepNavy,
        labelStyle: const TextStyle(color: _navy, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(
          color: _deepNavy,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(color: _gold.withValues(alpha: 0.42)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: baseTheme.navigationBarTheme.copyWith(
        backgroundColor: _deepNavy,
        indicatorColor: _gold,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? _deepNavy
                : _executiveMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? _deepNavy
                : _executiveMuted,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: _deepNavy,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _navy,
          side: BorderSide(color: _gold.withValues(alpha: 0.55)),
        ),
      ),
    );
    return Theme(
      data: executiveTheme,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _deepNavy,
        drawer: Drawer(child: _navigationPanel()),
        bottomNavigationBar: isWide ? null : _mobileNavigationBar(),
        appBar: isWide
            ? null
            : AppBar(
                backgroundColor: _deepNavy,
                foregroundColor: Colors.white,
                surfaceTintColor: _deepNavy,
                elevation: 0,
                shape: const Border(
                  bottom: BorderSide(color: Color(0xFFD6AA57), width: 1),
                ),
                title: MediaQuery.sizeOf(context).width < 600
                    ? const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CafeText(
                            'Gelye Sherane',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          CafeText(
                            'Café & Restaurant · Management',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFD8E2F0),
                            ),
                          ),
                        ],
                      )
                    : const CafeText('Gelye Sherane · Management System'),
                actions: [
                  const CafeLanguageButton(),
                  IconButton(tooltip: 'Favorites', onPressed: _openFavorites, icon: const Icon(Icons.star_outline)),
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
                        child: CafeText(
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
      ),
    );
  }

  Widget _desktopTopbar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: _deepNavy,
        border: Border(bottom: BorderSide(color: _gold, width: 1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            if (constraints.maxWidth >= 600) ...[
              const CafeText('Workspace', style: TextStyle(color: _executiveMuted)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.chevron_right, color: _gold),
              ),
            ],
            Expanded(
              child: Text(
                _sections[_selectedIndex].title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _executiveText,
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
                      style: const TextStyle(
                        color: _executiveMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            const CafeLanguageButton(),
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
                child: CafeText(
                  '${widget.email} · ${widget.role == 'admin' ? 'Admin' : 'Staff'}',
                  style: const TextStyle(color: _executiveMuted, fontSize: 11),
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
        backgroundColor: _deepNavy,
        indicatorColor: _gold,
        destinations: [
          for (final sectionIndex in visiblePrimary)
            NavigationDestination(
              icon: Icon(_primarySectionIcon(sectionIndex, selected: false)),
              selectedIcon: Icon(
                _primarySectionIcon(sectionIndex, selected: true),
              ),
              label: cafeTranslate(context, _primarySectionLabel(sectionIndex)),
            ),
          NavigationDestination(
            icon: const Icon(Icons.more_horiz),
            label: cafeTranslate(context, 'More'),
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
                    child: CafeText(
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
                        CafeText(
                          'Gelye Sherane',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        CafeText(
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
                children: [

                  for (final group in _navigationGroups)
                    if (group.indices.any(_hasSectionAccess)) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(23, 9, 12, 5),
                        child: Text(
                          group.title.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF91A1B8),
                            fontSize: 9,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      for (final index in group.indices)
                        if (_hasSectionAccess(index))
                          _navigationSectionItem(index),
                    ],
                ],
              ),
            ),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: CafeText(
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

  Widget _navigationSectionItem(int index) {
    final section = _sections[index];
    final selected = index == _selectedIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
        key: ValueKey('management-section-$index'),
        minLeadingWidth: 18,
        horizontalTitleGap: 10,
        selected: selected,
        selectedTileColor: _gold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          section.icon,
          size: 19,
          color: selected ? _deepNavy : const Color(0xFFC5D0DF),
        ),
        title: CafeText(
          section.title,
          style: TextStyle(
            color: selected ? _deepNavy : const Color(0xFFC5D0DF),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
  }

  void _openFavorites() {
    setState(() {  _selectedIndex = 0; _selectedDashboardCategory = 0; _dashboardSearch = ''; _selectedSubcard = null; });
    _scaffoldKey.currentState?.closeDrawer();
  }

  Widget _tableCategoryCard(String title, int index) {
                
                final isOperationalWorkflow = const {
                  'Add Table',
                  'Table Ordering',
                  'Edit & Manage Tables',
                  'Table Map',
                  'QR Code Management',
                  'Table Reservations',
                  'Chairs Management',
                }.contains(title) || _tableOverviewCards.contains(title);
                final description = switch (title) {
                  'Add Table' => 'Create and manage saved dining tables.',
                  'Edit & Manage Tables' =>
                    'View, edit, and maintain saved dining tables.',
                  'Table Map' =>
                    'Pan, zoom, and save an authorized layout of saved tables.',
                  'Chairs Management' =>
                    'Review base capacity; chair changes stay locked until '
                        'verified sources and guest counts are available.',
                  'QR Code Management' =>
                    'View, print, and rotate saved table QR codes.',
                  'Table Reservations' =>
                    'Create and manage dedicated table reservations.',
                  'Table Ordering' => 'Create priced table orders and track preparation.',
                  _ => _tableOverviewCards.contains(title) ? 'Live table status, visits and permission-controlled actions.' : 'Coming Soon — Awaiting Specification',
                };
                final palette = _executiveCardPalette(index);
                return Card(
                  key: ValueKey('tables-category-card-$title'),
                  margin: EdgeInsets.zero,
                  color: palette.background,
                  clipBehavior: Clip.antiAlias,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: palette.accent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: InkWell(
                    onTap: () => setState(() {
                      if (title == 'Add Table') {
                        _tableSearch = '';
                        _tableStatusFilter = 'All';
                        _selectedDiningTableArea = 'All areas';
                        _tableWorkspaceView = 'Table list';
                      }
                      if (title == 'Edit & Manage Tables' ||
                          title == 'QR Code Management') {
                        _tableSearch = '';
                        _tableWorkspaceView = 'Table list';
                      }
                      if (title == 'Table Map') {
                        _tableWorkspaceView = 'Floor map';
                      }
                      if (title == 'Add Table' ||
                          title == 'Edit & Manage Tables' ||
                          title == 'Table Map' ||
                          title == 'QR Code Management') {
                        _selectedDiningTablePanelId = null;
                        _diningTablePanelIsNew = title == 'Add Table';
                        _diningTablePanelOnMobile = title == 'Add Table';
                        _diningTablePanelShowMap = title == 'Table Map';
                        _diningTablePanelError = null;
                        _diningTableEditorTab = title == 'QR Code Management'
                            ? 3
                            : 0;
                        _diningTablePanelNameController.clear();
                        _diningTablePanelAreaController.text = 'Main';
                        _diningTablePanelSeatsController.text = '4';
                        _diningTablePanelPricingMode = 'normal';
                      }
                      _selectedSubcard = title;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _metricIcon(title, _sections[1].icon),
                                color: palette.accent,
                                size: 23,
                              ),
                              const Spacer(),
                              if (isOperationalWorkflow)
                                Icon(
                                  Icons.arrow_outward,
                                  size: 18,
                                  color: palette.accent,
                                )
                              else
                                Icon(
                                  Icons.schedule_outlined,
                                  size: 18,
                                  color: palette.accent,
                                ),
                            ],
                          ),
                          const Spacer(),
                          CafeText(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _executiveText,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _executiveMuted,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              
  }

  Widget _paymentCategoryCard(String title, int index) {
              
              final report = operationalReportCards['payment_management']?.contains(title) == true || cashWorkspaceCards['payment_management']?.contains(title) == true || expenseWorkspaceCards['payment_management']?.contains(title) == true;
              final connected = const {'Receive Payment', 'Payment History', 'Refunds & Voids'}.contains(title) || report;
              final palette = _executiveCardPalette(index);
              final description = switch (title) {
                'Receive Payment' => 'Record cash or manually confirmed card payments against an order.',
                'Payment History' => 'Review order balances, recorded payments and refunds.',
                'Refunds & Voids' => 'Record a refund against a collected payment.',
                _ => report ? 'View confirmed operational transactions with Baghdad date filters.' : 'Manual records only. Automated balances and approvals are not connected.',
              };
              return Card(
                key: ValueKey('payment-category-card-$title'),
                margin: EdgeInsets.zero, color: palette.background,
                clipBehavior: Clip.antiAlias, elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: palette.accent.withValues(alpha: 0.35))),
                child: InkWell(
                  onTap: () => setState(() {
                    _financeSearch = '';
                    _financeStatusFilter = 'All';
                    _selectedSubcard = title;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(_metricIcon(title, Icons.payments_outlined), color: palette.accent, size: 22),
                        const SizedBox(width: 8),
                        Expanded(child: CafeText(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _executiveText, fontWeight: FontWeight.w700))),
                        const Icon(Icons.chevron_right, color: _executiveMuted, size: 18),
                      ]),
                      const SizedBox(height: 8),
                      Text(description, maxLines: 3, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _executiveMuted, fontSize: 12)),
                      const Spacer(),
                      Text(connected ? 'Connected workflow' : 'Manual records',
                        style: TextStyle(color: palette.accent, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              );
            
  }

  Widget _favoriteCardPreview(FavoriteCardEntry card) {
    final index = _sections.indexWhere((section) => '${section.key}:${card.title}' == card.id);
    final position = _visibleSubcards(index).indexOf(card.title);
    return switch (index) {
      0 => _compactMetricCard(sectionIndex: 0, title: card.title, index: position),
      1 => _tableCategoryCard(card.title, position),
      2 => _paymentCategoryCard(card.title, position),
      3 when _menuCardPurposes.containsKey(card.title) => _menuCategoryCard(card.title),
      4 when _kitchenCardPurposes.containsKey(card.title) => _kitchenCategoryCard(card.title),
      5 when _motelOrderPurposes.containsKey(card.title) => _motelOrdersCategoryCard(card.title),
      6 when _inventoryCardPurposes.containsKey(card.title) => _inventoryCategoryCard(card.title),
      _ => _managementCard(index, card.title, cardIndex: position),
    };
  }

  Widget _favoritesContent({String title = 'Favorites', bool manage = false}) {
    final cards = <FavoriteCardEntry>[
      if (widget.permissionsLoadError == null)
        for (final index in _visibleSectionIndices)
          for (final title in _visibleSubcards(index))
            FavoriteCardEntry(id: '${_sections[index].key}:$title', section: _sections[index].title, title: title),
    ];
    return FavoritesPage(
      key: ValueKey('favorites-${widget.email.toLowerCase()}-$title'),
      title: title,
      manageInitially: manage,
      account: '$_supabaseExpectedProjectRef:${widget.email.toLowerCase()}',
      cards: cards,
      storage: widget.favoritesStorage,
      cardBuilder: _favoriteCardPreview,
      onOpen: (card) {
        if (widget.permissionsLoadError != null) return;
        var index = _sections.indexWhere((section) => '${section.key}:${card.title}' == card.id);
        if (index < 0 || !_visibleSubcards(index).contains(card.title)) return;
        if (index == 0 && card.title == 'Table Reservations') {
          if (!_canViewTableReservations || !_visibleSubcards(1).contains(card.title)) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: CafeText('Table Reservations access has not been assigned.')));
            return;
          }
          index = 1;
        }
        setState(() {
          
          _selectedIndex = index;
          _selectedSubcard = card.title;
          _workspaceSearch = '';
          _workspaceStatusFilter = 'All';
          _financeSearch = '';
          _financeStatusFilter = 'All';
          _reservationSearch = '';
          _reservationStatusFilter = 'All';
          if (index == 1) {
            _tableSearch = '';
            _tableStatusFilter = 'All';
            _selectedDiningTableArea = 'All areas';
            _selectedDiningTablePanelId = null;
            _diningTablePanelIsNew = card.title == 'Add Table';
            _diningTablePanelOnMobile = card.title == 'Add Table';
            _diningTablePanelShowMap = card.title == 'Table Map';
            _tableWorkspaceView = card.title == 'Table Map' ? 'Floor map' : 'Table list';
            _diningTablePanelError = null;
            _diningTableEditorTab = card.title == 'QR Code Management' ? 3 : 0;
            _diningTablePanelNameController.clear();
            _diningTablePanelAreaController.text = 'Main';
            _diningTablePanelSeatsController.text = '4';
            _diningTablePanelPricingMode = 'normal';
          }
        });
      },
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
            child: Container(
              key: const ValueKey('executive-workspace-panel'),
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 600 ? 14 : 24,
              ),
              decoration: BoxDecoration(
                color: _executiveWorkspacePanel,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _gold.withValues(alpha: 0.38)),
              ),
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
      ),
    );
  }

  Widget _sectionContent(int index) {
    if (index == 24) {
      return CafeTableOverview(
        rpc: _hasValidSupabaseConfiguration ? cafeOperationsRpc : null,
        onQr: (id) async {
          await _loadDiningTables();
          final matches = _diningTables.where((t) => t.id == id);
          if (matches.isNotEmpty && mounted) await _showDiningTableQr(matches.first);
        },
      );
    }
    final section = _sections[index];
    final subcard = _selectedSubcard;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (subcard != null)
          TextButton.icon(
            onPressed: () => setState(() => _selectedSubcard = null),
            icon: const Icon(Icons.arrow_back),
            label: CafeText('Back to ${section.title}'),
          ),
        if (index != 0) _sectionPageHeading(section, subcard),
        if (index != 0) const SizedBox(height: 16),
        if (index != 0 && index != 2 && index != 1) const SizedBox(height: 20),
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
        if (index == 7 && widget.role == 'admin' && subcard == null) ...[
          _sectionSubcardGrid(index),
          const SizedBox(height: 16),
          _employeeManagementPanel(),
        ] else if (_connectedOperations(index, subcard) != null)
          _connectedOperations(index, subcard)!
        else if (index == 2 && subcard != null)
          _financeDetail(section, subcard)
        else if (index == 0 &&
            subcard != null &&
            !_subcards[0].contains(subcard))
          _dashboardCardDesignDetail(subcard)
        else if (index == 1 && subcard != null)
          _tablesChairsCardDetail(section, subcard)
        else if (index == 3 &&
            subcard != null &&
            !_subcards[3].contains(subcard))
          _menuCardDesignDetail(subcard)
        else if (index == 3 && subcard != null)
          _menuLegacyCardDetail(section, subcard)
        else if (index == 4 &&
            subcard != null &&
            !_subcards[4].contains(subcard))
          _kitchenCardDesignDetail(subcard)
        else if (index == 4 && subcard != null)
          _kitchenLegacyCardDetail(section, subcard)
        else if (index == 5 && subcard != null)
          _motelOrderDesignDetail(subcard)
        else if (index == 6 &&
            subcard != null &&
            _inventoryWorkspaceTitle(subcard) == null)
          _inventoryCardDesignDetail(subcard)
        else if (index == 6 && subcard != null)
          _inventoryExistingWorkspaceDetail(
            section,
            _inventoryWorkspaceTitle(subcard)!,
          )
        else if (subcard == null)
          _sectionSubcardGrid(index)
        else
          _subcardDetail(section, subcard),
        if (index != 1 || subcard != null) ...[
          const SizedBox(height: 20),
          CafeText(
            'Signed in as ${widget.email}',
            style: const TextStyle(color: _executiveMuted, fontSize: 13),
          ),
        ],
      ],
    );
  }

  static const _tableOverviewCards = {'Table Availability', 'Live Tables', 'Table Status', 'Table Cleaning', 'Table Session Management', 'Table Service Requests', 'Waiter Table Assignment', 'Table Transfer', 'Table History & Audit', 'Guest Check-In & No-Show'};

  Widget? _connectedOperations(int index, String? card) {
    if (card == null || widget.permissionsLoadError != null || !_visibleSubcards(index).contains(card)) return null;
    bool allowed(int section, String title) => _visibleSubcards(section).contains(title);
    final rpc = _hasValidSupabaseConfiguration ? cafeOperationsRpc : null;
    if (index == 0 && const {'Dashboard Personalization', 'Personalization'}.contains(card)) {
      return _favoritesContent(title: card, manage: true);
    }
    if (index == 0 && cafeInventoryCards.containsKey(card)) {
      return CafeInventoryWorkspace(key: ValueKey('dashboard-inventory-$card'), title: card, rpc: rpc);
    }
    if (index == 0 && const {'Customer Feedback', 'Feedback', 'Employee Attendance', 'Attendance'}.contains(card)) {
      final kind = const {'Customer Feedback', 'Feedback'}.contains(card) ? 'feedback' : 'attendance';
      return CafePeopleWorkspace(key: ValueKey('dashboard-people-$kind'), kind: kind, rpc: rpc);
    }
    if (index == 0 && card == 'Reports') {
      return CafeReportLibrary(allowed: _visibleSubcards(0).toSet(), rpc: rpc);
    }
    if (index == 0 && const {'Tasks', 'Pending Staff Tasks'}.contains(card)) {
      return CafeStaffTasks(key: ValueKey('dashboard-tasks-$card'), rpc: rpc,
        pendingOnly: card == 'Pending Staff Tasks', kinds: {
          if (allowed(1, 'Table Maintenance')) 'maintenance',
          if (allowed(1, 'Extra Chairs Requests')) 'chairs',
          if (allowed(1, 'Reservation Waiting List')) 'waiting',
          if (allowed(1, 'Join & Split Tables')) 'group',
        });
    }
    if ((index == 0 && const {'Maintenance', 'Maintenance Requests'}.contains(card)) ||
        (index == 1 && card == 'Table Maintenance')) {
      if (!allowed(1, 'Table Maintenance')) {
        return const CafeText('Table Maintenance access has not been assigned.');
      }
      return CafeTableMaintenance(key: const ValueKey('table-maintenance-workflow'), rpc: rpc);
    }
    if (index == 0 && const {'Employees', 'Employee Assignments'}.contains(card)) {
      if (!allowed(1, 'Waiter Table Assignment') && !allowed(1, 'Table Assignment')) {
        return const CafeText('Table assignment access has not been assigned.');
      }
      if (card == 'Employees') return CafeDashboardEmployees(rpc: rpc);
      return CafeTableOverview(key: const ValueKey('dashboard-employee-assignments'),
        rpc: rpc, title: 'Employee Assignments', executiveStyle: true, initialStatus: 'Occupied',
        onQr: (id) async { await _loadDiningTables(); final table = _diningTables.where((t) => t.id == id).firstOrNull; if (table != null && mounted) await _showDiningTableQr(table); });
    }
    if (index == 0 && card == 'Station Printers') {
      if (!const ['Kitchen Stations Management','Kitchen Printing Management','Minibar Printing Management']
          .any((title) => allowed(4, title))) {
        return const Card(child: Padding(padding: EdgeInsets.all(20),
          child: CafeText('Kitchen or Minibar printing access has not been assigned.')));
      }
      return CafeFinanceSurface(builder: (context) => CafeStationWorkspace(
        key: const ValueKey('dashboard-station-printers'), rpc: rpc, devicePreferenceKey: widget.email));
    }
    if (index == 0 && card == 'Service Speed') {
      if (!allowed(0, 'Kitchen Orders')) {
        return const CafeText('Kitchen Orders access has not been assigned.');
      }
      return CafeOperationalReport(key: const ValueKey('dashboard-service-speed'),
        section: 'dashboard', card: 'kitchen_orders', title: card,
        rpc: rpc == null ? null : (name, params) async =>
          cafeServiceSpeedReport(Map<String, dynamic>.from(await rpc(name, params))));
    }
    if (index == 0 && card == 'Takeaway & Delivery') {
      return CafeDashboardFulfilment(online: allowed(5, 'Online Orders'),
        walkIn: allowed(5, 'Active Walk-In Orders'), rpc: rpc);
    }
    if ((index == 0 && card == 'Waiting List') || (index == 1 && card == 'Reservation Waiting List')) {
      if (!allowed(1, 'Reservation Waiting List')) {
        return const Card(child: Padding(padding: EdgeInsets.all(20),
          child: CafeText('Reservation Waiting List access has not been assigned.')));
      }
      return CafeWaitingList(key: const ValueKey('waiting-list-workflow'), rpc: rpc);
    }
    if (index == 0 && card == 'Table Map') {
      if (!allowed(1, 'Table Map')) {
        return const Card(child: Padding(padding: EdgeInsets.all(20),
          child: CafeText('Table Map access has not been assigned.')));
      }
      return CafeFinanceSurface(builder: (context) => Column(
        key: const ValueKey('dashboard-table-map'),
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const CafeText('Saved table layout and current recorded status. Edit layouts in Tables & Reservations.'),
          _diningTableWorkspace(allowTableEditing: false),
        ]));
    }
    if (index == 0 && card == 'Table History') {
      if (!allowed(0, 'Guests Today')) {
        return const Card(child: Padding(padding: EdgeInsets.all(20),
          child: CafeText('Guests Today access has not been assigned.')));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const CafeText('Each row is one table session. Search a table to see all its visits. Sessions spanning midnight appear on each day they overlap; duration is limited to the selected period. An empty departure time means the visit is still open.'),
        CafeOperationalReport(key: const ValueKey('dashboard-table-history'), section: 'dashboard',
          card: 'guests_today', title: 'Table History', rpc: rpc),
      ]);
    }
    if (index == 0 && card == 'Customer Number') {
      if (!allowed(0, 'Guests Today') || !allowed(1, 'Table Reservations') ||
          !(_tableOverviewCards.any((title) => allowed(1, title)) || allowed(24, 'Table Overview'))) {
        return const Card(child: Padding(padding: EdgeInsets.all(20),
          child: CafeText('Customer counts require Table Overview, Table Reservations and Guests Today access.')));
      }
      return CafeCustomerNumber(rpc: rpc, reservations: _hasValidSupabaseConfiguration
        ? (from, to) => loadCustomerReservations(Supabase.instance.client, from, to) : null);
    }
    if (index == 0 && card == 'Customer Requests') {
      if (!allowed(1, 'Table Service Requests')) {
        return const Card(child: Padding(padding: EdgeInsets.all(20),
          child: CafeText('Table Service Requests access has not been assigned.')));
      }
      return CafeTableOverview(key: const ValueKey('dashboard-customer-requests'), rpc: rpc,
        title: 'Customer Requests', executiveStyle: true, requestsOnly: true,
        onQr: (id) async { await _loadDiningTables(); final table = _diningTables.where((t) => t.id == id).firstOrNull; if (table != null && mounted) await _showDiningTableQr(table); });
    }
    if (index == 0 && card == 'Kitchen Live Board') {
      if (!allowed(4, 'Live Kitchen Orders')) {
        return const Card(child: Padding(padding: EdgeInsets.all(20),
          child: CafeText('Live Kitchen Orders access has not been assigned.')));
      }
      return CafeFinanceSurface(builder: (context) => CafeOperationsWorkspace(
        key: const ValueKey('dashboard-kitchen-live-board'), title: card,
        source: 'all', canCreate: false, rpc: rpc));
    }
    if (index == 0 && card == 'Reservations') {
      if (!_canViewTableReservations || !allowed(1, 'Table Reservations')) {
        return const Card(child: Padding(padding: EdgeInsets.all(20),
          child: CafeText('Table Reservations access has not been assigned.')));
      }
      return _tableReservationsWorkspace();
    }
    if (index == 0 && card == 'Guest Check-In') {
      if (!allowed(1, 'Guest Check-In & No-Show')) {
        return const Card(child: Padding(padding: EdgeInsets.all(20),
          child: CafeText('Guest Check-In & No-Show access has not been assigned.')));
      }
      return CafeTableOverview(key: const ValueKey('dashboard-guest-check-in'), rpc: rpc,
        title: 'Guest Check-In', executiveStyle: true, initialStatus: 'Reserved',
        onQr: (id) async { await _loadDiningTables(); final table = _diningTables.where((t) => t.id == id).firstOrNull; if (table != null && mounted) await _showDiningTableQr(table); });
    }
    if (index == 0 && dashboardMenuCards.contains(card)) {
      return CafeDashboardMenu(key: ValueKey('dashboard-menu-$card'), title: card,
        store: _hasValidSupabaseConfiguration ? SupabaseCafeMenuStore(Supabase.instance.client) : null);
    }
    if (index == 0 && dashboardTableCards.contains(card)) {
      return CafeDashboardTables(key: ValueKey('dashboard-tables-$card'), title: card, rpc: rpc);
    }
    if ((index==3 && card=='Product Printing Routing') || (index==4 && const {'Kitchen Stations Management','Kitchen Printing Management','Minibar Printing Management'}.contains(card))) {
      return CafeStationWorkspace(key:ValueKey('stations-$card'),rpc:rpc,devicePreferenceKey:widget.email);
    }
    if (expenseWorkspaceCards[_sections[index].key]?.contains(card) == true) {
      return CafeExpenseWorkspace(key: ValueKey('expenses-$index-$card'), title: card, rpc: rpc,
        evidence: _hasValidSupabaseConfiguration ? SupabaseExpenseEvidence(Supabase.instance.client) : null);
    }
    if (cashWorkspaceCards[_sections[index].key]?.contains(card) == true) {
      return CafeCashWorkspace(key: ValueKey('cash-$index-$card'), section: _sections[index].key, card: _permissionSlug(card), title: card, rpc: rpc);
    }
    if (operationalReportCards[_sections[index].key]?.contains(card) == true) {
      return CafeOperationalReport(key: ValueKey('report-$index-$card'), section: _sections[index].key, card: _permissionSlug(card), title: card, rpc: rpc);
    }
    if (index == 1 && _tableOverviewCards.contains(card)) {
      return CafeTableOverview(key: ValueKey('table-workflow-$card'), rpc: rpc,
        initialStatus: card == 'Table Availability' ? 'Available' : card == 'Table Cleaning' ? 'Cleaning' : 'All',
        requestsOnly: card == 'Table Service Requests',
        onQr: (id) async { await _loadDiningTables(); final table = _diningTables.where((t) => t.id == id).firstOrNull; if (table != null && mounted) await _showDiningTableQr(table); });
    }
    if (index == 3 && const {'Product Categories','Product Images & Descriptions'}.contains(card)) {
      return CafeMenuAssets(key:ValueKey('menu-assets-$card'), images:card=='Product Images & Descriptions',
        client:_hasValidSupabaseConfiguration?Supabase.instance.client:null);
    }
    if (index == 3 && const {'Add New Product','Edit & Manage Products','Menu Overview','Product Availability','Product Categories','Normal Pricing','Tourism Pricing','Owner Pricing'}.contains(card)) {
      return CafeMenuWorkspace(key: ValueKey('catalog-$card'),
        store: _hasValidSupabaseConfiguration ? SupabaseCafeMenuStore(Supabase.instance.client) : null,
        canCreate: allowed(3,'Add New Product'), canEdit: allowed(3,'Edit & Manage Products'));
    }
    if (index == 2 && const {'Receive Payment','Payment History','Refunds & Voids'}.contains(card)) {
      return CafeOperationsWorkspace(key: ValueKey('payments-$card'), source:'table', payments:true,
        canCreate:allowed(2,'Receive Payment'), canRefund:allowed(2,'Refunds & Voids'), rpc:rpc);
    }
    final orderView = switch ((index, card)) {
      (4, 'Kitchen Orders') => (source:'all', status:'All', history:true, required:'Live Kitchen Orders'),
      (4, 'Order Details') => (source:'all', status:'All', history:true, required:'Live Kitchen Orders'),
      (4, 'Kitchen Preparation') => (source:'all', status:'preparing', history:false, required:'Live Kitchen Orders'),
      (4, 'Ready for Delivery') => (source:'all', status:'ready', history:false, required:'Live Kitchen Orders'),
      (4, 'Kitchen Handover') => (source:'all', status:'ready', history:false, required:'Live Kitchen Orders'),
      (5, 'Room Orders') => (source:'motel', status:'All', history:false, required:'Motel Orders'),
      (5, 'Ready for Pickup') => (source:'walk_in', status:'ready', history:false, required:'Active Walk-In Orders'),
      (5, 'Walk-In Order History') => (source:'walk_in', status:'All', history:true, required:'Active Walk-In Orders'),
      _ => null,
    };
    if(orderView != null) {
      if(!allowed(index,orderView.required)) {
        return Card(child:Padding(padding:const EdgeInsets.all(20),
          child:CafeText('Ask an administrator to assign ${orderView.required} access to use this order workflow.')));
      }
      return CafeOperationsWorkspace(key:ValueKey('order-view-$index-$card'),
        source:orderView.source, canCreate:false, rpc:rpc,
        title:card, initialHistory:orderView.history, initialStatus:orderView.status);
    }
    String? source;
    if(index==1 && card=='Table Ordering') source='table';
    if(index==4) source=const {'Table Orders':'table','Motel Orders':'motel','Online Orders':'online','Live Kitchen Orders':'all','Status of All Orders':'all','Kitchen Display':'all'}[card];
    if(index==5) source=const {'New Motel Order':'motel','Motel Orders':'motel','New Online Order':'online','Online Orders':'online','New Walk-In Order':'walk_in','Active Walk-In Orders':'walk_in'}[card];
    if(source==null) return null;
    return CafeOperationsWorkspace(key:ValueKey('operations-$index-$card'),source:source,
      canCreate:index==1 || (index==5 && allowed(5, const {'motel':'New Motel Order','online':'New Online Order','walk_in':'New Walk-In Order'}[source]!)),rpc:rpc);
  }

  Widget _sectionPageHeading(
    ({String key, IconData icon, String title, String description}) section,
    String? subcard,
  ) {
    final description = subcard == null
        ? section.description
        : _inventoryCardPurposes[subcard] ??
              _motelOrderPurposes[subcard] ??
              _menuCardPurposes[subcard] ??
              _kitchenCardPurposes[subcard] ??
              _sectionCardDescriptions[subcard] ??
              (section.key == 'dashboard'
                  ? 'Dashboard preview; its live source is not verified.'
                  : 'Live workspace records for $subcard.');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _deepNavy,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            subcard == null ? section.icon : _metricIcon(subcard, section.icon),
            color: _gold,
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
                  color: _gold,
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
                  color: _executiveText,
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
        if (section.key != 'tables_orders' || subcard != null)
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

  Widget _diningTableWorkspace({
    bool forceList = false,
    bool allowTableEditing = false,
  }) {
    final query = _tableSearch.trim().toLowerCase();
    final areas = _diningTables.map((table) => table.area).toSet().toList()
      ..sort();
    final selectedArea = areas.contains(_selectedDiningTableArea)
        ? _selectedDiningTableArea
        : 'All areas';
    final tables = _diningTables
        .where(
          (table) =>
              (selectedArea == 'All areas' || table.area == selectedArea) &&
              (_tableStatusFilter == 'All' ||
                  table.status == _tableStatusFilter.toLowerCase()) &&
              (query.isEmpty ||
                  table.name.toLowerCase().contains(query) ||
                  table.area.toLowerCase().contains(query) ||
                  _diningTableStatusLabel(table.status)
                      .toLowerCase()
                      .contains(query)),
        )
        .toList(growable: false);
    final pageCount = (tables.length / _diningTableListPageSize).ceil();
    final page = pageCount == 0
        ? 0
        : _diningTableListPage.clamp(0, pageCount - 1);
    final pageStart = page * _diningTableListPageSize;
    final visibleTables = tables
        .skip(pageStart)
        .take(_diningTableListPageSize)
        .toList(growable: false);
    final showingMap = !forceList && _tableWorkspaceView == 'Floor map';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (forceList)
              SizedBox(
                width: 280,
                child: TextField(
                  key: const ValueKey('dining-table-search'),
                  decoration: const InputDecoration(
                    hintText: 'Search tables by name, area, or status',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() {
                    _tableSearch = value;
                    _diningTableListPage = 0;
                  }),
                ),
              ),
            DropdownButton<String>(
              value: selectedArea,
              items: [
                const DropdownMenuItem(
                  value: 'All areas',
                  child: CafeText('All areas'),
                ),
                for (final area in areas)
                  DropdownMenuItem(value: area, child: Text(area)),
              ],
              onChanged: (area) {
                if (area != null) {
                  setState(() {
                    _selectedDiningTableArea = area;
                    _diningTableListPage = 0;
                  });
                }
              },
            ),
            if (forceList)
              DropdownButton<String>(
                key: const ValueKey('dining-table-status-filter'),
                value: _tableStatusFilter,
                items: [
                  const DropdownMenuItem(
                    value: 'All',
                    child: CafeText('All statuses'),
                  ),
                  for (final status in CafeDiningTableRepository.statuses)
                    DropdownMenuItem(
                      value: status[0].toUpperCase() + status.substring(1),
                      child: Text(_diningTableStatusLabel(status)),
                    ),
                ],
                onChanged: (status) {
                  if (status != null) {
                    setState(() {
                      _tableStatusFilter = status;
                      _diningTableListPage = 0;
                    });
                  }
                },
              ),
            if (forceList)
              TextButton(
                onPressed: () => setState(() {
                  _tableSearch = '';
                  _tableStatusFilter = 'All';
                  _selectedDiningTableArea = 'All areas';
                  _diningTableListPage = 0;
                }),
                child: const CafeText('Reset filters'),
              ),
            OutlinedButton.icon(
              onPressed: _isLoadingDiningTables
                  ? null
                  : () => unawaited(_loadDiningTables()),
              icon: const Icon(Icons.refresh, size: 18),
              label: const CafeText('Refresh'),
            ),
            if (_canManageDiningTables && allowTableEditing)
              FilledButton.icon(
                key: const ValueKey('add-dining-table'),
                onPressed:
                    _isLoadingDiningTables ||
                        _diningTableError != null ||
                        _diningTableRepository == null
                    ? null
                    : () => _showDiningTableForm(),
                icon: const Icon(Icons.add, size: 18),
                label: const CafeText('Add table'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          forceList
              ? 'Manage saved tables and their manually maintained status.'
              : 'Drag table tiles to arrange the floor. Table status is '
                    'maintained manually and is not linked to live orders.',
          style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
        ),
        if (_diningTableError != null) ...[
          const SizedBox(height: 10),
          _AuthErrorMessage(_diningTableError!),
          if (_diningTableRepository == null)
            const SizedBox.shrink()
          else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: _isLoadingDiningTables
                    ? null
                    : () => unawaited(_loadDiningTables()),
                child: const CafeText('Retry loading tables'),
              ),
            ),
        ] else if (_isLoadingDiningTables) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ] else if (_diningTables.isNotEmpty && tables.isEmpty) ...[
          const SizedBox(height: 16),
          const CafeText(
            'No saved tables match these filters.',
            key: ValueKey('dining-table-no-results'),
            style: TextStyle(color: _muted),
          ),
        ] else if (_diningTables.isEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE4EAF1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.table_restaurant_outlined,
                  color: Color(0xFF7890B3),
                  size: 28,
                ),
                SizedBox(height: 7),
                CafeText(
                  'No dining tables yet',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                CafeText(
                  'Add a table to start building the floor layout.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ] else if (tables.isEmpty) ...[
          const SizedBox(height: 12),
          const CafeText(
            'There are no tables in this area yet.',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
        ] else if (showingMap) ...[
          const SizedBox(height: 10),
          _diningTableFloorMap(tables, allowTableEditing: allowTableEditing),
        ] else ...[
          const SizedBox(height: 8),
          for (final table in visibleTables)
            _diningTableListItem(table, allowTableEditing: allowTableEditing),
          if (forceList) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                CafeText(
                  '${tables.isEmpty ? 0 : pageStart + 1}–'
                  '${(pageStart + visibleTables.length)} of ${tables.length}',
                  key: const ValueKey('dining-table-list-range'),
                ),
                const SizedBox(width: 12),
                const CafeText('Rows'),
                const SizedBox(width: 6),
                DropdownButton<int>(
                  key: const ValueKey('dining-table-page-size'),
                  value: _diningTableListPageSize,
                  items: const [
                    DropdownMenuItem(value: 10, child: CafeText('10')),
                    DropdownMenuItem(value: 25, child: CafeText('25')),
                    DropdownMenuItem(value: 50, child: CafeText('50')),
                  ],
                  onChanged: (size) {
                    if (size != null) {
                      setState(() {
                        _diningTableListPageSize = size;
                        _diningTableListPage = 0;
                      });
                    }
                  },
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Previous tables page',
                  onPressed: page > 0
                      ? () => setState(() => _diningTableListPage = page - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                CafeText('${page + 1} / ${pageCount == 0 ? 1 : pageCount}'),
                IconButton(
                  tooltip: 'Next tables page',
                  onPressed: page + 1 < pageCount
                      ? () => setState(() => _diningTableListPage = page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _diningTableFloorMap(
    List<CafeDiningTable> tables, {
    required bool allowTableEditing,
  }) {
    final canEdit =
        _canManageDiningTables &&
        allowTableEditing &&
        _selectedSubcard == 'Table Map';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            if (canEdit && _isEditingDiningTableMap) ...[
              OutlinedButton.icon(
                key: const ValueKey('dining-map-discard'),
                onPressed: _isSavingDiningTableMap
                    ? null
                    : _discardDiningTableMapEdit,
                icon: const Icon(Icons.undo_outlined),
                label: const CafeText('Discard'),
              ),
              FilledButton.icon(
                key: const ValueKey('dining-map-save'),
                onPressed: _isSavingDiningTableMap
                    ? null
                    : _saveDiningTableMapEdit,
                icon: _isSavingDiningTableMap
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSavingDiningTableMap ? 'Saving…' : 'Save layout',
                ),
              ),
            ] else if (canEdit)
              FilledButton.tonalIcon(
                key: const ValueKey('dining-map-edit'),
                onPressed: _isLoadingDiningTables
                    ? null
                    : _startDiningTableMapEdit,
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const CafeText('Edit map'),
              ),
            IconButton(
              tooltip: 'Zoom in on table map',
              onPressed: () {
                _diningTableMapTransformationController.value =
                    _diningTableMapTransformationController.value.clone()
                      ..scaleByDouble(1.2, 1.2, 1.2, 1);
              },
              icon: const Icon(Icons.zoom_in),
            ),
            IconButton(
              tooltip: 'Zoom out on table map',
              onPressed: () {
                _diningTableMapTransformationController.value =
                    _diningTableMapTransformationController.value.clone()
                      ..scaleByDouble(1 / 1.2, 1 / 1.2, 1 / 1.2, 1);
              },
              icon: const Icon(Icons.zoom_out),
            ),
            IconButton(
              tooltip: 'Fit table map to screen',
              onPressed: () {
                _diningTableMapTransformationController.value =
                    _diningTableMapTransformationController.value.clone()
                      ..setIdentity();
              },
              icon: const Icon(Icons.fit_screen_outlined),
            ),
          ],
        ),
        if (_isEditingDiningTableMap && canEdit)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: CafeText(
              'Long-press and drag tables to arrange them. Use the list view '
              'for keyboard-accessible position controls.',
              style: TextStyle(color: _executiveMuted, fontSize: 12),
            ),
          ),
        SizedBox(
          height: 470,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InteractiveViewer(
              key: const ValueKey('dining-table-map-viewer'),
              transformationController: _diningTableMapTransformationController,
              minScale: 0.35,
              maxScale: 3,
              boundaryMargin: const EdgeInsets.all(220),
              child: Container(
                key: _diningTableMapKey,
                width: CafeDiningTableRepository.mapCanvasWidth,
                height: CafeDiningTableRepository.mapCanvasHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FBFE),
                  border: Border.all(color: const Color(0xFFD9E1EB)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    const PositionedDirectional(
                      start: 12,
                      top: 10,
                      child: CafeText(
                        'SINGLE-FLOOR VIEW · SAVED AREAS',
                        style: TextStyle(
                          color: Color(0xFF8491A4),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    for (final table in tables)
                      Builder(
                        builder: (context) {
                          final position = _diningTableMapPosition(table);
                          final tile = _diningTableTile(
                            table,
                            allowTableEditing: allowTableEditing,
                          );
                          return Align(
                            alignment: Alignment(
                              position.$1 * 2 - 1,
                              position.$2 * 2 - 1,
                            ),
                            child: canEdit && _isEditingDiningTableMap
                                ? LongPressDraggable<CafeDiningTable>(
                                    data: table,
                                    dragAnchorStrategy:
                                        pointerDragAnchorStrategy,
                                    maxSimultaneousDrags:
                                        _isSavingDiningTableMap ? 0 : 1,
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: _diningTableTile(
                                        table,
                                        isDragging: true,
                                        allowTableEditing: allowTableEditing,
                                      ),
                                    ),
                                    childWhenDragging: Opacity(
                                      opacity: 0.28,
                                      child: tile,
                                    ),
                                    onDragEnd: (details) =>
                                        _moveDiningTable(table, details),
                                    child: tile,
                                  )
                                : tile,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final status in CafeDiningTableRepository.statuses)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    size: 9,
                    color: _diningTableStatusColor(status),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _diningTableStatusLabel(status),
                    style: const TextStyle(
                      color: _executiveMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            const CafeText(
              'Saved table status (not live occupancy)',
              style: TextStyle(color: _executiveMuted, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  Widget _diningTableTile(
    CafeDiningTable table, {
    bool isDragging = false,
    required bool allowTableEditing,
  }) {
    final color = _diningTableStatusColor(table.status);
    final reservations = _reservationsForTable(table);
    final chairState = _chairStateFor(table);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _selectedSubcard == 'Table Map'
            ? () => _selectDiningTableInPanel(table)
            : _canManageDiningTables && allowTableEditing
            ? () => _showDiningTableForm(table: table)
            : () => _showDiningTableDetails(table),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 128,
          height: 86,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: color.withValues(alpha: 0.55),
              width: isDragging ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140E2844),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                table.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                chairState == null
                    ? '${table.seats} base seats · ${table.area}'
                    : '${chairState.currentChairs} chairs '
                          '(${chairState.baseChairs} base) · ${table.area}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 9),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _diningTableStatusLabel(table.status),
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (reservations.isNotEmpty) ...[
                const SizedBox(height: 3),
                CafeText(
                  '${reservations.length} reservation'
                  '${reservations.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Color(0xFF7B4B08),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  CafeChairTableState? _chairStateFor(CafeDiningTable table) {
    for (final chairState
        in _chairManagement?.tables ?? const <CafeChairTableState>[]) {
      if (chairState.tableId == table.id) return chairState;
    }
    return null;
  }

  Widget _diningTableListItem(
    CafeDiningTable table, {
    required bool allowTableEditing,
  }) {
    final reservations = _reservationsForTable(table);
    final isMapCard = _selectedSubcard == 'Table Map';
    final chairState = _chairStateFor(table);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _diningTableStatusColor(table.status)
              .withValues(alpha: 0.12),
          child: Icon(
            Icons.table_restaurant_outlined,
            color: _diningTableStatusColor(table.status),
          ),
        ),
        title: Text(table.name),
        subtitle: CafeText(
          '${table.area} · '
          '${chairState == null ? '${table.seats} base seats' : '${chairState.currentChairs} chairs (${chairState.baseChairs} base)'}'
          '${reservations.isEmpty ? '' : ' · ${reservations.length} reservation${reservations.length == 1 ? '' : 's'}'}',
        ),
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 2,
          children: [
            if (isMapCard) ...[
              Text(
                _diningTableStatusLabel(table.status),
                style: TextStyle(
                  color: _diningTableStatusColor(table.status),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_isEditingDiningTableMap) _tableMapListNudgers(table),
            ] else
              DropdownButton<String>(
                value: table.status,
                underline: const SizedBox.shrink(),
                items: [
                  for (final status in CafeDiningTableRepository.statuses)
                    DropdownMenuItem(
                      value: status,
                      child: Text(_diningTableStatusLabel(status)),
                    ),
                ],
                onChanged: _canManageDiningTables
                    ? (status) {
                        if (status != null) {
                          unawaited(_updateDiningTableStatus(table, status));
                        }
                      }
                    : null,
              ),
            if (_canManageDiningTables && allowTableEditing && !isMapCard) ...[
              IconButton(
                tooltip: 'Show ${table.name} QR code',
                onPressed: () => _showDiningTableQr(table),
                icon: const Icon(Icons.qr_code_2_outlined),
              ),
              IconButton(
                tooltip: 'Edit ${table.name}',
                onPressed: () => _showDiningTableForm(table: table),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete ${table.name}',
                onPressed: () => _confirmDeleteDiningTable(table),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tableMapListNudgers(CafeDiningTable table) {
    Widget nudge({
      required String direction,
      required IconData icon,
      required double dx,
      required double dy,
    }) {
      return IconButton(
        tooltip: 'Move ${table.name} $direction on map',
        visualDensity: VisualDensity.compact,
        onPressed: _isSavingDiningTableMap
            ? null
            : () => _nudgeDiningTableMapPosition(table, dx, dy),
        icon: Icon(icon, size: 18),
      );
    }

    const horizontalStep = 14 / CafeDiningTableRepository.mapCanvasWidth;
    const verticalStep = 14 / CafeDiningTableRepository.mapCanvasHeight;
    return Wrap(
      spacing: 0,
      children: [
        nudge(
          direction: 'left',
          icon: Icons.chevron_left,
          dx: -horizontalStep,
          dy: 0,
        ),
        nudge(
          direction: 'up',
          icon: Icons.keyboard_arrow_up,
          dx: 0,
          dy: -verticalStep,
        ),
        nudge(
          direction: 'down',
          icon: Icons.keyboard_arrow_down,
          dx: 0,
          dy: verticalStep,
        ),
        nudge(
          direction: 'right',
          icon: Icons.chevron_right,
          dx: horizontalStep,
          dy: 0,
        ),
      ],
    );
  }

  Color _diningTableStatusColor(String status) => switch (status) {
    'available' => const Color(0xFF16814A),
    'occupied' => const Color(0xFF2463EB),
    'reserved' => const Color(0xFFB9670C),
    'cleaning' => const Color(0xFF6B7280),
    _ => _muted,
  };

  String _diningTableStatusLabel(String status) => switch (status) {
    'available' => 'Available',
    'occupied' => 'Occupied',
    'reserved' => 'Reserved',
    'cleaning' => 'Cleaning',
    _ => status,
  };

  Widget _diningTableCombinedWorkspace() {
    final query = _tableSearch.trim().toLowerCase();
    final areas = _diningTables.map((table) => table.area).toSet().toList()
      ..sort();
    final selectedArea = areas.contains(_selectedDiningTableArea)
        ? _selectedDiningTableArea
        : 'All areas';
    final filteredTables = _diningTables
        .where(
          (table) =>
              (selectedArea == 'All areas' || table.area == selectedArea) &&
              (_tableStatusFilter == 'All' ||
                  table.status == _tableStatusFilter.toLowerCase()) &&
              (query.isEmpty ||
                  table.name.toLowerCase().contains(query) ||
                  table.area.toLowerCase().contains(query) ||
                  _diningTableStatusLabel(table.status)
                      .toLowerCase()
                      .contains(query)),
        )
        .toList(growable: false);
    final selectedTable = _diningTables.where(
      (table) => table.id == _selectedDiningTablePanelId,
    );
    final desktop = MediaQuery.sizeOf(context).width >= 980;
    final showEditor = desktop || _diningTablePanelOnMobile;
    final listPane = _diningTableSavedListPane(
      filteredTables,
      areas,
      selectedArea,
    );
    final editorPane = _diningTableEditorPane(
      selectedTable.isEmpty ? null : selectedTable.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _executiveSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _executiveBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.table_restaurant_outlined, color: _gold),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CafeText(
                      'Table workspace',
                      style: TextStyle(
                        color: _executiveText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    CafeText(
                      'Saved tables and table details',
                      style: TextStyle(color: _executiveMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (!desktop && _diningTablePanelOnMobile)
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _diningTablePanelOnMobile = false),
                  icon: const Icon(Icons.arrow_back),
                  label: const CafeText('List'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (desktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: listPane),
              const SizedBox(width: 14),
              Expanded(flex: 6, child: editorPane),
            ],
          )
        else if (showEditor)
          editorPane
        else
          listPane,
      ],
    );
  }

  Widget _diningTableSavedListPane(
    List<CafeDiningTable> tables,
    List<String> areas,
    String selectedArea,
  ) {
    final counts = {
      'All': _diningTables.length,
      for (final status in CafeDiningTableRepository.statuses)
        status: _diningTables.where((table) => table.status == status).length,
    };
    return Card(
      key: const ValueKey('saved-tables-panel'),
      margin: EdgeInsets.zero,
      color: _executiveSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _executiveBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: CafeText(
                    'Saved tables',
                    style: TextStyle(
                      color: _executiveText,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh saved tables',
                  onPressed: _isLoadingDiningTables
                      ? null
                      : () => unawaited(_loadDiningTables()),
                  icon: const Icon(Icons.refresh, color: _executiveMuted),
                ),
                if (_canManageDiningTables)
                  FilledButton.icon(
                    key: const ValueKey('add-dining-table'),
                    onPressed: _diningTableError != null
                        ? null
                        : _startDiningTablePanelDraft,
                    icon: const Icon(Icons.add),
                    label: const CafeText('Add table'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in counts.entries)
                  _tableSummaryCard(
                    width: 106,
                    label: entry.key == 'All'
                        ? 'Total'
                        : _diningTableStatusLabel(entry.key),
                    value: _isLoadingDiningTables ? '…' : '${entry.value}',
                    icon: Icons.table_restaurant_outlined,
                    color: entry.key == 'All'
                        ? _gold
                        : _diningTableStatusColor(entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('dining-table-search'),
              decoration: const InputDecoration(
                hintText: 'Search table or area',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() {
                _tableSearch = value;
                _diningTableListPage = 0;
              }),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final area in ['All areas', ...areas])
                  ChoiceChip(
                    key: ValueKey('dining-map-area-tab-$area'),
                    label: Text(area),
                    selected: selectedArea == area,
                    onSelected: (_) =>
                        setState(() => _selectedDiningTableArea = area),
                  ),
                DropdownButton<String>(
                  key: const ValueKey('dining-table-status-filter'),
                  value: _tableStatusFilter,
                  items: [
                    const DropdownMenuItem(
                      value: 'All',
                      child: CafeText('All statuses'),
                    ),
                    for (final status in CafeDiningTableRepository.statuses)
                      DropdownMenuItem(
                        value: status[0].toUpperCase() + status.substring(1),
                        child: Text(_diningTableStatusLabel(status)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _tableStatusFilter = value);
                    }
                  },
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _tableSearch = '';
                    _tableStatusFilter = 'All';
                    _selectedDiningTableArea = 'All areas';
                    _diningTableListPage = 0;
                  }),
                  child: const CafeText('Reset'),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(
                    () => _diningTablePanelShowMap = !_diningTablePanelShowMap,
                  ),
                  icon: Icon(
                    _diningTablePanelShowMap
                        ? Icons.list_alt_outlined
                        : Icons.map_outlined,
                  ),
                  label: Text(_diningTablePanelShowMap ? 'List' : 'Map'),
                ),
              ],
            ),
            if (_diningTableError != null) ...[
              const SizedBox(height: 8),
              _AuthErrorMessage(_diningTableError!),
            ],
            if (_isLoadingDiningTables)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_diningTables.isEmpty)
              const Padding(
                padding: EdgeInsets.all(18),
                child: CafeText(
                  'No saved tables yet.',
                  key: ValueKey('saved-tables-empty'),
                  style: TextStyle(color: _executiveMuted),
                ),
              )
            else if (tables.isEmpty)
              const Padding(
                padding: EdgeInsets.all(18),
                child: CafeText(
                  'No tables match these filters.',
                  key: ValueKey('saved-tables-no-results'),
                  style: TextStyle(color: _executiveMuted),
                ),
              )
            else if (_diningTablePanelShowMap)
              _diningTableFloorMap(
                tables,
                allowTableEditing: _canManageDiningTables,
              )
            else
              for (final table in tables.take(
                _selectedSubcard == 'Table Map' && _isEditingDiningTableMap
                    ? tables.length
                    : 8,
              ))
                Card(
                  key: ValueKey('saved-table-row-${table.id}'),
                  margin: const EdgeInsets.only(top: 6),
                  color: _selectedDiningTablePanelId == table.id
                      ? const Color(0xFF203754)
                      : const Color(0xFF182B43),
                  child: ListTile(
                    onTap: () => _selectDiningTableInPanel(table),
                    title: Text(
                      table.name,
                      style: const TextStyle(
                        color: _executiveText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: CafeText(
                      '${table.area} · ${table.seats} seats',
                      style: const TextStyle(color: _executiveMuted),
                    ),
                    trailing: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _diningTableStatusLabel(table.status),
                          style: TextStyle(
                            color: _diningTableStatusColor(table.status),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_selectedSubcard == 'Table Map' &&
                            _isEditingDiningTableMap)
                          _tableMapListNudgers(table),
                        if (_canManageDiningTables &&
                            _selectedSubcard != 'Table Map')
                          IconButton(
                            tooltip: 'Show ${table.name} QR',
                            onPressed: () => _showDiningTableQr(table),
                            icon: const Icon(
                              Icons.qr_code_2_outlined,
                              color: _executiveMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            if (tables.length > 8 &&
                !_diningTablePanelShowMap &&
                !(_selectedSubcard == 'Table Map' && _isEditingDiningTableMap))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: CafeText(
                  'Showing 8 of ${tables.length} saved tables. Use search '
                  'and filters to narrow the list.',
                  style: const TextStyle(color: _executiveMuted, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _diningTableEditorPane(CafeDiningTable? selectedTable) {
    final tabs = [
      'Basic Info',
      'Chairs & Capacity',
      'Location & Map',
      'QR Code',
      'Pricing & Modes',
      'Settings',
    ];
    final hasSelected = _diningTablePanelIsNew || selectedTable != null;
    return Card(
      key: const ValueKey('dining-table-editor-panel'),
      margin: EdgeInsets.zero,
      color: _executiveSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _executiveBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _diningTablePanelIsNew
                  ? 'New table'
                  : selectedTable?.name ?? 'Select a table to edit',
              style: const TextStyle(
                color: _executiveText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < tabs.length; index++) ...[
                    if (index > 0) const SizedBox(width: 6),
                    ChoiceChip(
                      key: ValueKey('dining-table-editor-tab-$index'),
                      label: Text(tabs[index]),
                      selected: _diningTableEditorTab == index,
                      onSelected: (_) =>
                          setState(() => _diningTableEditorTab = index),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (!hasSelected)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: CafeText(
                  'Select a saved table or choose Add table. '
                  'The current database supports name, area, seats, '
                  'manual status, and map position only.',
                  style: TextStyle(color: _executiveMuted, height: 1.5),
                ),
              )
            else if (_diningTableEditorTab == 0)
              Form(
                key: _diningTablePanelFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      key: const ValueKey('table-panel-name'),
                      controller: _diningTablePanelNameController,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        label: CafeText('Table name or number'),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a table name or number'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const ValueKey('table-panel-area'),
                      controller: _diningTablePanelAreaController,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        label: CafeText('Area'),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter an area'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const ValueKey('table-panel-capacity'),
                      controller: _diningTablePanelSeatsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        label: CafeText('Seat capacity'),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final seats = int.tryParse(value?.trim() ?? '');
                        return seats == null || seats < 1 || seats > 100
                            ? 'Enter a seat capacity from 1 to 100'
                            : null;
                      },
                    ),
                    if (selectedTable != null) ...[
                      const SizedBox(height: 8),
                      InputDecorator(
                        decoration: const InputDecoration(
                          label: CafeText('Current table status'),
                          border: OutlineInputBorder(),
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            _diningTableStatusLabel(selectedTable.status),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              _diningTableEditorTabContent(selectedTable),
            if (_diningTablePanelError != null) ...[
              const SizedBox(height: 10),
              _AuthErrorMessage(_diningTablePanelError!),
            ],
            const SizedBox(height: 14),
            if (_canManageDiningTables &&
                hasSelected &&
                (_diningTableEditorTab == 0 || _diningTableEditorTab == 4))
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    key: const ValueKey('save-dining-table-panel'),
                    onPressed: _isSavingDiningTablePanel
                        ? null
                        : () => _saveDiningTablePanel(addAnother: false),
                    child: Text(
                      _isSavingDiningTablePanel
                          ? 'Saving…'
                          : _diningTablePanelIsNew
                          ? 'Save table'
                          : 'Save changes',
                    ),
                  ),
                  if (_diningTablePanelIsNew)
                    OutlinedButton(
                      key: const ValueKey('save-add-another-table'),
                      onPressed: _isSavingDiningTablePanel
                          ? null
                          : () => _saveDiningTablePanel(addAnother: true),
                      child: const CafeText('Save & add another'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _diningTableEditorTabContent(CafeDiningTable? table) {
    if (_diningTableEditorTab == 4) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF101E31),
          border: Border.all(color: _executiveBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CafeText(
              'Default mode for this table',
              style: TextStyle(
                color: _executiveText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const ValueKey('dining-table-pricing-mode'),
              initialValue: _diningTablePanelPricingMode,
              decoration: const InputDecoration(
                label: CafeText('Pricing mode'),
                border: OutlineInputBorder(),
              ),
              items: [
                for (final mode in CafeDiningTableRepository.pricingModes)
                  DropdownMenuItem(
                    value: mode,
                    child: Text(switch (mode) { 'tourism' => 'Tourism Mode', 'owner' => 'Owner Mode', _ => 'Normal Mode' }),
                  ),
              ],
              onChanged: _canManageDiningTables
                  ? (mode) {
                      if (mode != null) {
                        setState(() {
                          _diningTablePanelPricingMode = mode;
                          _diningTablePanelError = null;
                        });
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            const CafeText(
              'This table’s active mode selects product prices for its QR menu and new orders. Existing orders keep their original prices.',
              style: TextStyle(color: _executiveMuted, height: 1.4),
            ),
          ],
        ),
      );
    }
    final description = switch (_diningTableEditorTab) {
      1 =>
        'Chair inventory, chair layouts, shapes, and extra-chair policy '
            'are not stored by the current dining-table schema.',
      2 =>
        table == null
            ? 'Save a table to view its current map position.'
            : 'Saved normalized map position: '
                  '${table.x.toStringAsFixed(3)}, ${table.y.toStringAsFixed(3)}. '
                  'Use the map view to move the table.',
      3 =>
        table == null
            ? 'Save a table before displaying its QR code.'
            : 'Table QR tokens are managed by the secured QR workflow.',
      _ =>
        'Floor, online booking, archive, and operational settings are not '
            'available in the current verified schema.',
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 175),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101E31),
        border: Border.all(color: _executiveBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description, style: const TextStyle(color: _executiveMuted)),
          if (_diningTableEditorTab == 2) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _diningTablePanelShowMap = true;
                if (MediaQuery.sizeOf(context).width < 980) {
                  _diningTablePanelOnMobile = false;
                }
              }),
              icon: const Icon(Icons.map_outlined),
              label: const CafeText('Show table map'),
            ),
          ],
          if (_diningTableEditorTab == 3 && table != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _showDiningTableQr(table),
              icon: const Icon(Icons.qr_code_2_outlined),
              label: const CafeText('Preview / print table QR'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionSubcardGrid(int sectionIndex) {
    if (sectionIndex == 0) return _dashboardLayout();
    if (sectionIndex == 1) {
      return _visibleSubcards(sectionIndex).isEmpty
          ? const CafeText(
              'Add Table access has not been assigned to this account.',
              style: TextStyle(color: _executiveMuted),
            )
          : _tablesChairsWorkspace();
    }
    final visibleSubcards = _visibleSubcards(sectionIndex);
    if (visibleSubcards.isEmpty) {
      return const CafeText(
        'No cards in this section are assigned to this account.',
        style: TextStyle(color: _executiveMuted),
      );
    }
    if (sectionIndex == 2) {
      return _paymentManagementOverview(visibleSubcards);
    }
    if (sectionIndex == 3) {
      return _menuManagementWorkspace(visibleSubcards);
    }
    if (sectionIndex == 4) {
      return _kitchenManagementWorkspace(visibleSubcards);
    }
    if (sectionIndex == 5) {
      return _motelOrdersWorkspace(visibleSubcards);
    }
    if (sectionIndex == 6) {
      return _inventoryManagementWorkspace(visibleSubcards);
    }
    if (sectionIndex == 6) {
      return _inventoryManagementWorkspace(visibleSubcards);
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
              color: _executiveSurface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: _executiveBorder),
              ),
              child: ExpansionTile(
                key: PageStorageKey<String>('section-more-cards-$sectionIndex'),
                title: CafeText(
                  'More cards (${additionalCards.length})',
                  style: const TextStyle(
                    color: _executiveText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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

  String? _inventoryWorkspaceTitle(String cardTitle) {
    final mappedTitle = _inventoryCardRouteTitles[cardTitle];
    if (mappedTitle != null) return mappedTitle;
    return _subcards[6].contains(cardTitle) ? cardTitle : null;
  }

  Widget _inventoryManagementWorkspace(List<String> visibleSubcards) {
    final category = _inventoryManagementCategories[_selectedInventoryCategory];
    final query = _inventoryCardSearch.trim().toLowerCase();
    final categoryCards = category.cards
        .where((title) {
          if (visibleSubcards.contains(title)) return true;
          final legacyTitle = _inventoryCardRouteTitles[title];
          return legacyTitle != null && visibleSubcards.contains(legacyTitle);
        })
        .where((title) {
          if (query.isEmpty) return true;
          return title.toLowerCase().contains(query) ||
              (_inventoryCardPurposes[title] ?? '').toLowerCase().contains(
                query,
              );
        })
        .toList(growable: false);
    final categoryCounts = [
      for (final inventoryCategory in _inventoryManagementCategories)
        inventoryCategory.cards.where((title) {
          if (visibleSubcards.contains(title)) return true;
          final legacyTitle = _inventoryCardRouteTitles[title];
          return legacyTitle != null && visibleSubcards.contains(legacyTitle);
        }).length,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (
                var index = 0;
                index < _inventoryManagementCategories.length;
                index++
              ) ...[
                if (index > 0) const SizedBox(width: 8),
                ChoiceChip(
                  key: ValueKey('inventory-category-tab-$index'),
                  avatar: Icon(
                    _inventoryManagementCategories[index].icon,
                    size: 17,
                  ),
                  label: CafeText(
                    '${_inventoryManagementCategories[index].title} '
                    '(${categoryCounts[index]})',
                  ),
                  selected: _selectedInventoryCategory == index,
                  onSelected: (_) => setState(() {
                    _selectedInventoryCategory = index;
                    _inventoryCardSearch = '';
                  }),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('inventory-card-search'),
          onChanged: (value) => setState(() => _inventoryCardSearch = value),
          decoration: InputDecoration(
            hintText: 'Search ${category.title.toLowerCase()} cards...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear inventory card search',
                    onPressed: () => setState(() => _inventoryCardSearch = ''),
                    icon: const Icon(Icons.close),
                  ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE1E7EF)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (categoryCards.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              query.isEmpty
                  ? 'No cards in this category are assigned to this account.'
                  : 'No inventory cards match "$_inventoryCardSearch".',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1120
                  ? 4
                  : constraints.maxWidth >= 760
                  ? 3
                  : constraints.maxWidth >= 500
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                key: ValueKey(
                  'inventory-category-cards-$_selectedInventoryCategory',
                ),
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final title in categoryCards)
                    SizedBox(
                      width: width,
                      child: _inventoryCategoryCard(title),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _inventoryCategoryCard(String title) {
    final theme = Theme.of(context);
    final palette = _executiveCardPalette(6);
    final purpose = _inventoryCardPurposes[title]!;
    final hasExistingWorkspace = _inventoryWorkspaceTitle(title) != null;
    return Semantics(
      button: true,
      label:
          '$title. $purpose. '
          '${hasExistingWorkspace ? 'Existing generic record workspace' : 'Design only'}',
      child: Card(
        key: ValueKey('inventory-category-card-$title'),
        margin: EdgeInsets.zero,
        color: palette.background,
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.accent.withValues(alpha: 0.35)),
        ),
        child: InkWell(
          onTap: () => setState(() {
            _workspaceSearch = '';
            _workspaceStatusFilter = 'All';
            _selectedSubcard = title;
          }),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _metricIcon(title, Icons.inventory_2_outlined),
                      color: palette.accent,
                      size: 22,
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_outward, size: 17, color: palette.accent),
                  ],
                ),
                const SizedBox(height: 9),
                CafeText(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _executiveText,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  purpose,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _executiveMuted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hasExistingWorkspace
                        ? 'Existing generic records · no stock ledger'
                        : 'Design only · ledger integration unverified',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inventoryCardDesignDetail(String title) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _metricIcon(title, Icons.inventory_2_outlined),
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CafeText(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Chip(
                  label: CafeText('Design only'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _inventoryCardPurposes[title]!,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const CafeText(
                'Coming Soon — Awaiting a verified inventory ledger and '
                'approved integrations. This preview does not change stock '
                'quantities, receive purchases, update menu availability, '
                'calculate inventory value, or perform backup or export '
                'operations. No inventory database schema has been added.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inventoryExistingWorkspaceDetail(
    ({String key, IconData icon, String title, String description}) section,
    String workspaceTitle,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: CafeText(
                    'This card preserves the existing generic records for '
                    '"$workspaceTitle". They are not connected to stock '
                    'balances or an inventory ledger.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _subcardDetail(section, workspaceTitle),
      ],
    );
  }

  Widget _motelOrdersWorkspace(List<String> visibleSubcards) {
    final category = _motelOrdersCategories[_selectedMotelOrdersCategory];
    final categoryCards = category.cards
        .where(visibleSubcards.contains)
        .toList(growable: false);
    final categoryCounts = [
      for (final motelCategory in _motelOrdersCategories)
        motelCategory.cards.where(visibleSubcards.contains).length,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (
                var index = 0;
                index < _motelOrdersCategories.length;
                index++
              ) ...[
                if (index > 0) const SizedBox(width: 8),
                ChoiceChip(
                  key: ValueKey('motel-orders-category-tab-$index'),
                  avatar: Icon(_motelOrdersCategories[index].icon, size: 17),
                  label: CafeText(
                    '${_motelOrdersCategories[index].title} '
                    '(${categoryCounts[index]})',
                  ),
                  selected: _selectedMotelOrdersCategory == index,
                  onSelected: (_) => setState(() {
                    _selectedMotelOrdersCategory = index;
                  }),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (categoryCards.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CafeText(
              'No cards in this category are assigned to this account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1120
                  ? 4
                  : constraints.maxWidth >= 760
                  ? 3
                  : constraints.maxWidth >= 500
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                key: ValueKey(
                  'motel-orders-category-cards-$_selectedMotelOrdersCategory',
                ),
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final title in categoryCards)
                    SizedBox(
                      width: width,
                      child: _motelOrdersCategoryCard(title),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _motelOrdersCategoryCard(String title) {
    final theme = Theme.of(context);
    final palette = _executiveCardPalette(5);
    final purpose = _motelOrderPurposes[title]!;
    return Semantics(
      button: true,
      label: '$title. $purpose. ${_connectedOperations(5, title) != null ? 'Connected order workflow' : 'Design only; no live order processing'}',
      child: Card(
        key: ValueKey('motel-orders-category-card-$title'),
        margin: EdgeInsets.zero,
        color: palette.background,
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.accent.withValues(alpha: 0.35)),
        ),
        child: InkWell(
          onTap: () => setState(() {
            _selectedSubcard = title;
          }),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _metricIcon(title, Icons.hotel_outlined),
                      color: palette.accent,
                      size: 22,
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_outward, size: 17, color: palette.accent),
                  ],
                ),
                const SizedBox(height: 9),
                CafeText(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _executiveText,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  purpose,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _executiveMuted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _connectedOperations(5, title) != null ? 'Connected order workflow' : 'Design only · integration unverified',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _motelOrderDesignDetail(String title) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _metricIcon(title, Icons.hotel_outlined),
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CafeText(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Chip(
                  label: CafeText('Design only'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _motelOrderPurposes[title]!,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const CafeText(
                'Coming Soon — Awaiting verified integrations. This preview '
                'does not create or process orders, charge payments, reserve '
                'rooms, or dispatch deliveries. Existing saved records remain '
                'unchanged.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuManagementWorkspace(List<String> visibleSubcards) {
    final category = _menuManagementCategories[_selectedMenuCategory];
    final query = _menuCardSearch.trim().toLowerCase();
    final categoryCards = category.cards
        .where(visibleSubcards.contains)
        .where((title) {
          if (query.isEmpty) return true;
          return title.toLowerCase().contains(query) ||
              (_menuCardPurposes[title] ?? '').toLowerCase().contains(query);
        })
        .toList(growable: false);
    final categoryCounts = [
      for (final menuCategory in _menuManagementCategories)
        menuCategory.cards.where(visibleSubcards.contains).length,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (
                var index = 0;
                index < _menuManagementCategories.length;
                index++
              ) ...[
                if (index > 0) const SizedBox(width: 8),
                ChoiceChip(
                  key: ValueKey('menu-category-tab-$index'),
                  avatar: Icon(_menuManagementCategories[index].icon, size: 17),
                  label: CafeText(
                    '${_menuManagementCategories[index].title} '
                    '(${categoryCounts[index]})',
                  ),
                  selected: _selectedMenuCategory == index,
                  onSelected: (_) => setState(() {
                    _selectedMenuCategory = index;
                    _menuCardSearch = '';
                  }),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('menu-card-search'),
          onChanged: (value) => setState(() => _menuCardSearch = value),
          decoration: InputDecoration(
            hintText: 'Search ${category.title.toLowerCase()} cards...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear menu card search',
                    onPressed: () => setState(() => _menuCardSearch = ''),
                    icon: const Icon(Icons.close),
                  ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE1E7EF)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (categoryCards.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              query.isEmpty
                  ? 'No cards in this category are assigned to this account.'
                  : 'No menu cards match "$_menuCardSearch".',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1120
                  ? 4
                  : constraints.maxWidth >= 760
                  ? 3
                  : constraints.maxWidth >= 500
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                key: ValueKey('menu-category-cards-$_selectedMenuCategory'),
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final title in categoryCards)
                    SizedBox(width: width, child: _menuCategoryCard(title)),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _kitchenManagementWorkspace(List<String> visibleSubcards) {
    final category = _kitchenManagementCategories[_selectedKitchenCategory];
    final query = _kitchenCardSearch.trim().toLowerCase();
    final categoryCards = category.cards
        .where(visibleSubcards.contains)
        .where((title) {
          if (query.isEmpty) return true;
          return title.toLowerCase().contains(query) ||
              (_kitchenCardPurposes[title] ?? '').toLowerCase().contains(query);
        })
        .toList(growable: false);
    final categoryCounts = [
      for (final kitchenCategory in _kitchenManagementCategories)
        kitchenCategory.cards.where(visibleSubcards.contains).length,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (
                var index = 0;
                index < _kitchenManagementCategories.length;
                index++
              ) ...[
                if (index > 0) const SizedBox(width: 8),
                ChoiceChip(
                  key: ValueKey('kitchen-category-tab-$index'),
                  avatar: Icon(
                    _kitchenManagementCategories[index].icon,
                    size: 17,
                  ),
                  label: CafeText(
                    '${_kitchenManagementCategories[index].title} '
                    '(${categoryCounts[index]})',
                  ),
                  selected: _selectedKitchenCategory == index,
                  onSelected: (_) => setState(() {
                    _selectedKitchenCategory = index;
                    _kitchenCardSearch = '';
                  }),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('kitchen-card-search'),
          onChanged: (value) => setState(() => _kitchenCardSearch = value),
          decoration: InputDecoration(
            hintText: 'Search ${category.title.toLowerCase()} cards...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear kitchen card search',
                    onPressed: () => setState(() => _kitchenCardSearch = ''),
                    icon: const Icon(Icons.close),
                  ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE1E7EF)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (categoryCards.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              query.isEmpty
                  ? 'No cards in this category are assigned to this account.'
                  : 'No kitchen cards match "$_kitchenCardSearch".',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1120
                  ? 4
                  : constraints.maxWidth >= 760
                  ? 3
                  : constraints.maxWidth >= 500
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                key: ValueKey(
                  'kitchen-category-cards-$_selectedKitchenCategory',
                ),
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final title in categoryCards)
                    SizedBox(width: width, child: _kitchenCategoryCard(title)),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _kitchenCategoryCard(String title) {
    final theme = Theme.of(context);
    final palette = _executiveCardPalette(4);
    final purpose = _kitchenCardPurposes[title]!;
    final hasExistingWorkspace = _subcards[4].contains(title);
    return Semantics(
      button: true,
      label:
          '$title. $purpose. '
          '${_connectedOperations(4, title) != null ? 'Connected kitchen workflow' : hasExistingWorkspace ? 'Existing generic workspace' : 'Design only'}',
      child: Card(
        key: ValueKey('kitchen-category-card-$title'),
        margin: EdgeInsets.zero,
        color: palette.background,
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.accent.withValues(alpha: 0.35)),
        ),
        child: InkWell(
          onTap: () => setState(() {
            _workspaceSearch = '';
            _workspaceStatusFilter = 'All';
            _selectedSubcard = title;
          }),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _metricIcon(title, Icons.soup_kitchen_outlined),
                      color: palette.accent,
                      size: 22,
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_outward, size: 17, color: palette.accent),
                  ],
                ),
                const SizedBox(height: 9),
                CafeText(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _executiveText,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  purpose,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _executiveMuted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _connectedOperations(4, title) != null ? 'Connected kitchen workflow' : hasExistingWorkspace
                        ? 'Existing generic workspace'
                        : 'Design only · integration unverified',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kitchenCardDesignDetail(String title) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _metricIcon(title, Icons.soup_kitchen_outlined),
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CafeText(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Chip(
                  label: CafeText('Design only'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _kitchenCardPurposes[title]!,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const CafeText(
                'Kitchen order, station, printer, menu and inventory '
                'integrations have not been verified. This card is a design '
                'preview only: it does not load or change orders, create '
                'tickets, print, or update stock.',
                style: TextStyle(height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kitchenLegacyCardDetail(
    ({String key, IconData icon, String title, String description}) section,
    String subcard,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const CafeText(
            'This existing route and its saved records are preserved in the '
            'generic workspace. They are not connected to a verified live '
            'kitchen order, station, or printer system.',
            style: TextStyle(height: 1.4),
          ),
        ),
        const SizedBox(height: 12),
        _subcardDetail(section, subcard),
      ],
    );
  }

  Widget _menuCategoryCard(String title) {
    final theme = Theme.of(context);
    final palette = _executiveCardPalette(3);
    final purpose = _menuCardPurposes[title]!;
    final isExistingWorkspace = _subcards[3].contains(title);
    return Semantics(
      button: true,
      label:
          '$title. $purpose. '
          '${_connectedOperations(3, title) != null ? 'Connected product catalog' : isExistingWorkspace ? 'Existing generic workspace' : 'Design only'}',
      child: Card(
        key: ValueKey('menu-category-card-$title'),
        margin: EdgeInsets.zero,
        color: palette.background,
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.accent.withValues(alpha: 0.35)),
        ),
        child: InkWell(
          onTap: () => setState(() {
            _workspaceSearch = '';
            _workspaceStatusFilter = 'All';
            _selectedSubcard = title;
          }),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _metricIcon(title, Icons.restaurant_menu_outlined),
                      color: palette.accent,
                      size: 22,
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_outward, size: 17, color: palette.accent),
                  ],
                ),
                const SizedBox(height: 9),
                CafeText(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _executiveText,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  purpose,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _executiveMuted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _connectedOperations(3, title) != null ? 'Connected product catalog' : isExistingWorkspace
                        ? 'Existing generic workspace'
                        : 'Design only · integration unverified',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuCardDesignDetail(String title) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _metricIcon(title, Icons.restaurant_menu_outlined),
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CafeText(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Chip(
                  label: CafeText('Design only'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _menuCardPurposes[title]!,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const CafeText(
                'Product-specific data sources and integrations have not been '
                'verified. This workspace is a design preview only: no catalog '
                'records are loaded or changed, and operational actions are '
                'not available.',
                style: TextStyle(height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuLegacyCardDetail(
    ({String key, IconData icon, String title, String description}) section,
    String subcard,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const CafeText(
            'This existing route and its stored workspace records are preserved. '
            'They use the generic record workspace and are not verified product '
            'catalog, pricing, inventory, or order integrations.',
            style: TextStyle(height: 1.4),
          ),
        ),
        const SizedBox(height: 12),
        _subcardDetail(section, subcard),
      ],
    );
  }

  Widget _tablesChairsWorkspace() {
    final category = _tablesChairsCategories[_selectedTablesCategory];
    bool canShowCard(String title) => _canAccessTablesCard(title);
    final visibleCards = category.cards
        .where(canShowCard)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (
                var index = 0;
                index < _tablesChairsCategories.length;
                index++
              ) ...[
                if (index > 0) const SizedBox(width: 8),
                ChoiceChip(
                  key: ValueKey('tables-category-$index'),
                  label: CafeText(
                    '${_tablesChairsCategories[index].title} '
                    '(${_tablesChairsCategories[index].cards.where(canShowCard).length})',
                  ),
                  selected: _selectedTablesCategory == index,
                  onSelected: (_) =>
                      setState(() => _selectedTablesCategory = index),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1050
                ? 4
                : constraints.maxWidth >= 700
                ? 3
                : constraints.maxWidth >= 450
                ? 2
                : 1;
            return GridView.builder(
              key: ValueKey('tables-category-cards-$_selectedTablesCategory'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleCards.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: 142,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) => _tableCategoryCard(visibleCards[index], index),
            );
          },
        ),
      ],
    );
  }

  Widget _tablesChairsCardDetail(
    ({String key, IconData icon, String title, String description}) section,
    String subcard,
  ) {
    if (subcard == 'Table Reservations') {
      return _tableReservationsWorkspace();
    }
    if (subcard == 'Add Table' ||
        subcard == 'Edit & Manage Tables' ||
        subcard == 'Table Map' ||
        subcard == 'QR Code Management' ||
        subcard == 'Chairs Management') {
      return _tableManagementDetail(section, subcard);
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _metricIcon(subcard, section.icon),
                  size: 42,
                  color: const Color(0xFF61718A),
                ),
                const SizedBox(height: 14),
                CafeText(
                  subcard,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const CafeText(
                  'Coming Soon — Awaiting Specification',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF61718A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const CafeText(
                  'This card is not operational yet. It will be designed and '
                  'implemented after its requirements are approved.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
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
            for (var index = 0; index < titles.length; index++)
              SizedBox(
                width: cardWidth,
                child: _managementCard(
                  sectionIndex,
                  titles[index],
                  cardIndex: index,
                  revenue: titles[index] == revenueCard ? revenue : null,
                  revenueUnavailable:
                      titles[index] == revenueCard && revenueUnavailable,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _dashboardLayout() {
    final assignedCards = _visibleSubcards(0);
    List<String> cardsForGroup(int index) => assignedCards
        .where(_dashboardGroups[index].cards.contains)
        .where((title) => '$title ${_dashboardGroups[index].title}'.toLowerCase().contains(_dashboardSearch.trim().toLowerCase()))
        .toList(growable: false);
    final visibleGroupIndices = [
      for (var index = 0; index < _dashboardGroups.length; index++)
        if (index == 0 ? (_dashboardSearch.trim().isEmpty || 'favorites'.contains(_dashboardSearch.trim().toLowerCase()) || cardsForGroup(0).isNotEmpty) : cardsForGroup(index).isNotEmpty) index,
    ];
    if (widget.permissionsLoadError != null) {
      return Text(
        widget.permissionsLoadError == null
            ? 'No dashboard cards are assigned to this account.'
            : 'Dashboard cards are unavailable until permissions can be loaded.',
        style: const TextStyle(color: _executiveMuted),
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
                const CafeText(
                  'Operational overview',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                const CafeText(
                  'Dashboard',
                  style: TextStyle(
                    color: _executiveText,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const CafeText(
                  'Saved records and confirmed bookings · Baghdad time (UTC+03:00).',
                  style: TextStyle(color: _executiveMuted, fontSize: 13),
                ),
              ],
            );
            final pageActions = Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _isLoadingRecords || _isLoadingTableReservations
                      ? null
                      : () => unawaited(Future.wait<void>([
                          _loadWorkspaceRecords(),
                          if (_canViewTableReservations) _loadTableReservations(),
                        ])),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const CafeText('Refresh'),
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
        TextField(
          key: const ValueKey('dashboard-search'),
          style: const TextStyle(color: _executiveText),
          decoration: const InputDecoration(
            label: CafeText('Search dashboard cards or categories'),
            labelStyle: TextStyle(color: _executiveMuted),
            prefixIcon: Icon(Icons.search, color: _executiveMuted),
          ),
          onChanged: (value) => setState(() => _dashboardSearch = value),
        ),
        const SizedBox(height: 12),
        if (visibleGroupIndices.isEmpty)
          const CafeText('No assigned dashboard cards match your search.', style: TextStyle(color: _executiveMuted)),
        if (visibleGroupIndices.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final index in visibleGroupIndices)
                ChoiceChip(
                  key: ValueKey('dashboard-category-tab-$index'),
                  label: Text(_dashboardGroups[index].title),
                  selected: index == (visibleGroupIndices.contains(_selectedDashboardCategory) ? _selectedDashboardCategory : visibleGroupIndices.first),
                  onSelected: (_) => setState(() => _selectedDashboardCategory = index),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final index in [visibleGroupIndices.contains(_selectedDashboardCategory) ? _selectedDashboardCategory : visibleGroupIndices.first])
            if (index == 0 && (_dashboardSearch.trim().isEmpty || cardsForGroup(0).isEmpty)) _favoritesContent() else _dashboardGroup(index: index, group: _dashboardGroups[index], visibleCards: cardsForGroup(index)),
        ],
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
                      'Existing cards show saved workspace records only. '
                          'Proposed dashboard cards are design previews until '
                          'their authoritative source integrations are verified. '
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
        const CafeText(
          'Quick Links',
          style: TextStyle(
            color: _executiveText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
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
                style: OutlinedButton.styleFrom(
                  foregroundColor: _executiveText,
                  side: BorderSide(color: _gold.withValues(alpha: 0.55)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  static const _dashboardGroups = [
    (
      title: 'Favorites',
      icon: Icons.dashboard_outlined,
      tint: Color(0xFFE9EFFD),
      iconColor: Color(0xFF3562B5),
      cards: ['Today Revenue', 'Tables Occupied', 'Kitchen Orders', 'Pending Payment', 'Today’s Orders', 'Today’s Customers', 'Motel Orders', 'Online & Walk-In Orders'],
    ),
    (
      title: 'Payments & Finance',
      icon: Icons.payments_outlined,
      tint: Color(0xFFDDF7EC),
      iconColor: Color(0xFF138052),
      cards: [
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
      ],
    ),
    (
      title: 'Tables & Reservations',
      icon: Icons.table_restaurant_outlined,
      tint: Color(0xFFE5EEFF),
      iconColor: Color(0xFF2463D3),
      cards: [
        'Live Tables',
        'Table Reservations',
        'Available Tables',
        'Waiting List',
        'Guest Check-In',
        'Table Cleaning',
        'Table Service Requests',
        'Guests Today',
        'Table History',
        'Table Map',
        'Reservations',
        'Cleaning Needed',
        'Table Occupancy',
      ],
    ),
    (
      title: 'Kitchen & Minibar',
      icon: Icons.soup_kitchen_outlined,
      tint: Color(0xFFFFEBD1),
      iconColor: Color(0xFFB75B11),
      cards: [
        'Kitchen Live Board',
        'Minibar Live Board',
        'Orders Preparing',
        'Ready for Delivery',
        'Delayed Orders',
        'Station Printers',
        'Menu Availability',
        'Menu',
        'Low Stock',
        'Nargile Orders',
        'Kitchen Queue',
      ],
    ),
    (
      title: 'Orders & Customer Service',
      icon: Icons.support_agent_outlined,
      tint: Color(0xFFE1F3F1),
      iconColor: Color(0xFF128277),
      cards: [
        'Table Orders',
        'Motel Orders Tracking',
        'Online Orders Tracking',
        'Walk-In Orders Tracking',
        'Customer Requests',
        'Customer Feedback',
        'Service Speed',
        'Today Orders',
        'Online Orders',
        'Takeaway & Delivery',
        'Feedback',
      ],
    ),
    (
      title: 'Employees & Operations',
      icon: Icons.groups_outlined,
      tint: Color(0xFFF0E4FF),
      iconColor: Color(0xFF7638BC),
      cards: [
        'Employee Attendance',
        'Employee Assignments',
        'Pending Staff Tasks',
        'Staff Performance',
        'Maintenance Requests',
        'Notifications & Alerts',
        'Customers',
        'Customer Number',
        'Employees',
        'Tasks',
        'Events',
        'Maintenance',
        'Attendance',
        'Tourism Customers',
      ],
    ),
    (
      title: 'Inventory & Purchasing',
      icon: Icons.inventory_2_outlined,
      tint: Color(0xFFFFF1D8),
      iconColor: Color(0xFFAC6C00),
      cards: [
        'Inventory Overview',
        'Low Stock Alerts',
        'Purchase Requests',
        'Pending Approvals',
        'Supplier Deliveries',
        'Inventory Waste',
      ],
    ),
    (
      title: 'Reports & System',
      icon: Icons.bar_chart_outlined,
      tint: Color(0xFFDFF5F6),
      iconColor: Color(0xFF117D84),
      cards: [
        'Sales Performance',
        'Product Performance',
        'Table Occupancy Reports',
        'Audit & Activity History',
        'System Health',
        'Backup & Sync Status',
        'Dashboard Personalization',
        'Reports',
        'Security',
        'Backup',
        'Offline Mode',
        'Audit & Activity',
        'Personalization',
      ],
    ),
  ];

  Widget _dashboardGroup({
    required int index,
    required ({
      String title,
      IconData icon,
      Color tint,
      Color iconColor,
      List<String> cards,
    })
    group,
    required List<String> visibleCards,
  }) {
    if (visibleCards.isEmpty) return const SizedBox.shrink();
    return Container(
      key: _dashboardCategoryKeys[index],
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _executiveSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _executiveBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
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
          backgroundColor: _executiveSurface,
          collapsedBackgroundColor: _executiveSurface,
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: group.iconColor.withValues(alpha: 0.15),
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
                    color: _executiveText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              CafeText(
                'See all (${visibleCards.length})',
                style: TextStyle(
                  color: _gold,
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
              paletteOffset: index,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardCardDesignDetail(String title) {
    final group = _dashboardGroups.firstWhere(
      (candidate) => candidate.cards.contains(title),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4EAF1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: group.tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(group.icon, color: group.iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CafeText(
                      title,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      group.title.toUpperCase(),
                      style: TextStyle(
                        color: group.iconColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const CafeText(
                      'Design preview — not live',
                      style: TextStyle(
                        color: Color(0xFF9A5B00),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const CafeText(
                      'The authoritative data source and integration for this '
                      'Dashboard card have not been verified. It does not '
                      'show live figures or perform business operations.',
                      style: TextStyle(color: _muted, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
          label: CafeText('$dateLabel · $_selectedDateRange'),
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

  static const _paymentCategories = [
    (title: 'Payments', cards: ['Receive Payment', 'Payment History', 'Refunds & Voids', 'Payment Overview', 'Pending Payments', 'Payment Collection', 'Cash/Card/Online', 'Pending Payment']),
    (title: 'Cash & Income', cards: ['Standing Cash', 'Collected Cash', 'Available Cash', 'Owner Cash Out', 'Table Income', 'Today Revenue', 'Revenue', 'Cash Over / Short', 'Cash Reconciliation']),
    (title: 'Expenses & Credit', cards: ['Expenses Management', 'Unpaid Expenses', 'Expense Payments', 'Confirm Credit Payment', 'Expenses', 'Confirm Credit', 'Costs & Expenses', 'Customer Credit', 'Discounts']),
    (title: 'Invoices & Administration', cards: ['Invoices & Receipts', 'Invoices & Payments', 'Invoices', 'Refunds', 'Approvals', 'Audit']),
  ];
  int _selectedPaymentCategory = 0;

  Widget _paymentManagementOverview(List<String> titles) {
    final groups = [
      for (var i = 0; i < _paymentCategories.length; i++)
        if (_paymentCategories[i].cards.any(titles.contains)) i,
    ];
    final selected = groups.contains(_selectedPaymentCategory)
        ? _selectedPaymentCategory : groups.first;
    final cards = _paymentCategories[selected].cards.where(titles.contains).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final index in groups) ...[
              if (index != groups.first) const SizedBox(width: 8),
              ChoiceChip(
                key: ValueKey('payment-category-$index'),
                label: CafeText('${_paymentCategories[index].title} (${_paymentCategories[index].cards.where(titles.contains).length})'),
                selected: selected == index,
                onSelected: (_) => setState(() => _selectedPaymentCategory = index),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1050 ? 4
              : constraints.maxWidth >= 700 ? 3
              : constraints.maxWidth >= 450 ? 2 : 1;
          return GridView.builder(
            key: ValueKey('payment-category-cards-$selected'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns, mainAxisExtent: 160,
              crossAxisSpacing: 12, mainAxisSpacing: 12,
            ),
              itemBuilder: (context, index) => _paymentCategoryCard(cards[index], index),
          );
        }),
      ],
    );
  }

  Widget _compactMetricGrid({
    required int sectionIndex,
    required List<String> titles,
    required double height,
    int paletteOffset = 0,
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
                  index: index + paletteOffset,
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
    final palette = _executiveCardPalette(sectionIndex + index);
    final section = _sections[sectionIndex];
    final reservationDashboardCard =
        sectionIndex == 0 && title == 'Table Reservations';
    final tableSnapshot = sectionIndex == 0 && dashboardTableCards.contains(title);
    final menuSnapshot = sectionIndex == 0 && dashboardMenuCards.contains(title);
    final reservationWorkflow = sectionIndex == 0 && const {'Reservations', 'Guest Check-In', 'Customer Number', 'Customer Requests', 'Kitchen Live Board', 'Table History', 'Waiting List', 'Table Map', 'Station Printers', 'Service Speed', 'Takeaway & Delivery', 'Employees', 'Employee Assignments', 'Maintenance', 'Maintenance Requests', 'Tasks', 'Pending Staff Tasks', 'Reports', 'Customer Feedback', 'Feedback', 'Employee Attendance', 'Attendance', 'Dashboard Personalization', 'Personalization'}.contains(title) || (sectionIndex == 0 && cafeInventoryCards.containsKey(title));
    final operationalReport = reservationWorkflow || menuSnapshot || tableSnapshot || operationalReportCards[section.key]?.contains(title) == true || cashWorkspaceCards[section.key]?.contains(title) == true || expenseWorkspaceCards[section.key]?.contains(title) == true;
    final designOnly =
        sectionIndex == 0 &&
        !_subcards[sectionIndex].contains(title) &&
        !reservationDashboardCard && !operationalReport;
    final records = designOnly || operationalReport
        ? const <CafeWorkspaceRecord>[]
        : _recordsInSelectedRange(
            _recordsFor(section.key, _permissionSlug(title)),
          );
    final confirmedReservationCount = _tableReservations
        .where((reservation) => reservation.status == 'confirmed' &&
          WorkspaceReportRange.forSelection(_selectedReportDate, _selectedDateRange).contains(reservation.startsAt))
        .length;
    final amountRecords = records.where((record) => record.amount != null);
    final recordedAmount = amountRecords.fold<double>(
      0,
      (total, record) => total + record.amount!,
    );
    final currency = amountRecords.isEmpty
        ? 'IQD'
        : amountRecords.first.currency;
    final unavailable = reservationDashboardCard
        ? !_canViewTableReservations || _tableReservationsError != null
        : _workspaceError != null;
    final isLoading = reservationDashboardCard
        ? _isLoadingTableReservations
        : _isLoadingRecords;
    final primary = reservationWorkflow ? 'Open workflow' : menuSnapshot ? 'Open products' : tableSnapshot ? 'Open tables' : operationalReport ? 'Open report' : reservationDashboardCard
        ? unavailable
              ? '—'
              : isLoading
              ? '…'
              : '$confirmedReservationCount'
        : designOnly
        ? 'Preview'
        : unavailable
        ? '—'
        : isLoading
        ? '…'
        : records.isEmpty
        ? '—'
        : amountRecords.isNotEmpty
        ? sectionIndex == 0
          ? workspaceAmountLabel(amountRecords.map((record) => (amount: record.amount, currency: record.currency)))
          : '${recordedAmount.toStringAsFixed(0)} $currency'
        : '${records.length}';
    final supporting = reservationWorkflow ? 'Requires workflow permissions' : menuSnapshot ? 'Current menu snapshot' : tableSnapshot ? 'Current table snapshot' : operationalReport ? 'Connected operational data' : reservationDashboardCard
        ? !_canViewTableReservations
              ? 'Access not assigned'
              : unavailable
              ? 'Unavailable'
              : isLoading
              ? 'Loading reservations'
              : 'Confirmed in selected period'
        : designOnly
        ? 'Not connected'
        : unavailable
        ? 'Unavailable'
        : isLoading
        ? 'Loading saved records'
        : records.isEmpty
        ? 'No records'
        : amountRecords.isNotEmpty
        ? '${records.length} saved amount record(s)'
        : records.length == 1
        ? '1 tracked record'
        : 'Tracked records';
    return Card(
      key: ValueKey(
        '${sectionIndex == 0 ? 'dashboard' : section.key}-card-'
        '${_permissionSlug(title)}',
      ),
      margin: EdgeInsets.zero,
      color: palette.background,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.accent.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (reservationDashboardCard &&
              (!_canViewTableReservations ||
                  !_hasSectionAccess(1) ||
                  !_visibleSubcards(1).contains(title))) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: CafeText(
                  'Table Reservations access has not been assigned.',
                ),
              ),
            );
            return;
          }
          setState(() {
            if (reservationDashboardCard) {
              
              _selectedIndex = 1;
              _reservationSearch = '';
              _reservationStatusFilter = 'All';
            } else if (sectionIndex == 2) {
              _financeSearch = '';
              _financeStatusFilter = 'All';
            } else if (sectionIndex == 1) {
              _tableSearch = '';
              _tableStatusFilter = 'All';
            }
            _selectedSubcard = title;
          });
        },
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
                      color: palette.accent.withValues(alpha: 0.14),
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
              CafeText(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _executiveText,
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
                  color: unavailable ? _executiveMuted : palette.accent,
                  fontSize: sectionIndex == 0 ? 14 : 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                supporting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _executiveMuted, fontSize: 9),
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
    'Add Table' ||
    'Add / Edit Tables' ||
    'Add/Edit Tables & Chairs' => Icons.add_box_outlined,
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

  Widget _tableReservationsWorkspace() {
    final query = _reservationSearch.trim().toLowerCase();
    final filteredReservations = _tableReservations
        .where((reservation) {
          final table = _diningTables.where(
            (item) => item.id == reservation.tableId,
          );
          final tableName = table.isEmpty ? 'Table' : table.first.name;
          final matchesStatus =
              _reservationStatusFilter == 'All' ||
              reservation.status ==
                  _reservationStatusFilter.toLowerCase().replaceAll(' ', '_');
          final matchesQuery =
              query.isEmpty ||
              reservation.customerName.toLowerCase().contains(query) ||
              reservation.contact.toLowerCase().contains(query) ||
              tableName.toLowerCase().contains(query);
          return matchesStatus && matchesQuery &&
              cafeReservationInPeriod(reservation, _reservationTimeFilter, DateTime.now());
        })
        .toList(growable: false);
    final confirmedCount = _tableReservations
        .where((reservation) => reservation.status == 'confirmed')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _executiveSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _executiveBorder),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: _gold),
              SizedBox(width: 10),
              Expanded(
                child: CafeText(
                  'New reservations are checked and saved by Supabase. The '
                  'server verifies table capacity, table state, time overlap, '
                  'staff permission, and retry identity before confirming.',
                  style: TextStyle(color: _executiveText, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _tableSummaryCard(
              width: 160,
              label: 'Confirmed bookings',
              value: _tableReservationsError != null
                  ? '—'
                  : _isLoadingTableReservations
                  ? '…'
                  : '$confirmedCount',
              icon: Icons.event_available_outlined,
              color: _gold,
            ),
            _tableSummaryCard(
              width: 160,
              label: 'Tables available now',
              value: _diningTableError != null
                  ? '—'
                  : _isLoadingDiningTables
                  ? '…'
                  : '${_diningTables.where((table) => table.status == 'available').length}',
              icon: Icons.table_restaurant_outlined,
              color: const Color(0xFF34D399),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('table-reservation-search'),
                onChanged: (value) =>
                    setState(() => _reservationSearch = value),
                decoration: InputDecoration(
                  hintText: 'Search reservations...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear reservation search',
                          onPressed: () =>
                              setState(() => _reservationSearch = ''),
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: _executiveSurface,
                  hintStyle: const TextStyle(color: _executiveMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Refresh reservations',
              onPressed: _isLoadingTableReservations
                  ? null
                  : () {
                      unawaited(_loadDiningTables());
                      unawaited(_loadTableReservations());
                    },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final status in const ['All', 'Confirmed', 'Cancelled'])
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    label: Text(status),
                    selected: _reservationStatusFilter == status,
                    onSelected: (_) =>
                        setState(() => _reservationStatusFilter = status),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final period in const ['All dates', 'Today', 'Upcoming', 'Past'])
            ChoiceChip(label: CafeText(period), selected: _reservationTimeFilter == period,
              onSelected: (_) => setState(() => _reservationTimeFilter = period)),
        ]),
        const CafeText('Reservation date filters use Baghdad time. Confirmed bookings above counts all loaded dates.'),
        CafeText('${filteredReservations.length} matching reservations'),
        if (_tableReservationsError != null)
          _AuthErrorMessage(_tableReservationsError!)
        else if (_diningTableError != null)
          _AuthErrorMessage(_diningTableError!)
        else if (_isLoadingTableReservations || _isLoadingDiningTables)
          const Center(child: CircularProgressIndicator())
        else if (filteredReservations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Text(
              _tableReservations.isEmpty
                  ? 'No table reservations have been saved yet.'
                  : 'No reservations match the current search or filter.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _executiveMuted),
            ),
          )
        else
          for (final reservation in filteredReservations)
            _tableReservationTile(reservation),
        if (_canManageTableReservations) ...[
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              key: const ValueKey('create-table-reservation'),
              onPressed:
                  _tableReservationsError != null ||
                      _diningTableError != null ||
                      _isLoadingDiningTables ||
                      _isLoadingTableReservations
                  ? null
                  : _showCreateTableReservation,
              icon: const Icon(Icons.add),
              label: const CafeText('New reservation'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _tableReservationTile(CafeTableReservation reservation) {
    final table = _diningTables.where((item) => item.id == reservation.tableId);
    final tableLabel = table.isEmpty
        ? 'Table unavailable'
        : '${table.first.name} · ${table.first.area}';
    final canCancel =
        _canManageTableReservations &&
        reservation.status == 'confirmed' &&
        reservation.startsAt.isAfter(DateTime.now());
    return Card(
      key: ValueKey('table-reservation-${reservation.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      color: _executiveSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _executiveBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    reservation.customerName,
                    style: const TextStyle(
                      color: _executiveText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (canCancel)
                  TextButton(
                    key: ValueKey('cancel-reservation-${reservation.id}'),
                    onPressed: () => _cancelTableReservation(reservation),
                    child: const CafeText('Cancel'),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            CafeText(
              '$tableLabel · ${reservation.partySize} guests',
              style: const TextStyle(color: _executiveMuted),
            ),
            const SizedBox(height: 3),
            CafeText(
              '${cafeFinanceTimestamp(reservation.startsAt.toUtc().toIso8601String())}'
              ' – ${cafeFinanceTimestamp(reservation.endsAt.toUtc().toIso8601String())} · Baghdad',
              style: const TextStyle(color: _executiveMuted),
            ),
            const SizedBox(height: 3),
            CafeText(
              '${reservation.contact} · ${reservation.status.toUpperCase()}',
              style: const TextStyle(color: _executiveMuted, fontSize: 12),
            ),
            if (reservation.notes.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                reservation.notes,
                style: const TextStyle(color: _executiveMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateTableReservation() async {
    if (!_canManageTableReservations) return;
    final repository = _tableReservationRepository;
    if (repository == null) {
      setState(() {
        _tableReservationsError = 'Reservation service is unavailable. Check the Supabase connection.';
      });
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    final partySizeController = TextEditingController(text: '2');
    final notesController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final requestId = CafeTableReservationRepository.newRequestId();
    final now = DateTime.now();
    var startsAt = DateTime(now.year, now.month, now.day, now.hour + 1);
    var endsAt = startsAt.add(const Duration(minutes: 90));
    final initialTables = _diningTables
        .where((table) => table.status == 'available' && table.seats >= 2)
        .toList(growable: false);
    String? selectedTableId = initialTables.isEmpty
        ? null
        : initialTables.first.id;
    var error = '';
    var isSaving = false;

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final partySize = int.tryParse(partySizeController.text) ?? 0;
            final eligibleTables = _diningTables
                .where(
                  (table) =>
                      table.status == 'available' &&
                      table.seats >= partySize &&
                      (table.id == selectedTableId ||
                          _tableReservations.every(
                            (reservation) =>
                                reservation.tableId != table.id ||
                                reservation.status != 'confirmed' ||
                                !reservation.startsAt.isBefore(endsAt) ||
                                !reservation.endsAt.isAfter(startsAt),
                          )),
                )
                .toList(growable: false);
            final availableTableIds = eligibleTables
                .map((table) => table.id)
                .toSet();
            final dropdownValue = availableTableIds.contains(selectedTableId)
                ? selectedTableId
                : null;

            Future<void> chooseDateTime({required bool chooseStart}) async {
              final current = chooseStart ? startsAt : endsAt;
              final date = await showDatePicker(
                context: dialogContext,
                initialDate: current,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date == null || !dialogContext.mounted) return;
              final time = await showTimePicker(
                context: dialogContext,
                initialTime: TimeOfDay.fromDateTime(current),
              );
              if (time == null || !dialogContext.mounted) return;
              final picked = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
              setDialogState(() {
                if (chooseStart) {
                  startsAt = picked;
                  if (!endsAt.isAfter(startsAt)) {
                    endsAt = startsAt.add(const Duration(minutes: 90));
                  }
                } else {
                  endsAt = picked;
                }
                error = '';
              });
            }

            String formatDateTime(DateTime value) {
              final localizations = MaterialLocalizations.of(dialogContext);
              return '${localizations.formatMediumDate(value)} · '
                  '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
            }

            return AlertDialog(
              title: const CafeText('New table reservation'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          autofocus: true,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            label: CafeText('Customer name'),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter the customer name'
                              : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: contactController,
                          maxLength: 80,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            label: CafeText('Contact number'),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().length < 5
                              ? 'Enter a valid contact number'
                              : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: partySizeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            label: CafeText('Party size'),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final count = int.tryParse(value?.trim() ?? '');
                            return count == null || count < 1 || count > 100
                                ? 'Enter a party size from 1 to 100'
                                : null;
                          },
                          onChanged: (_) => setDialogState(() {
                            if (selectedTableId != null &&
                                !eligibleTables.any(
                                  (table) => table.id == selectedTableId,
                                )) {
                              selectedTableId = null;
                            }
                          }),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'reservation-table-dropdown-$partySize',
                          ),
                          initialValue: dropdownValue,
                          decoration: const InputDecoration(
                            label: CafeText('Available table'),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final table in eligibleTables)
                              DropdownMenuItem(
                                value: table.id,
                                child: CafeText(
                                  '${table.name} · ${table.area} · ${table.seats} seats',
                                ),
                              ),
                          ],
                          onChanged: isSaving
                              ? null
                              : (value) => setDialogState(
                                  () => selectedTableId = value,
                                ),
                          validator: (value) => value == null
                              ? 'No unreserved available table fits this party.'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: isSaving
                                    ? null
                                    : () => chooseDateTime(chooseStart: true),
                                icon: const Icon(Icons.calendar_month_outlined),
                                label: CafeText(
                                  'Starts · ${formatDateTime(startsAt)}',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: isSaving
                                    ? null
                                    : () => chooseDateTime(chooseStart: false),
                                icon: const Icon(Icons.schedule_outlined),
                                label: CafeText('Ends · ${formatDateTime(endsAt)}'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: notesController,
                          maxLength: 1000,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            label: CafeText('Notes (optional)'),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (error.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _AuthErrorMessage(error),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const CafeText('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            isSaving = true;
                            error = '';
                          });
                          try {
                            await repository.createReservation(
                              requestId: requestId,
                              tableId: selectedTableId!,
                              customerName: nameController.text,
                              contact: contactController.text,
                              partySize: int.parse(
                                partySizeController.text.trim(),
                              ),
                              startsAt: startsAt,
                              endsAt: endsAt,
                              notes: notesController.text,
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } on Exception catch (exception) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              error =
                                  'Reservation could not be saved: $exception';
                              isSaving = false;
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const CafeText('Confirm reservation'),
                ),
              ],
            );
          },
        ),
      );

      if (saved == true) {
        await _loadTableReservations();
        if (mounted) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: CafeText('Reservation confirmed.')),
            );
        }
      }
    } finally {
      nameController.dispose();
      contactController.dispose();
      partySizeController.dispose();
      notesController.dispose();
    }
  }

  Future<void> _cancelTableReservation(CafeTableReservation reservation) async {
    if (!_canManageTableReservations) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const CafeText('Cancel reservation?'),
        content: CafeText(
          'Cancel the reservation for ${reservation.customerName}? '
          'This action will be recorded in the audit history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const CafeText('Keep reservation'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const CafeText('Cancel reservation'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repository = _tableReservationRepository;
    if (repository == null) return;
    try {
      await repository.cancelReservation(reservation.id);
      await _loadTableReservations();
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        _tableReservationsError = 'Reservation cancellation failed: $exception';
      });
    }
  }

  Widget _chairsManagementWorkspace() {
    final snapshot = _chairManagement;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF14243A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF30435A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CafeText(
                'Chair management',
                style: TextStyle(
                  color: _executiveText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const CafeText(
                'Current chairs equal the original table capacity plus audited '
                'movements. Record the actual spare pool and the verified '
                'guest/reservation minimum before moving chairs.',
                key: ValueKey('chairs-management-guidance'),
                style: TextStyle(color: _executiveMuted, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_chairManagementError != null)
          Row(
            children: [
              Expanded(child: _AuthErrorMessage(_chairManagementError!)),
              IconButton(
                tooltip: 'Retry chair data',
                onPressed: _isLoadingChairManagement
                    ? null
                    : () => unawaited(_loadChairManagement()),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        if (_isLoadingChairManagement)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (snapshot != null) ...[
          Card(
            color: _executiveSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: _executiveBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CafeText(
                        'Verified spare-chair pool',
                        style: TextStyle(
                          color: _executiveText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        snapshot.poolConfigured
                            ? '${snapshot.availableChairs} chairs available'
                            : 'Not reconciled with the physical stock yet',
                        style: const TextStyle(color: _executiveMuted),
                      ),
                    ],
                  ),
                  if (widget.role == 'admin')
                    OutlinedButton.icon(
                      key: const ValueKey('reconcile-chair-pool'),
                      onPressed: _isLoadingChairManagement
                          ? null
                          : _showChairPoolReconciliation,
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: Text(
                        snapshot.poolConfigured
                            ? 'Reconcile actual count'
                            : 'Record actual count',
                      ),
                    ),
                  OutlinedButton.icon(
                    key: const ValueKey('refresh-chair-management'),
                    onPressed: _isLoadingChairManagement
                        ? null
                        : () {
                            unawaited(_loadChairManagement());
                            unawaited(_loadDiningTables());
                          },
                    icon: const Icon(Icons.refresh),
                    label: const CafeText('Refresh'),
                  ),
                ],
              ),
            ),
          ),
          Card(
            color: _executiveSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: _executiveBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('give-extra-chairs'),
                    onPressed:
                        snapshot.poolConfigured && snapshot.availableChairs > 0
                        ? () => _showChairMovementForm('give')
                        : null,
                    icon: const Icon(Icons.add),
                    label: const CafeText('Give extra chairs'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('take-chairs'),
                    onPressed: snapshot.poolConfigured
                        ? () => _showChairMovementForm('take')
                        : null,
                    icon: const Icon(Icons.remove),
                    label: const CafeText('Take chairs'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('transfer-chairs'),
                    onPressed: snapshot.poolConfigured
                        ? () => _showChairMovementForm('transfer')
                        : null,
                    icon: const Icon(Icons.swap_horiz),
                    label: const CafeText('Transfer chairs'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('chair-movement-history'),
                    onPressed: () => _showChairMovementHistory(snapshot),
                    icon: const Icon(Icons.history),
                    label: const CafeText('Movement history'),
                  ),
                ],
              ),
            ),
          ),
          Card(
            color: _executiveSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: _executiveBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CafeText(
                    'Table chair counts',
                    style: TextStyle(
                      color: _executiveText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const CafeText(
                    'Before taking or transferring chairs, record the actual '
                    'current-guest and confirmed-reservation seat minimum.',
                    style: TextStyle(color: _executiveMuted, height: 1.4),
                  ),
                  if (snapshot.tables.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: CafeText(
                        'No saved tables are available for this account.',
                        style: TextStyle(color: _executiveMuted),
                      ),
                    )
                  else
                    for (final table in snapshot.tables)
                      ListTile(
                        key: ValueKey('chair-table-${table.tableId}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          table.name,
                          style: const TextStyle(color: _executiveText),
                        ),
                        subtitle: CafeText(
                          '${table.area} · ${_diningTableStatusLabel(table.status)}'
                          ' · ${table.protectedSeats == null ? 'guest minimum not verified' : '${table.protectedSeats} protected seats'}',
                          style: const TextStyle(color: _executiveMuted),
                        ),
                        trailing: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          children: [
                            CafeText(
                              '${table.currentChairs} / ${table.baseChairs} base',
                              style: const TextStyle(
                                color: _executiveText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Update ${table.name} guest minimum',
                              onPressed: () => _showProtectedSeatsForm(table),
                              icon: const Icon(Icons.people_alt_outlined),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showChairPoolReconciliation() async {
    final repository = _chairRepository;
    final snapshot = _chairManagement;
    if (repository == null || widget.role != 'admin') return;
    final countController = TextEditingController(
      text: snapshot?.poolConfigured == true
          ? '${snapshot!.availableChairs}'
          : '',
    );
    final reasonController = TextEditingController();
    final requestId = newCafeRequestId();
    var isSaving = false;
    var error = '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const CafeText('Record actual spare-chair count'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CafeText(
                  'Count the physical spare chairs now. This sets the verified '
                  'pool balance and is recorded in movement history.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: countController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    label: CafeText('Spare chairs physically available'),
                  ),
                  validator: (value) {
                    final count = int.tryParse(value ?? '');
                    return count == null || count < 0 || count > 10000
                        ? 'Enter a count from 0 to 10,000.'
                        : null;
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonController,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    label: CafeText('Reconciliation reason'),
                  ),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _AuthErrorMessage(error),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: const CafeText('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final count = int.tryParse(countController.text.trim());
                      if (count == null ||
                          count < 0 ||
                          count > 10000 ||
                          reasonController.text.trim().isEmpty ||
                          reasonController.text.trim().runes.length > 300) {
                        setDialogState(
                          () => error = 'Enter a valid count and a reconciliation reason.',
                        );
                        return;
                      }
                      setDialogState(() {
                        isSaving = true;
                        error = '';
                      });
                      try {
                        await repository.reconcileSparePool(
                          requestId: requestId,
                          availableChairs: count,
                          reason: reasonController.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } on Exception catch (exception) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          error = 'Chair count was not saved: $exception';
                          isSaving = false;
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const CafeText('Save verified count'),
            ),
          ],
        ),
      ),
    );
    countController.dispose();
    reasonController.dispose();
    if (saved == true) await _loadChairManagement();
  }

  Future<void> _showProtectedSeatsForm(CafeChairTableState table) async {
    final repository = _chairRepository;
    if (repository == null) return;
    final countController = TextEditingController(
      text: table.protectedSeats?.toString() ?? '',
    );
    final reasonController = TextEditingController();
    final requestId = newCafeRequestId();
    var isSaving = false;
    var error = '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: CafeText('${table.name} protected seat minimum'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CafeText(
                  'Enter the verified number of current guests plus confirmed '
                  'reservation seats that must remain available.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: countController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    label: CafeText('Guests and reserved seats to protect'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonController,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    label: CafeText('Why is this count being recorded?'),
                  ),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _AuthErrorMessage(error),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: const CafeText('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final count = int.tryParse(countController.text.trim());
                      if (count == null ||
                          count < 0 ||
                          count > 100 ||
                          reasonController.text.trim().isEmpty ||
                          reasonController.text.trim().runes.length > 300) {
                        setDialogState(
                          () => error = 'Enter a verified count from 0 to 100 and a reason.',
                        );
                        return;
                      }
                      setDialogState(() {
                        isSaving = true;
                        error = '';
                      });
                      try {
                        await repository.setProtectedSeats(
                          requestId: requestId,
                          tableId: table.tableId,
                          protectedSeats: count,
                          reason: reasonController.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } on Exception catch (exception) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          error =
                              'Protected seat count was not saved: '
                              '$exception';
                          isSaving = false;
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const CafeText('Save verified minimum'),
            ),
          ],
        ),
      ),
    );
    countController.dispose();
    reasonController.dispose();
    if (saved == true) await _loadChairManagement();
  }

  Future<void> _showChairMovementForm(String operation) async {
    final repository = _chairRepository;
    final snapshot = _chairManagement;
    if (repository == null || snapshot == null) return;
    final tables = snapshot.tables
        .where((table) => table.status != 'cleaning')
        .toList(growable: false);
    if (tables.isEmpty) return;
    if (operation == 'transfer' && tables.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: CafeText('A transfer needs two active dining tables.'),
        ),
      );
      return;
    }
    final sourceController = TextEditingController(
      text: operation == 'give' ? '' : tables.first.tableId,
    );
    final destinationController = TextEditingController(
      text: operation == 'take'
          ? ''
          : tables
                .firstWhere(
                  (table) =>
                      operation != 'transfer' ||
                      table.tableId != tables.first.tableId,
                  orElse: () => tables.first,
                )
                .tableId,
    );
    final quantityController = TextEditingController(text: '1');
    final reasonController = TextEditingController();
    final requestId = newCafeRequestId();
    var isSaving = false;
    var error = '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final sourceId = sourceController.text.isEmpty
              ? null
              : sourceController.text;
          final destinationId = destinationController.text.isEmpty
              ? null
              : destinationController.text;
          final quantity = int.tryParse(quantityController.text.trim());
          final selectedSource = tables.where(
            (table) => table.tableId == sourceId,
          );
          final selectedDestination = tables.where(
            (table) => table.tableId == destinationId,
          );
          final operationPreview = [
            if (operation != 'give' && selectedSource.isNotEmpty)
              '${selectedSource.first.name}: '
                  '${selectedSource.first.currentChairs} → '
                  '${(selectedSource.first.currentChairs - (quantity ?? 0)).clamp(0, 10000)}',
            if (operation != 'take' && selectedDestination.isNotEmpty)
              '${selectedDestination.first.name}: '
                  '${selectedDestination.first.currentChairs} → '
                  '${selectedDestination.first.currentChairs + (quantity ?? 0)}',
          ].join(' · ');
          return AlertDialog(
            title: Text(switch (operation) {
              'give' => 'Give extra chairs',
              'take' => 'Take chairs from a table',
              _ => 'Transfer chairs between tables',
            }),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (operation != 'give')
                      DropdownButtonFormField<String>(
                        initialValue: sourceId,
                        decoration: const InputDecoration(
                          label: CafeText('Source table'),
                        ),
                        items: [
                          for (final table in tables)
                            DropdownMenuItem(
                              value: table.tableId,
                              child: CafeText(
                                '${table.name} · ${table.currentChairs} chairs',
                              ),
                            ),
                        ],
                        onChanged: isSaving
                            ? null
                            : (value) => setDialogState(() {
                                sourceController.text = value ?? '';
                                if (operation == 'transfer' &&
                                    destinationController.text == value) {
                                  destinationController.text = tables
                                      .firstWhere(
                                        (table) => table.tableId != value,
                                      )
                                      .tableId;
                                }
                              }),
                      ),
                    if (operation != 'take') ...[
                      if (operation != 'give') const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: destinationId,
                        decoration: const InputDecoration(
                          label: CafeText('Destination table'),
                        ),
                        items: [
                          for (final table in tables)
                            if (operation != 'transfer' ||
                                table.tableId != sourceId)
                              DropdownMenuItem(
                                value: table.tableId,
                                child: CafeText(
                                  '${table.name} · ${table.currentChairs} chairs',
                                ),
                              ),
                        ],
                        onChanged: isSaving
                            ? null
                            : (value) => setDialogState(
                                () => destinationController.text = value ?? '',
                              ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        label: CafeText('Number of chairs'),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: reasonController,
                      maxLength: 300,
                      decoration: const InputDecoration(label: CafeText('Reason')),
                    ),
                    if (operationPreview.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      CafeText('Before → after: $operationPreview'),
                    ],
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _AuthErrorMessage(error),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const CafeText('Cancel'),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final parsedQuantity = int.tryParse(
                          quantityController.text.trim(),
                        );
                        if (parsedQuantity == null ||
                            parsedQuantity < 1 ||
                            parsedQuantity > 100 ||
                            reasonController.text.trim().isEmpty ||
                            reasonController.text.trim().runes.length > 300 ||
                            (operation != 'give' && sourceId == null) ||
                            (operation != 'take' && destinationId == null) ||
                            (operation == 'transfer' &&
                                sourceId == destinationId)) {
                          setDialogState(
                            () => error =
                                'Choose different tables where required, '
                                'a quantity from 1 to 100, and a reason.',
                          );
                          return;
                        }
                        setDialogState(() {
                          isSaving = true;
                          error = '';
                        });
                        try {
                          await repository.moveChairs(
                            requestId: requestId,
                            operation: operation,
                            sourceTableId: sourceId,
                            destinationTableId: destinationId,
                            quantity: parsedQuantity,
                            reason: reasonController.text,
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        } on Exception catch (exception) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            error =
                                'Chair movement was not confirmed: '
                                '$exception';
                            isSaving = false;
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const CafeText('Confirm movement'),
              ),
            ],
          );
        },
      ),
    );
    sourceController.dispose();
    destinationController.dispose();
    quantityController.dispose();
    reasonController.dispose();
    if (saved == true) {
      await _loadChairManagement();
      await _loadDiningTables();
    }
  }

  Future<void> _showChairMovementHistory(
    CafeChairManagementSnapshot snapshot,
  ) async {
    String tableName(String? id) {
      if (id == null) return 'Spare pool';
      for (final table in snapshot.tables) {
        if (table.tableId == id) return table.name;
      }
      return 'Deleted table ($id)';
    }

    String stateSummary(Map<String, dynamic> state) => state.entries
        .map((entry) => '${entry.key.replaceAll('_', ' ')}: ${entry.value}')
        .join(' · ');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const CafeText('Chair movement history'),
        content: SizedBox(
          width: 620,
          height: 480,
          child: snapshot.movements.isEmpty
              ? const Center(child: CafeText('No chair movements recorded yet.'))
              : ListView.separated(
                  itemCount: snapshot.movements.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final movement = snapshot.movements[index];
                    final action = movement.action.replaceAll('_', ' ');
                    final quantity = movement.quantity == null
                        ? ''
                        : ' · ${movement.quantity} chairs';
                    return ListTile(
                      isThreeLine: true,
                      title: CafeText(
                        '${action[0].toUpperCase()}${action.substring(1)}'
                        '$quantity',
                      ),
                      subtitle: CafeText(
                        '${tableName(movement.sourceTableId)} → '
                        '${tableName(movement.destinationTableId)}\n'
                        '${movement.reason}\n'
                        '${stateSummary(movement.beforeState)} → '
                        '${stateSummary(movement.afterState)}',
                      ),
                      trailing: CafeText(
                        'Staff ${movement.actorId.substring(0, 8)}\n'
                        '${movement.createdAt.toLocal()}',
                        textAlign: TextAlign.end,
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const CafeText('Close'),
          ),
        ],
      ),
    );
  }

  Widget _tableManagementDetail(
    ({String key, IconData icon, String title, String description}) section,
    String subcard,
  ) {
    if (subcard == 'Chairs Management') {
      return _chairsManagementWorkspace();
    }
    if (subcard == 'Table Reservations') {
      return _tableReservationsWorkspace();
    }
    if (const {
      'Add Table',
      'Edit & Manage Tables',
      'Table Map',
      'QR Code Management',
    }.contains(subcard)) {
      return _diningTableCombinedWorkspace();
    }
    if (const {
      'Add Table',
      'Edit & Manage Tables',
      'QR Code Management',
      'Live Tables',
      'Add / Edit Tables',
      'Table Map',
      'Table Availability',
      'Active Tables',
      'Table Status',
      'Table Overview',
      'Visual Table Map',
      'Add/Edit Tables & Chairs',
    }.contains(subcard)) {
      return _diningTableWorkspace(
        forceList: const {
          'Add Table',
          'Edit & Manage Tables',
          'QR Code Management',
          'Add / Edit Tables',
          'Table Availability',
          'Active Tables',
          'Table Status',
          'Add/Edit Tables & Chairs',
        }.contains(subcard),
        allowTableEditing: const {
          'Add Table',
          'Edit & Manage Tables',
          'QR Code Management',
          'Table Map',
        }.contains(subcard),
      );
    }
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
                label: const CafeText('Add record'),
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
            _workspaceRecordTile(
              record,
              canManage: canManage,
              canEdit: canManage,
            ),
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
    final palette = _executiveCardPalette(1);
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        color: palette.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.accent.withValues(alpha: 0.35)),
        ),
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
                    CafeText(label, style: const TextStyle(color: _executiveMuted)),
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
        _dateRangeControls(),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _financeSummaryCard(
              icon: Icons.receipt_long_outlined,
              label: 'Tracked records',
              value: _workspaceError != null
                  ? '—'
                  : _isLoadingRecords
                  ? '…'
                  : '${records.length}',
              tint: Colors.white,
              accent: const Color(0xFF2563D9),
            ),
            _financeSummaryCard(
              icon: Icons.payments_outlined,
              label: 'Recorded amount',
              value: _workspaceError != null
                  ? '—'
                  : amountRecords.isEmpty
                  ? '—'
                  : '${amountTotal.toStringAsFixed(0)} ${amountRecords.first.currency}',
              tint: Colors.white,
              accent: const Color(0xFF16814A),
            ),
            _financeSummaryCard(
              icon: Icons.schedule_outlined,
              label: 'Open records',
              value: _workspaceError != null ? '—' : '$openCount',
              tint: Colors.white,
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
                    child: CafeText(
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
                      label: const CafeText('Add record'),
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
                          const CafeText(
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
                  child: CafeText(
                    'Tracked amount total · ${amountTotal.toStringAsFixed(0)} ${amountRecords.first.currency}',
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              const CafeText(
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
  }) {
    final palette = _executiveCardPalette(2);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          tint.withValues(alpha: 0.12),
          palette.background,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
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
          CafeText(
            label,
            maxLines: 2,
            style: const TextStyle(color: _executiveMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

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
                    CafeText(
                      'Updated ${record.updatedAt.toLocal().toString().substring(0, 16)}',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (record.amount != null)
                CafeText(
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
                    PopupMenuItem(value: 'open', child: CafeText('Mark open')),
                    PopupMenuItem(
                      value: 'in_progress',
                      child: CafeText('Mark in progress'),
                    ),
                    PopupMenuItem(
                      value: 'completed',
                      child: CafeText('Mark completed'),
                    ),
                    PopupMenuItem(
                      value: 'cancelled',
                      child: CafeText('Mark cancelled'),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: CafeText('Delete record'),
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
    required int cardIndex,
    double? revenue,
    bool revenueUnavailable = false,
  }) {
    final section = _sections[sectionIndex];
    final isRevenueCard = sectionIndex == 0 && title == _subcards.first.first;
    final subcardKey = _permissionSlug(title);
    final records = _recordsFor(section.key, subcardKey);
    final palette = _executiveCardPalette(sectionIndex + cardIndex);
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
      height: 154,
      child: Card(
        key: ValueKey('management-card-${section.key}-$subcardKey'),
        margin: EdgeInsets.zero,
        color: palette.background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.accent.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            PositionedDirectional(
              start: 0,
              top: 15,
              bottom: 15,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadiusDirectional.horizontal(
                    end: Radius.circular(5),
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: () => setState(() {
                _tableSearch = '';
                _tableStatusFilter = 'All';
                _workspaceSearch = '';
                _workspaceStatusFilter = 'All';
                if (sectionIndex == 1) {
                  _tableWorkspaceView =
                      const {
                        'Table Map',
                        'Visual Table Map',
                        'Table Overview',
                        'Live Tables',
                      }.contains(title)
                      ? 'Floor map'
                      : 'Table list';
                  _selectedDiningTableArea = 'All areas';
                }
                _selectedSubcard = title;
              }),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 13, 13, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 29,
                          height: 29,
                          decoration: BoxDecoration(
                            color: palette.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _metricIcon(title, section.icon),
                            color: palette.accent,
                            size: 17,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_outward,
                          color: palette.accent,
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CafeText(
                      title,
                      maxLines: sectionIndex == 1 ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _executiveText,
                        fontSize: 11,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      primaryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: revenueUnavailable && isRevenueCard
                            ? _executiveMuted
                            : palette.accent,
                        fontSize: 18,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      secondaryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _executiveMuted,
                        fontSize: 9,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
          CafeText(
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
                  label: const CafeText('Add record'),
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
            const CafeText(
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
    bool canEdit = false,
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
                  CafeText(
                    '${record.amount!.toStringAsFixed(2)} ${record.currency}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                if (canEdit)
                  IconButton(
                    tooltip: 'Edit ${record.title}',
                    onPressed: () {
                      final section = _sections.firstWhere(
                        (section) => section.key == record.sectionKey,
                      );
                      unawaited(
                        _createWorkspaceRecord(
                          section,
                          record.subcardKey.replaceAll('_', ' '),
                          record: record,
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
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
                  child: CafeText(
                    'Updated ${record.updatedAt.toLocal().toString().substring(0, 16)}',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
                if (canManage)
                  DropdownButton<String>(
                    value: record.status,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'open', child: CafeText('Open')),
                      DropdownMenuItem(
                        value: 'in_progress',
                        child: CafeText('In progress'),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: CafeText('Completed'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: CafeText('Cancelled'),
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
                : const CafeText('Verify code'),
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
                : const CafeText('Sign out'),
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
                : const CafeText('Sign in'),
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
        CafeText('Signed in as $email.'),
        const SizedBox(height: 12),
        if (_isAdmin == true) ...[
          const CafeText(
            'Administrator access',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const CafeText(
            'Create staff accounts from the management workspace so you can '
            'assign their section and card permissions.',
            style: TextStyle(color: _muted, height: 1.45),
          ),
        ] else
          const CafeText(
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
            const CafeText(
              'Account setup key',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            SelectableText(secret),
            const SizedBox(height: 8),
            const CafeText(
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
              label: CafeText('Authenticator code'),
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
        const CafeText(
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
            child: CafeText(
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
              label: CafeText('Staff email'),
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
              label: CafeText('Password'),
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
