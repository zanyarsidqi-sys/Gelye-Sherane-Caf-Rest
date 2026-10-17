BEGIN;
ALTER TABLE public.cafe_print_stations ADD COLUMN department text NOT NULL DEFAULT 'unclassified'
 CHECK(department IN ('unclassified','kitchen','drinks','nargile'));
ALTER TABLE public.cafe_print_stations ADD COLUMN department_version integer NOT NULL DEFAULT 1;
CREATE TABLE cafe_private.station_classifications(
 request_id uuid PRIMARY KEY,actor uuid NOT NULL REFERENCES auth.users,
 signature jsonb NOT NULL,station_id uuid NOT NULL REFERENCES public.cafe_print_stations,
 previous jsonb NOT NULL,result jsonb NOT NULL,created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX station_classifications_actor_idx ON cafe_private.station_classifications(actor);
CREATE INDEX station_classifications_station_idx ON cafe_private.station_classifications(station_id,created_at DESC);
ALTER TABLE cafe_private.station_classifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON cafe_private.station_classifications FROM PUBLIC,anon,authenticated;
CREATE FUNCTION cafe_private.minibar_access(p_card text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT auth.uid() IS NOT NULL AND auth.jwt()->>'aal'='aal2'
 AND EXISTS(SELECT 1 FROM public.staff_profiles WHERE user_id=auth.uid() AND role IN ('admin','staff'))
 AND p_card IN ('minibar_live_board','nargile_orders')
 AND public.has_workspace_access('dashboard',p_card)
$$;
CREATE FUNCTION cafe_private.minibar_board(p_card text,p_history boolean,p_query text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE can_classify boolean; v_rows jsonb; v_count bigint; v_stations jsonb; v_unclassified bigint;
 v_query text:=lower(trim(coalesce(p_query,'')));
BEGIN
 IF cafe_private.minibar_access(p_card) IS DISTINCT FROM true THEN
  RAISE EXCEPTION 'Board permission and MFA required' USING ERRCODE='42501'; END IF;
 IF p_history IS NULL OR length(v_query)>120 THEN RAISE EXCEPTION 'Invalid filter' USING ERRCODE='22023'; END IF;
 SELECT role='admin' AND cafe_private.print_access(true) INTO can_classify FROM public.staff_profiles WHERE user_id=auth.uid();
 SELECT count(*) INTO v_unclassified FROM public.cafe_print_stations WHERE department='unclassified';
 SELECT coalesce(jsonb_agg(x ORDER BY x.name,x.id),'[]') INTO v_stations FROM (
  SELECT s.id,s.name,s.active,s.department,s.department_version,
   s.department<>'unclassified' AND EXISTS(SELECT 1 FROM public.cafe_station_tickets q WHERE q.station_id=s.id) AS classification_locked
  FROM public.cafe_print_stations s
  WHERE can_classify OR (s.department='nargile' OR (p_card='minibar_live_board' AND s.department='drinks'))
  ORDER BY s.name,s.id LIMIT 500
 ) x;
 WITH filtered AS (
  SELECT q.id,q.station_id,s.name AS station_name,s.department,o.id AS order_id,
   i.item_name,i.quantity,o.status AS order_status,o.created_at AS ordered_at,q.confirmed_at AS printed_at,
   coalesce(t.name,nullif(o.destination,''),o.source) AS destination,o.source,o.notes
  FROM public.cafe_station_tickets q
  JOIN public.cafe_print_stations s ON s.id=q.station_id
  JOIN public.cafe_table_order_items i ON i.id=q.item_id
  JOIN public.cafe_table_orders o ON o.id=i.order_id
  LEFT JOIN public.cafe_dining_tables t ON t.id=o.table_id
  WHERE q.event='new'
   AND (s.department='nargile' OR (p_card='minibar_live_board' AND s.department='drinks'))
   AND (NOT p_history AND o.status IN ('received','preparing','ready')
    OR p_history AND o.status IN ('served','cancelled') AND o.created_at>=now()-interval '7 days')
   AND (v_query='' OR position(v_query in lower(concat_ws(' ',i.item_name,o.id::text,t.name,o.destination,s.name)))>0)
 ), limited AS (SELECT * FROM filtered ORDER BY ordered_at,id LIMIT 500)
 SELECT coalesce((SELECT jsonb_agg(l ORDER BY l.ordered_at,l.id) FROM limited l),'[]'),
  (SELECT count(*) FROM filtered) INTO v_rows,v_count;
 RETURN jsonb_build_object('rows',v_rows,'total',v_count,'stations',v_stations,
  'unclassified_stations',v_unclassified,'can_classify',can_classify,'server_time',now());
END $$;
CREATE FUNCTION cafe_private.classify_station(p_card text,p_request_id uuid,p_station_id uuid,p_version integer,p_department text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE s public.cafe_print_stations; old_row jsonb; result jsonb; sig jsonb; prior cafe_private.station_classifications;
BEGIN
 IF cafe_private.minibar_access(p_card) IS DISTINCT FROM true OR
  NOT EXISTS(SELECT 1 FROM public.staff_profiles WHERE user_id=auth.uid() AND role='admin') OR
  cafe_private.print_access(true) IS DISTINCT FROM true THEN
  RAISE EXCEPTION 'Administrator, board and station management access required' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL OR p_department IS NULL OR p_department NOT IN ('unclassified','kitchen','drinks','nargile') THEN
  RAISE EXCEPTION 'Invalid station classification' USING ERRCODE='22023'; END IF;
 sig:=jsonb_build_object('card',p_card,'station',p_station_id,'version',p_version,'department',p_department);
 PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,261020));
 SELECT * INTO prior FROM cafe_private.station_classifications WHERE request_id=p_request_id;
 IF FOUND THEN
  IF prior.actor=auth.uid() AND prior.signature=sig THEN RETURN prior.result; END IF;
  RAISE EXCEPTION 'Request already used' USING ERRCODE='23505';
 END IF;
 SELECT * INTO s FROM public.cafe_print_stations WHERE id=p_station_id FOR UPDATE;
 IF s.id IS NULL OR p_version IS NULL OR s.department_version<>p_version THEN
  RAISE EXCEPTION 'Station changed; refresh' USING ERRCODE='40001'; END IF;
 IF s.department<>'unclassified' AND s.department<>p_department AND EXISTS(SELECT 1 FROM public.cafe_station_tickets WHERE station_id=s.id) THEN
  RAISE EXCEPTION 'Used station classification is locked; create a separate station for another department' USING ERRCODE='22023'; END IF;
 old_row:=to_jsonb(s);
 UPDATE public.cafe_print_stations SET department=p_department,department_version=department_version+1
 WHERE id=s.id RETURNING * INTO s;
 result:=to_jsonb(s);
 INSERT INTO cafe_private.station_classifications(request_id,actor,signature,station_id,previous,result)
 VALUES(p_request_id,auth.uid(),sig,s.id,old_row,result);
 RETURN result;
END $$;
CREATE FUNCTION public.get_cafe_minibar_board(p_card text,p_history boolean DEFAULT false,p_query text DEFAULT '') RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.minibar_board(p_card,p_history,p_query) $$;
CREATE FUNCTION public.classify_cafe_station(p_card text,p_request_id uuid,p_station_id uuid,p_version integer,p_department text) RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.classify_station(p_card,p_request_id,p_station_id,p_version,p_department) $$;
REVOKE ALL ON FUNCTION cafe_private.minibar_access(text),cafe_private.minibar_board(text,boolean,text),
 cafe_private.classify_station(text,uuid,uuid,integer,text),public.get_cafe_minibar_board(text,boolean,text),
 public.classify_cafe_station(text,uuid,uuid,integer,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION cafe_private.minibar_board(text,boolean,text),cafe_private.classify_station(text,uuid,uuid,integer,text),
 public.get_cafe_minibar_board(text,boolean,text),public.classify_cafe_station(text,uuid,uuid,integer,text) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
