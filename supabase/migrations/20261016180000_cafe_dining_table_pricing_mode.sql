-- Persist the selected table pricing mode. Normal Mode is the only supported
-- mode and does not add a charge; adding the default applies to existing rows.
BEGIN;

ALTER TABLE public.cafe_dining_tables
  ADD COLUMN pricing_mode text NOT NULL DEFAULT 'normal'
  CHECK (pricing_mode = 'normal');

COMMENT ON COLUMN public.cafe_dining_tables.pricing_mode IS
  'Table pricing mode. Normal Mode is informational and does not add a charge.';

DROP FUNCTION public.create_cafe_dining_table(
  text, text, integer, numeric, numeric
);

CREATE FUNCTION public.create_cafe_dining_table(
  table_name text,
  table_area text,
  table_seats integer,
  table_position_x numeric,
  table_position_y numeric,
  table_pricing_mode text
)
RETURNS TABLE (
  id uuid,
  name text,
  area text,
  seats integer,
  status text,
  position_x numeric,
  position_y numeric,
  pricing_mode text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  caller_id uuid := auth.uid();
  caller_role text;
BEGIN
  IF caller_id IS NULL
    OR auth.jwt()->>'aal' IS DISTINCT FROM 'aal2' THEN
    RAISE EXCEPTION 'Authenticator verification is required to add tables.'
      USING ERRCODE = '42501';
  END IF;

  SELECT profile.role
  INTO caller_role
  FROM public.staff_profiles profile
  WHERE profile.user_id = caller_id;

  IF caller_role IS DISTINCT FROM 'admin'
    AND (
      caller_role IS DISTINCT FROM 'staff'
      OR NOT EXISTS (
        SELECT 1
        FROM public.staff_permissions permission
        WHERE permission.user_id = caller_id
          AND permission.section_key = 'tables_orders'
          AND permission.subcard_key IN ('*', 'add_edit_tables')
      )
    ) THEN
    RAISE EXCEPTION 'Add / Edit Tables permission is required.'
      USING ERRCODE = '42501';
  END IF;

  IF table_pricing_mode IS DISTINCT FROM 'normal' THEN
    RAISE EXCEPTION 'Normal Mode is the only supported table pricing mode.'
      USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  INSERT INTO public.cafe_dining_tables AS dining_table (
    name,
    area,
    seats,
    position_x,
    position_y,
    pricing_mode,
    created_by,
    updated_by
  )
  VALUES (
    table_name,
    COALESCE(NULLIF(trim(table_area), ''), 'Main'),
    table_seats,
    table_position_x,
    table_position_y,
    table_pricing_mode,
    caller_id,
    caller_id
  )
  RETURNING
    dining_table.id,
    dining_table.name,
    dining_table.area,
    dining_table.seats,
    dining_table.status,
    dining_table.position_x,
    dining_table.position_y,
    dining_table.pricing_mode;
END;
$$;

REVOKE ALL ON FUNCTION public.create_cafe_dining_table(
  text, text, integer, numeric, numeric, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_cafe_dining_table(
  text, text, integer, numeric, numeric, text
) TO authenticated;

DROP FUNCTION public.list_cafe_dining_tables();

CREATE FUNCTION public.list_cafe_dining_tables()
RETURNS TABLE (
  id uuid,
  name text,
  area text,
  seats integer,
  status text,
  position_x numeric,
  position_y numeric,
  pricing_mode text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  caller_id uuid := auth.uid();
  caller_role text;
BEGIN
  IF caller_id IS NULL
    OR auth.jwt()->>'aal' IS DISTINCT FROM 'aal2' THEN
    RAISE EXCEPTION 'Authenticator verification is required to view tables.'
      USING ERRCODE = '42501';
  END IF;

  SELECT profile.role
  INTO caller_role
  FROM public.staff_profiles profile
  WHERE profile.user_id = caller_id;

  IF caller_role IS DISTINCT FROM 'admin'
    AND (
      caller_role IS DISTINCT FROM 'staff'
      OR NOT EXISTS (
        SELECT 1
        FROM public.staff_permissions permission
        WHERE permission.user_id = caller_id
          AND permission.section_key = 'tables_orders'
          AND permission.subcard_key IN (
            '*',
            'add_edit_tables',
            'table_overview',
            'visual_table_map',
            'table_map',
            'live_tables',
            'table_availability',
            'active_tables',
            'table_status'
          )
      )
    ) THEN
    RAISE EXCEPTION 'Tables & Orders read permission is required.'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    dining_table.id,
    dining_table.name,
    dining_table.area,
    dining_table.seats,
    dining_table.status,
    dining_table.position_x,
    dining_table.position_y,
    dining_table.pricing_mode
  FROM public.cafe_dining_tables AS dining_table
  ORDER BY dining_table.area, dining_table.name;
END;
$$;

REVOKE ALL ON FUNCTION public.list_cafe_dining_tables()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_cafe_dining_tables()
  TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
