-- Save a complete current-schema table layout atomically. Updated timestamps
-- act as optimistic concurrency tokens; existing table audit triggers record
-- each changed row.
BEGIN;

CREATE TABLE public.cafe_dining_table_map_requests (
  request_id uuid PRIMARY KEY,
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  request_payload jsonb NOT NULL
    CHECK (jsonb_typeof(request_payload) = 'array'),
  result_payload jsonb NOT NULL
    CHECK (jsonb_typeof(result_payload) = 'array'),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.cafe_dining_table_map_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.cafe_dining_table_map_requests
  FROM PUBLIC, anon, authenticated;

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
  pricing_mode text,
  updated_at timestamptz
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
            'chairs_management',
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
    dining_table.pricing_mode,
    dining_table.updated_at
  FROM public.cafe_dining_tables AS dining_table
  ORDER BY dining_table.area, dining_table.name;
END;
$$;

REVOKE ALL ON FUNCTION public.list_cafe_dining_tables()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_cafe_dining_tables()
  TO authenticated;

CREATE FUNCTION public.save_cafe_dining_table_map_layout(
  p_request_id uuid,
  p_changes jsonb
)
RETURNS TABLE (
  id uuid,
  position_x numeric,
  position_y numeric,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  caller_id uuid := auth.uid();
  prior_actor_id uuid;
  prior_payload jsonb;
  prior_result jsonb;
  current_table_count integer;
  matching_table_count integer;
  change_count integer;
  result_payload jsonb;
BEGIN
  IF caller_id IS NULL
    OR auth.jwt()->>'aal' IS DISTINCT FROM 'aal2' THEN
    RAISE EXCEPTION 'Authenticator verification is required to save the map.'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_workspace_access('tables_orders', 'add_edit_tables') THEN
    RAISE EXCEPTION 'Edit Tables permission is required to save the map.'
      USING ERRCODE = '42501';
  END IF;

  IF p_request_id IS NULL
    OR jsonb_typeof(p_changes) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'The table-map save request is invalid.'
      USING ERRCODE = '22023';
  END IF;

  IF jsonb_array_length(p_changes) NOT BETWEEN 1 AND 500 THEN
    RAISE EXCEPTION 'The table-map save request must include 1 to 500 tables.'
      USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended(p_request_id::text, 0)
  );

  SELECT request.actor_id, request.request_payload, request.result_payload
  INTO prior_actor_id, prior_payload, prior_result
  FROM public.cafe_dining_table_map_requests AS request
  WHERE request.request_id = p_request_id;

  IF FOUND THEN
    IF prior_actor_id IS DISTINCT FROM caller_id
      OR prior_payload IS DISTINCT FROM p_changes THEN
      RAISE EXCEPTION 'Map request identifier was already used.'
        USING ERRCODE = '23505';
    END IF;

    RETURN QUERY
    SELECT saved.id, saved.position_x, saved.position_y, saved.updated_at
    FROM jsonb_to_recordset(prior_result) AS saved(
      id uuid,
      position_x numeric,
      position_y numeric,
      updated_at timestamptz
    )
    ORDER BY saved.id;
    RETURN;
  END IF;

  LOCK TABLE public.cafe_dining_tables IN SHARE ROW EXCLUSIVE MODE;

  SELECT count(*)
  INTO change_count
  FROM jsonb_to_recordset(p_changes) AS changed(
    id uuid,
    expected_updated_at timestamptz,
    position_x numeric,
    position_y numeric
  );

  IF EXISTS (
    SELECT 1
    FROM jsonb_to_recordset(p_changes) AS changed(
      id uuid,
      expected_updated_at timestamptz,
      expected_position_x numeric,
      expected_position_y numeric,
      position_x numeric,
      position_y numeric
    )
    WHERE changed.id IS NULL
      OR changed.expected_updated_at IS NULL
      OR changed.expected_position_x IS NULL
      OR changed.expected_position_y IS NULL
      OR changed.position_x IS NULL
      OR changed.position_y IS NULL
      OR changed.expected_position_x NOT BETWEEN 0 AND 1
      OR changed.expected_position_y NOT BETWEEN 0 AND 1
      OR changed.position_x NOT BETWEEN 0 AND 1
      OR changed.position_y NOT BETWEEN 0 AND 1
  ) OR (
    SELECT count(DISTINCT changed.id)
    FROM jsonb_to_recordset(p_changes) AS changed(
      id uuid,
      expected_updated_at timestamptz,
      position_x numeric,
      position_y numeric
    )
  ) <> change_count THEN
    RAISE EXCEPTION 'The table-map positions are invalid.'
      USING ERRCODE = '22023';
  END IF;

  PERFORM dining_table.id
  FROM public.cafe_dining_tables AS dining_table
  JOIN jsonb_to_recordset(p_changes) AS changed(id uuid)
    ON changed.id = dining_table.id
  ORDER BY dining_table.id
  FOR UPDATE OF dining_table;

  SELECT count(*)
  INTO current_table_count
  FROM public.cafe_dining_tables;

  SELECT count(*)
  INTO matching_table_count
  FROM public.cafe_dining_tables AS dining_table
  JOIN jsonb_to_recordset(p_changes) AS changed(id uuid)
    ON changed.id = dining_table.id;

  IF matching_table_count <> change_count
    OR current_table_count <> change_count THEN
    RAISE EXCEPTION 'The saved table list changed. Reload the map and retry.'
      USING ERRCODE = '40001';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.cafe_dining_tables AS dining_table
    JOIN jsonb_to_recordset(p_changes) AS changed(
      id uuid,
      expected_updated_at timestamptz,
      expected_position_x numeric,
      expected_position_y numeric,
      position_x numeric,
      position_y numeric
    ) ON changed.id = dining_table.id
    WHERE dining_table.updated_at IS DISTINCT FROM
      changed.expected_updated_at
      OR dining_table.position_x IS DISTINCT FROM
        changed.expected_position_x
      OR dining_table.position_y IS DISTINCT FROM
        changed.expected_position_y
  ) THEN
    RAISE EXCEPTION 'A table changed while this map was being edited. Reload and retry.'
      USING ERRCODE = '40001';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_to_recordset(p_changes) AS first_table(
      id uuid,
      expected_updated_at timestamptz,
      position_x numeric,
      position_y numeric
    )
    JOIN jsonb_to_recordset(p_changes) AS second_table(
      id uuid,
      expected_updated_at timestamptz,
      position_x numeric,
      position_y numeric
    ) ON first_table.id < second_table.id
    WHERE abs(first_table.position_x - second_table.position_x)
        < 128::numeric / 900
      AND abs(first_table.position_y - second_table.position_y)
        < 86::numeric / 520
  ) THEN
    RAISE EXCEPTION 'Separate overlapping tables before saving the map.'
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.cafe_dining_tables AS dining_table
  SET
    position_x = changed.position_x,
    position_y = changed.position_y,
    updated_by = caller_id
  FROM jsonb_to_recordset(p_changes) AS changed(
    id uuid,
    expected_updated_at timestamptz,
    expected_position_x numeric,
    expected_position_y numeric,
    position_x numeric,
    position_y numeric
  )
  WHERE dining_table.id = changed.id
    AND (
      dining_table.position_x IS DISTINCT FROM changed.position_x
      OR dining_table.position_y IS DISTINCT FROM changed.position_y
    );

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', dining_table.id,
        'position_x', dining_table.position_x,
        'position_y', dining_table.position_y,
        'updated_at', dining_table.updated_at
      )
      ORDER BY dining_table.id
    ),
    '[]'::jsonb
  )
  INTO result_payload
  FROM public.cafe_dining_tables AS dining_table;

  INSERT INTO public.cafe_dining_table_map_requests (
    request_id,
    actor_id,
    request_payload,
    result_payload
  )
  VALUES (p_request_id, caller_id, p_changes, result_payload);

  RETURN QUERY
  SELECT saved.id, saved.position_x, saved.position_y, saved.updated_at
  FROM jsonb_to_recordset(result_payload) AS saved(
    id uuid,
    position_x numeric,
    position_y numeric,
    updated_at timestamptz
  )
  ORDER BY saved.id;
END;
$$;

REVOKE ALL ON FUNCTION public.save_cafe_dining_table_map_layout(
  uuid, jsonb
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_cafe_dining_table_map_layout(
  uuid, jsonb
) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
