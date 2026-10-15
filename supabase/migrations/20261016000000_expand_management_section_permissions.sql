-- Review-only migration. Apply to an isolated staging database after approval.
-- Keep this list aligned with the management sections in Flutter and the
-- create-staff-user Edge Function.
BEGIN;

ALTER TABLE public.staff_permissions
  DROP CONSTRAINT IF EXISTS staff_permissions_section_key_check;

ALTER TABLE public.staff_permissions
  ADD CONSTRAINT staff_permissions_section_key_check
  CHECK (
    section_key IN (
      'dashboard',
      'tables_orders',
      'payment_management',
      'kitchen_management',
      'customer_management',
      'statistics_management',
      'employee_management',
      'maintenance_management',
      'notifications_management',
      'settings_management',
      'operations_management',
      'motel_online_orders',
      'inventory_management',
      'customer_directory_management',
      'reservations_management',
      'devices_printing_management',
      'security_audit_management',
      'system_health_updates_management',
      'shisha_management',
      'delivery_management',
      'marketing_management',
      'customer_feedback_management',
      'staff_operations_management',
      'reports_management'
    )
  );

ALTER TABLE public.cafe_workspace_records
  DROP CONSTRAINT IF EXISTS cafe_workspace_records_section_key_check;

ALTER TABLE public.cafe_workspace_records
  ADD CONSTRAINT cafe_workspace_records_section_key_check
  CHECK (
    section_key IN (
      'dashboard',
      'tables_orders',
      'payment_management',
      'kitchen_management',
      'customer_management',
      'statistics_management',
      'employee_management',
      'maintenance_management',
      'notifications_management',
      'settings_management',
      'operations_management',
      'motel_online_orders',
      'inventory_management',
      'customer_directory_management',
      'reservations_management',
      'devices_printing_management',
      'security_audit_management',
      'system_health_updates_management',
      'shisha_management',
      'delivery_management',
      'marketing_management',
      'customer_feedback_management',
      'staff_operations_management',
      'reports_management'
    )
  );

COMMIT;
