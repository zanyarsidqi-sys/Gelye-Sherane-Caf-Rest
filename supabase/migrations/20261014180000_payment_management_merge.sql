-- Release 1.0.0.14: present six finance areas under one Payment Management entry.
-- Keep each employee permission key unchanged; only catalog metadata is removed.
-- This migration must run on the isolated staging project for this candidate.
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
    RAISE EXCEPTION 'Payment Management consolidation requires public.management_sections';
  END IF;
  IF to_regclass('public.employee_section_permissions') IS NULL THEN
    RAISE EXCEPTION 'Payment Management consolidation requires employee section grants';
  END IF;

  SELECT count(*) INTO catalog_count_before
  FROM public.management_sections;
  IF catalog_count_before <> 34 THEN
    RAISE EXCEPTION 'Expected the verified 34-section catalog before finance merge; found %',
      catalog_count_before;
  END IF;

  IF (
    SELECT count(*)
    FROM public.management_sections
    WHERE section_key = ANY (ARRAY[
      'cost',
      'revenue',
      'invoices_payments',
      'discount_management',
      'credit_management',
      'payments_management'
    ]::text[])
  ) <> 6 THEN
    RAISE EXCEPTION 'Expected exactly six existing finance catalog entries before consolidation';
  END IF;

  SELECT md5(COALESCE(string_agg(
    concat_ws('|', user_id::text, section_key, can_view::text, can_create::text,
      can_edit::text, can_delete::text),
    E'\n' ORDER BY user_id, section_key
  ), ''))
  INTO permission_digest_before
  FROM public.employee_section_permissions;

  -- Move all order values out of the target range before assigning the new
  -- stable order, so installations with a unique display_order index are safe.
  UPDATE public.management_sections
  SET display_order = display_order + 1000;

  DELETE FROM public.management_sections
  WHERE section_key IN (
    'cost',
    'revenue',
    'invoices_payments',
    'discount_management',
    'credit_management'
  );
  GET DIAGNOSTICS deleted_catalog_rows = ROW_COUNT;
  IF deleted_catalog_rows <> 5 THEN
    RAISE EXCEPTION 'Expected to remove exactly five duplicate finance catalog rows; removed %',
      deleted_catalog_rows;
  END IF;

  UPDATE public.management_sections
  SET title = 'Payment Management'
  WHERE section_key = 'payments_management';

  UPDATE public.management_sections AS section
  SET display_order = desired.display_order::integer
  FROM unnest(ARRAY[
    'dashboard',
    'tables',
    'motel_orders',
    'kitchen',
    'menu',
    'payments_management',
    'products_inventory',
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
    'test_mode_real_mode',
    'nargile_management'
  ]::text[]) WITH ORDINALITY AS desired(section_key, display_order)
  WHERE section.section_key = desired.section_key;

  SELECT count(*) INTO catalog_count_after
  FROM public.management_sections;
  IF catalog_count_after <> 29 OR EXISTS (
    SELECT 1
    FROM public.management_sections
    WHERE section_key IN (
      'cost',
      'revenue',
      'invoices_payments',
      'discount_management',
      'credit_management'
    )
  ) OR NOT EXISTS (
    SELECT 1
    FROM public.management_sections
    WHERE section_key = 'payments_management'
      AND title = 'Payment Management'
      AND display_order = 6
  ) THEN
    RAISE EXCEPTION 'Payment Management catalog verification failed; rows after merge: %',
      catalog_count_after;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.management_sections
    WHERE display_order < 1 OR display_order > 29
  ) OR (
    SELECT count(DISTINCT display_order)
    FROM public.management_sections
  ) <> 29 THEN
    RAISE EXCEPTION 'Payment Management catalog ordering is not contiguous from 1 to 29';
  END IF;

  SELECT md5(COALESCE(string_agg(
    concat_ws('|', user_id::text, section_key, can_view::text, can_create::text,
      can_edit::text, can_delete::text),
    E'\n' ORDER BY user_id, section_key
  ), ''))
  INTO permission_digest_after
  FROM public.employee_section_permissions;

  IF permission_digest_after IS DISTINCT FROM permission_digest_before THEN
    RAISE EXCEPTION 'Employee permission grants changed during finance consolidation';
  END IF;
END
$migration$;

COMMIT;
