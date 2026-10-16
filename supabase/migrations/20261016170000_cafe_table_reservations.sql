-- Development/staging migration for the first operational reservation flow.
-- Do not apply to production until the documented staging release gate passes.
BEGIN;

CREATE TABLE public.cafe_table_reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL UNIQUE,
  table_id uuid NOT NULL
    REFERENCES public.cafe_dining_tables(id) ON DELETE RESTRICT,
  customer_name text NOT NULL
    CHECK (length(trim(customer_name)) BETWEEN 1 AND 120),
  contact text NOT NULL
    CHECK (length(trim(contact)) BETWEEN 5 AND 80),
  party_size integer NOT NULL CHECK (party_size BETWEEN 1 AND 100),
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'confirmed'
    CHECK (status IN ('confirmed', 'cancelled')),
  notes text NOT NULL DEFAULT '' CHECK (length(notes) <= 1000),
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (ends_at > starts_at),
  CHECK (ends_at - starts_at <= interval '12 hours')
);

CREATE INDEX cafe_table_reservations_table_time_idx
  ON public.cafe_table_reservations (table_id, starts_at, ends_at)
  WHERE status = 'confirmed';
CREATE INDEX cafe_table_reservations_start_idx
  ON public.cafe_table_reservations (starts_at, id);

CREATE TABLE public.cafe_table_reservation_audit (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  reservation_id uuid NOT NULL
    REFERENCES public.cafe_table_reservations(id) ON DELETE RESTRICT,
  action text NOT NULL CHECK (action IN ('created', 'cancelled')),
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  safe_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb
    CHECK (jsonb_typeof(safe_snapshot) = 'object')
);

ALTER TABLE public.cafe_table_reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_table_reservations FORCE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_table_reservation_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_table_reservation_audit FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.cafe_table_reservations
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.cafe_table_reservation_audit
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.cafe_table_reservations TO authenticated;
GRANT SELECT ON TABLE public.cafe_table_reservation_audit TO authenticated;

CREATE POLICY cafe_table_reservations_select
ON public.cafe_table_reservations FOR SELECT TO authenticated
USING (
  public.has_workspace_access('tables_orders', 'table_reservations')
);

CREATE POLICY cafe_table_reservation_audit_select
ON public.cafe_table_reservation_audit FOR SELECT TO authenticated
USING (
  public.has_workspace_access('tables_orders', 'table_reservations')
  OR public.has_workspace_access('tables_orders', 'table_history_audit')
);

CREATE OR REPLACE FUNCTION public.create_cafe_table_reservation(
  p_request_id uuid,
  p_table_id uuid,
  p_customer_name text,
  p_contact text,
  p_party_size integer,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_notes text DEFAULT ''
)
RETURNS SETOF public.cafe_table_reservations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  caller_id uuid := auth.uid();
  table_seats integer;
  table_status text;
  reservation public.cafe_table_reservations;
BEGIN
  IF NOT public.has_workspace_access(
    'tables_orders',
    'table_reservations'
  ) THEN
    RAISE EXCEPTION 'Table Reservations permission is required.'
      USING ERRCODE = '42501';
  END IF;

  IF p_request_id IS NULL
    OR p_table_id IS NULL
    OR p_customer_name IS NULL
    OR length(trim(p_customer_name)) NOT BETWEEN 1 AND 120
    OR p_contact IS NULL
    OR length(trim(p_contact)) NOT BETWEEN 5 AND 80
    OR p_party_size IS NULL
    OR p_party_size NOT BETWEEN 1 AND 100
    OR p_starts_at IS NULL
    OR p_ends_at IS NULL
    OR p_starts_at <= now()
    OR p_ends_at <= p_starts_at
    OR p_ends_at - p_starts_at > interval '12 hours'
    OR length(COALESCE(p_notes, '')) > 1000 THEN
    RAISE EXCEPTION 'Reservation details are invalid.'
      USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended(p_request_id::text, 0)
  );

  SELECT *
  INTO reservation
  FROM public.cafe_table_reservations AS existing
  WHERE existing.request_id = p_request_id;

  IF FOUND THEN
    IF reservation.created_by = caller_id
      AND reservation.table_id = p_table_id
      AND reservation.customer_name = trim(p_customer_name)
      AND reservation.contact = trim(p_contact)
      AND reservation.party_size = p_party_size
      AND reservation.starts_at = p_starts_at
      AND reservation.ends_at = p_ends_at
      AND reservation.notes = COALESCE(trim(p_notes), '') THEN
      RETURN NEXT reservation;
      RETURN;
    END IF;
    RAISE EXCEPTION 'Reservation request identifier was already used.'
      USING ERRCODE = '23505';
  END IF;

  SELECT dining_table.seats, dining_table.status
  INTO table_seats, table_status
  FROM public.cafe_dining_tables AS dining_table
  WHERE dining_table.id = p_table_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Dining table was not found.'
      USING ERRCODE = 'P0002';
  END IF;
  IF p_party_size > table_seats THEN
    RAISE EXCEPTION 'Party size exceeds the selected table capacity.'
      USING ERRCODE = '22023';
  END IF;
  IF table_status <> 'available' THEN
    RAISE EXCEPTION 'Only currently available tables can be reserved.'
      USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM public.cafe_table_reservations AS existing
    WHERE existing.table_id = p_table_id
      AND existing.status = 'confirmed'
      AND existing.starts_at < p_ends_at
      AND existing.ends_at > p_starts_at
  ) THEN
    RAISE EXCEPTION 'The selected table is already reserved for that time.'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.cafe_table_reservations AS saved (
    request_id,
    table_id,
    customer_name,
    contact,
    party_size,
    starts_at,
    ends_at,
    notes,
    created_by
  )
  VALUES (
    p_request_id,
    p_table_id,
    trim(p_customer_name),
    trim(p_contact),
    p_party_size,
    p_starts_at,
    p_ends_at,
    COALESCE(trim(p_notes), ''),
    caller_id
  )
  ON CONFLICT (request_id) DO NOTHING
  RETURNING saved.* INTO reservation;

  IF NOT FOUND THEN
    SELECT *
    INTO reservation
    FROM public.cafe_table_reservations AS existing
    WHERE existing.request_id = p_request_id;
    IF NOT FOUND
      OR reservation.created_by IS DISTINCT FROM caller_id
      OR reservation.table_id IS DISTINCT FROM p_table_id
      OR reservation.customer_name IS DISTINCT FROM trim(p_customer_name)
      OR reservation.contact IS DISTINCT FROM trim(p_contact)
      OR reservation.party_size IS DISTINCT FROM p_party_size
      OR reservation.starts_at IS DISTINCT FROM p_starts_at
      OR reservation.ends_at IS DISTINCT FROM p_ends_at
      OR reservation.notes IS DISTINCT FROM COALESCE(trim(p_notes), '') THEN
      RAISE EXCEPTION 'Reservation request identifier was already used.'
        USING ERRCODE = '23505';
    END IF;
    RETURN NEXT reservation;
    RETURN;
  END IF;

  INSERT INTO public.cafe_table_reservation_audit (
    reservation_id,
    action,
    actor_id,
    safe_snapshot
  )
  VALUES (
    reservation.id,
    'created',
    caller_id,
    jsonb_build_object(
      'table_id', reservation.table_id,
      'party_size', reservation.party_size,
      'starts_at', reservation.starts_at,
      'ends_at', reservation.ends_at,
      'status', reservation.status
    )
  );

  RETURN NEXT reservation;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_cafe_table_reservation(
  p_reservation_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  caller_id uuid := auth.uid();
  reservation public.cafe_table_reservations;
BEGIN
  IF NOT public.has_workspace_access(
    'tables_orders',
    'table_reservations'
  ) THEN
    RAISE EXCEPTION 'Table Reservations permission is required.'
      USING ERRCODE = '42501';
  END IF;

  SELECT *
  INTO reservation
  FROM public.cafe_table_reservations AS current_reservation
  WHERE current_reservation.id = p_reservation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Reservation was not found.'
      USING ERRCODE = 'P0002';
  END IF;
  IF reservation.status <> 'confirmed'
    OR reservation.starts_at <= now() THEN
    RAISE EXCEPTION 'Only future confirmed reservations can be cancelled.'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.cafe_table_reservations AS current_reservation
  SET status = 'cancelled'
  WHERE current_reservation.id = p_reservation_id
  RETURNING current_reservation.* INTO reservation;

  INSERT INTO public.cafe_table_reservation_audit (
    reservation_id,
    action,
    actor_id,
    safe_snapshot
  )
  VALUES (
    reservation.id,
    'cancelled',
    caller_id,
    jsonb_build_object(
      'table_id', reservation.table_id,
      'party_size', reservation.party_size,
      'starts_at', reservation.starts_at,
      'ends_at', reservation.ends_at,
      'status', reservation.status
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.create_cafe_table_reservation(
  uuid, uuid, text, text, integer, timestamptz, timestamptz, text
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cancel_cafe_table_reservation(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_cafe_table_reservation(
  uuid, uuid, text, text, integer, timestamptz, timestamptz, text
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_cafe_table_reservation(uuid)
  TO authenticated;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'cafe_table_reservations'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.cafe_table_reservations;
  END IF;
END;
$$;

COMMIT;
