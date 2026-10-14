import 'package:flutter/material.dart';
import '../sections/dashboard.dart';
import '../sections/table_orders.dart';
import '../sections/motel_orders.dart';
import '../sections/kitchen.dart';
import '../sections/menu.dart';
import '../sections/products_inventory.dart';
import '../sections/customers.dart';
import '../sections/cost.dart';
import '../sections/revenue.dart';
import '../sections/invoices_payments.dart';
import '../sections/employees.dart';
import '../sections/maintenance.dart';
import '../sections/notifications.dart';
import '../sections/reports.dart';
import '../sections/backup_restore.dart';
import '../sections/settings_rules.dart';
import '../sections/analytics.dart';
import '../sections/action_center.dart';
import '../sections/pay_now.dart';
import '../sections/discount_management.dart';
import '../sections/payments_management.dart';
import '../sections/credit_management.dart';
import '../sections/device_layout_mode.dart';
import '../sections/appearance_dark_mode.dart';
import '../sections/dictionary_language_management.dart';
import '../sections/websites_management.dart';
import '../sections/general_information.dart';
import '../sections/invoice_design_customization.dart';
import '../sections/security_access_control.dart';
import '../sections/offline_mode_synchronization.dart';
import '../sections/app_publishing_updates.dart';
import '../sections/system_health_monitoring.dart';
import '../sections/test_mode_real_mode.dart';
import '../sections/nargile_management.dart';

class CafeSection {
  final String id;
  final String title;
  final WidgetBuilder builder;
  const CafeSection(this.id, this.title, this.builder);
}

final List<CafeSection> cafeSections = [
  CafeSection('dashboard', "Dashboard", (context) => const DashboardScreen()),
  CafeSection('tables', "Tables", (context) => const TablesAndOrdersScreen()),
  CafeSection(
      'motel_orders', "Motel Orders", (context) => const MotelOrdersScreen()),
  CafeSection('kitchen', "Kitchen", (context) => const KitchenScreen()),
  CafeSection('menu', "Menu", (context) => const MenuScreen()),
  CafeSection('products_inventory', "Products & Inventory",
      (context) => const ProductsInventoryScreen()),
  CafeSection('customers', "Customers", (context) => const CustomersScreen()),
  CafeSection('cost', "Cost", (context) => const CostScreen()),
  CafeSection('revenue', "Revenue", (context) => const RevenueScreen()),
  CafeSection('invoices_payments', "Invoices & Payments",
      (context) => const InvoicesPaymentsScreen()),
  CafeSection('employees', "Employees", (context) => const EmployeesScreen()),
  CafeSection(
      'maintenance', "Maintenance", (context) => const MaintenanceScreen()),
  CafeSection('notifications', "Notifications",
      (context) => const NotificationsScreen()),
  CafeSection('reports', "Reports", (context) => const ReportsScreen()),
  CafeSection('backup_restore', "Backup & Restore",
      (context) => const BackupRestoreScreen()),
  CafeSection('settings_rules', "Settings & Rules",
      (context) => const SettingsRulesScreen()),
  CafeSection('analytics', "Analytics", (context) => const AnalyticsScreen()),
  CafeSection('action_center', "Action Center",
      (context) => const ActionCenterScreen()),
  CafeSection('pay_now', "Pay Now", (context) => const PayNowScreen()),
  CafeSection('discount_management', "Discount Management",
      (context) => const DiscountManagementScreen()),
  CafeSection('payments_management', "Payments Management",
      (context) => const PaymentsManagementScreen()),
  CafeSection('credit_management', "Credit Management",
      (context) => const CreditManagementScreen()),
  CafeSection('device_layout_mode', "Device Layout Mode",
      (context) => const DeviceLayoutModeScreen()),
  CafeSection('appearance_dark_mode', "Appearance & Dark Mode",
      (context) => const AppearanceDarkModeScreen()),
  CafeSection(
      'dictionary_language_management',
      "Dictionary & Language Management",
      (context) => const DictionaryLanguageManagementScreen()),
  CafeSection('websites_management', "Websites Management",
      (context) => const WebsitesManagementScreen()),
  CafeSection('general_information', "General Information",
      (context) => const GeneralInformationScreen()),
  CafeSection('invoice_design_customization', "Invoice Design & Customization",
      (context) => const InvoiceDesignCustomizationScreen()),
  CafeSection('security_access_control', "Security & Access Control",
      (context) => const SecurityAccessControlScreen()),
  CafeSection('offline_mode_synchronization', "Offline Mode & Synchronization",
      (context) => const OfflineModeSynchronizationScreen()),
  CafeSection('app_publishing_updates', "App Publishing & Updates",
      (context) => const AppPublishingUpdatesScreen()),
  CafeSection('system_health_monitoring', "System Health & Monitoring",
      (context) => const SystemHealthMonitoringScreen()),
  CafeSection('test_mode_real_mode', "Test Mode / Real Mode",
      (context) => const TestModeRealModeScreen()),
  CafeSection('nargile_management', "Nargile Management",
      (context) => const NargileManagementScreen()),
];
