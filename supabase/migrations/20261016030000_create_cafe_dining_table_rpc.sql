-- Create tables through a narrowly scoped, MFA- and role-checked database
-- function so the server, rather than the browser, owns actor attribution.
BEGIN;

CREATE OR REPLACE FUNCTION public.create_cafe_dining_table(
  table_name text,
  table_area text,
  table_seats integer,
  table_position_x numeric,
  table_position_y numeric
)
RETURNS TABLE (
  id uuid,
  name text,
  area text,
  seats integer,
  status text,
  position_x numeric,
  position_y numeric
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
    AND NOT (
      caller_role = 'staff'
      AND EXISTS (
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

  RETURN QUERY
  INSERT INTO public.cafe_dining_tables AS dining_table (
    name,
    area,
    seats,
    position_x,
    position_y,
    created_by,
    updated_by
  )
  VALUES (
    table_name,
    COALESCE(NULLIF(trim(table_area), ''), 'Main'),
    table_seats,
    table_position_x,
    table_position_y,
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
    dining_table.position_y;
END;
$$;

REVOKE ALL ON FUNCTION public.create_cafe_dining_table(
  text, text, integer, numeric, numeric
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_cafe_dining_table(
  text, text, integer, numeric, numeric
) TO authenticated;

COMMIT;
