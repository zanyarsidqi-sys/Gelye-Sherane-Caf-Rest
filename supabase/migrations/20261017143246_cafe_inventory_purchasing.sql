
BEGIN;
CREATE TABLE public.cafe_inventory_items(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 name text NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 120),
 unit text NOT NULL CHECK(length(trim(unit)) BETWEEN 1 AND 16),
 department text NOT NULL CHECK(department IN ('kitchen','drinks','nargile','general')),
 on_hand numeric(14,3) NOT NULL DEFAULT 0 CHECK(on_hand BETWEEN 0 AND 999999999.999),
 reorder_level numeric(14,3) NOT NULL DEFAULT 0 CHECK(reorder_level BETWEEN 0 AND 999999999.999),
 version integer NOT NULL DEFAULT 1,
 created_by uuid NOT NULL REFERENCES auth.users,created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX cafe_inventory_name_idx ON public.cafe_inventory_items(lower(trim(name)));
CREATE INDEX cafe_inventory_creator_idx ON public.cafe_inventory_items(created_by);
CREATE TABLE public.cafe_inventory_purchases(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),item_id uuid NOT NULL REFERENCES public.cafe_inventory_items,
 supplier text NOT NULL CHECK(length(trim(supplier)) BETWEEN 1 AND 120),
 quantity numeric(14,3) NOT NULL CHECK(quantity BETWEEN 0.001 AND 999999999.999),
 received numeric(14,3) NOT NULL DEFAULT 0 CHECK(received>=0 AND received<=quantity),
 status text NOT NULL DEFAULT 'requested' CHECK(status IN ('requested','approved','rejected','part_received','received','cancelled')),
 note text NOT NULL DEFAULT '' CHECK(length(note)<=1000),review_note text NOT NULL DEFAULT '' CHECK(length(review_note)<=1000),
 version integer NOT NULL DEFAULT 1,created_by uuid NOT NULL REFERENCES auth.users,
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX cafe_inventory_purchase_item_idx ON public.cafe_inventory_purchases(item_id);
CREATE INDEX cafe_inventory_purchase_creator_idx ON public.cafe_inventory_purchases(created_by);
CREATE INDEX cafe_inventory_purchase_date_idx ON public.cafe_inventory_purchases(created_at DESC,id);
CREATE TABLE public.cafe_inventory_movements(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),item_id uuid NOT NULL REFERENCES public.cafe_inventory_items,
 purchase_id uuid REFERENCES public.cafe_inventory_purchases,
 kind text NOT NULL CHECK(kind IN ('opening','receipt','waste')),
 quantity numeric(14,3) NOT NULL CHECK(quantity<>0),
 balance_after numeric(14,3) NOT NULL CHECK(balance_after>=0),
 note text NOT NULL CHECK(length(trim(note)) BETWEEN 3 AND 1000),
 actor uuid NOT NULL REFERENCES auth.users,created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK((kind='waste' AND quantity<0 AND purchase_id IS NULL) OR
       (kind='opening' AND quantity>0 AND purchase_id IS NULL) OR
       (kind='receipt' AND quantity>0 AND purchase_id IS NOT NULL))
);
CREATE INDEX cafe_inventory_movement_item_idx ON public.cafe_inventory_movements(item_id,created_at DESC);
CREATE INDEX cafe_inventory_movement_purchase_idx ON public.cafe_inventory_movements(purchase_id);
CREATE INDEX cafe_inventory_movement_actor_idx ON public.cafe_inventory_movements(actor);
CREATE TABLE cafe_private.inventory_commands(
 request_id uuid PRIMARY KEY,actor uuid NOT NULL REFERENCES auth.users,signature jsonb NOT NULL,
 result jsonb NOT NULL,created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX cafe_inventory_commands_actor_idx ON cafe_private.inventory_commands(actor);
CREATE TABLE cafe_private.inventory_events(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,entity_id uuid NOT NULL,actor uuid NOT NULL REFERENCES auth.users,
 action text NOT NULL,previous jsonb,current jsonb,created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX cafe_inventory_events_actor_idx ON cafe_private.inventory_events(actor);
CREATE INDEX cafe_inventory_events_entity_idx ON cafe_private.inventory_events(entity_id,created_at DESC);
ALTER TABLE public.cafe_inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_inventory_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_inventory_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE cafe_private.inventory_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE cafe_private.inventory_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.cafe_inventory_items,public.cafe_inventory_purchases,public.cafe_inventory_movements,
 cafe_private.inventory_commands,cafe_private.inventory_events FROM PUBLIC,anon,authenticated;
REVOKE ALL ON SEQUENCE cafe_private.inventory_events_id_seq FROM PUBLIC,anon,authenticated;

CREATE FUNCTION cafe_private.inventory_access(p_card text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT auth.uid() IS NOT NULL AND auth.jwt()->>'aal'='aal2'
 AND EXISTS(SELECT 1 FROM public.staff_profiles WHERE user_id=auth.uid() AND role IN ('admin','staff'))
 AND p_card IN ('inventory_overview','low_stock','low_stock_alerts','purchase_requests','pending_approvals','supplier_deliveries','inventory_waste')
 AND public.has_workspace_access('dashboard',p_card)
$$;
CREATE FUNCTION cafe_private.inventory_quantity(value text,allow_zero boolean DEFAULT false) RETURNS numeric
LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog AS $$
DECLARE q numeric;
BEGIN
 IF value IS NULL OR value!~'^[0-9]+([.][0-9]{1,3})?$' OR length(value)>20 THEN
  RAISE EXCEPTION 'Use a quantity with at most three decimals' USING ERRCODE='22023'; END IF;
 q:=value::numeric;
 IF q>999999999.999 OR q<0 OR (NOT allow_zero AND q=0) THEN RAISE EXCEPTION 'Quantity outside allowed range' USING ERRCODE='22023'; END IF;
 RETURN q;
END $$;

CREATE FUNCTION cafe_private.inventory_workspace(p_card text,p_query text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE admin boolean; items jsonb; purchases jsonb; moves jsonb; counts jsonb; item_count bigint;
 purchase_count bigint:=0; move_count bigint:=0; query text:=lower(trim(coalesce(p_query,'')));
BEGIN
 IF cafe_private.inventory_access(p_card) IS DISTINCT FROM true THEN RAISE EXCEPTION 'Inventory card access and MFA required' USING ERRCODE='42501'; END IF;
 IF length(query)>120 THEN RAISE EXCEPTION 'Search is too long' USING ERRCODE='22023'; END IF;
 SELECT role='admin' INTO admin FROM public.staff_profiles WHERE user_id=auth.uid();
 SELECT count(*) INTO item_count FROM public.cafe_inventory_items i
 WHERE (query='' OR position(query in lower(i.name||' '||i.department))>0)
 AND (p_card NOT IN ('low_stock','low_stock_alerts') OR i.on_hand<=i.reorder_level)
 AND (p_card<>'low_stock' OR i.department<>'general');
 SELECT coalesce(jsonb_agg(x ORDER BY x.name,x.id),'[]') INTO items FROM(
  SELECT i.*,EXISTS(SELECT 1 FROM public.cafe_inventory_movements m WHERE m.item_id=i.id) has_movements,
   (EXISTS(SELECT 1 FROM public.cafe_inventory_movements m WHERE m.item_id=i.id) OR EXISTS(SELECT 1 FROM public.cafe_inventory_purchases p WHERE p.item_id=i.id)) unit_locked
  FROM public.cafe_inventory_items i
  WHERE (query='' OR position(query in lower(i.name||' '||i.department))>0)
  AND (p_card NOT IN ('low_stock','low_stock_alerts') OR i.on_hand<=i.reorder_level)
  AND (p_card<>'low_stock' OR i.department<>'general')
  ORDER BY i.name,i.id LIMIT 500) x;
 purchases:='[]';moves:='[]';
 IF p_card IN ('purchase_requests','pending_approvals','supplier_deliveries') THEN
  SELECT count(*) INTO purchase_count FROM public.cafe_inventory_purchases p JOIN public.cafe_inventory_items i ON i.id=p.item_id
   WHERE (query='' OR position(query in lower(i.name||' '||p.supplier||' '||p.note))>0)
    AND (p_card<>'pending_approvals' OR p.status='requested');
  SELECT coalesce(jsonb_agg(x ORDER BY x.created_at DESC,x.id),'[]') INTO purchases FROM (
   SELECT p.*,i.name item_name,i.unit FROM public.cafe_inventory_purchases p JOIN public.cafe_inventory_items i ON i.id=p.item_id
   WHERE (query='' OR position(query in lower(i.name||' '||p.supplier||' '||p.note))>0)
    AND (p_card<>'pending_approvals' OR p.status='requested')
   ORDER BY p.created_at DESC,p.id LIMIT 500) x;
 END IF;
 IF p_card IN ('inventory_overview','supplier_deliveries','inventory_waste') THEN
  SELECT count(*) INTO move_count FROM public.cafe_inventory_movements m JOIN public.cafe_inventory_items i ON i.id=m.item_id
   WHERE (query='' OR position(query in lower(i.name||' '||m.note))>0)
    AND (p_card<>'supplier_deliveries' OR m.kind='receipt') AND (p_card<>'inventory_waste' OR m.kind='waste');
  SELECT coalesce(jsonb_agg(x ORDER BY x.created_at DESC,x.id),'[]') INTO moves FROM (
   SELECT m.*,i.name item_name,i.unit FROM public.cafe_inventory_movements m JOIN public.cafe_inventory_items i ON i.id=m.item_id
   WHERE (query='' OR position(query in lower(i.name||' '||m.note))>0)
    AND (p_card<>'supplier_deliveries' OR m.kind='receipt') AND (p_card<>'inventory_waste' OR m.kind='waste')
   ORDER BY m.created_at DESC,m.id LIMIT 500) x;
 END IF;
 counts:=jsonb_build_object('items',item_count,'purchases',purchase_count,'movements',move_count);
 RETURN jsonb_build_object('items',items,'purchases',purchases,'movements',moves,'counts',counts,'server_time',now(),
  'can_manage',admin AND cafe_private.inventory_access('inventory_overview'),
  'can_request',cafe_private.inventory_access('purchase_requests'),
  'can_approve',admin AND cafe_private.inventory_access('pending_approvals'),
  'can_receive',cafe_private.inventory_access('supplier_deliveries'),
  'can_waste',cafe_private.inventory_access('inventory_waste'));
END $$;

CREATE FUNCTION cafe_private.inventory_command(p_request_id uuid,p_action text,p_id uuid,p_version integer,p_data jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE needed text; admin boolean; sig jsonb; prior cafe_private.inventory_commands;
 item public.cafe_inventory_items; purchase public.cafe_inventory_purchases; q numeric; v_note text;
 result jsonb; before_row jsonb; target uuid;
BEGIN
 needed:=CASE p_action WHEN 'create_item' THEN 'inventory_overview' WHEN 'update_item' THEN 'inventory_overview'
 WHEN 'opening' THEN 'inventory_overview' WHEN 'request' THEN 'purchase_requests'
 WHEN 'approve' THEN 'pending_approvals' WHEN 'reject' THEN 'pending_approvals' WHEN 'cancel' THEN 'pending_approvals'
 WHEN 'receive' THEN 'supplier_deliveries' WHEN 'waste' THEN 'inventory_waste' END;
 IF cafe_private.inventory_access(needed) IS DISTINCT FROM true THEN RAISE EXCEPTION 'Action permission and MFA required' USING ERRCODE='42501'; END IF;
 SELECT role='admin' INTO admin FROM public.staff_profiles WHERE user_id=auth.uid();
 IF p_action IN ('create_item','update_item','opening','approve','reject','cancel') AND NOT admin THEN
  RAISE EXCEPTION 'Administrator required' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL OR p_data IS NULL OR jsonb_typeof(p_data)<>'object' OR octet_length(p_data::text)>10000 THEN
  RAISE EXCEPTION 'Invalid command' USING ERRCODE='22023'; END IF;
 sig:=jsonb_build_object('action',p_action,'id',p_id,'version',p_version,'data',p_data);
 PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,261019));
 SELECT * INTO prior FROM cafe_private.inventory_commands WHERE request_id=p_request_id;
 IF FOUND THEN
  IF prior.actor=auth.uid() AND prior.signature=sig THEN RETURN prior.result; END IF;
  RAISE EXCEPTION 'Request identity already used' USING ERRCODE='23505';
 END IF;
 IF p_action IN ('create_item','request') AND (p_id IS NOT NULL OR p_version IS NOT NULL) THEN
  RAISE EXCEPTION 'New record cannot specify an existing identity' USING ERRCODE='22023'; END IF;
 IF p_action='create_item' THEN
  INSERT INTO public.cafe_inventory_items(name,unit,department,reorder_level,created_by)
  VALUES(trim(p_data->>'name'),trim(p_data->>'unit'),p_data->>'department',
   cafe_private.inventory_quantity(p_data->>'reorder_level',true),auth.uid()) RETURNING * INTO item;
  target:=item.id;result:=to_jsonb(item);
 ELSIF p_action IN ('update_item','opening','waste') THEN
  SELECT * INTO item FROM public.cafe_inventory_items WHERE id=p_id FOR UPDATE;
  IF item.id IS NULL OR p_version IS NULL OR item.version<>p_version THEN RAISE EXCEPTION 'Stock changed; refresh' USING ERRCODE='40001'; END IF;
  before_row:=to_jsonb(item);target:=item.id;
  IF p_action='update_item' THEN
   IF trim(p_data->>'unit') IS DISTINCT FROM item.unit AND (EXISTS(SELECT 1 FROM public.cafe_inventory_movements WHERE item_id=item.id) OR EXISTS(SELECT 1 FROM public.cafe_inventory_purchases WHERE item_id=item.id)) THEN
    RAISE EXCEPTION 'Unit cannot change after a movement or purchase request' USING ERRCODE='22023'; END IF;
   UPDATE public.cafe_inventory_items SET name=trim(p_data->>'name'),unit=trim(p_data->>'unit'),
    department=p_data->>'department',reorder_level=cafe_private.inventory_quantity(p_data->>'reorder_level',true),
    version=version+1,updated_at=clock_timestamp() WHERE id=item.id RETURNING * INTO item;
  ELSE
   q:=cafe_private.inventory_quantity(p_data->>'quantity');
   v_note:=trim(coalesce(p_data->>'note',''));
   IF length(v_note) NOT BETWEEN 3 AND 1000 THEN RAISE EXCEPTION 'Give a movement reason in 3-1000 characters' USING ERRCODE='22023'; END IF;
   IF p_action='opening' THEN
    IF EXISTS(SELECT 1 FROM public.cafe_inventory_movements WHERE item_id=item.id) OR item.on_hand<>0 THEN
     RAISE EXCEPTION 'Opening stock is allowed only before the first movement' USING ERRCODE='22023'; END IF;
   ELSE q:=-q;
   END IF;
   IF item.on_hand+q<0 OR item.on_hand+q>999999999.999 THEN RAISE EXCEPTION 'Movement exceeds stock range' USING ERRCODE='22023'; END IF;
   UPDATE public.cafe_inventory_items SET on_hand=on_hand+q,version=version+1,updated_at=clock_timestamp()
    WHERE id=item.id RETURNING * INTO item;
   INSERT INTO public.cafe_inventory_movements(item_id,kind,quantity,balance_after,note,actor)
    VALUES(item.id,p_action,q,item.on_hand,v_note,auth.uid());
  END IF;
  result:=to_jsonb(item);
 ELSIF p_action='request' THEN
  INSERT INTO public.cafe_inventory_purchases(item_id,supplier,quantity,note,created_by)
   VALUES((p_data->>'item_id')::uuid,trim(p_data->>'supplier'),cafe_private.inventory_quantity(p_data->>'quantity'),
    coalesce(p_data->>'note',''),auth.uid()) RETURNING * INTO purchase;
  target:=purchase.id;result:=to_jsonb(purchase);
 ELSE
  SELECT * INTO purchase FROM public.cafe_inventory_purchases WHERE id=p_id FOR UPDATE;
  IF purchase.id IS NULL OR p_version IS NULL OR purchase.version<>p_version THEN RAISE EXCEPTION 'Purchase changed; refresh' USING ERRCODE='40001'; END IF;
  before_row:=to_jsonb(purchase);target:=purchase.id;
  v_note:=trim(coalesce(p_data->>'note',''));
  IF p_action='receive' THEN
   IF purchase.status NOT IN ('approved','part_received') THEN RAISE EXCEPTION 'Only approved quantities can be received' USING ERRCODE='22023'; END IF;
   q:=cafe_private.inventory_quantity(p_data->>'quantity');
   IF q>purchase.quantity-purchase.received THEN RAISE EXCEPTION 'Delivery exceeds outstanding quantity' USING ERRCODE='22023'; END IF;
   IF length(v_note) NOT BETWEEN 3 AND 1000 THEN RAISE EXCEPTION 'Record delivery evidence or reference in 3-1000 characters' USING ERRCODE='22023'; END IF;
   SELECT * INTO item FROM public.cafe_inventory_items WHERE id=purchase.item_id FOR UPDATE;
   IF item.on_hand+q>999999999.999 THEN RAISE EXCEPTION 'Stock range exceeded' USING ERRCODE='22023'; END IF;
   UPDATE public.cafe_inventory_items SET on_hand=on_hand+q,version=version+1,updated_at=clock_timestamp()
    WHERE id=item.id RETURNING * INTO item;
   UPDATE public.cafe_inventory_purchases SET received=received+q,
    status=CASE WHEN received+q=quantity THEN 'received' ELSE 'part_received' END,
    version=version+1,updated_at=clock_timestamp() WHERE id=purchase.id RETURNING * INTO purchase;
   INSERT INTO public.cafe_inventory_movements(item_id,purchase_id,kind,quantity,balance_after,note,actor)
    VALUES(item.id,purchase.id,'receipt',q,item.on_hand,v_note,auth.uid());
  ELSE
   IF p_action IN ('approve','reject') AND purchase.status<>'requested' THEN RAISE EXCEPTION 'Request already reviewed' USING ERRCODE='22023'; END IF;
   IF p_action='cancel' AND purchase.status NOT IN ('requested','approved','part_received') THEN RAISE EXCEPTION 'Cannot cancel this request' USING ERRCODE='22023'; END IF;
   IF p_action IN ('reject','cancel') AND length(v_note) NOT BETWEEN 3 AND 1000 THEN RAISE EXCEPTION 'Explain this decision in 3-1000 characters' USING ERRCODE='22023'; END IF;
   UPDATE public.cafe_inventory_purchases SET status=CASE p_action WHEN 'approve' THEN 'approved' WHEN 'reject' THEN 'rejected' ELSE 'cancelled' END,
    review_note=v_note,version=version+1,updated_at=clock_timestamp() WHERE id=purchase.id RETURNING * INTO purchase;
  END IF;
  result:=to_jsonb(purchase);
 END IF;
 INSERT INTO cafe_private.inventory_events(entity_id,actor,action,previous,current) VALUES(target,auth.uid(),p_action,before_row,result);
 INSERT INTO cafe_private.inventory_commands(request_id,actor,signature,result) VALUES(p_request_id,auth.uid(),sig,result);
 RETURN result;
END $$;
CREATE FUNCTION public.get_cafe_inventory_workspace(p_card text,p_query text DEFAULT '') RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.inventory_workspace(p_card,p_query) $$;
CREATE FUNCTION public.perform_cafe_inventory_command(p_request_id uuid,p_action text,p_id uuid,p_version integer,p_data jsonb) RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.inventory_command(p_request_id,p_action,p_id,p_version,p_data) $$;
REVOKE ALL ON FUNCTION cafe_private.inventory_access(text),cafe_private.inventory_quantity(text,boolean),
 cafe_private.inventory_workspace(text,text),cafe_private.inventory_command(uuid,text,uuid,integer,jsonb),
 public.get_cafe_inventory_workspace(text,text),public.perform_cafe_inventory_command(uuid,text,uuid,integer,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION cafe_private.inventory_workspace(text,text),cafe_private.inventory_command(uuid,text,uuid,integer,jsonb),
 public.get_cafe_inventory_workspace(text,text),public.perform_cafe_inventory_command(uuid,text,uuid,integer,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
