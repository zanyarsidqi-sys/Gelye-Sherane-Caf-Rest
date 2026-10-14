-- Release 1.0.0.15: group Kitchen, Nargile, Menu and Products & Inventory.
-- Preserve every employee permission key; remove only duplicate catalog entries.
-- Run only after the verified Tables and Payment Management catalog migrations.
BEGIN;

DO $migration$
DECLARE
  catalog_count_before integer;
  catalog_count_after integer;
  deleted_catalog_rows integer;
  permission_digest_before text;
  permission_digest_after text;
BEGIN
  IF to_regclass('public.management_sections') IS NULL THEN
    RAISE EXCEPTION 'Kitchen consolidation requires public.management_sections';
  END IF;
  IF to_regclass('public.employee_section_permissions') IS NULL THEN
    RAISE EXCEPTION 'Kitchen consolidation requires employee section grants';
  END IF;

  SELECT count(*) INTO catalog_count_before
  FROM public.management_sections;
  IF catalog_count_before <> 29 THEN
    RAISE EXCEPTION
      'Expected the verified 29-entry catalog after Tables and finance merges; found %',
      catalog_count_before;
  END IF;

  IF (
    SELECT count(*)
    FROM public.management_sections
    WHERE section_key = ANY (ARRAY[
      'kitchen',
      'nargile_management',
      'menu',
      'products_inventory'
    ]::text[])
  ) <> 4 THEN
    RAISE EXCEPTION
      'Expected Kitchen, Nargile, Menu and Products & Inventory catalog entries';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.management_sections
    WHERE section_key = 'kitchen' AND display_order = 4
  ) OR NOT EXISTS (
    SELECT 1 FROM public.management_sections
    WHERE section_key = 'menu' AND display_order = 5
  ) OR NOT EXISTS (
    SELECT 1 FROM public.management_sections
    WHERE section_key = 'products_inventory' AND display_order = 7
  ) OR NOT EXISTS (
    SELECT 1 FROM public.management_sections
    WHERE section_key = 'nargile_management' AND display_order = 29
  ) THEN
    RAISE EXCEPTION
      'Kitchen merge ordering does not match the verified Payment Management catalog';
  END IF;

  SELECT md5(COALESCE(string_agg(
    concat_ws('|', user_id::text, section_key, can_view::text, can_create::text,
      can_edit::text, can_delete::text),
    E'\n' ORDER BY user_id, section_key
  ), ''))
  INTO permission_digest_before
  FROM public.employee_section_permissions;

  -- Shift all order values before compacting, remaining safe if display_order
  -- has a unique constraint.
  UPDATE public.management_sections
  SET display_order = display_order + 1000;

  DELETE FROM public.management_sections
  WHERE section_key IN ('nargile_management', 'menu', 'products_inventory');
  GET DIAGNOSTICS deleted_catalog_rows = ROW_COUNT;
  IF deleted_catalog_rows <> 3 THEN
    RAISE EXCEPTION
      'Expected to remove exactly three duplicate catalog rows; removed %',
      deleted_catalog_rows;
  END IF;

  UPDATE public.management_sections AS section
  SET display_order = desired.display_order::integer
  FROM unnest(ARRAY[
    'dashboard',
    'tables',
    'motel_orders',
    'kitchen',
    'payments_management',
    'customers',
    'employees',
    'maintenance',
    'notifications',
    'reports',
    'backup_restore',
    'settings_rules',
    'analytics',
    'action_center',
    'pay_now',
    'device_layout_mode',
    'appearance_dark_mode',
    'dictionary_language_management',
    'websites_management',
    'general_information',
    'invoice_design_customization',
    'security_access_control',
    'offline_mode_synchronization',
    'app_publishing_updates',
    'system_health_monitoring',
    'test_mode_real_mode'
  ]::text[]) WITH ORDINALITY AS desired(section_key, display_order)
  WHERE section.section_key = desired.section_key;

  SELECT count(*) INTO catalog_count_after
  FROM public.management_sections;
  IF catalog_count_after <> 26 OR EXISTS (
    SELECT 1
    FROM public.management_sections
    WHERE section_key IN ('nargile_management', 'menu', 'products_inventory')
  ) OR NOT EXISTS (
    SELECT 1
    FROM public.management_sections
    WHERE section_key = 'kitchen' AND display_order = 4
  ) THEN
    RAISE EXCEPTION
      'Kitchen catalog verification failed; rows after merge: %',
      catalog_count_after;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.management_sections
    WHERE display_order < 1 OR display_order > 26
  ) OR (
    SELECT count(DISTINCT display_order)
    FROM public.management_sections
  ) <> 26 THEN
    RAISE EXCEPTION
      'Kitchen catalog ordering is not contiguous from 1 to 26';
  END IF;

  SELECT md5(COALESCE(string_agg(
    concat_ws('|', user_id::text, section_key, can_view::text, can_create::text,
      can_edit::text, can_delete::text),
    E'\n' ORDER BY user_id, section_key
  ), ''))
  INTO permission_digest_after
  FROM public.employee_section_permissions;

  IF permission_digest_after IS DISTINCT FROM permission_digest_before THEN
    RAISE EXCEPTION
      'Employee permission grants changed during Kitchen consolidation';
  END IF;
END
$migration$;

COMMIT;
