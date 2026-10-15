-- Review-only migration. Apply to an isolated staging database after approval.
-- These grants control application navigation; operational data still needs
-- its own server-side authorization policies before it can be used.
BEGIN;

CREATE TABLE public.staff_permissions (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  section_key text NOT NULL CHECK (
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
  ),
  subcard_key text NOT NULL CHECK (
    subcard_key = '*'
    OR subcard_key ~ '^[a-z0-9]+(_[a-z0-9]+)*$'
  ),
  assigned_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, section_key, subcard_key)
);

ALTER TABLE public.staff_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_permissions FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.staff_permissions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.staff_permissions TO authenticated;

CREATE POLICY staff_permissions_self_read_aal2
ON public.staff_permissions FOR SELECT TO authenticated
USING (
  user_id = (SELECT auth.uid())
  AND (SELECT auth.jwt()->>'aal') = 'aal2'
);

COMMIT;
