-- Staging-only static navigation catalog seed. No café operational rows are copied.
DO $$
BEGIN
  IF to_regclass('public.management_sections') IS NULL THEN
    RAISE EXCEPTION 'The verified public schema baseline must be applied first';
  END IF;
END;
$$;

INSERT INTO public.management_sections (section_key, title, display_order, is_enabled)
VALUES
  ('dashboard', 'Dashboard', 1, true),
  ('tables', 'Tables', 2, true),
  ('table_orders', 'Table Orders', 3, true),
  ('motel_orders', 'Motel Orders', 4, true),
  ('kitchen', 'Kitchen', 5, true),
  ('menu', 'Menu', 6, true),
  ('products_inventory', 'Products & Inventory', 7, true),
  ('customers', 'Customers', 8, true),
  ('cost', 'Cost', 9, true),
  ('revenue', 'Revenue', 10, true),
  ('invoices_payments', 'Invoices & Payments', 11, true),
  ('employees', 'Employees', 12, true),
  ('maintenance', 'Maintenance', 13, true),
  ('notifications', 'Notifications', 14, true),
  ('reports', 'Reports', 15, true),
  ('backup_restore', 'Backup & Restore', 16, true),
  ('settings_rules', 'Settings & Rules', 17, true),
  ('analytics', 'Analytics', 18, true),
  ('action_center', 'Action Center', 19, true),
  ('pay_now', 'Pay Now', 20, true),
  ('discount_management', 'Discount Management', 21, true),
  ('payments_management', 'Payments Management', 22, true),
  ('credit_management', 'Credit Management', 23, true),
  ('device_layout_mode', 'Device Layout Mode', 24, true),
  ('appearance_dark_mode', 'Appearance & Dark Mode', 25, true),
  ('dictionary_language_management', 'Dictionary & Language Management', 26, true),
  ('websites_management', 'Websites Management', 27, true),
  ('general_information', 'General Information', 28, true),
  ('invoice_design_customization', 'Invoice Design & Customization', 29, true),
  ('security_access_control', 'Security & Access Control', 30, true),
  ('offline_mode_synchronization', 'Offline Mode & Synchronization', 31, true),
  ('app_publishing_updates', 'App Publishing & Updates', 32, true),
  ('system_health_monitoring', 'System Health & Monitoring', 33, true),
  ('test_mode_real_mode', 'Test Mode / Real Mode', 34, true),
  ('nargile_management', 'Nargile Management', 35, true)
ON CONFLICT (section_key) DO NOTHING;

DO $$
DECLARE
  actual_count integer;
  exact_matches integer;
BEGIN
  SELECT count(*) INTO actual_count FROM public.management_sections;
  SELECT count(*) INTO exact_matches
    FROM (
      VALUES
        ('dashboard', 'Dashboard', 1),
        ('tables', 'Tables', 2),
        ('table_orders', 'Table Orders', 3),
        ('motel_orders', 'Motel Orders', 4),
        ('kitchen', 'Kitchen', 5),
        ('menu', 'Menu', 6),
        ('products_inventory', 'Products & Inventory', 7),
        ('customers', 'Customers', 8),
        ('cost', 'Cost', 9),
        ('revenue', 'Revenue', 10),
        ('invoices_payments', 'Invoices & Payments', 11),
        ('employees', 'Employees', 12),
        ('maintenance', 'Maintenance', 13),
        ('notifications', 'Notifications', 14),
        ('reports', 'Reports', 15),
        ('backup_restore', 'Backup & Restore', 16),
        ('settings_rules', 'Settings & Rules', 17),
        ('analytics', 'Analytics', 18),
        ('action_center', 'Action Center', 19),
        ('pay_now', 'Pay Now', 20),
        ('discount_management', 'Discount Management', 21),
        ('payments_management', 'Payments Management', 22),
        ('credit_management', 'Credit Management', 23),
        ('device_layout_mode', 'Device Layout Mode', 24),
        ('appearance_dark_mode', 'Appearance & Dark Mode', 25),
        ('dictionary_language_management', 'Dictionary & Language Management', 26),
        ('websites_management', 'Websites Management', 27),
        ('general_information', 'General Information', 28),
        ('invoice_design_customization', 'Invoice Design & Customization', 29),
        ('security_access_control', 'Security & Access Control', 30),
        ('offline_mode_synchronization', 'Offline Mode & Synchronization', 31),
        ('app_publishing_updates', 'App Publishing & Updates', 32),
        ('system_health_monitoring', 'System Health & Monitoring', 33),
        ('test_mode_real_mode', 'Test Mode / Real Mode', 34),
        ('nargile_management', 'Nargile Management', 35)
    ) AS expected(section_key, title, display_order)
    JOIN public.management_sections actual
      ON actual.section_key = expected.section_key
     AND actual.title = expected.title
     AND actual.display_order = expected.display_order
     AND actual.is_enabled = true;

  IF actual_count <> 35 OR exact_matches <> 35 THEN
    RAISE EXCEPTION 'Staging section catalog verification failed: rows %, exact matches %',
      actual_count, exact_matches;
  END IF;
END;
$$;
