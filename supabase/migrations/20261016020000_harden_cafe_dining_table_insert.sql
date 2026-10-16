-- Enforce actor attribution in the database and avoid trusting client-supplied
-- created_by/updated_by values during table creation.
BEGIN;

CREATE OR REPLACE FUNCTION public.touch_cafe_dining_table()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, auth
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.created_by := auth.uid();
  END IF;
  NEW.updated_at := now();
  NEW.updated_by := auth.uid();
  RETURN NEW;
END;
$$;

DROP TRIGGER cafe_dining_table_touch ON public.cafe_dining_tables;
CREATE TRIGGER cafe_dining_table_touch
BEFORE INSERT OR UPDATE ON public.cafe_dining_tables
FOR EACH ROW EXECUTE FUNCTION public.touch_cafe_dining_table();

DROP POLICY cafe_dining_tables_insert ON public.cafe_dining_tables;
CREATE POLICY cafe_dining_tables_insert
ON public.cafe_dining_tables FOR INSERT TO authenticated
WITH CHECK (
  public.has_workspace_access('tables_orders', 'add_edit_tables')
);

COMMIT;
