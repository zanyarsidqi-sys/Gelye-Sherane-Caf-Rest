-- Shared live record store for the 11-section workspace.
-- Depends on staff_profiles and staff_permissions.
BEGIN;

CREATE OR REPLACE FUNCTION public.has_workspace_access(
  requested_section text,
  requested_subcard text
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  current_user_id uuid := auth.uid();
  current_role text;
BEGIN
  IF current_user_id IS NULL
    OR auth.jwt()->>'aal' IS DISTINCT FROM 'aal2' THEN
    RETURN false;
  END IF;

  SELECT role
  INTO current_role
  FROM public.staff_profiles
  WHERE user_id = current_user_id;

  IF current_role = 'admin' THEN
    RETURN true;
  END IF;

  IF current_role IS DISTINCT FROM 'staff' THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.staff_permissions permission
    WHERE permission.user_id = current_user_id
      AND permission.section_key = requested_section
      AND permission.subcard_key IN ('*', requested_subcard)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.has_workspace_access(text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_workspace_access(text, text)
  TO authenticated;

CREATE TABLE public.cafe_workspace_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  section_key text NOT NULL CHECK (
    section_key IN (
      'dashboard',
      'tables_orders',
      'payment_management',
      'kitchen_management',
      'customer_management',
      'statistics_management',
      'employee_management',
      'maintenance_management',
      'notifications_management',
      'settings_management',
      'operations_management'
    )
  ),
  subcard_key text NOT NULL CHECK (
    subcard_key ~ '^[a-z0-9]+(_[a-z0-9]+)*$'
  ),
  title text NOT NULL CHECK (
    length(trim(title)) BETWEEN 1 AND 160
  ),
  details text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'open' CHECK (
    status IN ('open', 'in_progress', 'completed', 'cancelled')
  ),
  amount numeric(14, 2),
  currency text NOT NULL DEFAULT 'IQD' CHECK (
    currency ~ '^[A-Z]{3}$'
  ),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (
    jsonb_typeof(metadata) = 'object'
  ),
  created_by uuid NOT NULL DEFAULT auth.uid()
    REFERENCES auth.users(id) ON DELETE RESTRICT,
  updated_by uuid NOT NULL DEFAULT auth.uid()
    REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX cafe_workspace_records_section_card_updated_idx
  ON public.cafe_workspace_records (
    section_key,
    subcard_key,
    updated_at DESC
  );

ALTER TABLE public.cafe_workspace_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_workspace_records FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.cafe_workspace_records
  FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.cafe_workspace_records TO authenticated;

CREATE POLICY cafe_workspace_records_select
ON public.cafe_workspace_records FOR SELECT TO authenticated
USING (
  public.has_workspace_access(section_key, subcard_key)
);

CREATE POLICY cafe_workspace_records_insert
ON public.cafe_workspace_records FOR INSERT TO authenticated
WITH CHECK (
  public.has_workspace_access(section_key, subcard_key)
  AND created_by = (SELECT auth.uid())
  AND updated_by = (SELECT auth.uid())
);

CREATE POLICY cafe_workspace_records_update
ON public.cafe_workspace_records FOR UPDATE TO authenticated
USING (
  public.has_workspace_access(section_key, subcard_key)
)
WITH CHECK (
  public.has_workspace_access(section_key, subcard_key)
  AND updated_by = (SELECT auth.uid())
);

CREATE POLICY cafe_workspace_records_delete
ON public.cafe_workspace_records FOR DELETE TO authenticated
USING (
  public.has_workspace_access(section_key, subcard_key)
);

CREATE TABLE public.cafe_workspace_audit (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  record_id uuid NOT NULL,
  section_key text NOT NULL,
  subcard_key text NOT NULL,
  action text NOT NULL CHECK (action IN ('insert', 'update', 'delete')),
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  changed_at timestamptz NOT NULL DEFAULT now(),
  record_snapshot jsonb NOT NULL CHECK (
    jsonb_typeof(record_snapshot) = 'object'
  )
);

CREATE INDEX cafe_workspace_audit_record_changed_idx
  ON public.cafe_workspace_audit (record_id, changed_at DESC);

ALTER TABLE public.cafe_workspace_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_workspace_audit FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.cafe_workspace_audit
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.cafe_workspace_audit TO authenticated;

CREATE POLICY cafe_workspace_audit_select
ON public.cafe_workspace_audit FOR SELECT TO authenticated
USING (
  public.has_workspace_access(section_key, subcard_key)
);

CREATE OR REPLACE FUNCTION public.audit_cafe_workspace_record()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  changed_record public.cafe_workspace_records;
BEGIN
  IF TG_OP = 'DELETE' THEN
    changed_record := OLD;
  ELSE
    changed_record := NEW;
  END IF;

  INSERT INTO public.cafe_workspace_audit (
    record_id,
    section_key,
    subcard_key,
    action,
    actor_id,
    record_snapshot
  )
  VALUES (
    changed_record.id,
    changed_record.section_key,
    changed_record.subcard_key,
    lower(TG_OP),
    auth.uid(),
    to_jsonb(changed_record)
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.audit_cafe_workspace_record()
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.touch_cafe_workspace_record()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, auth
AS $$
BEGIN
  NEW.updated_at := now();
  NEW.updated_by := auth.uid();
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.touch_cafe_workspace_record()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER cafe_workspace_record_touch
BEFORE UPDATE ON public.cafe_workspace_records
FOR EACH ROW EXECUTE FUNCTION public.touch_cafe_workspace_record();

CREATE TRIGGER cafe_workspace_record_audit
AFTER INSERT OR UPDATE OR DELETE ON public.cafe_workspace_records
FOR EACH ROW EXECUTE FUNCTION public.audit_cafe_workspace_record();

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'cafe_workspace_records'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.cafe_workspace_records;
  END IF;
END;
$$;

COMMIT;
