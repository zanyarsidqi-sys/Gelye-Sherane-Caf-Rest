-- Release 1.0.0.13: merge the top-level Table Orders catalog entry into Tables.
-- Keep the legacy permission key intact: server-side order RPCs still authorize
-- table_orders independently, and the app exposes it as a protected sub-view.
-- No employee grants or operational café records are changed.
DO $migration$
DECLARE
  catalog_count_before integer;
  catalog_count_after integer;
  permission_digest_before text;
  permission_digest_after text;
BEGIN
  IF to_regclass('public.management_sections') IS NULL THEN
    RAISE EXCEPTION 'Tables consolidation requires public.management_sections';
  END IF;
  IF to_regclass('public.employee_section_permissions') IS NULL THEN
    RAISE EXCEPTION 'Tables consolidation requires employee section grants';
  END IF;

  SELECT count(*) INTO catalog_count_before
  FROM public.management_sections;

  IF catalog_count_before NOT IN (34, 35) THEN
    RAISE EXCEPTION 'Expected the verified 35-section catalog (or already-merged 34); found %',
      catalog_count_before;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.management_sections
    WHERE section_key = 'tables' AND display_order = 2
  ) THEN
    RAISE EXCEPTION 'Expected Tables at display order 2';
  END IF;
  IF catalog_count_before = 35 AND NOT EXISTS (
    SELECT 1 FROM public.management_sections
    WHERE section_key = 'table_orders' AND display_order = 3
  ) THEN
    RAISE EXCEPTION 'Expected Table Orders at display order 3 before consolidation';
  END IF;
  IF catalog_count_before = 34 AND EXISTS (
    SELECT 1 FROM public.management_sections
    WHERE section_key = 'table_orders'
  ) THEN
    RAISE EXCEPTION 'Catalog count is 34 but the duplicate Table Orders entry remains';
  END IF;

  SELECT md5(COALESCE(string_agg(
    concat_ws('|', user_id::text, section_key, can_view::text, can_create::text,
      can_edit::text, can_delete::text),
    E'\n' ORDER BY user_id, section_key
  ), ''))
  INTO permission_digest_before
  FROM public.employee_section_permissions;

  IF catalog_count_before = 35 THEN
    -- Shift down in two phases to remain safe if display_order is unique.
    UPDATE public.management_sections
    SET display_order = display_order + 1000
    WHERE display_order > 3;

    DELETE FROM public.management_sections
    WHERE section_key = 'table_orders';

    UPDATE public.management_sections
    SET display_order = display_order - 1001
    WHERE display_order > 1000;
  END IF;

  SELECT count(*) INTO catalog_count_after
  FROM public.management_sections;
  IF catalog_count_after <> 34 OR EXISTS (
    SELECT 1 FROM public.management_sections
    WHERE section_key = 'table_orders'
  ) THEN
    RAISE EXCEPTION 'Tables consolidation verification failed: catalog rows %, duplicate present %',
      catalog_count_after,
      EXISTS (SELECT 1 FROM public.management_sections WHERE section_key = 'table_orders');
  END IF;

  SELECT md5(COALESCE(string_agg(
    concat_ws('|', user_id::text, section_key, can_view::text, can_create::text,
      can_edit::text, can_delete::text),
    E'\n' ORDER BY user_id, section_key
  ), ''))
  INTO permission_digest_after
  FROM public.employee_section_permissions;

  IF permission_digest_after IS DISTINCT FROM permission_digest_before THEN
    RAISE EXCEPTION 'Employee permission grants changed during Tables consolidation';
  END IF;
END
$migration$;
