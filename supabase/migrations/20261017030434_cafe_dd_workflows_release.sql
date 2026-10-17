BEGIN;
LOCK TABLE public.cafe_table_orders,public.cafe_payments,public.cafe_dining_tables IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.cafe_table_orders) OR EXISTS(SELECT 1 FROM public.cafe_payments) OR EXISTS(SELECT 1 FROM public.cafe_dining_tables WHERE status='occupied') THEN RAISE EXCEPTION 'Live business activity changed; reconcile visits before release'; END IF; END $$;

-- Source: 20261017014316_cafe_product_price_modes.sql

ALTER TABLE public.cafe_menu_items ADD COLUMN tourism_price_iqd bigint CHECK(tourism_price_iqd BETWEEN 1 AND 999999999);
ALTER TABLE public.cafe_menu_items ADD COLUMN owner_price_iqd bigint CHECK(owner_price_iqd BETWEEN 1 AND 999999999);
-- NULL on old-client inserts means use the existing normal price.
UPDATE public.cafe_menu_items SET tourism_price_iqd=price_iqd,owner_price_iqd=price_iqd;
ALTER TABLE public.cafe_table_orders ADD COLUMN pricing_mode text NOT NULL DEFAULT 'normal' CHECK(pricing_mode IN ('normal','tourism','owner'));

CREATE FUNCTION cafe_private.list_menu_priced() RETURNS SETOF jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM unnest(ARRAY['add_new_product','edit_manage_products','menu_overview','product_availability','product_categories','normal_pricing','tourism_pricing','owner_pricing']) c WHERE public.has_workspace_access('kitchen_management',c)) THEN RAISE EXCEPTION 'Menu access and MFA required' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT jsonb_build_object('id',m.id,'name',m.name,'category',m.category,'description',m.description,'price_iqd',m.price_iqd,'tourism_price_iqd',coalesce(m.tourism_price_iqd,m.price_iqd),'owner_price_iqd',coalesce(m.owner_price_iqd,m.price_iqd),'available',m.available) FROM public.cafe_menu_items m ORDER BY lower(m.category),m.name,m.id;
END;$$;
CREATE FUNCTION cafe_private.save_menu_priced(p_id uuid,p_name text,p_category text,p_description text,p_price_iqd bigint,p_available boolean,p_tourism_price_iqd bigint,p_owner_price_iqd bigint)
RETURNS SETOF public.cafe_menu_items LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE saved public.cafe_menu_items;
BEGIN
 IF auth.uid() IS NULL OR auth.jwt()->>'aal' IS DISTINCT FROM 'aal2' THEN RAISE EXCEPTION 'Verified staff required' USING ERRCODE='42501'; END IF;
 IF p_tourism_price_iqd IS NULL OR p_tourism_price_iqd NOT BETWEEN 1 AND 999999999 OR p_owner_price_iqd IS NULL OR p_owner_price_iqd NOT BETWEEN 1 AND 999999999 THEN RAISE EXCEPTION 'Enter all three whole IQD prices from 1 to 999999999' USING ERRCODE='22023'; END IF;
 SELECT * INTO saved FROM cafe_private.save_cafe_menu_item(p_id,p_name,p_category,p_description,p_price_iqd,p_available);
 UPDATE public.cafe_menu_items SET tourism_price_iqd=p_tourism_price_iqd,owner_price_iqd=p_owner_price_iqd WHERE id=saved.id RETURNING * INTO saved;
 RETURN NEXT saved;
END;$$;
CREATE FUNCTION cafe_private.submit_staff_order_priced(p_request_id uuid,p_source text,p_table_id uuid,p_destination text,p_items jsonb,p_notes text,p_pricing_mode text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth AS $$
DECLARE o public.cafe_table_orders; m public.cafe_menu_items; item jsonb; items jsonb:='[]'; signature jsonb; total bigint:=0; qty int; seen uuid[]:='{}'; unit_price bigint;
BEGIN
 IF auth.uid() IS NULL OR NOT (CASE p_source
 WHEN 'table' THEN public.has_workspace_access('tables_orders','table_ordering')
 WHEN 'motel' THEN public.has_workspace_access('motel_online_orders','new_motel_order')
 WHEN 'online' THEN public.has_workspace_access('motel_online_orders','new_online_order')
 WHEN 'walk_in' THEN public.has_workspace_access('motel_online_orders','new_walk_in_order') ELSE false END)
 THEN RAISE EXCEPTION 'Order creation permission and MFA required' USING ERRCODE='42501'; END IF;
 IF p_pricing_mode IS NULL OR p_pricing_mode NOT IN ('normal','tourism','owner') THEN RAISE EXCEPTION 'Invalid pricing mode' USING ERRCODE='22023'; END IF;
 IF p_pricing_mode<>'normal' AND NOT public.has_workspace_access('kitchen_management',p_pricing_mode||'_pricing') THEN RAISE EXCEPTION 'Pricing mode permission required' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL OR p_items IS NULL OR jsonb_typeof(p_items)<>'array' OR jsonb_array_length(p_items) NOT BETWEEN 1 AND 20 OR length(coalesce(p_notes,''))>500 OR length(coalesce(p_destination,''))>200 THEN RAISE EXCEPTION 'Invalid order details' USING ERRCODE='22023'; END IF;
 IF p_source='table' THEN
  PERFORM 1 FROM public.cafe_dining_tables WHERE id=p_table_id AND status<>'cleaning' FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Select an available table' USING ERRCODE='22023'; END IF;
 ELSIF p_table_id IS NOT NULL OR (p_source IN ('motel','online') AND length(trim(coalesce(p_destination,'')))<1) THEN RAISE EXCEPTION 'Enter a room or delivery reference' USING ERRCODE='22023'; END IF;
 signature:=jsonb_build_object('pricing_mode',p_pricing_mode,'source',p_source,'table',p_table_id,'destination',trim(coalesce(p_destination,'')),'items',p_items,'notes',trim(coalesce(p_notes,'')));
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
  unit_price:=CASE p_pricing_mode WHEN 'tourism' THEN coalesce(m.tourism_price_iqd,m.price_iqd) WHEN 'owner' THEN coalesce(m.owner_price_iqd,m.price_iqd) ELSE m.price_iqd END;
  seen:=array_append(seen,m.id);
  items:=items||jsonb_build_array(jsonb_build_object('id',m.id,'name',m.name,'qty',qty,'price',unit_price));
  total:=total+unit_price*qty;
 END LOOP;
 INSERT INTO public.cafe_table_orders(request_id,table_id,source,destination,total_iqd,notes,request_signature,created_by,pricing_mode)
 VALUES(p_request_id,p_table_id,p_source,trim(coalesce(p_destination,'')),total,trim(coalesce(p_notes,'')),signature,auth.uid(),p_pricing_mode) RETURNING * INTO o;
 INSERT INTO public.cafe_table_order_items(order_id,menu_item_id,item_name,quantity,unit_price_iqd)
 SELECT o.id,(v->>'id')::uuid,v->>'name',(v->>'qty')::int,(v->>'price')::bigint FROM jsonb_array_elements(items) v;
 INSERT INTO public.cafe_table_order_audit(order_id,action,actor_id) VALUES(o.id,'received',auth.uid());
 RETURN public.cafe_table_order_payload(o.id);
END;$$;


CREATE FUNCTION cafe_private.order_catalog_priced(p_source text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE result jsonb; modes jsonb:='["normal"]';
BEGIN
 result:=cafe_private.order_catalog(p_source);
 IF public.has_workspace_access('kitchen_management','tourism_pricing') THEN modes:=modes||'["tourism"]'::jsonb; END IF;
 IF public.has_workspace_access('kitchen_management','owner_pricing') THEN modes:=modes||'["owner"]'::jsonb; END IF;
 RETURN result||jsonb_build_object('pricing_modes',modes);
END;$$;
CREATE FUNCTION public.list_cafe_menu_prices() RETURNS SETOF jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT * FROM cafe_private.list_menu_priced() $$;
CREATE FUNCTION public.save_cafe_menu_prices(p_id uuid,p_name text,p_category text,p_description text,p_price_iqd bigint,p_available boolean,p_tourism_price_iqd bigint,p_owner_price_iqd bigint)
RETURNS SETOF public.cafe_menu_items LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT * FROM cafe_private.save_menu_priced(p_id,p_name,p_category,p_description,p_price_iqd,p_available,p_tourism_price_iqd,p_owner_price_iqd) $$;
CREATE FUNCTION public.submit_cafe_priced_order(p_request_id uuid,p_source text,p_table_id uuid,p_destination text,p_items jsonb,p_notes text,p_pricing_mode text)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.submit_staff_order_priced(p_request_id,p_source,p_table_id,p_destination,p_items,p_notes,p_pricing_mode) $$;
CREATE FUNCTION public.get_cafe_priced_order_catalog(p_source text) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.order_catalog_priced(p_source) $$;
REVOKE ALL ON FUNCTION cafe_private.list_menu_priced() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION cafe_private.list_menu_priced() TO authenticated;
REVOKE ALL ON FUNCTION cafe_private.save_menu_priced(uuid,text,text,text,bigint,boolean,bigint,bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION cafe_private.save_menu_priced(uuid,text,text,text,bigint,boolean,bigint,bigint) TO authenticated;
REVOKE ALL ON FUNCTION cafe_private.submit_staff_order_priced(uuid,text,uuid,text,jsonb,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION cafe_private.submit_staff_order_priced(uuid,text,uuid,text,jsonb,text,text) TO authenticated;
REVOKE ALL ON FUNCTION cafe_private.order_catalog_priced(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION cafe_private.order_catalog_priced(text) TO authenticated;
REVOKE ALL ON FUNCTION public.list_cafe_menu_prices() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.list_cafe_menu_prices() TO authenticated;
REVOKE ALL ON FUNCTION public.save_cafe_menu_prices(uuid,text,text,text,bigint,boolean,bigint,bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.save_cafe_menu_prices(uuid,text,text,text,bigint,boolean,bigint,bigint) TO authenticated;
REVOKE ALL ON FUNCTION public.submit_cafe_priced_order(uuid,text,uuid,text,jsonb,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.submit_cafe_priced_order(uuid,text,uuid,text,jsonb,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.get_cafe_priced_order_catalog(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_cafe_priced_order_catalog(text) TO authenticated;
CREATE OR REPLACE FUNCTION public.cafe_table_order_payload(p_order_id uuid) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT jsonb_build_object('id',o.id,'source',o.source,'destination',o.destination,
 'table_name',coalesce(t.name, nullif(o.destination,''),initcap(replace(o.source,'_',' '))),
 'status',o.status,'pricing_mode',o.pricing_mode,'total_iqd',o.total_iqd,'created_at',o.created_at,'notes',o.notes,
 'items',coalesce((SELECT jsonb_agg(jsonb_build_object('name',i.item_name,'quantity',i.quantity,'unit_price_iqd',i.unit_price_iqd) ORDER BY i.id)
 FROM public.cafe_table_order_items i WHERE i.order_id=o.id),'[]'::jsonb))
 FROM public.cafe_table_orders o LEFT JOIN public.cafe_dining_tables t ON t.id=o.table_id WHERE o.id=p_order_id;
$$;
REVOKE ALL ON FUNCTION public.cafe_table_order_payload(uuid) FROM PUBLIC,anon,authenticated;


NOTIFY pgrst,'reload schema';


-- Source: 20261017014655_cafe_table_driven_prices.sql

ALTER TABLE public.cafe_dining_tables DROP CONSTRAINT cafe_dining_tables_pricing_mode_check;
ALTER TABLE public.cafe_dining_tables ADD CONSTRAINT cafe_dining_tables_pricing_mode_check CHECK(pricing_mode IN ('normal','tourism','owner'));
CREATE OR REPLACE FUNCTION public.create_cafe_dining_table(table_name text, table_area text, table_seats integer, table_position_x numeric, table_position_y numeric, table_pricing_mode text)
 RETURNS TABLE(id uuid, name text, area text, seats integer, status text, position_x numeric, position_y numeric, pricing_mode text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
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
    AND (
      caller_role IS DISTINCT FROM 'staff'
      OR NOT EXISTS (
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

  IF table_pricing_mode IS NULL OR table_pricing_mode NOT IN ('normal','tourism','owner') THEN
    RAISE EXCEPTION 'Select Normal, Tourism or Owner pricing mode.'
      USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  INSERT INTO public.cafe_dining_tables AS dining_table (
    name,
    area,
    seats,
    position_x,
    position_y,
    pricing_mode,
    created_by,
    updated_by
  )
  VALUES (
    table_name,
    COALESCE(NULLIF(trim(table_area), ''), 'Main'),
    table_seats,
    table_position_x,
    table_position_y,
    table_pricing_mode,
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
    dining_table.position_y,
    dining_table.pricing_mode;
END;
$function$
;
CREATE OR REPLACE FUNCTION cafe_private.get_cafe_guest_menu(p_qr_token uuid)
 RETURNS TABLE(id uuid, name text, category text, description text, price_iqd bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE active_mode text;
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

  SELECT t.pricing_mode INTO active_mode FROM public.cafe_dining_tables t JOIN public.cafe_dining_table_qr_tokens q ON q.table_id=t.id WHERE q.token=p_qr_token;
  RETURN QUERY
  SELECT menu_item.id,
         menu_item.name,
         menu_item.category,
         menu_item.description,
         CASE active_mode WHEN 'tourism' THEN coalesce(menu_item.tourism_price_iqd,menu_item.price_iqd) WHEN 'owner' THEN coalesce(menu_item.owner_price_iqd,menu_item.price_iqd) ELSE menu_item.price_iqd END
  FROM public.cafe_menu_items menu_item
  WHERE menu_item.available
  ORDER BY lower(menu_item.category), menu_item.name, menu_item.id;
END;
$function$
;
CREATE OR REPLACE FUNCTION cafe_private.submit_cafe_guest_table_order(p_qr_token uuid, p_request_id uuid, p_items jsonb, p_notes text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
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
  unit_price bigint;
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

    unit_price:=CASE table_record.pricing_mode WHEN 'tourism' THEN coalesce(menu_item.tourism_price_iqd,menu_item.price_iqd) WHEN 'owner' THEN coalesce(menu_item.owner_price_iqd,menu_item.price_iqd) ELSE menu_item.price_iqd END;
    normalized_item := jsonb_build_object(
      'item_id', menu_item.id,
      'name', menu_item.name,
      'quantity', item_quantity,
      'unit_price_iqd', unit_price
    );
    priced_items := priced_items || jsonb_build_array(normalized_item);
    order_total := order_total + unit_price * item_quantity;
  END LOOP;

  INSERT INTO public.cafe_table_orders (
    request_id,
    table_id,
    total_iqd,
    notes,
    request_signature,
    created_by, pricing_mode
  )
  VALUES (
    p_request_id,
    table_record.id,
    order_total,
    COALESCE(trim(p_notes), ''),
    request_signature,
    auth.uid(), table_record.pricing_mode
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
$function$
;
CREATE OR REPLACE FUNCTION public.get_cafe_guest_table_context(p_qr_token uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'table', jsonb_build_object(
      'id', dining_table.id,
      'name', dining_table.name,
      'area', dining_table.area,
      'pricing_mode', dining_table.pricing_mode
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
$function$
;
CREATE OR REPLACE FUNCTION cafe_private.submit_staff_order_priced(p_request_id uuid,p_source text,p_table_id uuid,p_destination text,p_items jsonb,p_notes text,p_pricing_mode text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth AS $$
DECLARE o public.cafe_table_orders; m public.cafe_menu_items; item jsonb; items jsonb:='[]'; signature jsonb; total bigint:=0; qty int; seen uuid[]:='{}'; unit_price bigint; table_mode text;
BEGIN
 IF auth.uid() IS NULL OR NOT (CASE p_source
 WHEN 'table' THEN public.has_workspace_access('tables_orders','table_ordering')
 WHEN 'motel' THEN public.has_workspace_access('motel_online_orders','new_motel_order')
 WHEN 'online' THEN public.has_workspace_access('motel_online_orders','new_online_order')
 WHEN 'walk_in' THEN public.has_workspace_access('motel_online_orders','new_walk_in_order') ELSE false END)
 THEN RAISE EXCEPTION 'Order creation permission and MFA required' USING ERRCODE='42501'; END IF;
 IF p_pricing_mode IS NULL OR p_pricing_mode NOT IN ('normal','tourism','owner') THEN RAISE EXCEPTION 'Invalid pricing mode' USING ERRCODE='22023'; END IF;
 IF p_source<>'table' AND p_pricing_mode<>'normal' AND NOT public.has_workspace_access('kitchen_management',p_pricing_mode||'_pricing') THEN RAISE EXCEPTION 'Pricing mode permission required' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL OR p_items IS NULL OR jsonb_typeof(p_items)<>'array' OR jsonb_array_length(p_items) NOT BETWEEN 1 AND 20 OR length(coalesce(p_notes,''))>500 OR length(coalesce(p_destination,''))>200 THEN RAISE EXCEPTION 'Invalid order details' USING ERRCODE='22023'; END IF;
 IF p_source='table' THEN
  SELECT pricing_mode INTO table_mode FROM public.cafe_dining_tables WHERE id=p_table_id AND status<>'cleaning' FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Select an available table' USING ERRCODE='22023'; END IF;
 ELSIF p_table_id IS NOT NULL OR (p_source IN ('motel','online') AND length(trim(coalesce(p_destination,'')))<1) THEN RAISE EXCEPTION 'Enter a room or delivery reference' USING ERRCODE='22023'; END IF;
 signature:=jsonb_build_object('pricing_mode',p_pricing_mode,'source',p_source,'table',p_table_id,'destination',trim(coalesce(p_destination,'')),'items',p_items,'notes',trim(coalesce(p_notes,'')));
 PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
 SELECT * INTO o FROM public.cafe_table_orders WHERE request_id=p_request_id;
 IF FOUND THEN
  IF o.created_by=auth.uid() AND o.request_signature=signature THEN RETURN public.cafe_table_order_payload(o.id); END IF;
  RAISE EXCEPTION 'Request already used' USING ERRCODE='23505';
 END IF;
 IF p_source='table' AND p_pricing_mode IS DISTINCT FROM table_mode THEN RAISE EXCEPTION 'Table price mode changed; refresh the menu before ordering' USING ERRCODE='22023'; END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
  IF coalesce(item->>'quantity','') !~ '^[0-9]{1,2}$' THEN RAISE EXCEPTION 'Invalid quantity' USING ERRCODE='22023'; END IF;
  qty:=(item->>'quantity')::int;
  IF qty NOT BETWEEN 1 AND 20 THEN RAISE EXCEPTION 'Invalid quantity' USING ERRCODE='22023'; END IF;
  SELECT * INTO m FROM public.cafe_menu_items WHERE id=(item->>'item_id')::uuid AND available FOR SHARE;
  IF NOT FOUND OR m.id=ANY(seen) THEN RAISE EXCEPTION 'Unavailable or repeated product' USING ERRCODE='22023'; END IF;
  unit_price:=CASE p_pricing_mode WHEN 'tourism' THEN coalesce(m.tourism_price_iqd,m.price_iqd) WHEN 'owner' THEN coalesce(m.owner_price_iqd,m.price_iqd) ELSE m.price_iqd END;
  seen:=array_append(seen,m.id);
  items:=items||jsonb_build_array(jsonb_build_object('id',m.id,'name',m.name,'qty',qty,'price',unit_price));
  total:=total+unit_price*qty;
 END LOOP;
 INSERT INTO public.cafe_table_orders(request_id,table_id,source,destination,total_iqd,notes,request_signature,created_by,pricing_mode)
 VALUES(p_request_id,p_table_id,p_source,trim(coalesce(p_destination,'')),total,trim(coalesce(p_notes,'')),signature,auth.uid(),p_pricing_mode) RETURNING * INTO o;
 INSERT INTO public.cafe_table_order_items(order_id,menu_item_id,item_name,quantity,unit_price_iqd)
 SELECT o.id,(v->>'id')::uuid,v->>'name',(v->>'qty')::int,(v->>'price')::bigint FROM jsonb_array_elements(items) v;
 INSERT INTO public.cafe_table_order_audit(order_id,action,actor_id) VALUES(o.id,'received',auth.uid());
 RETURN public.cafe_table_order_payload(o.id);
END;$$;



CREATE OR REPLACE FUNCTION cafe_private.order_catalog(p_source text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth AS $$
BEGIN
 IF NOT cafe_private.order_access(p_source) THEN RAISE EXCEPTION 'Order access required' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('products',coalesce((SELECT jsonb_agg(to_jsonb(m)-'created_by'-'updated_by' ORDER BY m.category,m.name) FROM public.cafe_menu_items m WHERE available),'[]'::jsonb),
 'tables',CASE WHEN p_source='table' THEN coalesce((SELECT jsonb_agg(jsonb_build_object('id',t.id,'name',t.name,'pricing_mode',t.pricing_mode) ORDER BY t.name) FROM public.cafe_dining_tables t WHERE status<>'cleaning'),'[]'::jsonb) ELSE '[]'::jsonb END);
END;$$;

NOTIFY pgrst,'reload schema';


-- Source: 20261017014914_cafe_qr_guest_service.sql

CREATE TABLE public.cafe_table_visits(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), table_id uuid NOT NULL REFERENCES public.cafe_dining_tables,
 guest_count int NOT NULL CHECK(guest_count BETWEEN 1 AND 100), customer_name text NOT NULL DEFAULT '' CHECK(length(customer_name)<=120),
 contact text NOT NULL DEFAULT '' CHECK(length(contact)<=80), waiter_id uuid REFERENCES auth.users,
 started_at timestamptz NOT NULL DEFAULT now(), closed_at timestamptz, created_by uuid NOT NULL REFERENCES auth.users);
CREATE UNIQUE INDEX cafe_table_one_active_visit ON public.cafe_table_visits(table_id) WHERE closed_at IS NULL;
CREATE INDEX cafe_visits_waiter_idx ON public.cafe_table_visits(waiter_id);
ALTER TABLE public.cafe_table_orders ADD COLUMN visit_id uuid REFERENCES public.cafe_table_visits;
CREATE INDEX cafe_orders_visit_idx ON public.cafe_table_orders(visit_id);
ALTER TABLE public.cafe_dining_tables ADD COLUMN cleaning_started_at timestamptz;
ALTER TABLE public.cafe_table_reservations ADD COLUMN arrived_at timestamptz;
CREATE TABLE public.cafe_service_requests(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),request_id uuid NOT NULL UNIQUE,table_id uuid NOT NULL REFERENCES public.cafe_dining_tables,
 visit_id uuid REFERENCES public.cafe_table_visits,kind text NOT NULL CHECK(kind IN ('call_staff','special_request','bill')),
 message text NOT NULL DEFAULT '' CHECK(length(message)<=1000),status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','acknowledged','completed')),
 created_at timestamptz NOT NULL DEFAULT now(),acknowledged_at timestamptz,completed_at timestamptz,handled_by uuid REFERENCES auth.users);
CREATE INDEX cafe_requests_table_idx ON public.cafe_service_requests(table_id,created_at DESC);
CREATE INDEX cafe_requests_visit_idx ON public.cafe_service_requests(visit_id);
CREATE INDEX cafe_requests_handler_idx ON public.cafe_service_requests(handled_by);
CREATE TABLE public.cafe_table_activity(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),request_id uuid UNIQUE,table_id uuid NOT NULL REFERENCES public.cafe_dining_tables,
 visit_id uuid REFERENCES public.cafe_table_visits,actor_id uuid REFERENCES auth.users,action text NOT NULL,
 details jsonb NOT NULL DEFAULT '{}',created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX cafe_table_activity_table_idx ON public.cafe_table_activity(table_id,created_at DESC);
CREATE INDEX cafe_table_activity_visit_idx ON public.cafe_table_activity(visit_id);
CREATE INDEX cafe_table_activity_actor_idx ON public.cafe_table_activity(actor_id);
DO $rls$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['cafe_table_visits','cafe_service_requests','cafe_table_activity'] LOOP
 EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY',t);
 EXECUTE format('REVOKE ALL ON public.%I FROM anon,authenticated',t);
 EXECUTE format('CREATE POLICY deny_direct ON public.%I AS RESTRICTIVE FOR ALL TO anon,authenticated USING(false) WITH CHECK(false)',t);
 END LOOP;
END;$rls$;
CREATE FUNCTION cafe_private.table_access(p_card text) RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT auth.uid() IS NOT NULL AND (public.has_workspace_access('tables_orders',p_card) OR public.has_workspace_access('table_overview',p_card));
$$;
CREATE FUNCTION cafe_private.attach_order_visit() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NEW.source='table' THEN
  PERFORM 1 FROM public.cafe_dining_tables WHERE id=NEW.table_id FOR UPDATE;
  SELECT id INTO NEW.visit_id FROM public.cafe_table_visits WHERE table_id=NEW.table_id AND closed_at IS NULL;
  IF NEW.visit_id IS NULL THEN RAISE EXCEPTION 'Ask staff to start this table visit before ordering' USING ERRCODE='22023'; END IF;
 END IF;
 RETURN NEW;
END;$$;
REVOKE ALL ON FUNCTION cafe_private.attach_order_visit() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER cafe_order_visit BEFORE INSERT ON public.cafe_table_orders FOR EACH ROW EXECUTE FUNCTION cafe_private.attach_order_visit();

CREATE FUNCTION cafe_private.visit_bill(p_visit uuid) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 WITH orders AS (
 SELECT o.*,coalesce((SELECT sum(CASE WHEN p.kind='payment' THEN p.amount_iqd ELSE -p.amount_iqd END) FROM public.cafe_payments p WHERE p.order_id=o.id),0) paid
 FROM public.cafe_table_orders o WHERE o.visit_id=p_visit AND o.status<>'cancelled')
 SELECT jsonb_build_object('total_iqd',coalesce(sum(total_iqd),0),'paid_iqd',coalesce(sum(paid),0),
 'balance_iqd',coalesce(sum(total_iqd-paid),0),'orders',coalesce(jsonb_agg(public.cafe_table_order_payload(id)||jsonb_build_object('paid_iqd',paid) ORDER BY created_at),'[]'::jsonb)) FROM orders;
$$;
REVOKE ALL ON FUNCTION cafe_private.visit_bill(uuid) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION cafe_private.guest_portal(p_qr_token uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE context jsonb; t uuid; v uuid;
BEGIN
 context:=public.get_cafe_guest_table_context(p_qr_token);
 t:=(context->'table'->>'id')::uuid;
 SELECT id INTO v FROM public.cafe_table_visits WHERE table_id=t AND closed_at IS NULL;
 RETURN context||jsonb_build_object('server_time',now(),'visit_id',v,
 'menu',coalesce((SELECT jsonb_agg(to_jsonb(m)) FROM cafe_private.get_cafe_guest_menu(p_qr_token) m),'[]'::jsonb),
 'bill',CASE WHEN v IS NOT NULL THEN cafe_private.visit_bill(v) ELSE jsonb_build_object('orders','[]'::jsonb,'total_iqd',0,'paid_iqd',0,'balance_iqd',0) END,
 'requests',coalesce((SELECT jsonb_agg(jsonb_build_object('id',r.id,'kind',r.kind,'status',r.status,'created_at',r.created_at) ORDER BY r.created_at DESC) FROM public.cafe_service_requests r WHERE r.table_id=t AND r.visit_id=v AND r.created_at>now()-interval '24 hours'),'[]'::jsonb));
END;$$;

CREATE FUNCTION cafe_private.guest_service(p_qr_token uuid,p_request_id uuid,p_kind text,p_message text) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t uuid;v uuid;existing public.cafe_service_requests; result uuid;
BEGIN
 t:=((public.get_cafe_guest_table_context(p_qr_token))->'table'->>'id')::uuid;
 IF p_request_id IS NULL OR p_kind IS NULL OR p_kind NOT IN ('call_staff','special_request','bill') OR length(coalesce(p_message,''))>1000 OR (p_kind='special_request' AND length(trim(coalesce(p_message,'')))<1) THEN RAISE EXCEPTION 'Invalid request' USING ERRCODE='22023'; END IF;
 PERFORM 1 FROM public.cafe_dining_tables WHERE id=t FOR UPDATE;
 SELECT * INTO existing FROM public.cafe_service_requests WHERE request_id=p_request_id;
 IF FOUND THEN
  IF existing.table_id=t AND existing.kind=p_kind AND existing.message=trim(coalesce(p_message,'')) THEN RETURN existing.id; END IF;
  RAISE EXCEPTION 'Request identifier reused' USING ERRCODE='23505';
 END IF;
 SELECT id INTO v FROM public.cafe_table_visits WHERE table_id=t AND closed_at IS NULL;
 IF p_kind='bill' AND v IS NULL THEN RAISE EXCEPTION 'No active visit' USING ERRCODE='22023'; END IF;
 IF EXISTS(SELECT 1 FROM public.cafe_service_requests WHERE table_id=t AND status<>'completed' AND created_at>now()-interval '15 seconds') THEN RAISE EXCEPTION 'Your request was sent. Please allow staff time to respond.' USING ERRCODE='22023'; END IF;
 INSERT INTO public.cafe_service_requests(request_id,table_id,visit_id,kind,message) VALUES(p_request_id,t,v,p_kind,trim(coalesce(p_message,''))) RETURNING id INTO result;
 RETURN result;
END;$$;

CREATE FUNCTION cafe_private.table_overview() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE result jsonb;
BEGIN
 IF NOT (cafe_private.table_access('table_overview') OR cafe_private.table_access('live_tables') OR cafe_private.table_access('table_status') OR cafe_private.table_access('table_availability') OR cafe_private.table_access('table_session_management') OR cafe_private.table_access('table_service_requests') OR cafe_private.table_access('table_cleaning')) THEN RAISE EXCEPTION 'Table Overview permission required' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',t.id,'name',t.name,'area',t.area,'seats',t.seats,'status',t.status,'pricing_mode',t.pricing_mode,
 'cleaning_started_at',t.cleaning_started_at,'visit_id',v.id,'started_at',v.started_at,'guest_count',v.guest_count,
 'customer_name',CASE WHEN cafe_private.table_access('customer_details') THEN v.customer_name ELSE '' END,
 'contact',CASE WHEN cafe_private.table_access('customer_details') THEN v.contact ELSE '' END,'waiter_id',v.waiter_id,
 'order_count',(SELECT count(*) FROM public.cafe_table_orders o WHERE o.visit_id=v.id AND o.status<>'cancelled'),
 'pending_orders',(SELECT count(*) FROM public.cafe_table_orders o WHERE o.visit_id=v.id AND o.status IN ('received','preparing','ready')),
 'payment_status',CASE WHEN v.id IS NULL THEN '' WHEN (SELECT count(*) FROM public.cafe_table_orders o WHERE o.visit_id=v.id AND o.status<>'cancelled')=0 THEN 'No orders' WHEN (cafe_private.visit_bill(v.id)->>'balance_iqd')::bigint=0 THEN 'Paid — Still Seated' WHEN (cafe_private.visit_bill(v.id)->>'paid_iqd')::bigint>0 THEN 'Partially Paid' ELSE 'Unpaid' END,
 'requests',coalesce((SELECT jsonb_agg(jsonb_build_object('id',r.id,'kind',r.kind,'message',r.message,'status',r.status,'created_at',r.created_at) ORDER BY r.created_at) FROM public.cafe_service_requests r WHERE r.table_id=t.id AND r.status<>'completed'),'[]'::jsonb),
 'reservation',(SELECT jsonb_build_object('id',r.id,'starts_at',r.starts_at,'ends_at',r.ends_at,'party_size',r.party_size,'arrived_at',r.arrived_at) FROM public.cafe_table_reservations r WHERE r.table_id=t.id AND r.status='confirmed' AND r.ends_at>now() ORDER BY r.starts_at LIMIT 1)) ORDER BY t.name),'[]'::jsonb)
 INTO result FROM public.cafe_dining_tables t LEFT JOIN public.cafe_table_visits v ON v.table_id=t.id AND v.closed_at IS NULL;
 RETURN jsonb_build_object('server_time',now(),'tables',result,'capabilities',jsonb_build_object(
 'take',cafe_private.table_access('table_session_management'),'arrived',cafe_private.table_access('guest_check_in_no_show'),
 'close',cafe_private.table_access('table_session_management'),'ready',cafe_private.table_access('table_cleaning'),
 'mode',cafe_private.table_access('edit_manage_tables'),'service',cafe_private.table_access('table_service_requests'),
 'orders',public.has_workspace_access('tables_orders','table_ordering'),
 'bills',public.has_workspace_access('payment_management','payment_history') OR public.has_workspace_access('payment_management','receive_payment')));
END;$$;

CREATE FUNCTION cafe_private.table_action(p_request_id uuid,p_table_id uuid,p_action text,p_data jsonb DEFAULT '{}') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t public.cafe_dining_tables; v public.cafe_table_visits; r public.cafe_table_reservations; e public.cafe_table_activity; cap text; n int; signature jsonb; rid uuid;
BEGIN
 IF p_request_id IS NULL OR p_data IS NULL OR jsonb_typeof(p_data)<>'object' THEN RAISE EXCEPTION 'Invalid action' USING ERRCODE='22023'; END IF;
 cap:=CASE p_action WHEN 'take' THEN 'table_session_management' WHEN 'close' THEN 'table_session_management' WHEN 'ready' THEN 'table_cleaning' WHEN 'arrived' THEN 'guest_check_in_no_show' WHEN 'mode' THEN 'edit_manage_tables' WHEN 'acknowledge' THEN 'table_service_requests' WHEN 'complete_request' THEN 'table_service_requests' ELSE NULL END;
 IF cap IS NULL OR NOT cafe_private.table_access(cap) THEN RAISE EXCEPTION 'Action permission required' USING ERRCODE='42501'; END IF;
 signature:=jsonb_build_object('action',p_action,'data',p_data);
 PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,12));
 SELECT * INTO e FROM public.cafe_table_activity WHERE request_id=p_request_id;
 IF FOUND THEN IF e.table_id=p_table_id AND e.actor_id=auth.uid() AND e.details=signature THEN RETURN jsonb_build_object('ok',true); END IF; RAISE EXCEPTION 'Action identifier reused' USING ERRCODE='23505'; END IF;
 SELECT * INTO t FROM public.cafe_dining_tables WHERE id=p_table_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Table missing' USING ERRCODE='22023'; END IF;
 SELECT * INTO v FROM public.cafe_table_visits WHERE table_id=t.id AND closed_at IS NULL FOR UPDATE;
 IF p_action='take' THEN
  IF v.id IS NOT NULL OR t.status IN ('occupied','cleaning') THEN RAISE EXCEPTION 'Table not available' USING ERRCODE='22023'; END IF;
  IF coalesce(p_data->>'guests','') !~ '^[0-9]{1,3}$' THEN RAISE EXCEPTION 'Enter guest count' USING ERRCODE='22023'; END IF;
  n:=(p_data->>'guests')::int;
  IF n<1 OR n>t.seats OR length(coalesce(p_data->>'name',''))>120 OR length(coalesce(p_data->>'contact',''))>80 THEN RAISE EXCEPTION 'Invalid guest details or capacity exceeded' USING ERRCODE='22023'; END IF;
  SELECT * INTO r FROM public.cafe_table_reservations WHERE table_id=t.id AND status='confirmed' AND starts_at<now()+interval '2 hours' AND ends_at>now() ORDER BY starts_at LIMIT 1 FOR UPDATE;
  IF r.id IS NOT NULL AND r.arrived_at IS NULL THEN RAISE EXCEPTION 'Confirm reserved guest arrival first' USING ERRCODE='22023'; END IF;
  INSERT INTO public.cafe_table_visits(table_id,guest_count,customer_name,contact,waiter_id,created_by) VALUES(t.id,n,coalesce(p_data->>'name',''),coalesce(p_data->>'contact',''),auth.uid(),auth.uid()) RETURNING * INTO v;
  UPDATE public.cafe_dining_tables SET status='occupied',updated_by=auth.uid() WHERE id=t.id;
 ELSIF p_action='arrived' THEN
  SELECT * INTO r FROM public.cafe_table_reservations WHERE id=(p_data->>'reservation_id')::uuid AND table_id=t.id AND status='confirmed' FOR UPDATE;
  IF r.id IS NULL OR r.ends_at<now() THEN RAISE EXCEPTION 'Reservation unavailable' USING ERRCODE='22023'; END IF;
  UPDATE public.cafe_table_reservations SET arrived_at=coalesce(arrived_at,now()) WHERE id=r.id;
  IF v.id IS NULL THEN UPDATE public.cafe_dining_tables SET status='reserved',updated_by=auth.uid() WHERE id=t.id; END IF;
 ELSIF p_action='close' THEN
  IF v.id IS NULL THEN RAISE EXCEPTION 'No active visit' USING ERRCODE='22023'; END IF;
  IF (cafe_private.visit_bill(v.id)->>'balance_iqd')::bigint<>0 OR EXISTS(SELECT 1 FROM public.cafe_table_orders WHERE visit_id=v.id AND status IN ('received','preparing','ready')) THEN RAISE EXCEPTION 'Settle all charges and finish orders before closing' USING ERRCODE='22023'; END IF;
  UPDATE public.cafe_table_visits SET closed_at=now() WHERE id=v.id;
  UPDATE public.cafe_dining_tables SET status='cleaning',cleaning_started_at=now(),pricing_mode='normal',updated_by=auth.uid() WHERE id=t.id;
 ELSIF p_action='ready' THEN
  IF t.status<>'cleaning' OR v.id IS NOT NULL THEN RAISE EXCEPTION 'Table is not awaiting cleaning' USING ERRCODE='22023'; END IF;
  UPDATE public.cafe_dining_tables SET status=CASE WHEN EXISTS(SELECT 1 FROM public.cafe_table_reservations WHERE table_id=t.id AND status='confirmed' AND ends_at>now() AND starts_at<now()+interval '30 minutes') THEN 'reserved' ELSE 'available' END,cleaning_started_at=NULL,updated_by=auth.uid() WHERE id=t.id;
 ELSIF p_action='mode' THEN
  IF coalesce(p_data->>'mode','') NOT IN ('normal','tourism','owner') OR length(trim(coalesce(p_data->>'reason','')))<3 THEN RAISE EXCEPTION 'Select mode and enter reason' USING ERRCODE='22023'; END IF;
  IF p_data->>'mode'='owner' AND NOT EXISTS(SELECT 1 FROM public.staff_profiles WHERE user_id=auth.uid() AND role='admin') THEN RAISE EXCEPTION 'Owner mode requires administrator approval' USING ERRCODE='42501'; END IF;
  UPDATE public.cafe_dining_tables SET pricing_mode=p_data->>'mode',updated_by=auth.uid() WHERE id=t.id;
 ELSE
  SELECT id INTO rid FROM public.cafe_service_requests WHERE id=(p_data->>'request_id')::uuid AND table_id=t.id AND status<>'completed' FOR UPDATE;
  IF rid IS NULL THEN RAISE EXCEPTION 'Request changed; refresh' USING ERRCODE='22023'; END IF;
  UPDATE public.cafe_service_requests SET status=CASE WHEN p_action='acknowledge' THEN 'acknowledged' ELSE 'completed' END,acknowledged_at=coalesce(acknowledged_at,now()),completed_at=CASE WHEN p_action='complete_request' THEN now() END,handled_by=auth.uid() WHERE id=rid;
 END IF;
 INSERT INTO public.cafe_table_activity(request_id,table_id,visit_id,actor_id,action,details) VALUES(p_request_id,t.id,v.id,auth.uid(),p_action,signature);
 RETURN jsonb_build_object('ok',true);
END;$$;

CREATE FUNCTION cafe_private.staff_visit_bill(p_table_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v uuid; BEGIN
 IF NOT (public.has_workspace_access('payment_management','payment_history') OR public.has_workspace_access('payment_management','receive_payment')) THEN RAISE EXCEPTION 'Bill permission required' USING ERRCODE='42501'; END IF;
 SELECT id INTO v FROM public.cafe_table_visits WHERE table_id=p_table_id AND closed_at IS NULL;
 IF v IS NULL THEN RAISE EXCEPTION 'No active visit' USING ERRCODE='22023'; END IF;
 RETURN cafe_private.visit_bill(v);
END;$$;
CREATE FUNCTION public.get_cafe_guest_portal(p_qr_token uuid) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.guest_portal(p_qr_token) $$;
CREATE FUNCTION public.submit_cafe_guest_service(p_qr_token uuid,p_request_id uuid,p_kind text,p_message text) RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.guest_service(p_qr_token,p_request_id,p_kind,p_message) $$;
CREATE FUNCTION public.get_cafe_table_overview() RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.table_overview() $$;
CREATE FUNCTION public.perform_cafe_table_action(p_request_id uuid,p_table_id uuid,p_action text,p_data jsonb DEFAULT '{}') RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.table_action(p_request_id,p_table_id,p_action,p_data) $$;
CREATE FUNCTION public.get_cafe_visit_bill(p_table_id uuid) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.staff_visit_bill(p_table_id) $$;
REVOKE ALL ON FUNCTION cafe_private.table_access(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION cafe_private.table_access(text) TO authenticated;
REVOKE ALL ON FUNCTION cafe_private.guest_portal(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION cafe_private.guest_portal(uuid) TO authenticated,anon;
REVOKE ALL ON FUNCTION cafe_private.guest_service(uuid,uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION cafe_private.guest_service(uuid,uuid,text,text) TO authenticated,anon;
REVOKE ALL ON FUNCTION cafe_private.table_overview() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION cafe_private.table_overview() TO authenticated;
REVOKE ALL ON FUNCTION cafe_private.table_action(uuid,uuid,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION cafe_private.table_action(uuid,uuid,text,jsonb) TO authenticated;
REVOKE ALL ON FUNCTION cafe_private.staff_visit_bill(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION cafe_private.staff_visit_bill(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.get_cafe_guest_portal(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_cafe_guest_portal(uuid) TO authenticated,anon;
REVOKE ALL ON FUNCTION public.submit_cafe_guest_service(uuid,uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.submit_cafe_guest_service(uuid,uuid,text,text) TO authenticated,anon;
REVOKE ALL ON FUNCTION public.get_cafe_table_overview() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_cafe_table_overview() TO authenticated;
REVOKE ALL ON FUNCTION public.perform_cafe_table_action(uuid,uuid,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.perform_cafe_table_action(uuid,uuid,text,jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public.get_cafe_visit_bill(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_cafe_visit_bill(uuid) TO authenticated;
NOTIFY pgrst,'reload schema';


-- Source: 20261017020354_cafe_table_workflow_guards.sql

CREATE OR REPLACE FUNCTION cafe_private.submit_staff_order(p_request_id uuid,p_source text,p_table_id uuid,p_destination text,p_items jsonb,p_notes text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth AS $$
DECLARE o public.cafe_table_orders; m public.cafe_menu_items; item jsonb; items jsonb:='[]'; signature jsonb; total bigint:=0; qty int; seen uuid[]:='{}'; table_mode text:='normal'; unit_price bigint;
BEGIN
 IF auth.uid() IS NULL OR NOT (CASE p_source
 WHEN 'table' THEN public.has_workspace_access('tables_orders','table_ordering')
 WHEN 'motel' THEN public.has_workspace_access('motel_online_orders','new_motel_order')
 WHEN 'online' THEN public.has_workspace_access('motel_online_orders','new_online_order')
 WHEN 'walk_in' THEN public.has_workspace_access('motel_online_orders','new_walk_in_order') ELSE false END)
 THEN RAISE EXCEPTION 'Order creation permission and MFA required' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL OR p_items IS NULL OR jsonb_typeof(p_items)<>'array' OR jsonb_array_length(p_items) NOT BETWEEN 1 AND 20 OR length(coalesce(p_notes,''))>500 OR length(coalesce(p_destination,''))>200 THEN RAISE EXCEPTION 'Invalid order details' USING ERRCODE='22023'; END IF;
 IF p_source='table' THEN
  SELECT pricing_mode INTO table_mode FROM public.cafe_dining_tables WHERE id=p_table_id AND status<>'cleaning' FOR UPDATE;
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
  unit_price:=CASE table_mode WHEN 'tourism' THEN coalesce(m.tourism_price_iqd,m.price_iqd) WHEN 'owner' THEN coalesce(m.owner_price_iqd,m.price_iqd) ELSE m.price_iqd END;
  seen:=array_append(seen,m.id);
  items:=items||jsonb_build_array(jsonb_build_object('id',m.id,'name',m.name,'qty',qty,'price',unit_price));
  total:=total+unit_price*qty;
 END LOOP;
 INSERT INTO public.cafe_table_orders(request_id,table_id,source,destination,total_iqd,notes,request_signature,created_by,pricing_mode)
 VALUES(p_request_id,p_table_id,p_source,trim(coalesce(p_destination,'')),total,trim(coalesce(p_notes,'')),signature,auth.uid(),table_mode) RETURNING * INTO o;
 INSERT INTO public.cafe_table_order_items(order_id,menu_item_id,item_name,quantity,unit_price_iqd)
 SELECT o.id,(v->>'id')::uuid,v->>'name',(v->>'qty')::int,(v->>'price')::bigint FROM jsonb_array_elements(items) v;
 INSERT INTO public.cafe_table_order_audit(order_id,action,actor_id) VALUES(o.id,'received',auth.uid());
 RETURN public.cafe_table_order_payload(o.id);
END;$$;
CREATE OR REPLACE FUNCTION cafe_private.submit_cafe_guest_table_order(p_qr_token uuid, p_request_id uuid, p_items jsonb, p_notes text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
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
  unit_price bigint;
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
  FOR UPDATE OF dining_table;

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

    unit_price:=CASE table_record.pricing_mode WHEN 'tourism' THEN coalesce(menu_item.tourism_price_iqd,menu_item.price_iqd) WHEN 'owner' THEN coalesce(menu_item.owner_price_iqd,menu_item.price_iqd) ELSE menu_item.price_iqd END;
    normalized_item := jsonb_build_object(
      'item_id', menu_item.id,
      'name', menu_item.name,
      'quantity', item_quantity,
      'unit_price_iqd', unit_price
    );
    priced_items := priced_items || jsonb_build_array(normalized_item);
    order_total := order_total + unit_price * item_quantity;
  END LOOP;

  INSERT INTO public.cafe_table_orders (
    request_id,
    table_id,
    total_iqd,
    notes,
    request_signature,
    created_by, pricing_mode
  )
  VALUES (
    p_request_id,
    table_record.id,
    order_total,
    COALESCE(trim(p_notes), ''),
    request_signature,
    auth.uid(), table_record.pricing_mode
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
$function$
;
CREATE OR REPLACE FUNCTION cafe_private.submit_staff_order_priced(p_request_id uuid,p_source text,p_table_id uuid,p_destination text,p_items jsonb,p_notes text,p_pricing_mode text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth AS $$
DECLARE o public.cafe_table_orders; m public.cafe_menu_items; item jsonb; items jsonb:='[]'; signature jsonb; total bigint:=0; qty int; seen uuid[]:='{}'; unit_price bigint; table_mode text;
BEGIN
 IF auth.uid() IS NULL OR NOT (CASE p_source
 WHEN 'table' THEN public.has_workspace_access('tables_orders','table_ordering')
 WHEN 'motel' THEN public.has_workspace_access('motel_online_orders','new_motel_order')
 WHEN 'online' THEN public.has_workspace_access('motel_online_orders','new_online_order')
 WHEN 'walk_in' THEN public.has_workspace_access('motel_online_orders','new_walk_in_order') ELSE false END)
 THEN RAISE EXCEPTION 'Order creation permission and MFA required' USING ERRCODE='42501'; END IF;
 IF p_pricing_mode IS NULL OR p_pricing_mode NOT IN ('normal','tourism','owner') THEN RAISE EXCEPTION 'Invalid pricing mode' USING ERRCODE='22023'; END IF;
 IF p_source<>'table' AND p_pricing_mode<>'normal' AND NOT public.has_workspace_access('kitchen_management',p_pricing_mode||'_pricing') THEN RAISE EXCEPTION 'Pricing mode permission required' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL OR p_items IS NULL OR jsonb_typeof(p_items)<>'array' OR jsonb_array_length(p_items) NOT BETWEEN 1 AND 20 OR length(coalesce(p_notes,''))>500 OR length(coalesce(p_destination,''))>200 THEN RAISE EXCEPTION 'Invalid order details' USING ERRCODE='22023'; END IF;
 IF p_source='table' THEN
  SELECT pricing_mode INTO table_mode FROM public.cafe_dining_tables WHERE id=p_table_id AND status<>'cleaning' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Select an available table' USING ERRCODE='22023'; END IF;
 ELSIF p_table_id IS NOT NULL OR (p_source IN ('motel','online') AND length(trim(coalesce(p_destination,'')))<1) THEN RAISE EXCEPTION 'Enter a room or delivery reference' USING ERRCODE='22023'; END IF;
 signature:=jsonb_build_object('pricing_mode',p_pricing_mode,'source',p_source,'table',p_table_id,'destination',trim(coalesce(p_destination,'')),'items',p_items,'notes',trim(coalesce(p_notes,'')));
 PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
 SELECT * INTO o FROM public.cafe_table_orders WHERE request_id=p_request_id;
 IF FOUND THEN
  IF o.created_by=auth.uid() AND o.request_signature=signature THEN RETURN public.cafe_table_order_payload(o.id); END IF;
  RAISE EXCEPTION 'Request already used' USING ERRCODE='23505';
 END IF;
 IF p_source='table' AND p_pricing_mode IS DISTINCT FROM table_mode THEN RAISE EXCEPTION 'Table price mode changed; refresh the menu before ordering' USING ERRCODE='22023'; END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
  IF coalesce(item->>'quantity','') !~ '^[0-9]{1,2}$' THEN RAISE EXCEPTION 'Invalid quantity' USING ERRCODE='22023'; END IF;
  qty:=(item->>'quantity')::int;
  IF qty NOT BETWEEN 1 AND 20 THEN RAISE EXCEPTION 'Invalid quantity' USING ERRCODE='22023'; END IF;
  SELECT * INTO m FROM public.cafe_menu_items WHERE id=(item->>'item_id')::uuid AND available FOR SHARE;
  IF NOT FOUND OR m.id=ANY(seen) THEN RAISE EXCEPTION 'Unavailable or repeated product' USING ERRCODE='22023'; END IF;
  unit_price:=CASE p_pricing_mode WHEN 'tourism' THEN coalesce(m.tourism_price_iqd,m.price_iqd) WHEN 'owner' THEN coalesce(m.owner_price_iqd,m.price_iqd) ELSE m.price_iqd END;
  seen:=array_append(seen,m.id);
  items:=items||jsonb_build_array(jsonb_build_object('id',m.id,'name',m.name,'qty',qty,'price',unit_price));
  total:=total+unit_price*qty;
 END LOOP;
 INSERT INTO public.cafe_table_orders(request_id,table_id,source,destination,total_iqd,notes,request_signature,created_by,pricing_mode)
 VALUES(p_request_id,p_table_id,p_source,trim(coalesce(p_destination,'')),total,trim(coalesce(p_notes,'')),signature,auth.uid(),p_pricing_mode) RETURNING * INTO o;
 INSERT INTO public.cafe_table_order_items(order_id,menu_item_id,item_name,quantity,unit_price_iqd)
 SELECT o.id,(v->>'id')::uuid,v->>'name',(v->>'qty')::int,(v->>'price')::bigint FROM jsonb_array_elements(items) v;
 INSERT INTO public.cafe_table_order_audit(order_id,action,actor_id) VALUES(o.id,'received',auth.uid());
 RETURN public.cafe_table_order_payload(o.id);
END;$$;
CREATE OR REPLACE FUNCTION public.cafe_table_order_payload(p_order_id uuid) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT jsonb_build_object('id',o.id,'table_id',o.table_id,'visit_id',o.visit_id,'source',o.source,'destination',o.destination,
 'table_name',coalesce(t.name, nullif(o.destination,''),initcap(replace(o.source,'_',' '))),
 'status',o.status,'pricing_mode',o.pricing_mode,'total_iqd',o.total_iqd,'created_at',o.created_at,'notes',o.notes,
 'items',coalesce((SELECT jsonb_agg(jsonb_build_object('name',i.item_name,'quantity',i.quantity,'unit_price_iqd',i.unit_price_iqd) ORDER BY i.id)
 FROM public.cafe_table_order_items i WHERE i.order_id=o.id),'[]'::jsonb))
 FROM public.cafe_table_orders o LEFT JOIN public.cafe_dining_tables t ON t.id=o.table_id WHERE o.id=p_order_id;
$$;

CREATE FUNCTION cafe_private.guard_table_state() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF NEW.pricing_mode='owner' AND (TG_OP='INSERT' OR OLD.pricing_mode IS DISTINCT FROM NEW.pricing_mode) AND NOT EXISTS(SELECT 1 FROM public.staff_profiles WHERE user_id=auth.uid() AND role='admin') THEN RAISE EXCEPTION 'Owner mode requires administrator approval' USING ERRCODE='42501'; END IF;
 IF TG_OP='UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
  IF NEW.status='occupied' AND NOT EXISTS(SELECT 1 FROM public.cafe_table_visits WHERE table_id=NEW.id AND closed_at IS NULL) THEN RAISE EXCEPTION 'Use Take to start a visit' USING ERRCODE='22023'; END IF;
  IF NEW.status<>'occupied' AND EXISTS(SELECT 1 FROM public.cafe_table_visits WHERE table_id=NEW.id AND closed_at IS NULL) THEN RAISE EXCEPTION 'Close the active visit before changing status' USING ERRCODE='22023'; END IF;
 END IF;
 RETURN NEW;
END;$$;
CREATE TRIGGER cafe_table_state_guard BEFORE INSERT OR UPDATE ON public.cafe_dining_tables FOR EACH ROW EXECUTE FUNCTION cafe_private.guard_table_state();
REVOKE ALL ON FUNCTION cafe_private.guard_table_state() FROM PUBLIC,anon,authenticated;

CREATE FUNCTION cafe_private.submit_guest_quoted(p_qr_token uuid,p_request_id uuid,p_items jsonb,p_notes text,p_visit_id uuid,p_expected_total bigint,p_expected_mode text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE result jsonb; t public.cafe_dining_tables; existing boolean; active_visit uuid;
BEGIN
 SELECT d.* INTO t FROM public.cafe_dining_tables d JOIN public.cafe_dining_table_qr_tokens q ON q.table_id=d.id WHERE q.token=p_qr_token FOR UPDATE OF d;
 IF NOT FOUND THEN RAISE EXCEPTION 'Invalid table QR' USING ERRCODE='22023'; END IF;
 SELECT EXISTS(SELECT 1 FROM public.cafe_table_orders WHERE request_id=p_request_id) INTO existing;
 IF NOT existing THEN
  SELECT id INTO active_visit FROM public.cafe_table_visits WHERE table_id=t.id AND closed_at IS NULL;
  IF p_visit_id IS NULL OR active_visit IS DISTINCT FROM p_visit_id THEN RAISE EXCEPTION 'The table visit changed; ask staff before ordering' USING ERRCODE='22023'; END IF;
  IF p_expected_mode IS DISTINCT FROM t.pricing_mode OR p_expected_total IS NULL OR p_expected_total<=0 THEN RAISE EXCEPTION 'Menu prices changed; review the menu again' USING ERRCODE='22023'; END IF;
 END IF;
 result:=cafe_private.submit_cafe_guest_table_order(p_qr_token,p_request_id,p_items,p_notes);
 IF NOT existing AND (result->>'total_iqd')::bigint<>p_expected_total THEN RAISE EXCEPTION 'Menu prices changed; review the menu again' USING ERRCODE='22023'; END IF;
 RETURN result;
END;$$;
CREATE FUNCTION public.submit_cafe_guest_quoted_order(p_qr_token uuid,p_request_id uuid,p_items jsonb,p_notes text,p_visit_id uuid,p_expected_total bigint,p_expected_mode text) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.submit_guest_quoted(p_qr_token,p_request_id,p_items,p_notes,p_visit_id,p_expected_total,p_expected_mode) $$;
REVOKE ALL ON FUNCTION cafe_private.submit_guest_quoted(uuid,uuid,jsonb,text,uuid,bigint,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.submit_cafe_guest_quoted_order(uuid,uuid,jsonb,text,uuid,bigint,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION cafe_private.submit_guest_quoted(uuid,uuid,jsonb,text,uuid,bigint,text),public.submit_cafe_guest_quoted_order(uuid,uuid,jsonb,text,uuid,bigint,text) TO anon,authenticated;

CREATE OR REPLACE FUNCTION cafe_private.table_overview() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE result jsonb;
BEGIN
 IF NOT (cafe_private.table_access('table_overview') OR cafe_private.table_access('live_tables') OR cafe_private.table_access('table_status') OR cafe_private.table_access('table_availability') OR cafe_private.table_access('table_session_management') OR cafe_private.table_access('table_service_requests') OR cafe_private.table_access('table_cleaning')) THEN RAISE EXCEPTION 'Table Overview permission required' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',t.id,'name',t.name,'area',t.area,'seats',t.seats,'status',t.status,'pricing_mode',t.pricing_mode,
 'cleaning_started_at',t.cleaning_started_at,'visit_id',v.id,'started_at',v.started_at,'guest_count',v.guest_count,
 'customer_name',CASE WHEN cafe_private.table_access('customer_details') THEN v.customer_name ELSE '' END,
 'contact',CASE WHEN cafe_private.table_access('customer_details') THEN v.contact ELSE '' END,'waiter_id',v.waiter_id,
 'order_count',(SELECT count(*) FROM public.cafe_table_orders o WHERE o.visit_id=v.id AND o.status<>'cancelled'),
 'pending_orders',(SELECT count(*) FROM public.cafe_table_orders o WHERE o.visit_id=v.id AND o.status IN ('received','preparing','ready')),
 'payment_status',CASE WHEN v.id IS NULL THEN '' WHEN (SELECT count(*) FROM public.cafe_table_orders o WHERE o.visit_id=v.id AND o.status<>'cancelled')=0 THEN 'No orders' WHEN (cafe_private.visit_bill(v.id)->>'balance_iqd')::bigint=0 THEN 'Paid — Still Seated' WHEN (cafe_private.visit_bill(v.id)->>'paid_iqd')::bigint>0 THEN 'Partially Paid' ELSE 'Unpaid' END,
 'requests',coalesce((SELECT jsonb_agg(jsonb_build_object('id',r.id,'kind',r.kind,'message',r.message,'status',r.status,'created_at',r.created_at) ORDER BY r.created_at) FROM public.cafe_service_requests r WHERE r.table_id=t.id AND r.status<>'completed'),'[]'::jsonb),
 'reservation',(SELECT jsonb_build_object('id',r.id,'starts_at',r.starts_at,'ends_at',r.ends_at,'party_size',r.party_size,'arrived_at',r.arrived_at) FROM public.cafe_table_reservations r WHERE r.table_id=t.id AND r.status='confirmed' AND r.ends_at>now() ORDER BY r.starts_at LIMIT 1)) ORDER BY t.name),'[]'::jsonb)
 INTO result FROM public.cafe_dining_tables t LEFT JOIN public.cafe_table_visits v ON v.table_id=t.id AND v.closed_at IS NULL;
 RETURN jsonb_build_object('server_time',now(),'tables',result,'capabilities',jsonb_build_object(
 'take',cafe_private.table_access('table_session_management'),'arrived',cafe_private.table_access('guest_check_in_no_show'),
 'close',cafe_private.table_access('table_session_management'),'ready',cafe_private.table_access('table_cleaning'),
 'mode',cafe_private.table_access('edit_manage_tables'),'service',cafe_private.table_access('table_service_requests'),
 'payments',public.has_workspace_access('payment_management','receive_payment'),
 'orders',public.has_workspace_access('tables_orders','table_ordering'),
 'bills',public.has_workspace_access('payment_management','payment_history') OR public.has_workspace_access('payment_management','receive_payment')));
END;$$;
CREATE OR REPLACE FUNCTION cafe_private.guest_table_context(p_qr_token uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'table', jsonb_build_object(
      'id', dining_table.id,
      'name', dining_table.name,
      'area', dining_table.area,
      'pricing_mode', dining_table.pricing_mode
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
$function$
;
CREATE OR REPLACE FUNCTION public.get_cafe_guest_table_context(p_qr_token uuid) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.guest_table_context(p_qr_token) $$;
REVOKE ALL ON FUNCTION cafe_private.guest_table_context(uuid),public.get_cafe_guest_table_context(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION cafe_private.guest_table_context(uuid),public.get_cafe_guest_table_context(uuid) TO anon,authenticated;
NOTIFY pgrst,'reload schema';


-- Source: 20261017021202_cafe_table_assignments.sql

ALTER TABLE public.cafe_table_reservations ADD COLUMN no_show_at timestamptz;
ALTER TABLE public.cafe_table_orders ADD COLUMN original_table_id uuid REFERENCES public.cafe_dining_tables;
CREATE INDEX cafe_order_original_table_idx ON public.cafe_table_orders(original_table_id);
UPDATE public.cafe_table_orders SET original_table_id=table_id WHERE table_id IS NOT NULL;
CREATE FUNCTION cafe_private.order_origin() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$ BEGIN NEW.original_table_id:=NEW.table_id; RETURN NEW; END; $$;
CREATE TRIGGER cafe_order_origin BEFORE INSERT ON public.cafe_table_orders FOR EACH ROW EXECUTE FUNCTION cafe_private.order_origin();
REVOKE ALL ON FUNCTION cafe_private.order_origin() FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION cafe_private.table_action(p_request_id uuid,p_table_id uuid,p_action text,p_data jsonb DEFAULT '{}') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t public.cafe_dining_tables; v public.cafe_table_visits; r public.cafe_table_reservations; e public.cafe_table_activity; cap text; n int; signature jsonb; rid uuid; target public.cafe_dining_tables; target_id uuid;
BEGIN
 IF p_request_id IS NULL OR p_data IS NULL OR jsonb_typeof(p_data)<>'object' THEN RAISE EXCEPTION 'Invalid action' USING ERRCODE='22023'; END IF;
 cap:=CASE p_action WHEN 'take' THEN 'table_session_management' WHEN 'close' THEN 'table_session_management' WHEN 'ready' THEN 'table_cleaning' WHEN 'arrived' THEN 'guest_check_in_no_show' WHEN 'mode' THEN 'edit_manage_tables' WHEN 'acknowledge' THEN 'table_service_requests' WHEN 'complete_request' THEN 'table_service_requests' WHEN 'assign_waiter' THEN 'waiter_table_assignment' WHEN 'transfer' THEN 'table_transfer' WHEN 'no_show' THEN 'guest_check_in_no_show' WHEN 'call_staff' THEN 'table_service_requests' ELSE NULL END;
 IF cap IS NULL OR NOT cafe_private.table_access(cap) THEN RAISE EXCEPTION 'Action permission required' USING ERRCODE='42501'; END IF;
 signature:=jsonb_build_object('action',p_action,'data',p_data);
 PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,12));
 SELECT * INTO e FROM public.cafe_table_activity WHERE request_id=p_request_id;
 IF FOUND THEN IF e.table_id=p_table_id AND e.actor_id=auth.uid() AND e.details=signature THEN RETURN jsonb_build_object('ok',true); END IF; RAISE EXCEPTION 'Action identifier reused' USING ERRCODE='23505'; END IF;
 IF p_action='transfer' THEN
  target_id:=(p_data->>'target_id')::uuid;
  IF target_id IS NULL OR target_id=p_table_id THEN RAISE EXCEPTION 'Choose a different destination table' USING ERRCODE='22023'; END IF;
  PERFORM 1 FROM public.cafe_dining_tables WHERE id IN (p_table_id,target_id) ORDER BY id FOR UPDATE;
 END IF;
 SELECT * INTO t FROM public.cafe_dining_tables WHERE id=p_table_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Table missing' USING ERRCODE='22023'; END IF;
 SELECT * INTO v FROM public.cafe_table_visits WHERE table_id=t.id AND closed_at IS NULL FOR UPDATE;
 IF p_action='take' THEN
  IF v.id IS NOT NULL OR t.status IN ('occupied','cleaning') THEN RAISE EXCEPTION 'Table not available' USING ERRCODE='22023'; END IF;
  IF coalesce(p_data->>'guests','') !~ '^[0-9]{1,3}$' THEN RAISE EXCEPTION 'Enter guest count' USING ERRCODE='22023'; END IF;
  n:=(p_data->>'guests')::int;
  IF n<1 OR n>t.seats OR length(coalesce(p_data->>'name',''))>120 OR length(coalesce(p_data->>'contact',''))>80 THEN RAISE EXCEPTION 'Invalid guest details or capacity exceeded' USING ERRCODE='22023'; END IF;
  SELECT * INTO r FROM public.cafe_table_reservations WHERE table_id=t.id AND status='confirmed' AND starts_at<now()+interval '2 hours' AND ends_at>now() ORDER BY starts_at LIMIT 1 FOR UPDATE;
  IF r.id IS NOT NULL AND r.arrived_at IS NULL THEN RAISE EXCEPTION 'Confirm reserved guest arrival first' USING ERRCODE='22023'; END IF;
  INSERT INTO public.cafe_table_visits(table_id,guest_count,customer_name,contact,waiter_id,created_by) VALUES(t.id,n,coalesce(p_data->>'name',''),coalesce(p_data->>'contact',''),auth.uid(),auth.uid()) RETURNING * INTO v;
  UPDATE public.cafe_dining_tables SET status='occupied',updated_by=auth.uid() WHERE id=t.id;
 ELSIF p_action='arrived' THEN
  SELECT * INTO r FROM public.cafe_table_reservations WHERE id=(p_data->>'reservation_id')::uuid AND table_id=t.id AND status='confirmed' FOR UPDATE;
  IF r.id IS NULL OR r.ends_at<now() THEN RAISE EXCEPTION 'Reservation unavailable' USING ERRCODE='22023'; END IF;
  UPDATE public.cafe_table_reservations SET arrived_at=coalesce(arrived_at,now()) WHERE id=r.id;
  IF v.id IS NULL THEN UPDATE public.cafe_dining_tables SET status='reserved',updated_by=auth.uid() WHERE id=t.id; END IF;
 ELSIF p_action='close' THEN
  IF v.id IS NULL THEN RAISE EXCEPTION 'No active visit' USING ERRCODE='22023'; END IF;
  IF (cafe_private.visit_bill(v.id)->>'balance_iqd')::bigint<>0 OR EXISTS(SELECT 1 FROM public.cafe_table_orders WHERE visit_id=v.id AND status IN ('received','preparing','ready')) THEN RAISE EXCEPTION 'Settle all charges and finish orders before closing' USING ERRCODE='22023'; END IF;
  UPDATE public.cafe_table_visits SET closed_at=now() WHERE id=v.id;
  UPDATE public.cafe_dining_tables SET status='cleaning',cleaning_started_at=now(),pricing_mode='normal',updated_by=auth.uid() WHERE id=t.id;
 ELSIF p_action='ready' THEN
  IF t.status<>'cleaning' OR v.id IS NOT NULL THEN RAISE EXCEPTION 'Table is not awaiting cleaning' USING ERRCODE='22023'; END IF;
  UPDATE public.cafe_dining_tables SET status=CASE WHEN EXISTS(SELECT 1 FROM public.cafe_table_reservations WHERE table_id=t.id AND status='confirmed' AND ends_at>now() AND starts_at<now()+interval '30 minutes') THEN 'reserved' ELSE 'available' END,cleaning_started_at=NULL,updated_by=auth.uid() WHERE id=t.id;
 ELSIF p_action='assign_waiter' THEN
  IF v.id IS NULL OR NOT EXISTS(SELECT 1 FROM public.staff_profiles WHERE user_id=(p_data->>'waiter_id')::uuid AND role IN ('admin','staff')) THEN RAISE EXCEPTION 'Select an active visit and staff member' USING ERRCODE='22023'; END IF;
  UPDATE public.cafe_table_visits SET waiter_id=(p_data->>'waiter_id')::uuid WHERE id=v.id;
 ELSIF p_action='call_staff' THEN
  IF length(coalesce(p_data->>'message',''))>1000 THEN RAISE EXCEPTION 'Message too long' USING ERRCODE='22023'; END IF;
  INSERT INTO public.cafe_service_requests(request_id,table_id,visit_id,kind,message) VALUES(p_request_id,t.id,v.id,'call_staff',coalesce(p_data->>'message',''));
 ELSIF p_action='no_show' THEN
  SELECT * INTO r FROM public.cafe_table_reservations WHERE id=(p_data->>'reservation_id')::uuid AND table_id=t.id AND status='confirmed' FOR UPDATE;
  IF r.id IS NULL OR r.arrived_at IS NOT NULL OR r.starts_at>now() THEN RAISE EXCEPTION 'Only an unarrived reservation after its start can be marked no-show' USING ERRCODE='22023'; END IF;
  UPDATE public.cafe_table_reservations SET status='cancelled',no_show_at=now() WHERE id=r.id;
  IF v.id IS NULL AND t.status='reserved' THEN UPDATE public.cafe_dining_tables SET status='available',updated_by=auth.uid() WHERE id=t.id; END IF;
 ELSIF p_action='transfer' THEN
  SELECT * INTO target FROM public.cafe_dining_tables WHERE id=target_id;
  IF v.id IS NULL OR target.id IS NULL OR target.status<>'available' OR v.guest_count>target.seats OR EXISTS(SELECT 1 FROM public.cafe_table_visits WHERE table_id=target_id AND closed_at IS NULL) OR EXISTS(SELECT 1 FROM public.cafe_table_reservations WHERE table_id=target_id AND status='confirmed' AND ends_at>now() AND starts_at<now()+interval '2 hours') THEN RAISE EXCEPTION 'Destination must be available, large enough, and free of upcoming reservations' USING ERRCODE='22023'; END IF;
  UPDATE public.cafe_table_visits SET table_id=target_id WHERE id=v.id;
  UPDATE public.cafe_table_orders SET table_id=target_id WHERE visit_id=v.id;
  UPDATE public.cafe_service_requests SET table_id=target_id WHERE visit_id=v.id AND status<>'completed';
  UPDATE public.cafe_dining_tables SET status='occupied',updated_by=auth.uid() WHERE id=target_id;
  UPDATE public.cafe_dining_tables SET status='cleaning',cleaning_started_at=now(),pricing_mode='normal',updated_by=auth.uid() WHERE id=t.id;
  INSERT INTO public.cafe_table_activity(table_id,visit_id,actor_id,action,details) VALUES(target_id,v.id,auth.uid(),'transfer_received',jsonb_build_object('source_table',t.id));
 ELSIF p_action='mode' THEN
  IF coalesce(p_data->>'mode','') NOT IN ('normal','tourism','owner') OR length(trim(coalesce(p_data->>'reason','')))<3 THEN RAISE EXCEPTION 'Select mode and enter reason' USING ERRCODE='22023'; END IF;
  IF p_data->>'mode'='owner' AND NOT EXISTS(SELECT 1 FROM public.staff_profiles WHERE user_id=auth.uid() AND role='admin') THEN RAISE EXCEPTION 'Owner mode requires administrator approval' USING ERRCODE='42501'; END IF;
  UPDATE public.cafe_dining_tables SET pricing_mode=p_data->>'mode',updated_by=auth.uid() WHERE id=t.id;
 ELSE
  SELECT id INTO rid FROM public.cafe_service_requests WHERE id=(p_data->>'request_id')::uuid AND table_id=t.id AND status<>'completed' FOR UPDATE;
  IF rid IS NULL THEN RAISE EXCEPTION 'Request changed; refresh' USING ERRCODE='22023'; END IF;
  UPDATE public.cafe_service_requests SET status=CASE WHEN p_action='acknowledge' THEN 'acknowledged' ELSE 'completed' END,acknowledged_at=coalesce(acknowledged_at,now()),completed_at=CASE WHEN p_action='complete_request' THEN now() END,handled_by=auth.uid() WHERE id=rid;
 END IF;
 INSERT INTO public.cafe_table_activity(request_id,table_id,visit_id,actor_id,action,details) VALUES(p_request_id,t.id,v.id,auth.uid(),p_action,signature);
 RETURN jsonb_build_object('ok',true);
END;$$;
CREATE OR REPLACE FUNCTION cafe_private.table_overview() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE result jsonb;
BEGIN
 IF NOT (cafe_private.table_access('table_overview') OR cafe_private.table_access('live_tables') OR cafe_private.table_access('table_status') OR cafe_private.table_access('table_availability') OR cafe_private.table_access('table_session_management') OR cafe_private.table_access('table_service_requests') OR cafe_private.table_access('table_cleaning') OR cafe_private.table_access('waiter_table_assignment') OR cafe_private.table_access('table_transfer') OR cafe_private.table_access('table_history_audit') OR cafe_private.table_access('guest_check_in_no_show')) THEN RAISE EXCEPTION 'Table Overview permission required' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',t.id,'name',t.name,'area',t.area,'seats',t.seats,'status',t.status,'pricing_mode',t.pricing_mode,
 'cleaning_started_at',t.cleaning_started_at,'visit_id',v.id,'started_at',v.started_at,'guest_count',v.guest_count,
 'customer_name',CASE WHEN cafe_private.table_access('customer_details') THEN v.customer_name ELSE '' END,
 'contact',CASE WHEN cafe_private.table_access('customer_details') THEN v.contact ELSE '' END,'waiter_id',v.waiter_id,
 'waiter_name',(SELECT coalesce(email,user_id::text) FROM public.staff_profiles WHERE user_id=v.waiter_id),
 'order_count',(SELECT count(*) FROM public.cafe_table_orders o WHERE o.visit_id=v.id AND o.status<>'cancelled'),
 'pending_orders',(SELECT count(*) FROM public.cafe_table_orders o WHERE o.visit_id=v.id AND o.status IN ('received','preparing','ready')),
 'payment_status',CASE WHEN v.id IS NULL THEN '' WHEN (SELECT count(*) FROM public.cafe_table_orders o WHERE o.visit_id=v.id AND o.status<>'cancelled')=0 THEN 'No orders' WHEN (cafe_private.visit_bill(v.id)->>'balance_iqd')::bigint=0 THEN 'Paid — Still Seated' WHEN (cafe_private.visit_bill(v.id)->>'paid_iqd')::bigint>0 THEN 'Partially Paid' ELSE 'Unpaid' END,
 'requests',coalesce((SELECT jsonb_agg(jsonb_build_object('id',r.id,'kind',r.kind,'message',r.message,'status',r.status,'created_at',r.created_at) ORDER BY r.created_at) FROM public.cafe_service_requests r WHERE r.table_id=t.id AND r.status<>'completed'),'[]'::jsonb),
 'reservation',(SELECT jsonb_build_object('id',r.id,'starts_at',r.starts_at,'ends_at',r.ends_at,'party_size',r.party_size,'arrived_at',r.arrived_at) FROM public.cafe_table_reservations r WHERE r.table_id=t.id AND r.status='confirmed' AND r.ends_at>now() ORDER BY r.starts_at LIMIT 1)) ORDER BY t.name),'[]'::jsonb)
 INTO result FROM public.cafe_dining_tables t LEFT JOIN public.cafe_table_visits v ON v.table_id=t.id AND v.closed_at IS NULL;
 RETURN jsonb_build_object('server_time',now(),'tables',result,'capabilities',jsonb_build_object(
 'assign_waiter',cafe_private.table_access('waiter_table_assignment'),'transfer',cafe_private.table_access('table_transfer'),'history',cafe_private.table_access('table_history_audit'),
 'take',cafe_private.table_access('table_session_management'),'arrived',cafe_private.table_access('guest_check_in_no_show'),
 'close',cafe_private.table_access('table_session_management'),'ready',cafe_private.table_access('table_cleaning'),
 'mode',cafe_private.table_access('edit_manage_tables'),'service',cafe_private.table_access('table_service_requests'),
 'payments',public.has_workspace_access('payment_management','receive_payment'),
 'orders',public.has_workspace_access('tables_orders','table_ordering'),
 'bills',public.has_workspace_access('payment_management','payment_history') OR public.has_workspace_access('payment_management','receive_payment')));
END;$$;
CREATE FUNCTION cafe_private.table_staff() RETURNS SETOF jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT cafe_private.table_access('waiter_table_assignment') THEN RAISE EXCEPTION 'Assignment permission required' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT jsonb_build_object('id',user_id,'name',coalesce(email,user_id::text)) FROM public.staff_profiles WHERE role IN ('admin','staff') ORDER BY email;
END;$$;
CREATE FUNCTION cafe_private.table_history(p_table_id uuid) RETURNS SETOF jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT cafe_private.table_access('table_history_audit') THEN RAISE EXCEPTION 'History permission required' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT jsonb_build_object('id',a.id,'action',a.action,'created_at',a.created_at,'actor',coalesce(s.email,a.actor_id::text),'visit_id',a.visit_id,'reason',a.details->'data'->>'reason') FROM public.cafe_table_activity a LEFT JOIN public.staff_profiles s ON s.user_id=a.actor_id WHERE table_id=p_table_id ORDER BY a.created_at DESC LIMIT 200;
END;$$;
CREATE FUNCTION public.get_cafe_table_staff() RETURNS SETOF jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.table_staff() $$;
CREATE FUNCTION public.get_cafe_table_history(p_table_id uuid) RETURNS SETOF jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.table_history(p_table_id) $$;
REVOKE ALL ON FUNCTION cafe_private.table_staff(),cafe_private.table_history(uuid),public.get_cafe_table_staff(),public.get_cafe_table_history(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION cafe_private.table_staff(),cafe_private.table_history(uuid),public.get_cafe_table_staff(),public.get_cafe_table_history(uuid) TO authenticated;
CREATE OR REPLACE FUNCTION cafe_private.payment_balances()
RETURNS SETOF jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth AS $fn$
BEGIN
 IF auth.uid() IS NULL OR NOT (public.has_workspace_access('payment_management','receive_payment') OR public.has_workspace_access('payment_management','payment_history') OR public.has_workspace_access('payment_management','refunds_voids')) THEN RAISE EXCEPTION 'Payment access and MFA required' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT jsonb_build_object('id',o.id,'table_id',o.table_id,'visit_id',o.visit_id,'table_name',coalesce(t.name,nullif(o.destination,''),o.source),'source',o.source,'created_at',o.created_at,'total_iqd',o.total_iqd,'status',o.status,
   'paid_iqd',coalesce((SELECT sum(CASE WHEN p.kind='payment' THEN p.amount_iqd ELSE -p.amount_iqd END) FROM public.cafe_payments p WHERE p.order_id=o.id),0),
   'payments',coalesce((SELECT jsonb_agg(to_jsonb(p)-'created_by'-'request_id' ORDER BY p.created_at,p.id) FROM public.cafe_payments p WHERE p.order_id=o.id),'[]'::jsonb))
 FROM public.cafe_table_orders o LEFT JOIN public.cafe_dining_tables t ON t.id=o.table_id ORDER BY o.created_at DESC,o.id;
END;$fn$;
NOTIFY pgrst,'reload schema';


-- Source: 20261017021635_cafe_operational_reports.sql

CREATE TABLE public.cafe_menu_history(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, product_id uuid NOT NULL REFERENCES public.cafe_menu_items,actor_id uuid REFERENCES auth.users,occurred_at timestamptz NOT NULL DEFAULT now(),previous jsonb,current jsonb NOT NULL);
CREATE INDEX cafe_menu_history_product_idx ON public.cafe_menu_history(product_id,occurred_at DESC);
CREATE INDEX cafe_menu_history_actor_idx ON public.cafe_menu_history(actor_id);
ALTER TABLE public.cafe_menu_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_menu_history FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.cafe_menu_history FROM PUBLIC,anon,authenticated;
CREATE POLICY deny_direct ON public.cafe_menu_history AS RESTRICTIVE FOR ALL TO anon,authenticated USING(false) WITH CHECK(false);
CREATE FUNCTION cafe_private.log_menu_change() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF TG_OP='INSERT' OR (to_jsonb(OLD)-'updated_at'-'updated_by') IS DISTINCT FROM (to_jsonb(NEW)-'updated_at'-'updated_by') THEN
 INSERT INTO public.cafe_menu_history(product_id,actor_id,previous,current) VALUES(NEW.id,auth.uid(),CASE WHEN TG_OP='UPDATE' THEN to_jsonb(OLD)-'created_by'-'updated_by' END,to_jsonb(NEW)-'created_by'-'updated_by');
 END IF; RETURN NEW;
END;$$;
CREATE TRIGGER cafe_menu_change_history AFTER INSERT OR UPDATE ON public.cafe_menu_items FOR EACH ROW EXECUTE FUNCTION cafe_private.log_menu_change();
REVOKE ALL ON FUNCTION cafe_private.log_menu_change() FROM PUBLIC,anon,authenticated;

CREATE FUNCTION cafe_private.operational_report(p_section text,p_card text,p_from date,p_to date) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE report text; start_at timestamptz; end_at timestamptz; rows jsonb; columns jsonb; note text:=''; today date:=(now() AT TIME ZONE 'Asia/Baghdad')::date;
BEGIN
 SELECT kind INTO report FROM (VALUES ('dashboard','today_revenue','revenue'),
('dashboard','cash_received','revenue'),
('dashboard','daily_financial_summary','revenue'),
('dashboard','cash_payment_methods','revenue'),
('dashboard','sales_performance','revenue'),
('payment_management','today_revenue','revenue'),
('payment_management','revenue','revenue'),
('payment_management','payment_overview','revenue'),
('payment_management','collected_cash','revenue'),
('payment_management','table_income','revenue'),
('dashboard','pending_payment','unpaid'),
('payment_management','pending_payments','unpaid'),
('payment_management','pending_payment','unpaid'),
('dashboard','refunds_adjustments','refunds'),
('payment_management','refunds','refunds'),
('payment_management','invoices_receipts','receipts'),
('payment_management','invoices','receipts'),
('payment_management','invoices_payments','receipts'),
('dashboard','invoices','receipts'),
('dashboard','today_s_orders','orders'),
('dashboard','today_orders','orders'),
('dashboard','kitchen_orders','orders'),
('dashboard','motel_orders','orders'),
('dashboard','online_walk_in_orders','orders'),
('dashboard','orders_preparing','orders'),
('dashboard','ready_for_delivery','orders'),
('dashboard','delayed_orders','orders'),
('dashboard','table_orders','orders'),
('dashboard','motel_orders_tracking','orders'),
('dashboard','online_orders_tracking','orders'),
('dashboard','walk_in_orders_tracking','orders'),
('dashboard','online_orders','orders'),
('dashboard','kitchen_queue','orders'),
('motel_online_orders','motel_online_orders_overview','orders'),
('motel_online_orders','order_tracking','orders'),
('motel_online_orders','order_history','orders'),
('motel_online_orders','order_details','orders'),
('motel_online_orders','room_orders','orders'),
('motel_online_orders','ready_for_pickup','orders'),
('motel_online_orders','walk_in_order_history','orders'),
('customer_management','kitchen_overview','kitchen'),
('customer_management','kitchen_reports','kitchen'),
('customer_management','kitchen_performance_timing','kitchen'),
('customer_management','kitchen_priority_delays','kitchen'),
('dashboard','today_s_customers','visits'),
('dashboard','guests_today','visits'),
('dashboard','table_occupancy_reports','visits'),
('dashboard','table_occupancy','visits'),
('tables_orders','table_reports','visits'),
('kitchen_management','product_sales_performance','products'),
('kitchen_management','menu_reports','products'),
('kitchen_management','customer_favorites_popular_items','products'),
('dashboard','product_performance','products'),
('kitchen_management','price_change_history','menu_audit'),
('kitchen_management','menu_audit_history','menu_audit'),
('kitchen_management','revisions','menu_audit'),
('dashboard','audit_activity_history','audit'),
('dashboard','audit_activity','audit'),
('payment_management','audit','payment_audit')) allowed(section,card,kind) WHERE section=p_section AND card=p_card;
 IF report IS NULL OR NOT public.has_workspace_access(p_section,p_card) THEN RAISE EXCEPTION 'Report permission required' USING ERRCODE='42501'; END IF;
 IF p_from IS NULL OR p_to IS NULL OR p_to<p_from OR p_to-p_from>366 THEN RAISE EXCEPTION 'Choose a date range up to one year' USING ERRCODE='22023'; END IF;
 start_at:=p_from::timestamp AT TIME ZONE 'Asia/Baghdad'; end_at:=(p_to+1)::timestamp AT TIME ZONE 'Asia/Baghdad';
 IF report='revenue' THEN
  columns:='["Method","Payments IQD","Refunds IQD","Net received IQD"]';
  SELECT coalesce(jsonb_agg(jsonb_build_array(method,collected,refunded,collected-refunded)),'[]') INTO rows FROM (
   SELECT method,coalesce(sum(amount_iqd) FILTER(WHERE kind='payment'),0) collected,coalesce(sum(amount_iqd) FILTER(WHERE kind='refund'),0) refunded
   FROM public.cafe_payments WHERE created_at>=start_at AND created_at<end_at AND (p_card<>'collected_cash' OR method='cash') AND (p_card<>'table_income' OR EXISTS(SELECT 1 FROM public.cafe_table_orders o WHERE o.id=order_id AND o.source='table')) GROUP BY method ORDER BY method) s;
  note:='Confirmed receipts less recorded refunds. Cash drawer balances also require opening cash, expenses and transfers.';
 ELSIF report IN ('refunds','receipts','payment_audit') THEN
  columns:='["Transaction","Time (Baghdad)","Order","Kind","Method","Amount IQD","Reference"]';
  SELECT coalesce(jsonb_agg(jsonb_build_array(id,to_char(created_at AT TIME ZONE 'Asia/Baghdad','YYYY-MM-DD HH24:MI'),order_id,kind,method,amount_iqd,reference) ORDER BY created_at DESC),'[]') INTO rows FROM public.cafe_payments WHERE created_at>=start_at AND created_at<end_at AND (report<>'refunds' OR kind='refund');
  note:='Payment ledger entries; recorded receipts are not tax invoices. Original transactions remain unchanged after refunds.';
 ELSIF report='unpaid' THEN
  columns:='["Order","Table / destination","Source","Status","Charges IQD","Received IQD","Balance IQD"]';
  SELECT coalesce(jsonb_agg(jsonb_build_array(id,destination,source,status,total_iqd,paid,total_iqd-paid)),'[]') INTO rows FROM (
   SELECT o.id,coalesce(t.name,nullif(o.destination,''),o.source) destination,o.source,o.status,o.total_iqd,coalesce((SELECT sum(CASE WHEN p.kind='payment' THEN p.amount_iqd ELSE -p.amount_iqd END) FROM public.cafe_payments p WHERE p.order_id=o.id),0) paid FROM public.cafe_table_orders o LEFT JOIN public.cafe_dining_tables t ON t.id=o.table_id WHERE o.status<>'cancelled') s WHERE total_iqd>paid;
  note:='All currently outstanding orders, including older charges. Date filters do not hide unpaid balances.';
 ELSIF report IN ('orders','kitchen') THEN
  columns:='["Order","Created (Baghdad)","Source","Table / destination","Status","Mode","Total IQD","Minutes to ready"]';
  SELECT coalesce(jsonb_agg(jsonb_build_array(o.id,to_char(o.created_at AT TIME ZONE 'Asia/Baghdad','YYYY-MM-DD HH24:MI'),o.source,coalesce(t.name,nullif(o.destination,''),o.source),o.status,o.pricing_mode,o.total_iqd,round(extract(epoch FROM ((SELECT min(a.occurred_at) FROM public.cafe_table_order_audit a WHERE a.order_id=o.id AND a.action='ready')-o.created_at))/60,1)) ORDER BY o.created_at DESC),'[]') INTO rows FROM public.cafe_table_orders o LEFT JOIN public.cafe_dining_tables t ON t.id=o.table_id WHERE o.created_at>=start_at AND o.created_at<end_at
   AND (p_section<>'motel_online_orders' OR o.source IN ('motel','online','walk_in'))
   AND (p_card NOT IN ('motel_orders','motel_orders_tracking','room_orders') OR o.source='motel')
   AND (p_card NOT IN ('online_orders','online_orders_tracking') OR o.source='online')
   AND (p_card NOT IN ('walk_in_orders_tracking','walk_in_order_history','ready_for_pickup') OR o.source='walk_in')
   AND (p_card<>'online_walk_in_orders' OR o.source IN ('online','walk_in'))
   AND (p_card<>'table_orders' OR o.source='table')
   AND (p_card<>'orders_preparing' OR o.status='preparing')
   AND (p_card NOT IN ('ready_for_delivery','ready_for_pickup') OR o.status='ready')
   AND (p_card NOT IN ('delayed_orders','kitchen_priority_delays') OR (o.status IN ('received','preparing') AND o.created_at<now()-interval '30 minutes'));
  note:='Canonical orders and preparation timestamps. Delay view uses 30 minutes since receipt; cancelled orders remain visible in history.';
 ELSIF report='visits' THEN
  columns:='["Table","Visit","Guests","Started (Baghdad)","Closed (Baghdad)","Minutes in selected period"]';
  SELECT coalesce(jsonb_agg(jsonb_build_array(t.name,v.id,v.guest_count,to_char(v.started_at AT TIME ZONE 'Asia/Baghdad','YYYY-MM-DD HH24:MI'),to_char(v.closed_at AT TIME ZONE 'Asia/Baghdad','YYYY-MM-DD HH24:MI'),round(extract(epoch FROM (least(coalesce(v.closed_at,now()),end_at)-greatest(v.started_at,start_at)))/60,1)) ORDER BY v.started_at DESC),'[]') INTO rows FROM public.cafe_table_visits v JOIN public.cafe_dining_tables t ON t.id=v.table_id WHERE v.started_at<end_at AND coalesce(v.closed_at,now())>=start_at;
  note:='Recorded visits, including visits spanning the selected dates. Anonymous parties are counted by their recorded guest count.';
 ELSIF report='products' THEN
  columns:='["Product","Quantity served","Served order value IQD"]';
  SELECT coalesce(jsonb_agg(jsonb_build_array(name,qty,value) ORDER BY qty DESC),'[]') INTO rows FROM (
   SELECT i.item_name name,sum(i.quantity) qty,sum(i.line_total_iqd) value FROM public.cafe_table_order_items i JOIN public.cafe_table_orders o ON o.id=i.order_id WHERE o.status='served' AND o.created_at>=start_at AND o.created_at<end_at GROUP BY i.menu_item_id,i.item_name) s;
  note:='Products from served orders only. Popularity is based on quantities served; no customer favorites are inferred.';
 ELSIF report='menu_audit' THEN
  columns:='["Changed (Baghdad)","Product","Previous normal","Normal","Tourism","Owner","Available"]';
  SELECT coalesce(jsonb_agg(jsonb_build_array(to_char(occurred_at AT TIME ZONE 'Asia/Baghdad','YYYY-MM-DD HH24:MI'),current->>'name',previous->>'price_iqd',current->>'price_iqd',current->>'tourism_price_iqd',current->>'owner_price_iqd',current->>'available') ORDER BY occurred_at DESC),'[]') INTO rows FROM public.cafe_menu_history WHERE occurred_at>=start_at AND occurred_at<end_at;
  note:='Audited changes recorded since menu history was enabled. Earlier changes are not reconstructed.';
 ELSE
  columns:='["Time (Baghdad)","Type","Action","Record","Actor"]';
  SELECT coalesce(jsonb_agg(jsonb_build_array(to_char(at_time AT TIME ZONE 'Asia/Baghdad','YYYY-MM-DD HH24:MI'),kind,action,id,actor) ORDER BY at_time DESC),'[]') INTO rows FROM (
   SELECT occurred_at at_time,'Order' kind,action,order_id::text id,actor_id::text actor FROM public.cafe_table_order_audit WHERE occurred_at>=start_at AND occurred_at<end_at
   UNION ALL SELECT created_at,'Table',action,table_id::text,actor_id::text FROM public.cafe_table_activity WHERE created_at>=start_at AND created_at<end_at) s;
 END IF;
 RETURN jsonb_build_object('columns',columns,'rows',rows,'note',note,'generated_at',now(),'from',p_from,'to',p_to);
END;$$;
CREATE FUNCTION public.get_cafe_operational_report(p_section text,p_card text,p_from date,p_to date) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.operational_report(p_section,p_card,p_from,p_to) $$;
REVOKE ALL ON FUNCTION cafe_private.operational_report(text,text,date,date),public.get_cafe_operational_report(text,text,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION cafe_private.operational_report(text,text,date,date),public.get_cafe_operational_report(text,text,date,date) TO authenticated;
NOTIFY pgrst,'reload schema';


-- Source: 20261017022241_cafe_cash_journal.sql

CREATE TABLE public.cafe_cash_journal(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),request_id uuid NOT NULL UNIQUE,kind text NOT NULL CHECK(kind IN ('cash_in','cash_out','expense')),
 amount_iqd bigint NOT NULL CHECK(amount_iqd BETWEEN 1 AND 999999999999),method text NOT NULL CHECK(method IN ('cash','manual_card')),
 reason text NOT NULL CHECK(length(trim(reason)) BETWEEN 3 AND 500),status text NOT NULL CHECK(status IN ('pending','posted','rejected')),
 created_by uuid NOT NULL REFERENCES auth.users,created_at timestamptz NOT NULL DEFAULT now(),reviewed_by uuid REFERENCES auth.users,reviewed_at timestamptz,review_reason text);
CREATE INDEX cafe_cash_journal_creator_idx ON public.cafe_cash_journal(created_by);
CREATE INDEX cafe_cash_journal_reviewer_idx ON public.cafe_cash_journal(reviewed_by);
CREATE TABLE public.cafe_cash_counts(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),request_id uuid NOT NULL UNIQUE,expected_iqd bigint NOT NULL,counted_iqd bigint NOT NULL CHECK(counted_iqd BETWEEN 0 AND 999999999999),reason text NOT NULL CHECK(length(reason) BETWEEN 3 AND 500),created_by uuid NOT NULL REFERENCES auth.users,created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX cafe_cash_counts_creator_idx ON public.cafe_cash_counts(created_by);
DO $rls$ DECLARE t text; BEGIN FOREACH t IN ARRAY ARRAY['cafe_cash_journal','cafe_cash_counts'] LOOP
 EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY',t);
 EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated',t);
 EXECUTE format('CREATE POLICY deny_direct ON public.%I AS RESTRICTIVE FOR ALL TO anon,authenticated USING(false) WITH CHECK(false)',t);
END LOOP; END;$rls$;
CREATE FUNCTION cafe_private.cash_allowed(p_action text) RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
SELECT CASE p_action
 WHEN 'cash_in' THEN public.has_workspace_access('dashboard','cash_in')
 WHEN 'cash_out' THEN public.has_workspace_access('dashboard','cash_out_owner') OR public.has_workspace_access('payment_management','owner_cash_out')
 WHEN 'expense' THEN public.has_workspace_access('dashboard','expenses') OR public.has_workspace_access('payment_management','expenses_management') OR public.has_workspace_access('payment_management','expenses') OR public.has_workspace_access('payment_management','costs_expenses')
 WHEN 'count' THEN public.has_workspace_access('dashboard','cash_reconciliation') OR public.has_workspace_access('payment_management','cash_reconciliation') OR public.has_workspace_access('payment_management','cash_over_short')
 WHEN 'approve' THEN public.has_workspace_access('payment_management','approvals')
 ELSE false END;
$$;
REVOKE ALL ON FUNCTION cafe_private.cash_allowed(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION cafe_private.cash_allowed(text) TO authenticated;
CREATE FUNCTION cafe_private.recorded_cash_balance() RETURNS bigint LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
SELECT coalesce((SELECT sum(CASE WHEN kind='payment' THEN amount_iqd ELSE -amount_iqd END) FROM public.cafe_payments WHERE method='cash'),0)::bigint
 +coalesce((SELECT sum(CASE WHEN kind='cash_in' THEN amount_iqd ELSE -amount_iqd END) FROM public.cafe_cash_journal WHERE status='posted' AND method='cash'),0)::bigint;
$$;
REVOKE ALL ON FUNCTION cafe_private.recorded_cash_balance() FROM PUBLIC,anon,authenticated;
CREATE FUNCTION cafe_private.lock_cash_posting() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$ BEGIN IF NEW.method='cash' THEN PERFORM pg_advisory_xact_lock(74210919); END IF; RETURN NEW; END;$$;
CREATE TRIGGER cafe_payment_cash_lock BEFORE INSERT ON public.cafe_payments FOR EACH ROW EXECUTE FUNCTION cafe_private.lock_cash_posting();
REVOKE ALL ON FUNCTION cafe_private.lock_cash_posting() FROM PUBLIC,anon,authenticated;

CREATE FUNCTION cafe_private.cash_workspace(p_section text,p_card text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE result jsonb;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM (VALUES ('dashboard','standing_cash'),('dashboard','cash_out_owner'),('dashboard','expenses'),('dashboard','remaining_cash'),('dashboard','cash_in'),('dashboard','pending_expenses'),('dashboard','expected_vs_actual_cash'),('dashboard','financial_alerts'),('dashboard','cash_reconciliation'),('payment_management','standing_cash'),('payment_management','available_cash'),('payment_management','owner_cash_out'),('payment_management','expenses_management'),('payment_management','expenses'),('payment_management','costs_expenses'),('payment_management','cash_over_short'),('payment_management','cash_reconciliation'),('payment_management','approvals')) a(section,card) WHERE section=p_section AND card=p_card) OR NOT public.has_workspace_access(p_section,p_card) THEN RAISE EXCEPTION 'Cash workspace permission required' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('balance_iqd',cafe_private.recorded_cash_balance(),
 'entries',coalesce((SELECT jsonb_agg(to_jsonb(j)-'request_id' ORDER BY created_at DESC) FROM (SELECT * FROM public.cafe_cash_journal ORDER BY created_at DESC LIMIT 500) j),'[]'::jsonb),
 'counts',coalesce((SELECT jsonb_agg(to_jsonb(c)-'request_id' ORDER BY created_at DESC) FROM (SELECT * FROM public.cafe_cash_counts ORDER BY created_at DESC LIMIT 100)c),'[]'::jsonb),
 'capabilities',jsonb_build_object('cash_in',cafe_private.cash_allowed('cash_in'),'cash_out',cafe_private.cash_allowed('cash_out'),'expense',cafe_private.cash_allowed('expense'),'count',cafe_private.cash_allowed('count'),'approve',cafe_private.cash_allowed('approve')));
END;$$;
CREATE FUNCTION cafe_private.submit_cash(p_request_id uuid,p_kind text,p_amount bigint,p_method text,p_reason text) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE e public.cafe_cash_journal; c public.cafe_cash_counts; new_id uuid; balance bigint;
BEGIN
 IF NOT cafe_private.cash_allowed(p_kind) THEN RAISE EXCEPTION 'Cash action permission required' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL OR p_amount IS NULL OR p_amount<(CASE WHEN p_kind='count' THEN 0 ELSE 1 END) OR p_amount>999999999999 OR length(trim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500 OR p_method NOT IN ('cash','manual_card') OR (p_kind<>'expense' AND p_method<>'cash') THEN RAISE EXCEPTION 'Enter a valid amount, method and reason' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,71));
 PERFORM pg_advisory_xact_lock(74210919);
 IF p_kind='count' THEN
  SELECT * INTO c FROM public.cafe_cash_counts WHERE request_id=p_request_id;
  IF FOUND THEN IF c.created_by=auth.uid() AND c.counted_iqd=p_amount AND c.reason=trim(p_reason) THEN RETURN c.id; END IF; RAISE EXCEPTION 'Request reused' USING ERRCODE='23505'; END IF;
  balance:=cafe_private.recorded_cash_balance();
  INSERT INTO public.cafe_cash_counts(request_id,expected_iqd,counted_iqd,reason,created_by) VALUES(p_request_id,balance,p_amount,trim(p_reason),auth.uid()) RETURNING id INTO new_id;
 ELSE
  SELECT * INTO e FROM public.cafe_cash_journal WHERE request_id=p_request_id;
  IF FOUND THEN IF e.created_by=auth.uid() AND e.kind=p_kind AND e.amount_iqd=p_amount AND e.method=p_method AND e.reason=trim(p_reason) THEN RETURN e.id; END IF; RAISE EXCEPTION 'Request reused' USING ERRCODE='23505'; END IF;
  INSERT INTO public.cafe_cash_journal(request_id,kind,amount_iqd,method,reason,status,created_by) VALUES(p_request_id,p_kind,p_amount,p_method,trim(p_reason),CASE WHEN p_kind='cash_in' THEN 'posted' ELSE 'pending' END,auth.uid()) RETURNING id INTO new_id;
 END IF;
 RETURN new_id;
END;$$;
CREATE FUNCTION cafe_private.review_cash(p_id uuid,p_approve boolean,p_reason text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE e public.cafe_cash_journal; admin boolean;
BEGIN
 IF NOT cafe_private.cash_allowed('approve') THEN RAISE EXCEPTION 'Cash approval permission required' USING ERRCODE='42501'; END IF;
 IF p_approve IS NULL OR length(trim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'Review reason required' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(74210919);
 SELECT * INTO e FROM public.cafe_cash_journal WHERE id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Entry missing' USING ERRCODE='22023'; END IF;
 IF e.status<>'pending' THEN
  IF e.status=(CASE WHEN p_approve THEN 'posted' ELSE 'rejected' END) AND e.reviewed_by=auth.uid() AND e.review_reason=trim(p_reason) THEN RETURN; END IF;
  RAISE EXCEPTION 'Entry already reviewed; refresh' USING ERRCODE='22023';
 END IF;
 SELECT EXISTS(SELECT 1 FROM public.staff_profiles WHERE user_id=auth.uid() AND role='admin') INTO admin;
 IF p_approve AND (e.kind='cash_out' OR e.created_by=auth.uid()) AND NOT admin THEN RAISE EXCEPTION 'Administrator approval required for owner withdrawal or own request' USING ERRCODE='42501'; END IF;
 IF p_approve AND e.method='cash' AND e.amount_iqd>cafe_private.recorded_cash_balance() THEN RAISE EXCEPTION 'Insufficient recorded cash; record opening cash or missing receipts first' USING ERRCODE='22023'; END IF;
 UPDATE public.cafe_cash_journal SET status=CASE WHEN p_approve THEN 'posted' ELSE 'rejected' END,reviewed_by=auth.uid(),reviewed_at=now(),review_reason=trim(p_reason) WHERE id=e.id;
END;$$;
CREATE FUNCTION public.get_cafe_cash_workspace(p_section text,p_card text) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.cash_workspace(p_section,p_card) $$;
CREATE FUNCTION public.submit_cafe_cash_entry(p_request_id uuid,p_kind text,p_amount bigint,p_method text,p_reason text) RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.submit_cash(p_request_id,p_kind,p_amount,p_method,p_reason) $$;
CREATE FUNCTION public.review_cafe_cash_entry(p_id uuid,p_approve boolean,p_reason text) RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.review_cash(p_id,p_approve,p_reason) $$;
REVOKE ALL ON FUNCTION cafe_private.cash_workspace(text,text),cafe_private.submit_cash(uuid,text,bigint,text,text),cafe_private.review_cash(uuid,boolean,text),public.get_cafe_cash_workspace(text,text),public.submit_cafe_cash_entry(uuid,text,bigint,text,text),public.review_cafe_cash_entry(uuid,boolean,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION cafe_private.cash_workspace(text,text),cafe_private.submit_cash(uuid,text,bigint,text,text),cafe_private.review_cash(uuid,boolean,text),public.get_cafe_cash_workspace(text,text),public.submit_cafe_cash_entry(uuid,text,bigint,text,text),public.review_cafe_cash_entry(uuid,boolean,text) TO authenticated;
NOTIFY pgrst,'reload schema';


-- Source: 20261017022701_cafe_guest_order_tracking.sql

CREATE OR REPLACE FUNCTION cafe_private.guest_portal(p_qr_token uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE context jsonb; t uuid; v uuid;
BEGIN
 context:=public.get_cafe_guest_table_context(p_qr_token);
 t:=(context->'table'->>'id')::uuid;
 SELECT id INTO v FROM public.cafe_table_visits WHERE table_id=t AND closed_at IS NULL;
 RETURN context||jsonb_build_object('server_time',now(),'visit_id',v,
 'menu',coalesce((SELECT jsonb_agg(to_jsonb(m)) FROM cafe_private.get_cafe_guest_menu(p_qr_token) m),'[]'::jsonb),
 'orders',coalesce((SELECT jsonb_agg(public.cafe_table_order_payload(o.id)||jsonb_build_object('updated_at',o.updated_at) ORDER BY o.created_at DESC) FROM public.cafe_table_orders o WHERE o.visit_id=v),'[]'::jsonb),
 'bill',CASE WHEN v IS NOT NULL THEN cafe_private.visit_bill(v) ELSE jsonb_build_object('orders','[]'::jsonb,'total_iqd',0,'paid_iqd',0,'balance_iqd',0) END,
 'requests',coalesce((SELECT jsonb_agg(jsonb_build_object('id',r.id,'kind',r.kind,'status',r.status,'created_at',r.created_at) ORDER BY r.created_at DESC) FROM public.cafe_service_requests r WHERE r.table_id=t AND r.visit_id=v AND r.created_at>now()-interval '24 hours'),'[]'::jsonb));
END;$$;
NOTIFY pgrst,'reload schema';


-- Source: 20261017022808_cafe_unpaid_expenses.sql

CREATE TABLE public.cafe_supplier_expenses(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),request_id uuid NOT NULL UNIQUE,supplier text NOT NULL CHECK(length(trim(supplier)) BETWEEN 1 AND 160),
 description text NOT NULL CHECK(length(trim(description)) BETWEEN 3 AND 1000),invoice_reference text NOT NULL DEFAULT '' CHECK(length(invoice_reference)<=160),
 amount_iqd bigint NOT NULL CHECK(amount_iqd BETWEEN 1 AND 999999999999),purchased_on date NOT NULL,due_on date,
 created_by uuid NOT NULL REFERENCES auth.users,created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX cafe_supplier_expenses_creator_idx ON public.cafe_supplier_expenses(created_by);
CREATE TABLE public.cafe_expense_payments(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),request_id uuid NOT NULL UNIQUE,expense_id uuid NOT NULL REFERENCES public.cafe_supplier_expenses,
 amount_iqd bigint NOT NULL CHECK(amount_iqd>0),method text NOT NULL CHECK(method IN ('cash','manual_card')),reference text NOT NULL DEFAULT '',
 journal_id uuid NOT NULL UNIQUE REFERENCES public.cafe_cash_journal,created_by uuid NOT NULL REFERENCES auth.users,created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX cafe_expense_payments_expense_idx ON public.cafe_expense_payments(expense_id);
CREATE INDEX cafe_expense_payments_creator_idx ON public.cafe_expense_payments(created_by);
CREATE TABLE public.cafe_expense_evidence(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),request_id uuid NOT NULL UNIQUE,expense_id uuid NOT NULL REFERENCES public.cafe_supplier_expenses,
 file_name text NOT NULL CHECK(length(file_name) BETWEEN 1 AND 200),object_path text NOT NULL UNIQUE,mime_type text NOT NULL CHECK(mime_type IN ('application/pdf','image/jpeg','image/png')),
 size_bytes int NOT NULL CHECK(size_bytes BETWEEN 1 AND 10485760),uploaded boolean NOT NULL DEFAULT false,
 created_by uuid NOT NULL REFERENCES auth.users,created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX cafe_expense_evidence_expense_idx ON public.cafe_expense_evidence(expense_id);
CREATE INDEX cafe_expense_evidence_creator_idx ON public.cafe_expense_evidence(created_by);
DO $rls$ DECLARE t text; BEGIN FOREACH t IN ARRAY ARRAY['cafe_supplier_expenses','cafe_expense_payments','cafe_expense_evidence'] LOOP
 EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t); EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY',t);
 EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated',t);
 EXECUTE format('CREATE POLICY deny_direct ON public.%I AS RESTRICTIVE FOR ALL TO anon,authenticated USING(false) WITH CHECK(false)',t);
END LOOP; END;$rls$;
CREATE FUNCTION cafe_private.expense_access(p_write boolean DEFAULT false) RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT public.has_workspace_access('payment_management','unpaid_expenses') OR public.has_workspace_access('payment_management','expenses_management') OR public.has_workspace_access('payment_management','expenses') OR public.has_workspace_access('payment_management','costs_expenses')
 OR (NOT p_write AND (public.has_workspace_access('dashboard','accounts_payable') OR public.has_workspace_access('dashboard','pending_expenses') OR public.has_workspace_access('payment_management','expense_payments')));
$$;
REVOKE ALL ON FUNCTION cafe_private.expense_access(boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION cafe_private.expense_access(boolean) TO authenticated;
CREATE FUNCTION cafe_private.expense_workspace() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT cafe_private.expense_access(false) THEN RAISE EXCEPTION 'Expense permission required' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('can_create',cafe_private.expense_access(true),'can_pay',public.has_workspace_access('payment_management','expense_payments'),
 'expenses',coalesce((SELECT jsonb_agg(to_jsonb(e)-'request_id'||jsonb_build_object(
 'paid_iqd',coalesce((SELECT sum(p.amount_iqd) FROM public.cafe_expense_payments p WHERE p.expense_id=e.id),0),
 'payments',coalesce((SELECT jsonb_agg(to_jsonb(p)-'request_id'-'created_by' ORDER BY p.created_at) FROM public.cafe_expense_payments p WHERE p.expense_id=e.id),'[]'::jsonb),
 'evidence',coalesce((SELECT jsonb_agg(to_jsonb(a)-'request_id'-'created_by' ORDER BY a.created_at) FROM public.cafe_expense_evidence a WHERE a.expense_id=e.id AND a.uploaded),'[]'::jsonb)) ORDER BY e.created_at DESC) FROM public.cafe_supplier_expenses e),'[]'::jsonb));
END;$$;
CREATE FUNCTION cafe_private.create_expense(p_request_id uuid,p_supplier text,p_description text,p_reference text,p_amount bigint,p_purchased date,p_due date) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE e public.cafe_supplier_expenses; result uuid;
BEGIN
 IF NOT cafe_private.expense_access(true) THEN RAISE EXCEPTION 'Expense creation permission required' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL OR length(trim(coalesce(p_supplier,''))) NOT BETWEEN 1 AND 160 OR length(trim(coalesce(p_description,''))) NOT BETWEEN 3 AND 1000 OR length(coalesce(p_reference,''))>160 OR p_amount IS NULL OR p_amount NOT BETWEEN 1 AND 999999999999 OR p_purchased IS NULL OR (p_due IS NOT NULL AND p_due<p_purchased) THEN RAISE EXCEPTION 'Invalid purchase details' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,72));
 SELECT * INTO e FROM public.cafe_supplier_expenses WHERE request_id=p_request_id;
 IF FOUND THEN IF e.created_by=auth.uid() AND e.supplier=trim(p_supplier) AND e.description=trim(p_description) AND e.invoice_reference=trim(coalesce(p_reference,'')) AND e.amount_iqd=p_amount AND e.purchased_on=p_purchased AND e.due_on IS NOT DISTINCT FROM p_due THEN RETURN e.id; END IF; RAISE EXCEPTION 'Request reused' USING ERRCODE='23505'; END IF;
 INSERT INTO public.cafe_supplier_expenses(request_id,supplier,description,invoice_reference,amount_iqd,purchased_on,due_on,created_by) VALUES(p_request_id,trim(p_supplier),trim(p_description),trim(coalesce(p_reference,'')),p_amount,p_purchased,p_due,auth.uid()) RETURNING id INTO result;
 RETURN result;
END;$$;
CREATE FUNCTION cafe_private.pay_expense(p_request_id uuid,p_expense_id uuid,p_amount bigint,p_method text,p_reference text) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE e public.cafe_supplier_expenses; p public.cafe_expense_payments; paid bigint; j uuid; result uuid;
BEGIN
 IF NOT public.has_workspace_access('payment_management','expense_payments') THEN RAISE EXCEPTION 'Expense payment permission required' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL OR p_amount IS NULL OR p_amount<1 OR p_method IS NULL OR p_method NOT IN ('cash','manual_card') OR length(coalesce(p_reference,''))>500 OR (p_method='manual_card' AND length(trim(coalesce(p_reference,'')))<3) THEN RAISE EXCEPTION 'Enter payment amount, method and card reference when required' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,73));
 SELECT * INTO p FROM public.cafe_expense_payments WHERE request_id=p_request_id;
 IF FOUND THEN IF p.created_by=auth.uid() AND p.expense_id=p_expense_id AND p.amount_iqd=p_amount AND p.method=p_method AND p.reference=trim(coalesce(p_reference,'')) THEN RETURN p.id; END IF; RAISE EXCEPTION 'Request reused' USING ERRCODE='23505'; END IF;
 SELECT * INTO e FROM public.cafe_supplier_expenses WHERE id=p_expense_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Expense missing' USING ERRCODE='22023'; END IF;
 SELECT coalesce(sum(amount_iqd),0) INTO paid FROM public.cafe_expense_payments WHERE expense_id=e.id;
 IF p_amount>e.amount_iqd-paid THEN RAISE EXCEPTION 'Payment exceeds unpaid amount' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(74210919);
 IF p_method='cash' AND p_amount>cafe_private.recorded_cash_balance() THEN RAISE EXCEPTION 'Insufficient recorded cash' USING ERRCODE='22023'; END IF;
 INSERT INTO public.cafe_cash_journal(request_id,kind,amount_iqd,method,reason,status,created_by,reviewed_by,reviewed_at,review_reason)
 VALUES(p_request_id,'expense',p_amount,p_method,'Supplier expense '||e.id::text||' · '||left(e.supplier,160),'posted',auth.uid(),auth.uid(),now(),'Confirmed expense payment') RETURNING id INTO j;
 INSERT INTO public.cafe_expense_payments(request_id,expense_id,amount_iqd,method,reference,journal_id,created_by) VALUES(p_request_id,e.id,p_amount,p_method,trim(coalesce(p_reference,'')),j,auth.uid()) RETURNING id INTO result;
 RETURN result;
END;$$;
CREATE FUNCTION cafe_private.prepare_expense_evidence(p_request_id uuid,p_expense_id uuid,p_name text,p_mime text,p_size int) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a public.cafe_expense_evidence; ext text;
BEGIN
 IF NOT cafe_private.expense_access(true) THEN RAISE EXCEPTION 'Evidence upload permission required' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL OR length(trim(coalesce(p_name,''))) NOT BETWEEN 1 AND 200 OR p_size IS NULL OR p_size NOT BETWEEN 1 AND 10485760 OR p_mime IS NULL OR p_mime NOT IN ('application/pdf','image/jpeg','image/png') OR NOT EXISTS(SELECT 1 FROM public.cafe_supplier_expenses WHERE id=p_expense_id) THEN RAISE EXCEPTION 'Use a PDF, JPEG or PNG up to 10 MB for a saved expense' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,74));
 SELECT * INTO a FROM public.cafe_expense_evidence WHERE request_id=p_request_id;
 IF FOUND THEN IF a.created_by=auth.uid() AND a.expense_id=p_expense_id AND a.file_name=trim(p_name) AND a.size_bytes=p_size AND a.mime_type=p_mime THEN RETURN jsonb_build_object('id',a.id,'path',a.object_path); END IF; RAISE EXCEPTION 'Request reused' USING ERRCODE='23505'; END IF;
 ext:=CASE p_mime WHEN 'application/pdf' THEN '.pdf' WHEN 'image/jpeg' THEN '.jpg' ELSE '.png' END;
 INSERT INTO public.cafe_expense_evidence(request_id,expense_id,file_name,object_path,mime_type,size_bytes,created_by)
 VALUES(p_request_id,p_expense_id,trim(p_name),auth.uid()::text||'/'||p_expense_id::text||'/'||gen_random_uuid()::text||ext,p_mime,p_size,auth.uid()) RETURNING * INTO a;
 RETURN jsonb_build_object('id',a.id,'path',a.object_path);
END;$$;
CREATE FUNCTION cafe_private.finish_expense_evidence(p_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a public.cafe_expense_evidence;
BEGIN
 IF NOT cafe_private.expense_access(true) THEN RAISE EXCEPTION 'Evidence upload permission required' USING ERRCODE='42501'; END IF;
 SELECT * INTO a FROM public.cafe_expense_evidence WHERE id=p_id AND created_by=auth.uid() FOR UPDATE;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='cafe-expense-evidence' AND name=a.object_path AND (metadata->>'size')::bigint=a.size_bytes) THEN RAISE EXCEPTION 'Upload has not completed; retry upload' USING ERRCODE='22023'; END IF;
 UPDATE public.cafe_expense_evidence SET uploaded=true WHERE id=a.id;
END;$$;
CREATE FUNCTION cafe_private.expense_object_allowed(p_path text,p_write boolean) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT cafe_private.expense_access(p_write) AND EXISTS(SELECT 1 FROM public.cafe_expense_evidence a WHERE a.object_path=p_path AND (NOT p_write OR (a.created_by=auth.uid() AND NOT a.uploaded)));
$$;
REVOKE ALL ON FUNCTION cafe_private.expense_object_allowed(text,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION cafe_private.expense_object_allowed(text,boolean) TO authenticated;
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES('cafe-expense-evidence','cafe-expense-evidence',false,10485760,ARRAY['application/pdf','image/jpeg','image/png']);
CREATE POLICY cafe_expense_evidence_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='cafe-expense-evidence' AND cafe_private.expense_object_allowed(name,true));
CREATE POLICY cafe_expense_evidence_select ON storage.objects FOR SELECT TO authenticated USING(bucket_id='cafe-expense-evidence' AND cafe_private.expense_object_allowed(name,false));
CREATE FUNCTION public.get_cafe_expenses() RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.expense_workspace() $$;
CREATE FUNCTION public.create_cafe_expense(p_request_id uuid,p_supplier text,p_description text,p_reference text,p_amount bigint,p_purchased date,p_due date) RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.create_expense(p_request_id,p_supplier,p_description,p_reference,p_amount,p_purchased,p_due) $$;
CREATE FUNCTION public.pay_cafe_expense(p_request_id uuid,p_expense_id uuid,p_amount bigint,p_method text,p_reference text) RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.pay_expense(p_request_id,p_expense_id,p_amount,p_method,p_reference) $$;
CREATE FUNCTION public.prepare_cafe_expense_evidence(p_request_id uuid,p_expense_id uuid,p_name text,p_mime text,p_size int) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.prepare_expense_evidence(p_request_id,p_expense_id,p_name,p_mime,p_size) $$;
CREATE FUNCTION public.finish_cafe_expense_evidence(p_id uuid) RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.finish_expense_evidence(p_id) $$;
REVOKE ALL ON FUNCTION cafe_private.expense_workspace(),cafe_private.create_expense(uuid,text,text,text,bigint,date,date),cafe_private.pay_expense(uuid,uuid,bigint,text,text),cafe_private.prepare_expense_evidence(uuid,uuid,text,text,int),cafe_private.finish_expense_evidence(uuid),public.get_cafe_expenses(),public.create_cafe_expense(uuid,text,text,text,bigint,date,date),public.pay_cafe_expense(uuid,uuid,bigint,text,text),public.prepare_cafe_expense_evidence(uuid,uuid,text,text,int),public.finish_cafe_expense_evidence(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION cafe_private.expense_workspace(),cafe_private.create_expense(uuid,text,text,text,bigint,date,date),cafe_private.pay_expense(uuid,uuid,bigint,text,text),cafe_private.prepare_expense_evidence(uuid,uuid,text,text,int),cafe_private.finish_expense_evidence(uuid),public.get_cafe_expenses(),public.create_cafe_expense(uuid,text,text,text,bigint,date,date),public.pay_cafe_expense(uuid,uuid,bigint,text,text),public.prepare_cafe_expense_evidence(uuid,uuid,text,text,int),public.finish_cafe_expense_evidence(uuid) TO authenticated;
NOTIFY pgrst,'reload schema';


-- Source: 20261017024346_cafe_menu_print_stations.sql

CREATE TABLE public.cafe_print_stations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 60),
 active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX cafe_print_station_name ON public.cafe_print_stations(lower(trim(name)));
INSERT INTO public.cafe_print_stations(name) VALUES('Kitchen'),('Minibar');
CREATE TABLE public.cafe_product_stations (
 product_id uuid NOT NULL REFERENCES public.cafe_menu_items(id), station_id uuid NOT NULL REFERENCES public.cafe_print_stations(id), PRIMARY KEY(product_id,station_id)
);
CREATE INDEX cafe_product_stations_station ON public.cafe_product_stations(station_id);
CREATE TABLE public.cafe_station_tickets (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), item_id bigint NOT NULL REFERENCES public.cafe_table_order_items(id),
 station_id uuid NOT NULL REFERENCES public.cafe_print_stations(id), station_name text NOT NULL,
 event text NOT NULL CHECK(event IN ('new','cancelled')), created_at timestamptz NOT NULL DEFAULT now(),
 confirmed_at timestamptz, confirmed_by uuid REFERENCES auth.users(id), UNIQUE(item_id,station_id,event)
);
CREATE INDEX cafe_station_tickets_station ON public.cafe_station_tickets(station_id,created_at);
CREATE INDEX cafe_station_tickets_actor ON public.cafe_station_tickets(confirmed_by);
DO $$ DECLARE n text; BEGIN FOREACH n IN ARRAY ARRAY['cafe_print_stations','cafe_product_stations','cafe_station_tickets'] LOOP
 EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',n);
 EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY',n);
 EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated',n);
 EXECUTE format('CREATE POLICY rpc_only ON public.%I AS RESTRICTIVE FOR ALL TO anon,authenticated USING(false) WITH CHECK(false)',n);
END LOOP; END $$;

CREATE FUNCTION cafe_private.print_access(p_manage boolean DEFAULT false) RETURNS boolean LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT auth.uid() IS NOT NULL AND auth.jwt()->>'aal'='aal2' AND
 (public.has_workspace_access('kitchen_management','product_printing_routing') OR
 public.has_workspace_access('customer_management','kitchen_stations_management') OR
 (NOT p_manage AND (public.has_workspace_access('customer_management','kitchen_printing_management') OR public.has_workspace_access('customer_management','minibar_printing_management'))));
$$;
CREATE FUNCTION cafe_private.print_station_list() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT (cafe_private.print_access() OR public.has_workspace_access('kitchen_management','add_new_product') OR public.has_workspace_access('kitchen_management','edit_manage_products')) THEN RAISE EXCEPTION 'Menu or station access required' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('can_manage',cafe_private.print_access(true),'stations',(SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.name),'[]') FROM public.cafe_print_stations s));
END; $$;
CREATE FUNCTION cafe_private.save_print_station(p_id uuid,p_name text,p_active boolean) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE result uuid;
BEGIN
 IF NOT cafe_private.print_access(true) THEN RAISE EXCEPTION 'Station management permission required' USING ERRCODE='42501'; END IF;
 IF length(trim(coalesce(p_name,''))) NOT BETWEEN 1 AND 60 OR p_active IS NULL THEN RAISE EXCEPTION 'Enter station name' USING ERRCODE='22023'; END IF;
 IF p_id IS NULL THEN INSERT INTO public.cafe_print_stations(name,active) VALUES(trim(p_name),p_active) RETURNING id INTO result;
 ELSE
 PERFORM 1 FROM public.cafe_print_stations WHERE id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Station not found' USING ERRCODE='22023'; END IF;
 IF NOT p_active AND EXISTS(SELECT 1 FROM public.cafe_product_stations ps JOIN public.cafe_menu_items m ON m.id=ps.product_id WHERE ps.station_id=p_id AND m.available) THEN RAISE EXCEPTION 'Remove this station from available products before disabling it' USING ERRCODE='22023'; END IF;
 UPDATE public.cafe_print_stations SET name=trim(p_name),active=p_active WHERE id=p_id RETURNING id INTO result;
 END IF; RETURN result;
END; $$;
CREATE FUNCTION cafe_private.save_menu_routed(p_id uuid,p_name text,p_category text,p_description text,p_price_iqd bigint,p_available boolean,p_tourism_price_iqd bigint,p_owner_price_iqd bigint,p_station_ids uuid[]) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE saved public.cafe_menu_items; station uuid;
BEGIN
 IF p_station_ids IS NULL OR cardinality(p_station_ids) NOT BETWEEN 1 AND 10 OR array_position(p_station_ids,NULL) IS NOT NULL OR (SELECT count(DISTINCT x) FROM unnest(p_station_ids) x)<>cardinality(p_station_ids) THEN RAISE EXCEPTION 'Select one to ten different print stations' USING ERRCODE='22023'; END IF;
 -- Stable lock order protects station deactivation against menu edits.
 FOR station IN SELECT id FROM public.cafe_print_stations WHERE id=ANY(p_station_ids) ORDER BY id FOR SHARE LOOP NULL; END LOOP;
 IF (SELECT count(*) FROM public.cafe_print_stations WHERE id=ANY(p_station_ids) AND active)<>cardinality(p_station_ids) THEN RAISE EXCEPTION 'Select active print stations' USING ERRCODE='22023'; END IF;
 SELECT * INTO saved FROM cafe_private.save_menu_priced(p_id,p_name,p_category,p_description,p_price_iqd,p_available,p_tourism_price_iqd,p_owner_price_iqd);
 DELETE FROM public.cafe_product_stations WHERE product_id=saved.id;
 INSERT INTO public.cafe_product_stations SELECT saved.id,unnest(p_station_ids);
 RETURN saved.id;
END; $$;
CREATE FUNCTION cafe_private.list_menu_routed() RETURNS SETOF jsonb LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT m || jsonb_build_object('station_ids',coalesce((SELECT jsonb_agg(station_id) FROM public.cafe_product_stations WHERE product_id=(m->>'id')::uuid),'[]'),
 'station_names',coalesce((SELECT jsonb_agg(s.name ORDER BY s.name) FROM public.cafe_product_stations ps JOIN public.cafe_print_stations s ON s.id=ps.station_id WHERE product_id=(m->>'id')::uuid),'[]')) FROM cafe_private.list_menu_priced() m;
$$;
CREATE FUNCTION cafe_private.route_station_ticket() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 INSERT INTO public.cafe_station_tickets(item_id,station_id,station_name,event)
 SELECT NEW.id,s.id,s.name,'new' FROM public.cafe_product_stations ps JOIN public.cafe_print_stations s ON s.id=ps.station_id WHERE ps.product_id=NEW.menu_item_id AND s.active;
 RETURN NEW;
END; $$;
CREATE TRIGGER route_station_ticket AFTER INSERT ON public.cafe_table_order_items FOR EACH ROW EXECUTE FUNCTION cafe_private.route_station_ticket();
CREATE FUNCTION cafe_private.cancel_station_ticket() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NEW.status='cancelled' AND OLD.status<>'cancelled' THEN
 INSERT INTO public.cafe_station_tickets(item_id,station_id,station_name,event)
 SELECT q.item_id,q.station_id,q.station_name,'cancelled' FROM public.cafe_station_tickets q JOIN public.cafe_table_order_items i ON i.id=q.item_id WHERE i.order_id=NEW.id AND q.event='new' ON CONFLICT DO NOTHING;
 END IF; RETURN NEW;
END; $$;
CREATE TRIGGER cancel_station_ticket AFTER UPDATE OF status ON public.cafe_table_orders FOR EACH ROW EXECUTE FUNCTION cafe_private.cancel_station_ticket();
CREATE FUNCTION cafe_private.station_queue(p_station_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT cafe_private.print_access() THEN RAISE EXCEPTION 'Station printing permission required' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('tickets',coalesce((SELECT jsonb_agg(v ORDER BY v->>'created_at') FROM (
 SELECT jsonb_build_object('order_id',o.id,'station',q.station_name,'event',q.event,'status',o.status,'created_at',min(q.created_at),'destination',coalesce(t.name,nullif(o.destination,''),o.source),'notes',o.notes,
 'items',jsonb_agg(jsonb_build_object('ticket_id',q.id,'name',i.item_name,'quantity',i.quantity) ORDER BY i.id)) v
 FROM public.cafe_station_tickets q JOIN public.cafe_table_order_items i ON i.id=q.item_id JOIN public.cafe_table_orders o ON o.id=i.order_id LEFT JOIN public.cafe_dining_tables t ON t.id=o.table_id
 WHERE q.station_id=p_station_id AND q.confirmed_at IS NULL GROUP BY o.id,t.name,q.station_name,q.event LIMIT 200) rows),'[]'),
 'unrouted_products',(SELECT count(*) FROM public.cafe_menu_items m WHERE m.available AND NOT EXISTS(SELECT 1 FROM public.cafe_product_stations ps WHERE ps.product_id=m.id)));
END; $$;
CREATE FUNCTION cafe_private.confirm_station_tickets(p_ids uuid[]) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT cafe_private.print_access() THEN RAISE EXCEPTION 'Station printing permission required' USING ERRCODE='42501'; END IF;
 IF p_ids IS NULL OR cardinality(p_ids) NOT BETWEEN 1 AND 200 THEN RAISE EXCEPTION 'Select tickets' USING ERRCODE='22023'; END IF;
 UPDATE public.cafe_station_tickets SET confirmed_at=now(),confirmed_by=auth.uid() WHERE id=ANY(p_ids) AND confirmed_at IS NULL;
END; $$;
CREATE FUNCTION public.get_cafe_print_stations() RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.print_station_list() $$;
CREATE FUNCTION public.save_cafe_print_station(p_id uuid,p_name text,p_active boolean) RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.save_print_station(p_id,p_name,p_active) $$;
CREATE FUNCTION public.save_cafe_menu_routed(p_id uuid,p_name text,p_category text,p_description text,p_price_iqd bigint,p_available boolean,p_tourism_price_iqd bigint,p_owner_price_iqd bigint,p_station_ids uuid[]) RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.save_menu_routed(p_id,p_name,p_category,p_description,p_price_iqd,p_available,p_tourism_price_iqd,p_owner_price_iqd,p_station_ids) $$;
CREATE FUNCTION public.list_cafe_menu_routed() RETURNS SETOF jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT * FROM cafe_private.list_menu_routed() $$;
CREATE FUNCTION public.get_cafe_station_queue(p_station_id uuid) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.station_queue(p_station_id) $$;
CREATE FUNCTION public.confirm_cafe_station_tickets(p_ids uuid[]) RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.confirm_station_tickets(p_ids) $$;
DO $$ DECLARE f regprocedure; BEGIN
 FOR f IN SELECT p.oid::regprocedure FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE
 (n.nspname='cafe_private' AND p.proname=ANY(ARRAY['print_access','print_station_list','save_print_station','save_menu_routed','list_menu_routed','route_station_ticket','cancel_station_ticket','station_queue','confirm_station_tickets'])) OR
 (n.nspname='public' AND p.proname=ANY(ARRAY['get_cafe_print_stations','save_cafe_print_station','save_cafe_menu_routed','list_cafe_menu_routed','get_cafe_station_queue','confirm_cafe_station_tickets'])) LOOP
 EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',f);
 IF f::text NOT LIKE '%route_station_ticket(%' AND f::text NOT LIKE '%cancel_station_ticket(%' THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',f); END IF;
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';


NOTIFY pgrst,'reload schema';
COMMIT;

