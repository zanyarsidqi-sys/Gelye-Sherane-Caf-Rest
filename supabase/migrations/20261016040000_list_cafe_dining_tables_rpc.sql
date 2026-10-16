-- Read dining tables through an explicit MFA- and role-checked path. This
-- keeps authorized floor-map reads reliable without exposing the table to
-- unauthenticated or unassigned users.
BEGIN;

CREATE OR REPLACE FUNCTION public.list_cafe_dining_tables()
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
    RAISE EXCEPTION 'Authenticator verification is required to view tables.'
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
    dining_table.position_y
  FROM public.cafe_dining_tables AS dining_table
  ORDER BY dining_table.area, dining_table.name;
END;
$$;

REVOKE ALL ON FUNCTION public.list_cafe_dining_tables()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_cafe_dining_tables()
  TO authenticated;

COMMIT;
