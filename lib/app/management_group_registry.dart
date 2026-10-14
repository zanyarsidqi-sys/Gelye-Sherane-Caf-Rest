import 'section_registry.dart';

/// Presentation-only groups. Original CafeSection IDs and permission keys remain authoritative.
class ManagementGroup {
  final String id;
  final String title;
  final List<String> sectionIds;
  const ManagementGroup(this.id, this.title, this.sectionIds);
}

const managementGroups = <ManagementGroup>[
  ManagementGroup('dashboard', 'Dashboard', <String>['dashboard']),
  ManagementGroup('tables_orders', 'Tables & Orders', <String>['tables', 'table_orders']),
  ManagementGroup('payment', 'Payment', <String>['cost', 'revenue', 'invoices_payments', 'pay_now', 'discount_management', 'payments_management', 'credit_management']),
  ManagementGroup('kitchen_group', 'Kitchen', <String>['kitchen', 'menu', 'products_inventory', 'nargile_management']),
  ManagementGroup('customer', 'Customer', <String>['customers', 'motel_orders']),
  ManagementGroup('statistics', 'Statistics', <String>['reports', 'analytics']),
  ManagementGroup('employee', 'Employee', <String>['employees']),
  ManagementGroup('maintenance_group', 'Maintenance', <String>['maintenance']),
  ManagementGroup('notifications_group', 'Notifications', <String>['notifications']),
  ManagementGroup('settings_group', 'Settings', <String>['backup_restore', 'settings_rules', 'device_layout_mode', 'appearance_dark_mode', 'dictionary_language_management', 'websites_management', 'invoice_design_customization', 'security_access_control', 'offline_mode_synchronization', 'app_publishing_updates', 'system_health_monitoring', 'test_mode_real_mode']),
  ManagementGroup('operations', 'Operations', <String>['action_center', 'general_information']),
];

List<ManagementGroup> allowedManagementGroups(Set<String> allowed) =>
    managementGroups.where((group) => group.sectionIds.any(allowed.contains)).toList();

List<CafeSection> allowedGroupChildren(ManagementGroup group, Set<String> allowed) =>
    cafeSections.where((section) => group.sectionIds.contains(section.id) && allowed.contains(section.id)).toList();
