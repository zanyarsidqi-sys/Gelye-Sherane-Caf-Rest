BEGIN;
-- Staging migration for QR table ordering and its staff menu/order workflows.
-- Validate the guest and AAL2 staff paths in staging before production rollout.

CREATE TABLE public.cafe_menu_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 120),
  category text NOT NULL CHECK (length(trim(category)) BETWEEN 1 AND 60),
  description text NOT NULL DEFAULT '' CHECK (length(description) <= 500),
  price_iqd bigint NOT NULL CHECK (price_iqd BETWEEN 1 AND 999999999),
  available boolean NOT NULL DEFAULT true,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX cafe_menu_items_category_name_idx
  ON public.cafe_menu_items (lower(category), lower(name));

CREATE TABLE public.cafe_table_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL UNIQUE,
  table_id uuid NOT NULL
    REFERENCES public.cafe_dining_tables(id) ON DELETE RESTRICT,
  status text NOT NULL DEFAULT 'received'
    CHECK (status IN ('received', 'preparing', 'ready', 'served', 'cancelled')),
  total_iqd bigint NOT NULL CHECK (total_iqd BETWEEN 1 AND 19999999980),
  notes text NOT NULL DEFAULT '' CHECK (length(notes) <= 500),
  request_signature jsonb NOT NULL
    CHECK (jsonb_typeof(request_signature) = 'object'),
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX cafe_table_orders_status_created_idx
  ON public.cafe_table_orders (status, created_at, id);
CREATE INDEX cafe_table_orders_table_created_idx
  ON public.cafe_table_orders (table_id, created_at DESC);

CREATE TABLE public.cafe_table_order_items (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id uuid NOT NULL
    REFERENCES public.cafe_table_orders(id) ON DELETE RESTRICT,
  menu_item_id uuid NOT NULL
    REFERENCES public.cafe_menu_items(id) ON DELETE RESTRICT,
  item_name text NOT NULL CHECK (length(trim(item_name)) BETWEEN 1 AND 120),
  quantity integer NOT NULL CHECK (quantity BETWEEN 1 AND 20),
  unit_price_iqd bigint NOT NULL CHECK (unit_price_iqd BETWEEN 1 AND 999999999),
  line_total_iqd bigint GENERATED ALWAYS AS (quantity * unit_price_iqd) STORED
);

CREATE INDEX cafe_table_order_items_order_idx
  ON public.cafe_table_order_items (order_id, id);

CREATE TABLE public.cafe_table_order_audit (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id uuid NOT NULL
    REFERENCES public.cafe_table_orders(id) ON DELETE RESTRICT,
  action text NOT NULL CHECK (
    action IN ('received', 'preparing', 'ready', 'served', 'cancelled')
  ),
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  safe_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb
    CHECK (jsonb_typeof(safe_snapshot) = 'object')
);

ALTER TABLE public.cafe_menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_menu_items FORCE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_table_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_table_orders FORCE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_table_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_table_order_items FORCE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_table_order_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_table_order_audit FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.cafe_menu_items,
  public.cafe_table_orders,
  public.cafe_table_order_items,
  public.cafe_table_order_audit
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.touch_cafe_menu_item()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.touch_cafe_menu_item()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER cafe_menu_item_touch
BEFORE UPDATE ON public.cafe_menu_items
FOR EACH ROW EXECUTE FUNCTION public.touch_cafe_menu_item();

CREATE OR REPLACE FUNCTION public.touch_cafe_table_order()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.touch_cafe_table_order()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER cafe_table_order_touch
BEFORE UPDATE ON public.cafe_table_orders
FOR EACH ROW EXECUTE FUNCTION public.touch_cafe_table_order();

CREATE OR REPLACE FUNCTION public.get_cafe_guest_menu(p_qr_token uuid)
RETURNS TABLE (
  id uuid,
  name text,
  category text,
  description text,
  price_iqd bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.cafe_dining_table_qr_tokens qr
    JOIN public.cafe_dining_tables dining_table
      ON dining_table.id = qr.table_id
    WHERE qr.token = p_qr_token
      AND dining_table.status <> 'cleaning'
  ) THEN
    RAISE EXCEPTION 'This table QR code is invalid or inactive.'
      USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT menu_item.id,
         menu_item.name,
         menu_item.category,
         menu_item.description,
         menu_item.price_iqd
  FROM public.cafe_menu_items menu_item
  WHERE menu_item.available
  ORDER BY lower(menu_item.category), menu_item.name, menu_item.id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_cafe_menu_items()
RETURNS TABLE (
  id uuid,
  name text,
  category text,
  description text,
  price_iqd bigint,
  available boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
BEGIN
  IF NOT (
    public.has_workspace_access('kitchen_management', 'add_new_product')
    OR public.has_workspace_access('kitchen_management', 'edit_manage_products')
  ) THEN
    RAISE EXCEPTION 'Menu product access is required.'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT menu_item.id,
         menu_item.name,
         menu_item.category,
         menu_item.description,
         menu_item.price_iqd,
         menu_item.available
  FROM public.cafe_menu_items menu_item
  ORDER BY lower(menu_item.category), menu_item.name, menu_item.id;
END;
$$;

CREATE OR REPLACE FUNCTION public.save_cafe_menu_item(
  p_id uuid,
  p_name text,
  p_category text,
  p_description text,
  p_price_iqd bigint,
  p_available boolean
)
RETURNS SETOF public.cafe_menu_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  caller_id uuid := auth.uid();
  saved_item public.cafe_menu_items;
BEGIN
  IF caller_id IS NULL
    OR auth.jwt()->>'aal' IS DISTINCT FROM 'aal2' THEN
    RAISE EXCEPTION 'Authenticator verification is required to manage menu items.'
      USING ERRCODE = '42501';
  END IF;

  IF p_name IS NULL
    OR length(trim(p_name)) NOT BETWEEN 1 AND 120
    OR p_category IS NULL
    OR length(trim(p_category)) NOT BETWEEN 1 AND 60
    OR length(COALESCE(p_description, '')) > 500
    OR p_price_iqd IS NULL
    OR p_price_iqd NOT BETWEEN 1 AND 999999999
    OR p_available IS NULL THEN
    RAISE EXCEPTION 'Menu item details are invalid.'
      USING ERRCODE = '22023';
  END IF;

  IF p_id IS NULL THEN
    IF NOT public.has_workspace_access(
      'kitchen_management',
      'add_new_product'
    ) THEN
      RAISE EXCEPTION 'Add New Product permission is required.'
        USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.cafe_menu_items (
      name, category, description, price_iqd, available, created_by, updated_by
    )
    VALUES (
      trim(p_name),
      trim(p_category),
      COALESCE(trim(p_description), ''),
      p_price_iqd,
      p_available,
      caller_id,
      caller_id
    )
    RETURNING * INTO saved_item;
  ELSE
    IF NOT public.has_workspace_access(
      'kitchen_management',
      'edit_manage_products'
    ) THEN
      RAISE EXCEPTION 'Edit & Manage Products permission is required.'
        USING ERRCODE = '42501';
    END IF;

    UPDATE public.cafe_menu_items menu_item
    SET name = trim(p_name),
        category = trim(p_category),
        description = COALESCE(trim(p_description), ''),
        price_iqd = p_price_iqd,
        available = p_available,
        updated_by = caller_id
    WHERE menu_item.id = p_id
    RETURNING menu_item.* INTO saved_item;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Menu item was not found.'
        USING ERRCODE = 'P0002';
    END IF;
  END IF;

  RETURN NEXT saved_item;
END;
$$;

CREATE OR REPLACE FUNCTION public.cafe_table_order_payload(p_order_id uuid)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT jsonb_build_object(
    'id', order_record.id,
    'table_name', dining_table.name,
    'area', dining_table.area,
    'status', order_record.status,
    'total_iqd', order_record.total_iqd,
    'created_at', order_record.created_at,
    'notes', order_record.notes,
    'items', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'name', order_item.item_name,
          'quantity', order_item.quantity,
          'unit_price_iqd', order_item.unit_price_iqd
        )
        ORDER BY order_item.id
      )
      FROM public.cafe_table_order_items order_item
      WHERE order_item.order_id = order_record.id
    ), '[]'::jsonb)
  )
  FROM public.cafe_table_orders order_record
  JOIN public.cafe_dining_tables dining_table
    ON dining_table.id = order_record.table_id
  WHERE order_record.id = p_order_id;
$$;

REVOKE ALL ON FUNCTION public.cafe_table_order_payload(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.submit_cafe_guest_table_order(
  p_qr_token uuid,
  p_request_id uuid,
  p_items jsonb,
  p_notes text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  table_record public.cafe_dining_tables;
  order_record public.cafe_table_orders;
  item_value jsonb;
  normalized_item jsonb;
  normalized_items jsonb := '[]'::jsonb;
  priced_items jsonb := '[]'::jsonb;
  signature_items jsonb;
  request_signature jsonb;
  item_id uuid;
  item_quantity integer;
  menu_item public.cafe_menu_items;
  order_total bigint := 0;
BEGIN
  IF p_request_id IS NULL
    OR p_items IS NULL
    OR jsonb_typeof(p_items) <> 'array'
    OR jsonb_array_length(p_items) NOT BETWEEN 1 AND 20
    OR length(COALESCE(p_notes, '')) > 500 THEN
    RAISE EXCEPTION 'Order details are invalid.'
      USING ERRCODE = '22023';
  END IF;

  SELECT dining_table.*
  INTO table_record
  FROM public.cafe_dining_table_qr_tokens qr
  JOIN public.cafe_dining_tables dining_table
    ON dining_table.id = qr.table_id
  WHERE qr.token = p_qr_token
    AND dining_table.status <> 'cleaning'
  FOR SHARE OF dining_table;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'This table QR code is invalid or inactive.'
      USING ERRCODE = '22023';
  END IF;

  FOR item_value IN SELECT value FROM jsonb_array_elements(p_items)
  LOOP
    IF jsonb_typeof(item_value) <> 'object'
      OR item_value->>'item_id' !~*
        '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      OR item_value->>'quantity' !~ '^[0-9]{1,2}$' THEN
      RAISE EXCEPTION 'Order item details are invalid.'
        USING ERRCODE = '22023';
    END IF;

    item_id := (item_value->>'item_id')::uuid;
    item_quantity := (item_value->>'quantity')::integer;
    IF item_quantity NOT BETWEEN 1 AND 20
      OR EXISTS (
        SELECT 1
        FROM jsonb_array_elements(normalized_items) existing_item
        WHERE existing_item->>'item_id' = item_id::text
      ) THEN
      RAISE EXCEPTION 'Order item details are invalid.'
        USING ERRCODE = '22023';
    END IF;

    normalized_items := normalized_items || jsonb_build_array(
      jsonb_build_object('item_id', item_id, 'quantity', item_quantity)
    );
  END LOOP;

  SELECT jsonb_agg(
    jsonb_build_object('item_id', entry.value->>'item_id', 'quantity', (entry.value->>'quantity')::integer)
    ORDER BY entry.value->>'item_id')
  INTO signature_items
  FROM jsonb_array_elements(normalized_items) AS entry(value);
  request_signature := jsonb_build_object(
    'items', signature_items,
    'notes', COALESCE(trim(p_notes), '')
  );

  PERFORM pg_advisory_xact_lock(
    hashtextextended(p_request_id::text, 0)
  );

  SELECT existing.*
  INTO order_record
  FROM public.cafe_table_orders existing
  WHERE existing.request_id = p_request_id;

  IF FOUND THEN
    IF order_record.table_id = table_record.id
      AND order_record.request_signature = request_signature THEN
      RETURN public.cafe_table_order_payload(order_record.id);
    END IF;
    RAISE EXCEPTION 'Order request identifier was already used.'
      USING ERRCODE = '23505';
  END IF;

  FOR item_value IN SELECT value FROM jsonb_array_elements(normalized_items)
  LOOP
    item_id := (item_value->>'item_id')::uuid;
    item_quantity := (item_value->>'quantity')::integer;
    SELECT menu_record.*
    INTO menu_item
    FROM public.cafe_menu_items menu_record
    WHERE menu_record.id = item_id
      AND menu_record.available
    FOR SHARE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'One or more selected menu items are unavailable.'
        USING ERRCODE = 'P0001';
    END IF;

    normalized_item := jsonb_build_object(
      'item_id', menu_item.id,
      'name', menu_item.name,
      'quantity', item_quantity,
      'unit_price_iqd', menu_item.price_iqd
    );
    priced_items := priced_items || jsonb_build_array(normalized_item);
    order_total := order_total + menu_item.price_iqd * item_quantity;
  END LOOP;

  INSERT INTO public.cafe_table_orders (
    request_id,
    table_id,
    total_iqd,
    notes,
    request_signature,
    created_by
  )
  VALUES (
    p_request_id,
    table_record.id,
    order_total,
    COALESCE(trim(p_notes), ''),
    request_signature,
    auth.uid()
  )
  RETURNING * INTO order_record;

  INSERT INTO public.cafe_table_order_items (
    order_id, menu_item_id, item_name, quantity, unit_price_iqd
  )
  SELECT
    order_record.id,
    (entry.value->>'item_id')::uuid,
    entry.value->>'name',
    (entry.value->>'quantity')::integer,
    (entry.value->>'unit_price_iqd')::bigint
  FROM jsonb_array_elements(priced_items) AS entry(value);

  INSERT INTO public.cafe_table_order_audit (order_id, action)
  VALUES (order_record.id, 'received');

  RETURN public.cafe_table_order_payload(order_record.id);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_cafe_guest_table_order_status(
  p_qr_token uuid,
  p_order_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  result jsonb;
BEGIN
  SELECT public.cafe_table_order_payload(order_record.id)
  INTO result
  FROM public.cafe_table_orders order_record
  JOIN public.cafe_dining_table_qr_tokens qr
    ON qr.table_id = order_record.table_id
  JOIN public.cafe_dining_tables dining_table
    ON dining_table.id = order_record.table_id
  WHERE order_record.id = p_order_id
    AND qr.token = p_qr_token
    AND dining_table.status <> 'cleaning';

  IF result IS NULL THEN
    RAISE EXCEPTION 'Order was not found for this table.'
      USING ERRCODE = 'P0002';
  END IF;
  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_cafe_table_orders()
RETURNS SETOF jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
BEGIN
  IF NOT (
    public.has_workspace_access('tables_orders', 'table_ordering')
    OR public.has_workspace_access('customer_management', 'table_orders')
  ) THEN
    RAISE EXCEPTION 'Table Orders access is required.'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT public.cafe_table_order_payload(order_record.id)
  FROM public.cafe_table_orders order_record
  WHERE order_record.status IN ('received', 'preparing', 'ready')
  ORDER BY order_record.created_at, order_record.id;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_cafe_table_order_status(
  p_order_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  current_status text;
BEGIN
  IF NOT (
    public.has_workspace_access('tables_orders', 'table_ordering')
    OR public.has_workspace_access('customer_management', 'table_orders')
  ) THEN
    RAISE EXCEPTION 'Table Orders access is required.'
      USING ERRCODE = '42501';
  END IF;

  IF p_status NOT IN ('preparing', 'ready', 'served', 'cancelled') THEN
    RAISE EXCEPTION 'Choose a supported order status.'
      USING ERRCODE = '22023';
  END IF;

  SELECT order_record.status
  INTO current_status
  FROM public.cafe_table_orders order_record
  WHERE order_record.id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order was not found.'
      USING ERRCODE = 'P0002';
  END IF;

  IF NOT (
    (current_status = 'received'
      AND p_status IN ('preparing', 'cancelled'))
    OR (current_status = 'preparing'
      AND p_status IN ('ready', 'cancelled'))
    OR (current_status = 'ready' AND p_status = 'served')
  ) THEN
    RAISE EXCEPTION 'That order status transition is not allowed.'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.cafe_table_orders order_record
  SET status = p_status
  WHERE order_record.id = p_order_id;

  INSERT INTO public.cafe_table_order_audit (order_id, action, actor_id)
  VALUES (p_order_id, p_status, auth.uid());
END;
$$;

REVOKE ALL ON FUNCTION public.get_cafe_guest_menu(uuid)
  FROM PUBLIC, authenticated;
REVOKE ALL ON FUNCTION public.list_cafe_menu_items()
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.save_cafe_menu_item(
  uuid, text, text, text, bigint, boolean
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.submit_cafe_guest_table_order(
  uuid, uuid, jsonb, text
) FROM PUBLIC, authenticated;
REVOKE ALL ON FUNCTION public.get_cafe_guest_table_order_status(uuid, uuid)
  FROM PUBLIC, authenticated;
REVOKE ALL ON FUNCTION public.list_cafe_table_orders()
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.update_cafe_table_order_status(uuid, text)
  FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.get_cafe_guest_menu(uuid)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_cafe_menu_items()
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_cafe_menu_item(
  uuid, text, text, text, bigint, boolean
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_cafe_guest_table_order(
  uuid, uuid, jsonb, text
) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_cafe_guest_table_order_status(uuid, uuid)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_cafe_table_orders()
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_cafe_table_order_status(uuid, text)
  TO authenticated;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'cafe_table_orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.cafe_table_orders;
  END IF;
END;
$$;

NOTIFY pgrst, 'reload schema';


CREATE SCHEMA IF NOT EXISTS cafe_private;
REVOKE ALL ON SCHEMA cafe_private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA cafe_private TO authenticated;
ALTER TABLE public.cafe_table_orders ALTER COLUMN table_id DROP NOT NULL;
ALTER TABLE public.cafe_table_orders ADD COLUMN source text NOT NULL DEFAULT 'table'
 CHECK(source IN ('table','motel','online','walk_in'));
ALTER TABLE public.cafe_table_orders ADD COLUMN destination text NOT NULL DEFAULT '' CHECK(length(destination)<=200);
ALTER TABLE public.cafe_table_orders ADD CONSTRAINT cafe_order_destination CHECK(
 (source='table' AND table_id IS NOT NULL) OR (source<>'table' AND table_id IS NULL));
CREATE INDEX cafe_orders_source_created_idx ON public.cafe_table_orders(source,created_at DESC,id);

CREATE FUNCTION cafe_private.order_access(p_source text) RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT auth.uid() IS NOT NULL AND CASE p_source
 WHEN 'table' THEN public.has_workspace_access('tables_orders','table_ordering') OR public.has_workspace_access('customer_management','table_orders')
 WHEN 'motel' THEN public.has_workspace_access('motel_online_orders','new_motel_order') OR public.has_workspace_access('motel_online_orders','motel_orders') OR public.has_workspace_access('customer_management','motel_orders')
 WHEN 'online' THEN public.has_workspace_access('motel_online_orders','new_online_order') OR public.has_workspace_access('motel_online_orders','online_orders') OR public.has_workspace_access('customer_management','online_orders')
 WHEN 'walk_in' THEN public.has_workspace_access('motel_online_orders','new_walk_in_order') OR public.has_workspace_access('motel_online_orders','active_walk_in_orders')
 ELSE false END;
$$;

CREATE OR REPLACE FUNCTION public.cafe_table_order_payload(p_order_id uuid) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT jsonb_build_object('id',o.id,'source',o.source,'destination',o.destination,
 'table_name',coalesce(t.name, nullif(o.destination,''),initcap(replace(o.source,'_',' '))),
 'status',o.status,'total_iqd',o.total_iqd,'created_at',o.created_at,'notes',o.notes,
 'items',coalesce((SELECT jsonb_agg(jsonb_build_object('name',i.item_name,'quantity',i.quantity,'unit_price_iqd',i.unit_price_iqd) ORDER BY i.id)
 FROM public.cafe_table_order_items i WHERE i.order_id=o.id),'[]'::jsonb))
 FROM public.cafe_table_orders o LEFT JOIN public.cafe_dining_tables t ON t.id=o.table_id WHERE o.id=p_order_id;
$$;
REVOKE ALL ON FUNCTION public.cafe_table_order_payload(uuid) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION cafe_private.submit_staff_order(p_request_id uuid,p_source text,p_table_id uuid,p_destination text,p_items jsonb,p_notes text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth AS $$
DECLARE o public.cafe_table_orders; m public.cafe_menu_items; item jsonb; items jsonb:='[]'; signature jsonb; total bigint:=0; qty int; seen uuid[]:='{}';
BEGIN
 IF auth.uid() IS NULL OR NOT (CASE p_source
 WHEN 'table' THEN public.has_workspace_access('tables_orders','table_ordering')
 WHEN 'motel' THEN public.has_workspace_access('motel_online_orders','new_motel_order')
 WHEN 'online' THEN public.has_workspace_access('motel_online_orders','new_online_order')
 WHEN 'walk_in' THEN public.has_workspace_access('motel_online_orders','new_walk_in_order') ELSE false END)
 THEN RAISE EXCEPTION 'Order creation permission and MFA required' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL OR p_items IS NULL OR jsonb_typeof(p_items)<>'array' OR jsonb_array_length(p_items) NOT BETWEEN 1 AND 20 OR length(coalesce(p_notes,''))>500 OR length(coalesce(p_destination,''))>200 THEN RAISE EXCEPTION 'Invalid order details' USING ERRCODE='22023'; END IF;
 IF p_source='table' THEN
  PERFORM 1 FROM public.cafe_dining_tables WHERE id=p_table_id AND status<>'cleaning' FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Select an available table' USING ERRCODE='22023'; END IF;
 ELSIF p_table_id IS NOT NULL OR (p_source IN ('motel','online') AND length(trim(coalesce(p_destination,'')))<1) THEN RAISE EXCEPTION 'Enter a room or delivery reference' USING ERRCODE='22023'; END IF;
 signature:=jsonb_build_object('source',p_source,'table',p_table_id,'destination',trim(coalesce(p_destination,'')),'items',p_items,'notes',trim(coalesce(p_notes,'')));
 PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
 SELECT * INTO o FROM public.cafe_table_orders WHERE request_id=p_request_id;
 IF FOUND THEN
  IF o.created_by=auth.uid() AND o.request_signature=signature THEN RETURN public.cafe_table_order_payload(o.id); END IF;
  RAISE EXCEPTION 'Request already used' USING ERRCODE='23505';
 END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
  IF coalesce(item->>'quantity','') !~ '^[0-9]{1,2}$' THEN RAISE EXCEPTION 'Invalid quantity' USING ERRCODE='22023'; END IF;
  qty:=(item->>'quantity')::int;
  IF qty NOT BETWEEN 1 AND 20 THEN RAISE EXCEPTION 'Invalid quantity' USING ERRCODE='22023'; END IF;
  SELECT * INTO m FROM public.cafe_menu_items WHERE id=(item->>'item_id')::uuid AND available FOR SHARE;
  IF NOT FOUND OR m.id=ANY(seen) THEN RAISE EXCEPTION 'Unavailable or repeated product' USING ERRCODE='22023'; END IF;
  seen:=array_append(seen,m.id);
  items:=items||jsonb_build_array(jsonb_build_object('id',m.id,'name',m.name,'qty',qty,'price',m.price_iqd));
  total:=total+m.price_iqd*qty;
 END LOOP;
 INSERT INTO public.cafe_table_orders(request_id,table_id,source,destination,total_iqd,notes,request_signature,created_by)
 VALUES(p_request_id,p_table_id,p_source,trim(coalesce(p_destination,'')),total,trim(coalesce(p_notes,'')),signature,auth.uid()) RETURNING * INTO o;
 INSERT INTO public.cafe_table_order_items(order_id,menu_item_id,item_name,quantity,unit_price_iqd)
 SELECT o.id,(v->>'id')::uuid,v->>'name',(v->>'qty')::int,(v->>'price')::bigint FROM jsonb_array_elements(items) v;
 INSERT INTO public.cafe_table_order_audit(order_id,action,actor_id) VALUES(o.id,'received',auth.uid());
 RETURN public.cafe_table_order_payload(o.id);
END;$$;

CREATE FUNCTION cafe_private.order_catalog(p_source text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth AS $$
BEGIN
 IF NOT cafe_private.order_access(p_source) THEN RAISE EXCEPTION 'Order access required' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('products',coalesce((SELECT jsonb_agg(to_jsonb(m)-'created_by'-'updated_by' ORDER BY m.category,m.name) FROM public.cafe_menu_items m WHERE available),'[]'::jsonb),
 'tables',CASE WHEN p_source='table' THEN coalesce((SELECT jsonb_agg(jsonb_build_object('id',t.id,'name',t.name) ORDER BY t.name) FROM public.cafe_dining_tables t WHERE status<>'cleaning'),'[]'::jsonb) ELSE '[]'::jsonb END);
END;$$;

CREATE FUNCTION cafe_private.staff_orders(p_source text,p_history boolean) RETURNS SETOF jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth AS $$
BEGIN
 IF NOT cafe_private.order_access(p_source) THEN RAISE EXCEPTION 'Order access required' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT public.cafe_table_order_payload(o.id) FROM public.cafe_table_orders o WHERE o.source=p_source AND (p_history OR o.status IN ('received','preparing','ready')) ORDER BY o.created_at DESC,o.id LIMIT 500;
END;$$;

CREATE FUNCTION cafe_private.transition_order(p_order_id uuid,p_status text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth AS $$
DECLARE o public.cafe_table_orders;
BEGIN
 SELECT * INTO o FROM public.cafe_table_orders WHERE id=p_order_id FOR UPDATE;
 IF NOT FOUND OR NOT cafe_private.order_access(o.source) THEN RAISE EXCEPTION 'Order access required' USING ERRCODE='42501'; END IF;
 IF p_status IS NULL OR NOT ((o.status='received' AND p_status IN ('preparing','cancelled')) OR (o.status='preparing' AND p_status IN ('ready','cancelled')) OR (o.status='ready' AND p_status='served')) THEN RAISE EXCEPTION 'Order changed; refresh before retrying' USING ERRCODE='22023'; END IF;
 UPDATE public.cafe_table_orders SET status=p_status WHERE id=o.id;
 INSERT INTO public.cafe_table_order_audit(order_id,action,actor_id) VALUES(o.id,p_status,auth.uid());
END;$$;

CREATE FUNCTION public.submit_cafe_staff_order(p_request_id uuid,p_source text,p_table_id uuid,p_destination text,p_items jsonb,p_notes text) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.submit_staff_order(p_request_id,p_source,p_table_id,p_destination,p_items,p_notes); $$;
CREATE FUNCTION public.get_cafe_order_catalog(p_source text) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.order_catalog(p_source); $$;
CREATE FUNCTION public.list_cafe_staff_orders(p_source text,p_history boolean DEFAULT false) RETURNS SETOF jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT * FROM cafe_private.staff_orders(p_source,p_history); $$;
CREATE FUNCTION public.transition_cafe_order(p_order_id uuid,p_status text) RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.transition_order(p_order_id,p_status); $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA cafe_private FROM PUBLIC,anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA cafe_private TO authenticated;
REVOKE ALL ON FUNCTION public.submit_cafe_staff_order(uuid,text,uuid,text,jsonb,text),public.get_cafe_order_catalog(text),public.list_cafe_staff_orders(text,boolean),public.transition_cafe_order(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.submit_cafe_staff_order(uuid,text,uuid,text,jsonb,text),public.get_cafe_order_catalog(text),public.list_cafe_staff_orders(text,boolean),public.transition_cafe_order(uuid,text) TO authenticated;
NOTIFY pgrst,'reload schema';

CREATE SCHEMA IF NOT EXISTS cafe_private;
REVOKE ALL ON SCHEMA cafe_private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA cafe_private TO authenticated;

CREATE TABLE public.cafe_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL UNIQUE,
  order_id uuid NOT NULL REFERENCES public.cafe_table_orders(id) ON DELETE RESTRICT,
  kind text NOT NULL CHECK (kind IN ('payment','refund')),
  method text NOT NULL CHECK (method IN ('cash','manual_card')),
  amount_iqd bigint NOT NULL CHECK (amount_iqd > 0 AND amount_iqd <= 19999999980),
  original_payment_id uuid REFERENCES public.cafe_payments(id) ON DELETE RESTRICT,
  reference text NOT NULL DEFAULT '' CHECK(length(reference)<=120),
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((kind='payment' AND original_payment_id IS NULL) OR (kind='refund' AND original_payment_id IS NOT NULL))
);
CREATE INDEX cafe_payments_order_idx ON public.cafe_payments(order_id,created_at);
CREATE INDEX cafe_payments_original_idx ON public.cafe_payments(original_payment_id) WHERE original_payment_id IS NOT NULL;
CREATE INDEX cafe_payments_actor_idx ON public.cafe_payments(created_by);
ALTER TABLE public.cafe_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_payments FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.cafe_payments FROM PUBLIC,anon,authenticated;

CREATE FUNCTION cafe_private.capture_payment(p_request_id uuid,p_order_id uuid,p_amount_iqd bigint,p_method text,p_reference text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth AS $fn$
DECLARE existing public.cafe_payments; target public.cafe_table_orders; paid bigint; payment_id uuid;
BEGIN
 IF auth.uid() IS NULL OR NOT public.has_workspace_access('payment_management','receive_payment') THEN RAISE EXCEPTION 'Receive Payment permission and MFA required' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL OR p_order_id IS NULL OR p_amount_iqd IS NULL OR p_amount_iqd<=0 OR p_method IS NULL OR p_method NOT IN ('cash','manual_card') OR length(coalesce(p_reference,''))>120 THEN RAISE EXCEPTION 'Invalid payment details' USING ERRCODE='22023'; END IF;
 IF p_method='manual_card' AND length(trim(coalesce(p_reference,'')))<3 THEN RAISE EXCEPTION 'Enter the external terminal reference' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,1));
 SELECT * INTO existing FROM public.cafe_payments WHERE request_id=p_request_id;
 IF FOUND THEN
  IF existing.kind='payment' AND existing.order_id=p_order_id AND existing.amount_iqd=p_amount_iqd AND existing.method=p_method AND existing.reference=trim(coalesce(p_reference,'')) AND existing.created_by=auth.uid() THEN RETURN existing.id; END IF;
  RAISE EXCEPTION 'Request identifier already used' USING ERRCODE='23505';
 END IF;
 SELECT * INTO target FROM public.cafe_table_orders WHERE id=p_order_id FOR UPDATE;
 IF NOT FOUND OR target.status='cancelled' THEN RAISE EXCEPTION 'Order unavailable' USING ERRCODE='22023'; END IF;
 SELECT coalesce(sum(CASE WHEN kind='payment' THEN amount_iqd ELSE -amount_iqd END),0) INTO paid FROM public.cafe_payments WHERE order_id=p_order_id;
 IF p_amount_iqd>target.total_iqd-paid THEN RAISE EXCEPTION 'Amount exceeds outstanding balance' USING ERRCODE='22023'; END IF;
 INSERT INTO public.cafe_payments(request_id,order_id,kind,method,amount_iqd,reference,created_by)
 VALUES(p_request_id,p_order_id,'payment',p_method,p_amount_iqd,trim(coalesce(p_reference,'')),auth.uid()) RETURNING id INTO payment_id;
 RETURN payment_id;
END;$fn$;

CREATE FUNCTION cafe_private.refund_payment(p_request_id uuid,p_payment_id uuid,p_amount_iqd bigint,p_reason text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth AS $fn$
DECLARE original public.cafe_payments; existing public.cafe_payments; refunded bigint; refund_id uuid;
BEGIN
 IF auth.uid() IS NULL OR NOT public.has_workspace_access('payment_management','refunds_voids') THEN RAISE EXCEPTION 'Refunds and Voids permission and MFA required' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL OR p_payment_id IS NULL OR p_amount_iqd IS NULL OR p_amount_iqd<=0 OR length(trim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 120 THEN RAISE EXCEPTION 'Invalid refund details or reason' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,1));
 SELECT * INTO existing FROM public.cafe_payments WHERE request_id=p_request_id;
 IF FOUND THEN
  IF existing.kind='refund' AND existing.original_payment_id=p_payment_id AND existing.amount_iqd=p_amount_iqd AND existing.reference=trim(p_reason) AND existing.created_by=auth.uid() THEN RETURN existing.id; END IF;
  RAISE EXCEPTION 'Request identifier already used' USING ERRCODE='23505';
 END IF;
 SELECT * INTO original FROM public.cafe_payments WHERE id=p_payment_id AND kind='payment';
 IF NOT FOUND THEN RAISE EXCEPTION 'Original payment missing' USING ERRCODE='22023'; END IF;
 PERFORM 1 FROM public.cafe_table_orders WHERE id=original.order_id FOR UPDATE;
 SELECT coalesce(sum(amount_iqd),0) INTO refunded FROM public.cafe_payments WHERE original_payment_id=p_payment_id;
 IF p_amount_iqd>original.amount_iqd-refunded THEN RAISE EXCEPTION 'Refund exceeds original payment remainder' USING ERRCODE='22023'; END IF;
 INSERT INTO public.cafe_payments(request_id,order_id,kind,method,amount_iqd,original_payment_id,reference,created_by)
 VALUES(p_request_id,original.order_id,'refund',original.method,p_amount_iqd,p_payment_id,trim(p_reason),auth.uid()) RETURNING id INTO refund_id;
 RETURN refund_id;
END;$fn$;

CREATE FUNCTION cafe_private.payment_balances()
RETURNS SETOF jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth AS $fn$
BEGIN
 IF auth.uid() IS NULL OR NOT (public.has_workspace_access('payment_management','receive_payment') OR public.has_workspace_access('payment_management','payment_history') OR public.has_workspace_access('payment_management','refunds_voids')) THEN RAISE EXCEPTION 'Payment access and MFA required' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT jsonb_build_object('id',o.id,'table_name',coalesce(t.name,nullif(o.destination,''),o.source),'source',o.source,'created_at',o.created_at,'total_iqd',o.total_iqd,'status',o.status,
   'paid_iqd',coalesce((SELECT sum(CASE WHEN p.kind='payment' THEN p.amount_iqd ELSE -p.amount_iqd END) FROM public.cafe_payments p WHERE p.order_id=o.id),0),
   'payments',coalesce((SELECT jsonb_agg(to_jsonb(p)-'created_by'-'request_id' ORDER BY p.created_at,p.id) FROM public.cafe_payments p WHERE p.order_id=o.id),'[]'::jsonb))
 FROM public.cafe_table_orders o LEFT JOIN public.cafe_dining_tables t ON t.id=o.table_id ORDER BY o.created_at DESC,o.id;
END;$fn$;

CREATE FUNCTION cafe_private.guard_paid_order_cancel() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fn$
BEGIN
 IF NEW.status='cancelled' AND OLD.status<>'cancelled' AND (SELECT coalesce(sum(CASE WHEN kind='payment' THEN amount_iqd ELSE -amount_iqd END),0) FROM public.cafe_payments WHERE order_id=NEW.id)>0 THEN RAISE EXCEPTION 'Refund recorded payments before cancelling this order' USING ERRCODE='22023'; END IF;
 RETURN NEW;
END;$fn$;
CREATE TRIGGER cafe_paid_order_cancel_guard BEFORE UPDATE OF status ON public.cafe_table_orders FOR EACH ROW EXECUTE FUNCTION cafe_private.guard_paid_order_cancel();

REVOKE ALL ON FUNCTION cafe_private.capture_payment(uuid,uuid,bigint,text,text),cafe_private.refund_payment(uuid,uuid,bigint,text),cafe_private.payment_balances(),cafe_private.guard_paid_order_cancel() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION cafe_private.capture_payment(uuid,uuid,bigint,text,text),cafe_private.refund_payment(uuid,uuid,bigint,text),cafe_private.payment_balances() TO authenticated;
CREATE FUNCTION public.capture_cafe_payment(p_request_id uuid,p_order_id uuid,p_amount_iqd bigint,p_method text,p_reference text DEFAULT '') RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $fn$ SELECT cafe_private.capture_payment(p_request_id,p_order_id,p_amount_iqd,p_method,p_reference); $fn$;
CREATE FUNCTION public.refund_cafe_payment(p_request_id uuid,p_payment_id uuid,p_amount_iqd bigint,p_reason text) RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $fn$ SELECT cafe_private.refund_payment(p_request_id,p_payment_id,p_amount_iqd,p_reason); $fn$;
CREATE FUNCTION public.list_cafe_payment_balances() RETURNS SETOF jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $fn$ SELECT * FROM cafe_private.payment_balances(); $fn$;
REVOKE ALL ON FUNCTION public.capture_cafe_payment(uuid,uuid,bigint,text,text),public.refund_cafe_payment(uuid,uuid,bigint,text),public.list_cafe_payment_balances() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.capture_cafe_payment(uuid,uuid,bigint,text,text),public.refund_cafe_payment(uuid,uuid,bigint,text),public.list_cafe_payment_balances() TO authenticated;
NOTIFY pgrst,'reload schema';

-- The compatibility table-only endpoints must never expose other order sources.
CREATE OR REPLACE FUNCTION public.list_cafe_table_orders() RETURNS SETOF jsonb
LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT * FROM cafe_private.staff_orders('table',false); $$;
CREATE OR REPLACE FUNCTION public.update_cafe_table_order_status(p_order_id uuid,p_status text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.cafe_table_orders WHERE id=p_order_id AND source='table') THEN RAISE EXCEPTION 'Table order unavailable' USING ERRCODE='42501'; END IF;
 PERFORM cafe_private.transition_order(p_order_id,p_status);
END;$$;

CREATE OR REPLACE FUNCTION public.list_cafe_menu_items()
RETURNS TABLE(id uuid,name text,category text,description text,price_iqd bigint,available boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM unnest(ARRAY['add_new_product','edit_manage_products','menu_overview','product_availability','product_categories','normal_pricing']) c WHERE public.has_workspace_access('kitchen_management',c)) THEN RAISE EXCEPTION 'Menu access and MFA required' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT m.id,m.name,m.category,m.description,m.price_iqd,m.available FROM public.cafe_menu_items m ORDER BY lower(m.category),m.name,m.id;
END;$$;

-- Keep privileged implementations outside the exposed public API. Public
-- wrappers run as the caller and retain the exact intended execute grants.
DO $move$
DECLARE f record; args text; identities text; result_type text; invocation text; guest boolean;
BEGIN
 FOR f IN SELECT p.* FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname IN ('get_cafe_guest_menu','list_cafe_menu_items','save_cafe_menu_item','submit_cafe_guest_table_order','get_cafe_guest_table_order_status','update_cafe_table_order_status')
 LOOP
  args:=pg_get_function_arguments(f.oid); identities:=pg_get_function_identity_arguments(f.oid); result_type:=pg_get_function_result(f.oid);
  SELECT string_agg(format('%I',f.proargnames[i]),',') INTO invocation FROM generate_series(1,f.pronargs) i;
  EXECUTE format('ALTER FUNCTION public.%I(%s) SET SCHEMA cafe_private',f.proname,identities);
  EXECUTE format('REVOKE ALL ON FUNCTION cafe_private.%I(%s) FROM PUBLIC,anon,authenticated',f.proname,identities);
  EXECUTE format('CREATE FUNCTION public.%I(%s) RETURNS %s LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS %L',f.proname,args,result_type,format('SELECT * FROM cafe_private.%I(%s)',f.proname,coalesce(invocation,'')));
  EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM PUBLIC,anon,authenticated',f.proname,identities);
  EXECUTE format('GRANT EXECUTE ON FUNCTION public.%I(%s),cafe_private.%I(%s) TO authenticated',f.proname,identities,f.proname,identities);
  guest:=f.proname IN ('get_cafe_guest_menu','submit_cafe_guest_table_order','get_cafe_guest_table_order_status');
  IF guest THEN EXECUTE format('GRANT EXECUTE ON FUNCTION public.%I(%s),cafe_private.%I(%s) TO anon',f.proname,identities,f.proname,identities); END IF;
 END LOOP;
END;$move$;
GRANT USAGE ON SCHEMA cafe_private TO anon;
-- RPC-only tables: no direct table access, even if a future grant is added.
CREATE POLICY cafe_menu_rpc_only ON public.cafe_menu_items AS RESTRICTIVE FOR ALL TO anon,authenticated USING(false) WITH CHECK(false);
CREATE POLICY cafe_orders_rpc_only ON public.cafe_table_orders AS RESTRICTIVE FOR ALL TO anon,authenticated USING(false) WITH CHECK(false);
CREATE POLICY cafe_items_rpc_only ON public.cafe_table_order_items AS RESTRICTIVE FOR ALL TO anon,authenticated USING(false) WITH CHECK(false);
CREATE POLICY cafe_order_audit_rpc_only ON public.cafe_table_order_audit AS RESTRICTIVE FOR ALL TO anon,authenticated USING(false) WITH CHECK(false);
CREATE POLICY cafe_payments_rpc_only ON public.cafe_payments AS RESTRICTIVE FOR ALL TO anon,authenticated USING(false) WITH CHECK(false);
CREATE INDEX cafe_menu_created_by_idx ON public.cafe_menu_items(created_by);
CREATE INDEX cafe_menu_updated_by_idx ON public.cafe_menu_items(updated_by);
CREATE INDEX cafe_order_created_by_idx ON public.cafe_table_orders(created_by);
CREATE INDEX cafe_order_item_product_idx ON public.cafe_table_order_items(menu_item_id);
CREATE INDEX cafe_order_audit_actor_idx ON public.cafe_table_order_audit(actor_id);
CREATE INDEX cafe_order_audit_order_idx ON public.cafe_table_order_audit(order_id);
NOTIFY pgrst,'reload schema';

CREATE OR REPLACE FUNCTION cafe_private.order_access(p_source text) RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT auth.uid() IS NOT NULL AND (
 public.has_workspace_access('customer_management','live_kitchen_orders')
 OR public.has_workspace_access('customer_management','status_of_all_orders')
 OR public.has_workspace_access('customer_management','kitchen_display')
 OR CASE p_source
 WHEN 'table' THEN public.has_workspace_access('tables_orders','table_ordering') OR public.has_workspace_access('customer_management','table_orders')
 WHEN 'motel' THEN public.has_workspace_access('motel_online_orders','new_motel_order') OR public.has_workspace_access('motel_online_orders','motel_orders') OR public.has_workspace_access('customer_management','motel_orders')
 WHEN 'online' THEN public.has_workspace_access('motel_online_orders','new_online_order') OR public.has_workspace_access('motel_online_orders','online_orders') OR public.has_workspace_access('customer_management','online_orders')
 WHEN 'walk_in' THEN public.has_workspace_access('motel_online_orders','new_walk_in_order') OR public.has_workspace_access('motel_online_orders','active_walk_in_orders')
 ELSE false END);
$$;
CREATE OR REPLACE FUNCTION cafe_private.staff_orders(p_source text,p_history boolean) RETURNS SETOF jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth AS $$
BEGIN
 IF NOT cafe_private.order_access(p_source) THEN RAISE EXCEPTION 'Order access required' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT public.cafe_table_order_payload(o.id) FROM public.cafe_table_orders o WHERE (p_source='all' OR o.source=p_source) AND (p_history OR o.status IN ('received','preparing','ready')) ORDER BY o.created_at DESC,o.id LIMIT 500;
END;$$;
NOTIFY pgrst,'reload schema';

COMMIT;
