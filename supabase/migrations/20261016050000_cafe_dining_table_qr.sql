-- Opaque table QR identifiers and their audit trail.
-- Apply only to an isolated development project after the table RPC migrations.
BEGIN;

CREATE TABLE public.cafe_dining_table_qr_tokens (
  table_id uuid PRIMARY KEY
    REFERENCES public.cafe_dining_tables(id) ON DELETE CASCADE,
  token uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  rotated_at timestamptz
);

CREATE TABLE public.cafe_dining_table_qr_audit (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  table_id uuid NOT NULL
    REFERENCES public.cafe_dining_tables(id) ON DELETE CASCADE,
  action text NOT NULL CHECK (action IN ('created', 'regenerated')),
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  changed_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.cafe_dining_table_qr_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_dining_table_qr_tokens FORCE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_dining_table_qr_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_dining_table_qr_audit FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.cafe_dining_table_qr_tokens
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.cafe_dining_table_qr_audit
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.cafe_dining_table_qr_audit TO authenticated;

CREATE POLICY cafe_dining_table_qr_audit_select
ON public.cafe_dining_table_qr_audit FOR SELECT TO authenticated
USING (public.has_workspace_access('tables_orders', 'add_edit_tables'));

CREATE OR REPLACE FUNCTION public.create_cafe_dining_table_qr_token()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
BEGIN
  INSERT INTO public.cafe_dining_table_qr_tokens (table_id)
  VALUES (NEW.id);

  INSERT INTO public.cafe_dining_table_qr_audit (table_id, action, actor_id)
  VALUES (NEW.id, 'created', auth.uid());

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.create_cafe_dining_table_qr_token()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER cafe_dining_table_qr_token_create
AFTER INSERT ON public.cafe_dining_tables
FOR EACH ROW EXECUTE FUNCTION public.create_cafe_dining_table_qr_token();

INSERT INTO public.cafe_dining_table_qr_tokens (table_id)
SELECT dining_table.id
FROM public.cafe_dining_tables AS dining_table
ON CONFLICT (table_id) DO NOTHING;

INSERT INTO public.cafe_dining_table_qr_audit (table_id, action, actor_id)
SELECT qr.table_id, 'created', NULL
FROM public.cafe_dining_table_qr_tokens AS qr
WHERE NOT EXISTS (
  SELECT 1
  FROM public.cafe_dining_table_qr_audit AS audit
  WHERE audit.table_id = qr.table_id
    AND audit.action = 'created'
);

CREATE OR REPLACE FUNCTION public.get_cafe_dining_table_qr_token(p_table_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  result uuid;
BEGIN
  IF NOT public.has_workspace_access('tables_orders', 'add_edit_tables') THEN
    RAISE EXCEPTION 'Add Table permission is required to access QR codes.'
      USING ERRCODE = '42501';
  END IF;

  SELECT qr.token INTO result
  FROM public.cafe_dining_table_qr_tokens AS qr
  WHERE qr.table_id = p_table_id;
  IF result IS NULL THEN
    RAISE EXCEPTION 'Dining table QR code was not found.'
      USING ERRCODE = 'P0002';
  END IF;
  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.regenerate_cafe_dining_table_qr_token(
  p_table_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  caller_id uuid := auth.uid();
  result uuid;
BEGIN
  IF NOT public.has_workspace_access('tables_orders', 'add_edit_tables') THEN
    RAISE EXCEPTION 'Add Table permission is required to regenerate QR codes.'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.cafe_dining_table_qr_tokens
  SET token = gen_random_uuid(), rotated_at = now()
  WHERE table_id = p_table_id
  RETURNING token INTO result;
  IF result IS NULL THEN
    RAISE EXCEPTION 'Dining table QR code was not found.'
      USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.cafe_dining_table_qr_audit (table_id, action, actor_id)
  VALUES (p_table_id, 'regenerated', caller_id);
  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_cafe_guest_table_context(p_qr_token uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'table', jsonb_build_object(
      'id', dining_table.id,
      'name', dining_table.name,
      'area', dining_table.area
    ),
    'restaurant_name', 'Gelye Sherane Café & Restaurant'
  )
  INTO result
  FROM public.cafe_dining_table_qr_tokens AS qr
  JOIN public.cafe_dining_tables AS dining_table
    ON dining_table.id = qr.table_id
  WHERE qr.token = p_qr_token
    AND dining_table.status <> 'cleaning';

  IF result IS NULL THEN
    RAISE EXCEPTION 'This table QR code is invalid or inactive.'
      USING ERRCODE = '22023';
  END IF;
  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_cafe_dining_table_qr_token(uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.regenerate_cafe_dining_table_qr_token(uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_cafe_guest_table_context(uuid)
  FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_cafe_dining_table_qr_token(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.regenerate_cafe_dining_table_qr_token(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_cafe_guest_table_context(uuid)
  TO anon, authenticated;

COMMIT;
