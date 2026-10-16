-- Apply to the production Supabase project before deploying the table manager.
BEGIN;

CREATE TABLE public.cafe_dining_tables (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 80),
  area text NOT NULL DEFAULT 'Main' CHECK (length(trim(area)) BETWEEN 1 AND 80),
  seats integer NOT NULL DEFAULT 4 CHECK (seats BETWEEN 1 AND 100),
  status text NOT NULL DEFAULT 'available' CHECK (
    status IN ('available', 'occupied', 'reserved', 'cleaning')
  ),
  position_x numeric(5, 4) NOT NULL DEFAULT 0.5 CHECK (
    position_x BETWEEN 0 AND 1
  ),
  position_y numeric(5, 4) NOT NULL DEFAULT 0.5 CHECK (
    position_y BETWEEN 0 AND 1
  ),
  created_by uuid NOT NULL DEFAULT auth.uid()
    REFERENCES auth.users(id) ON DELETE RESTRICT,
  updated_by uuid NOT NULL DEFAULT auth.uid()
    REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX cafe_dining_tables_area_name_idx
  ON public.cafe_dining_tables (lower(area), lower(name));

CREATE INDEX cafe_dining_tables_area_name_order_idx
  ON public.cafe_dining_tables (area, name);

ALTER TABLE public.cafe_dining_tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_dining_tables FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.cafe_dining_tables
  FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.cafe_dining_tables TO authenticated;

CREATE POLICY cafe_dining_tables_select
ON public.cafe_dining_tables FOR SELECT TO authenticated
USING (
  public.has_workspace_access('tables_orders', 'add_edit_tables')
  OR public.has_workspace_access('tables_orders', 'table_overview')
  OR public.has_workspace_access('tables_orders', 'visual_table_map')
  OR public.has_workspace_access('tables_orders', 'table_map')
  OR public.has_workspace_access('tables_orders', 'live_tables')
  OR public.has_workspace_access('tables_orders', 'table_availability')
  OR public.has_workspace_access('tables_orders', 'active_tables')
  OR public.has_workspace_access('tables_orders', 'table_status')
);

CREATE POLICY cafe_dining_tables_insert
ON public.cafe_dining_tables FOR INSERT TO authenticated
WITH CHECK (
  public.has_workspace_access('tables_orders', 'add_edit_tables')
  AND created_by = (SELECT auth.uid())
  AND updated_by = (SELECT auth.uid())
);

CREATE POLICY cafe_dining_tables_update
ON public.cafe_dining_tables FOR UPDATE TO authenticated
USING (
  public.has_workspace_access('tables_orders', 'add_edit_tables')
)
WITH CHECK (
  public.has_workspace_access('tables_orders', 'add_edit_tables')
  AND updated_by = (SELECT auth.uid())
);

CREATE POLICY cafe_dining_tables_delete
ON public.cafe_dining_tables FOR DELETE TO authenticated
USING (
  public.has_workspace_access('tables_orders', 'add_edit_tables')
);

CREATE OR REPLACE FUNCTION public.touch_cafe_dining_table()
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

REVOKE ALL ON FUNCTION public.touch_cafe_dining_table()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER cafe_dining_table_touch
BEFORE UPDATE ON public.cafe_dining_tables
FOR EACH ROW EXECUTE FUNCTION public.touch_cafe_dining_table();

CREATE OR REPLACE FUNCTION public.audit_cafe_dining_table()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  changed_table public.cafe_dining_tables;
BEGIN
  IF TG_OP = 'DELETE' THEN
    changed_table := OLD;
  ELSE
    changed_table := NEW;
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
    changed_table.id,
    'tables_orders',
    'add_edit_tables',
    lower(TG_OP),
    auth.uid(),
    to_jsonb(changed_table)
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.audit_cafe_dining_table()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER cafe_dining_table_audit
AFTER INSERT OR UPDATE OR DELETE ON public.cafe_dining_tables
FOR EACH ROW EXECUTE FUNCTION public.audit_cafe_dining_table();

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'cafe_dining_tables'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.cafe_dining_tables;
  END IF;
END;
$$;

COMMIT;
