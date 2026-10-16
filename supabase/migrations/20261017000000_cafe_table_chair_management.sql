BEGIN;

CREATE TABLE public.cafe_table_chair_state (
  table_id uuid PRIMARY KEY
    REFERENCES public.cafe_dining_tables(id) ON DELETE CASCADE,
  base_chairs integer NOT NULL CHECK (base_chairs BETWEEN 1 AND 100),
  protected_seats integer CHECK (
    protected_seats IS NULL OR protected_seats BETWEEN 0 AND 100
  ),
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

INSERT INTO public.cafe_table_chair_state (table_id, base_chairs)
SELECT dining_table.id, dining_table.seats
FROM public.cafe_dining_tables AS dining_table
ON CONFLICT (table_id) DO NOTHING;

CREATE TABLE public.cafe_spare_chair_pool (
  id smallint PRIMARY KEY CHECK (id = 1),
  available_chairs integer NOT NULL DEFAULT 0
    CHECK (available_chairs BETWEEN 0 AND 10000),
  is_configured boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

INSERT INTO public.cafe_spare_chair_pool (id)
VALUES (1)
ON CONFLICT (id) DO NOTHING;

CREATE TABLE public.cafe_chair_requests (
  request_id uuid PRIMARY KEY,
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  request_payload jsonb NOT NULL,
  result_payload jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.cafe_chair_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL UNIQUE
    REFERENCES public.cafe_chair_requests(request_id) ON DELETE RESTRICT,
  action text NOT NULL CHECK (
    action IN (
      'pool_reconciled',
      'protected_seats_updated',
      'give',
      'take',
      'transfer'
    )
  ),
  source_table_id uuid REFERENCES public.cafe_dining_tables(id)
    ON DELETE SET NULL,
  destination_table_id uuid REFERENCES public.cafe_dining_tables(id)
    ON DELETE SET NULL,
  quantity integer CHECK (quantity IS NULL OR quantity BETWEEN 0 AND 10000),
  reason text NOT NULL CHECK (length(trim(reason)) BETWEEN 1 AND 300),
  before_state jsonb NOT NULL,
  after_state jsonb NOT NULL,
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.cafe_table_chair_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_table_chair_state FORCE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_spare_chair_pool ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_spare_chair_pool FORCE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_chair_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_chair_requests FORCE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_chair_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_chair_movements FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.cafe_table_chair_state
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.cafe_spare_chair_pool
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.cafe_chair_requests
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.cafe_chair_movements
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.initialize_cafe_table_chair_state()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  INSERT INTO public.cafe_table_chair_state (table_id, base_chairs)
  VALUES (NEW.id, NEW.seats)
  ON CONFLICT (table_id) DO NOTHING;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.initialize_cafe_table_chair_state()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER cafe_dining_table_chair_state_create
AFTER INSERT ON public.cafe_dining_tables
FOR EACH ROW EXECUTE FUNCTION public.initialize_cafe_table_chair_state();

CREATE OR REPLACE FUNCTION public.list_cafe_dining_tables()
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
  FROM public.staff_profiles AS profile
  WHERE profile.user_id = caller_id;

  IF caller_role IS DISTINCT FROM 'admin'
    AND NOT (
      caller_role = 'staff'
      AND EXISTS (
        SELECT 1
        FROM public.staff_permissions AS permission
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

CREATE OR REPLACE FUNCTION public.get_cafe_chair_management()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  caller_id uuid := auth.uid();
  pool_row public.cafe_spare_chair_pool;
  table_rows jsonb;
  movement_rows jsonb;
BEGIN
  IF caller_id IS NULL
    OR auth.jwt()->>'aal' IS DISTINCT FROM 'aal2'
    OR NOT public.has_workspace_access('tables_orders', 'chairs_management')
  THEN
    RAISE EXCEPTION 'Verified Chairs Management access is required.'
      USING ERRCODE = '42501';
  END IF;

  SELECT pool.*
  INTO pool_row
  FROM public.cafe_spare_chair_pool AS pool
  WHERE pool.id = 1;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'table_id', dining_table.id,
        'name', dining_table.name,
        'area', dining_table.area,
        'status', dining_table.status,
        'base_chairs', chair_state.base_chairs,
        'current_chairs', chair_state.base_chairs + COALESCE(
          (
            SELECT sum(
              CASE
                WHEN movement.destination_table_id = dining_table.id
                  THEN movement.quantity
                WHEN movement.source_table_id = dining_table.id
                  THEN -movement.quantity
                ELSE 0
              END
            )
            FROM public.cafe_chair_movements AS movement
            WHERE movement.action IN ('give', 'take', 'transfer')
              AND (
                movement.source_table_id = dining_table.id
                OR movement.destination_table_id = dining_table.id
              )
          ),
          0
        ),
        'protected_seats', chair_state.protected_seats
      )
      ORDER BY dining_table.area, dining_table.name
    ),
    '[]'::jsonb
  )
  INTO table_rows
  FROM public.cafe_dining_tables AS dining_table
  JOIN public.cafe_table_chair_state AS chair_state
    ON chair_state.table_id = dining_table.id;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', movement.id,
        'action', movement.action,
        'source_table_id', movement.source_table_id,
        'destination_table_id', movement.destination_table_id,
        'quantity', movement.quantity,
        'reason', movement.reason,
        'before_state', movement.before_state,
        'after_state', movement.after_state,
        'actor_id', movement.actor_id,
        'created_at', movement.created_at
      )
      ORDER BY movement.created_at DESC, movement.id DESC
    ),
    '[]'::jsonb
  )
  INTO movement_rows
  FROM (
    SELECT *
    FROM public.cafe_chair_movements
    ORDER BY created_at DESC, id DESC
    LIMIT 100
  ) AS movement;

  RETURN jsonb_build_object(
    'pool', jsonb_build_object(
      'available_chairs', pool_row.available_chairs,
      'is_configured', pool_row.is_configured,
      'updated_at', pool_row.updated_at
    ),
    'tables', table_rows,
    'movements', movement_rows
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.set_cafe_spare_chair_count(
  p_request_id uuid,
  p_available_chairs integer,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  caller_id uuid := auth.uid();
  caller_role text;
  existing_actor uuid;
  existing_payload jsonb;
  existing_result jsonb;
  pool_row public.cafe_spare_chair_pool;
  result jsonb;
  payload jsonb;
BEGIN
  IF caller_id IS NULL
    OR auth.jwt()->>'aal' IS DISTINCT FROM 'aal2' THEN
    RAISE EXCEPTION 'Authenticator verification is required.'
      USING ERRCODE = '42501';
  END IF;

  SELECT profile.role
  INTO caller_role
  FROM public.staff_profiles AS profile
  WHERE profile.user_id = caller_id;

  IF caller_role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'Only an administrator may reconcile spare-chair stock.'
      USING ERRCODE = '42501';
  END IF;

  IF p_request_id IS NULL
    OR p_available_chairs IS NULL
    OR p_available_chairs NOT BETWEEN 0 AND 10000
    OR length(trim(COALESCE(p_reason, ''))) NOT BETWEEN 1 AND 300 THEN
    RAISE EXCEPTION 'Enter a valid stock count and reconciliation reason.'
      USING ERRCODE = '22023';
  END IF;

  payload := jsonb_build_object(
    'operation', 'pool_reconciled',
    'available_chairs', p_available_chairs,
    'reason', trim(p_reason)
  );

  PERFORM pg_advisory_xact_lock(
    hashtextextended(p_request_id::text, 0)
  );

  SELECT request.actor_id, request.request_payload, request.result_payload
  INTO existing_actor, existing_payload, existing_result
  FROM public.cafe_chair_requests AS request
  WHERE request.request_id = p_request_id;

  IF FOUND THEN
    IF existing_actor IS DISTINCT FROM caller_id
      OR existing_payload IS DISTINCT FROM payload THEN
      RAISE EXCEPTION 'Chair request identifier was already used.'
        USING ERRCODE = '23505';
    END IF;
    RETURN existing_result;
  END IF;

  SELECT pool.*
  INTO pool_row
  FROM public.cafe_spare_chair_pool AS pool
  WHERE pool.id = 1
  FOR UPDATE;

  UPDATE public.cafe_spare_chair_pool AS pool
  SET available_chairs = p_available_chairs,
      is_configured = true,
      updated_at = now(),
      updated_by = caller_id
  WHERE pool.id = 1;

  result := jsonb_build_object(
    'available_chairs', p_available_chairs,
    'is_configured', true
  );

  INSERT INTO public.cafe_chair_requests (
    request_id, actor_id, request_payload, result_payload
  ) VALUES (
    p_request_id, caller_id, payload, result
  );

  INSERT INTO public.cafe_chair_movements (
    request_id, action, quantity, reason, before_state, after_state, actor_id
  ) VALUES (
    p_request_id,
    'pool_reconciled',
    p_available_chairs,
    trim(p_reason),
    jsonb_build_object(
      'available_chairs', pool_row.available_chairs,
      'is_configured', pool_row.is_configured
    ),
    result,
    caller_id
  );

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_cafe_table_protected_seats(
  p_request_id uuid,
  p_table_id uuid,
  p_protected_seats integer,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  caller_id uuid := auth.uid();
  existing_actor uuid;
  existing_payload jsonb;
  existing_result jsonb;
  old_value integer;
  result jsonb;
  payload jsonb;
BEGIN
  IF caller_id IS NULL
    OR auth.jwt()->>'aal' IS DISTINCT FROM 'aal2'
    OR NOT public.has_workspace_access('tables_orders', 'chairs_management')
  THEN
    RAISE EXCEPTION 'Verified Chairs Management access is required.'
      USING ERRCODE = '42501';
  END IF;

  IF p_request_id IS NULL
    OR p_table_id IS NULL
    OR p_protected_seats IS NULL
    OR p_protected_seats NOT BETWEEN 0 AND 100
    OR length(trim(COALESCE(p_reason, ''))) NOT BETWEEN 1 AND 300 THEN
    RAISE EXCEPTION 'Enter a valid protected-seat count and reason.'
      USING ERRCODE = '22023';
  END IF;

  payload := jsonb_build_object(
    'operation', 'protected_seats_updated',
    'table_id', p_table_id,
    'protected_seats', p_protected_seats,
    'reason', trim(p_reason)
  );

  PERFORM pg_advisory_xact_lock(
    hashtextextended(p_request_id::text, 0)
  );

  SELECT request.actor_id, request.request_payload, request.result_payload
  INTO existing_actor, existing_payload, existing_result
  FROM public.cafe_chair_requests AS request
  WHERE request.request_id = p_request_id;

  IF FOUND THEN
    IF existing_actor IS DISTINCT FROM caller_id
      OR existing_payload IS DISTINCT FROM payload THEN
      RAISE EXCEPTION 'Chair request identifier was already used.'
        USING ERRCODE = '23505';
    END IF;
    RETURN existing_result;
  END IF;

  SELECT state.protected_seats
  INTO old_value
  FROM public.cafe_table_chair_state AS state
  JOIN public.cafe_dining_tables AS dining_table
    ON dining_table.id = state.table_id
  WHERE state.table_id = p_table_id
    AND dining_table.status <> 'cleaning'
  FOR UPDATE OF state;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The selected table is not active.'
      USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.cafe_table_chair_state
  SET protected_seats = p_protected_seats,
      updated_at = now(),
      updated_by = caller_id
  WHERE table_id = p_table_id;

  result := jsonb_build_object(
    'table_id', p_table_id,
    'protected_seats', p_protected_seats
  );

  INSERT INTO public.cafe_chair_requests (
    request_id, actor_id, request_payload, result_payload
  ) VALUES (
    p_request_id, caller_id, payload, result
  );

  INSERT INTO public.cafe_chair_movements (
    request_id, action, source_table_id, reason,
    before_state, after_state, actor_id
  ) VALUES (
    p_request_id,
    'protected_seats_updated',
    p_table_id,
    trim(p_reason),
    jsonb_build_object('protected_seats', old_value),
    result,
    caller_id
  );

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.move_cafe_table_chairs(
  p_request_id uuid,
  p_operation text,
  p_source_table_id uuid,
  p_destination_table_id uuid,
  p_quantity integer,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  caller_id uuid := auth.uid();
  existing_actor uuid;
  existing_payload jsonb;
  existing_result jsonb;
  pool_row public.cafe_spare_chair_pool;
  source_base_chairs integer;
  source_protected_seats integer;
  destination_base_chairs integer;
  source_status text;
  destination_status text;
  source_current integer;
  destination_current integer;
  source_after integer;
  destination_after integer;
  pool_after integer;
  result jsonb;
  payload jsonb;
BEGIN
  IF caller_id IS NULL
    OR auth.jwt()->>'aal' IS DISTINCT FROM 'aal2'
    OR NOT public.has_workspace_access('tables_orders', 'chairs_management')
  THEN
    RAISE EXCEPTION 'Verified Chairs Management access is required.'
      USING ERRCODE = '42501';
  END IF;

  IF p_request_id IS NULL
    OR p_operation IS NULL
    OR p_operation NOT IN ('give', 'take', 'transfer')
    OR p_quantity IS NULL
    OR p_quantity NOT BETWEEN 1 AND 100
    OR length(trim(COALESCE(p_reason, ''))) NOT BETWEEN 1 AND 300
    OR (
      p_operation = 'give'
      AND (p_source_table_id IS NOT NULL OR p_destination_table_id IS NULL)
    )
    OR (
      p_operation = 'take'
      AND (p_source_table_id IS NULL OR p_destination_table_id IS NOT NULL)
    )
    OR (
      p_operation = 'transfer'
      AND (
        p_source_table_id IS NULL
        OR p_destination_table_id IS NULL
        OR p_source_table_id = p_destination_table_id
      )
    ) THEN
    RAISE EXCEPTION 'The chair movement request is invalid.'
      USING ERRCODE = '22023';
  END IF;

  payload := jsonb_build_object(
    'operation', p_operation,
    'source_table_id', p_source_table_id,
    'destination_table_id', p_destination_table_id,
    'quantity', p_quantity,
    'reason', trim(p_reason)
  );

  PERFORM pg_advisory_xact_lock(
    hashtextextended(p_request_id::text, 0)
  );

  SELECT request.actor_id, request.request_payload, request.result_payload
  INTO existing_actor, existing_payload, existing_result
  FROM public.cafe_chair_requests AS request
  WHERE request.request_id = p_request_id;

  IF FOUND THEN
    IF existing_actor IS DISTINCT FROM caller_id
      OR existing_payload IS DISTINCT FROM payload THEN
      RAISE EXCEPTION 'Chair request identifier was already used.'
        USING ERRCODE = '23505';
    END IF;
    RETURN existing_result;
  END IF;

  SELECT pool.*
  INTO pool_row
  FROM public.cafe_spare_chair_pool AS pool
  WHERE pool.id = 1
  FOR UPDATE;

  IF NOT pool_row.is_configured THEN
    RAISE EXCEPTION 'An administrator must record the actual spare-chair count first.'
      USING ERRCODE = '23514';
  END IF;

  PERFORM dining_table.id
  FROM public.cafe_dining_tables AS dining_table
  WHERE dining_table.id IN (
    p_source_table_id,
    p_destination_table_id
  )
  ORDER BY dining_table.id
  FOR UPDATE;

  PERFORM chair_state.table_id
  FROM public.cafe_table_chair_state AS chair_state
  WHERE chair_state.table_id IN (
    p_source_table_id,
    p_destination_table_id
  )
  ORDER BY chair_state.table_id
  FOR UPDATE;

  IF p_source_table_id IS NOT NULL THEN
    SELECT
      chair_state.base_chairs,
      chair_state.protected_seats,
      dining_table.status
    INTO
      source_base_chairs,
      source_protected_seats,
      source_status
    FROM public.cafe_table_chair_state AS chair_state
    JOIN public.cafe_dining_tables AS dining_table
      ON dining_table.id = chair_state.table_id
    WHERE chair_state.table_id = p_source_table_id;

    IF NOT FOUND OR source_status = 'cleaning' THEN
      RAISE EXCEPTION 'The source table is not active.'
        USING ERRCODE = 'P0002';
    END IF;

    SELECT source_base_chairs + COALESCE(
      sum(
        CASE
          WHEN movement.destination_table_id = p_source_table_id
            THEN movement.quantity
          WHEN movement.source_table_id = p_source_table_id
            THEN -movement.quantity
          ELSE 0
        END
      ),
      0
    )
    INTO source_current
    FROM public.cafe_chair_movements AS movement
    WHERE movement.action IN ('give', 'take', 'transfer')
      AND (
        movement.source_table_id = p_source_table_id
        OR movement.destination_table_id = p_source_table_id
      );

    IF source_protected_seats IS NULL THEN
      RAISE EXCEPTION 'Record the verified guest and reservation seat minimum for the source table first.'
        USING ERRCODE = '23514';
    END IF;
    source_after := source_current - p_quantity;
    IF source_after < source_protected_seats THEN
      RAISE EXCEPTION 'The movement would leave fewer chairs than the protected guest/reservation count.'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  IF p_destination_table_id IS NOT NULL THEN
    SELECT
      chair_state.base_chairs,
      dining_table.status
    INTO
      destination_base_chairs,
      destination_status
    FROM public.cafe_table_chair_state AS chair_state
    JOIN public.cafe_dining_tables AS dining_table
      ON dining_table.id = chair_state.table_id
    WHERE chair_state.table_id = p_destination_table_id;

    IF NOT FOUND OR destination_status = 'cleaning' THEN
      RAISE EXCEPTION 'The destination table is not active.'
        USING ERRCODE = 'P0002';
    END IF;

    SELECT destination_base_chairs + COALESCE(
      sum(
        CASE
          WHEN movement.destination_table_id = p_destination_table_id
            THEN movement.quantity
          WHEN movement.source_table_id = p_destination_table_id
            THEN -movement.quantity
          ELSE 0
        END
      ),
      0
    )
    INTO destination_current
    FROM public.cafe_chair_movements AS movement
    WHERE movement.action IN ('give', 'take', 'transfer')
      AND (
        movement.source_table_id = p_destination_table_id
        OR movement.destination_table_id = p_destination_table_id
      );
    destination_after := destination_current + p_quantity;
  END IF;

  pool_after := CASE
    WHEN p_operation = 'give' THEN pool_row.available_chairs - p_quantity
    WHEN p_operation = 'take' THEN pool_row.available_chairs + p_quantity
    ELSE pool_row.available_chairs
  END;

  IF pool_after < 0 OR pool_after > 10000 THEN
    RAISE EXCEPTION 'There are not enough verified spare chairs in the pool.'
      USING ERRCODE = '23514';
  END IF;

  UPDATE public.cafe_spare_chair_pool
  SET available_chairs = pool_after,
      updated_at = now(),
      updated_by = caller_id
  WHERE id = 1;

  result := jsonb_build_object(
    'operation', p_operation,
    'source_table_id', p_source_table_id,
    'destination_table_id', p_destination_table_id,
    'quantity', p_quantity,
    'pool_available_chairs', pool_after,
    'source_current_chairs', source_after,
    'destination_current_chairs', destination_after
  );

  INSERT INTO public.cafe_chair_requests (
    request_id, actor_id, request_payload, result_payload
  ) VALUES (
    p_request_id, caller_id, payload, result
  );

  INSERT INTO public.cafe_chair_movements (
    request_id, action, source_table_id, destination_table_id,
    quantity, reason, before_state, after_state, actor_id
  ) VALUES (
    p_request_id,
    p_operation,
    p_source_table_id,
    p_destination_table_id,
    p_quantity,
    trim(p_reason),
    jsonb_build_object(
      'pool_available_chairs', pool_row.available_chairs,
      'source_current_chairs', source_current,
      'destination_current_chairs', destination_current
    ),
    result,
    caller_id
  );

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_cafe_chair_management()
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_cafe_spare_chair_count(uuid, integer, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_cafe_table_protected_seats(
  uuid, uuid, integer, text
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.move_cafe_table_chairs(
  uuid, text, uuid, uuid, integer, text
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.get_cafe_chair_management()
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_cafe_spare_chair_count(uuid, integer, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_cafe_table_protected_seats(
  uuid, uuid, integer, text
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.move_cafe_table_chairs(
  uuid, text, uuid, uuid, integer, text
) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
