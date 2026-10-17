BEGIN;
CREATE TABLE public.cafe_table_tasks (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 kind text NOT NULL CHECK(kind IN ('maintenance','chairs','waiting','group')),
 table_id uuid REFERENCES public.cafe_dining_tables,
 other_table_id uuid REFERENCES public.cafe_dining_tables,
 title text NOT NULL CHECK(length(trim(title)) BETWEEN 1 AND 120),
 details text NOT NULL DEFAULT '' CHECK(length(details)<=1000),
 quantity integer NOT NULL DEFAULT 1 CHECK(quantity BETWEEN 1 AND 100),
 status text NOT NULL DEFAULT 'open',
 assigned_to uuid REFERENCES public.staff_profiles(user_id),
 version integer NOT NULL DEFAULT 1,
 created_by uuid NOT NULL REFERENCES auth.users,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX cafe_table_tasks_table_idx ON public.cafe_table_tasks(table_id);
CREATE INDEX cafe_table_tasks_other_idx ON public.cafe_table_tasks(other_table_id);
CREATE INDEX cafe_table_tasks_assigned_idx ON public.cafe_table_tasks(assigned_to);
CREATE INDEX cafe_table_tasks_creator_idx ON public.cafe_table_tasks(created_by);
CREATE TABLE public.cafe_table_task_commands (
 request_id uuid PRIMARY KEY, actor uuid NOT NULL REFERENCES auth.users,
 signature jsonb NOT NULL, result jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX cafe_table_task_commands_actor_idx ON public.cafe_table_task_commands(actor);
CREATE TABLE public.cafe_table_task_events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 task_id uuid REFERENCES public.cafe_table_tasks,
 actor uuid NOT NULL REFERENCES auth.users, action text NOT NULL,
 previous jsonb, current jsonb, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX cafe_table_task_events_task_idx ON public.cafe_table_task_events(task_id);
CREATE INDEX cafe_table_task_events_actor_idx ON public.cafe_table_task_events(actor);
CREATE TABLE public.cafe_table_rules (
 id boolean PRIMARY KEY DEFAULT true CHECK(id),
 alert_after_minutes integer NOT NULL DEFAULT 10 CHECK(alert_after_minutes BETWEEN 1 AND 240),
 version integer NOT NULL DEFAULT 1
);
INSERT INTO public.cafe_table_rules(id) VALUES(true);
DO $$ DECLARE n text; BEGIN
 FOREACH n IN ARRAY ARRAY['cafe_table_tasks','cafe_table_task_commands','cafe_table_task_events','cafe_table_rules'] LOOP
 EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',n);
 EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated',n);
 END LOOP;
END $$;
CREATE FUNCTION cafe_private.table_task_card(p_kind text) RETURNS text LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $$
 SELECT CASE p_kind WHEN 'maintenance' THEN 'table_maintenance' WHEN 'chairs' THEN 'extra_chairs_requests' WHEN 'waiting' THEN 'reservation_waiting_list' WHEN 'group' THEN 'join_split_tables' WHEN 'settings' THEN 'table_settings' WHEN 'permissions' THEN 'table_permissions' END
$$;
CREATE FUNCTION cafe_private.table_task_workspace(p_kind text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE result jsonb; admin boolean;
BEGIN
 IF cafe_private.table_task_card(p_kind) IS NULL OR NOT cafe_private.table_access(cafe_private.table_task_card(p_kind)) THEN RAISE EXCEPTION 'Card permission and MFA required' USING ERRCODE='42501'; END IF;
 SELECT EXISTS(SELECT 1 FROM public.staff_profiles WHERE user_id=auth.uid() AND role='admin') INTO admin;
 IF p_kind='permissions' AND NOT admin THEN RAISE EXCEPTION 'Administrator required' USING ERRCODE='42501'; END IF;
 SELECT jsonb_build_object(
 'tasks',coalesce((SELECT jsonb_agg(to_jsonb(t)||jsonb_build_object('table_name',d.name,'other_name',o.name,'assignee',s.email) ORDER BY t.created_at DESC)
 FROM public.cafe_table_tasks t LEFT JOIN public.cafe_dining_tables d ON d.id=t.table_id LEFT JOIN public.cafe_dining_tables o ON o.id=t.other_table_id LEFT JOIN public.staff_profiles s ON s.user_id=t.assigned_to WHERE t.kind=p_kind),'[]'),
 'tables',coalesce((SELECT jsonb_agg(jsonb_build_object('id',d.id,'name',d.name,'area',d.area,'seats',d.seats,'status',d.status,'active',EXISTS(SELECT 1 FROM public.cafe_table_visits v WHERE v.table_id=d.id AND v.closed_at IS NULL),'blocked',EXISTS(SELECT 1 FROM public.cafe_table_tasks b WHERE b.kind='maintenance' AND b.table_id=d.id AND b.status NOT IN ('resolved','cancelled'))) ORDER BY d.area,d.name) FROM public.cafe_dining_tables d),'[]'),
 'staff',coalesce((SELECT jsonb_agg(jsonb_build_object('id',user_id,'name',email,'role',role) ORDER BY email) FROM public.staff_profiles WHERE role IN ('admin','staff')),'[]'),
 'rules',(SELECT to_jsonb(r) FROM public.cafe_table_rules r WHERE id),
 'permissions',CASE WHEN p_kind='permissions' THEN coalesce((SELECT jsonb_agg(to_jsonb(p)) FROM public.staff_permissions p WHERE section_key='tables_orders'),'[]') ELSE '[]'::jsonb END,
 'can_approve',admin,'can_deliver_chairs',cafe_private.table_access('chairs_management'),
 'can_seat',cafe_private.table_access('table_session_management'),
 'events',coalesce((SELECT jsonb_agg(x) FROM (SELECT e.action,e.created_at,e.previous,e.current,s.email actor FROM public.cafe_table_task_events e LEFT JOIN public.cafe_table_tasks t ON t.id=e.task_id LEFT JOIN public.staff_profiles s ON s.user_id=e.actor WHERE t.kind=p_kind OR (t.id IS NULL AND e.action LIKE p_kind||':%') ORDER BY e.created_at DESC LIMIT 100) x),'[]')
 ) INTO result;
 RETURN result;
END $$;
CREATE FUNCTION cafe_private.table_maintenance_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE target uuid; BEGIN
 IF TG_TABLE_NAME='cafe_dining_tables' THEN target:=NEW.id; ELSE target:=NEW.table_id; END IF;
 PERFORM 1 FROM public.cafe_dining_tables WHERE id=target FOR UPDATE;
 IF EXISTS(SELECT 1 FROM public.cafe_table_tasks WHERE kind='maintenance' AND table_id=target AND status NOT IN ('resolved','cancelled')) THEN
  IF TG_TABLE_NAME='cafe_dining_tables' THEN
   IF NEW.status='available' AND OLD.status IS DISTINCT FROM NEW.status THEN RAISE EXCEPTION 'Table blocked for maintenance' USING ERRCODE='22023'; END IF;
  ELSE RAISE EXCEPTION 'Table blocked for maintenance; relocate or verify repair' USING ERRCODE='22023'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER cafe_maintenance_visit BEFORE INSERT OR UPDATE OF table_id ON public.cafe_table_visits FOR EACH ROW EXECUTE FUNCTION cafe_private.table_maintenance_guard();
CREATE TRIGGER cafe_maintenance_reservation BEFORE INSERT OR UPDATE OF table_id ON public.cafe_table_reservations FOR EACH ROW EXECUTE FUNCTION cafe_private.table_maintenance_guard();
CREATE TRIGGER cafe_maintenance_status BEFORE UPDATE OF status ON public.cafe_dining_tables FOR EACH ROW EXECUTE FUNCTION cafe_private.table_maintenance_guard();
REVOKE ALL ON FUNCTION cafe_private.table_maintenance_guard() FROM PUBLIC,anon,authenticated;
CREATE FUNCTION cafe_private.table_task_command(p_request_id uuid,p_kind text,p_action text,p_id uuid,p_version integer,p_data jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE r public.cafe_table_tasks; oldrow jsonb; sig jsonb; prior public.cafe_table_task_commands; result jsonb; admin boolean; target uuid; other uuid; nxt text; uid uuid; perm text;
BEGIN
 IF cafe_private.table_task_card(p_kind) IS NULL OR NOT cafe_private.table_access(cafe_private.table_task_card(p_kind)) THEN RAISE EXCEPTION 'Card permission and MFA required' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL OR p_data IS NULL OR jsonb_typeof(p_data)<>'object' OR octet_length(p_data::text)>10000 THEN RAISE EXCEPTION 'Invalid command' USING ERRCODE='22023'; END IF;
 SELECT EXISTS(SELECT 1 FROM public.staff_profiles WHERE user_id=auth.uid() AND role='admin') INTO admin;
 sig:=jsonb_build_object('kind',p_kind,'action',p_action,'id',p_id,'version',p_version,'data',p_data);
 PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
 SELECT * INTO prior FROM public.cafe_table_task_commands WHERE request_id=p_request_id;
 IF FOUND THEN IF prior.actor=auth.uid() AND prior.signature=sig THEN RETURN prior.result; END IF; RAISE EXCEPTION 'Request already used' USING ERRCODE='23505'; END IF;
 PERFORM pg_advisory_xact_lock(17092728);
 IF p_kind='settings' THEN
  IF NOT admin OR p_action<>'save' THEN RAISE EXCEPTION 'Administrator required' USING ERRCODE='42501'; END IF;
  SELECT to_jsonb(x) INTO oldrow FROM public.cafe_table_rules x WHERE id;
  UPDATE public.cafe_table_rules SET alert_after_minutes=(p_data->>'alert_after_minutes')::int,version=version+1 WHERE id AND version=p_version RETURNING to_jsonb(cafe_table_rules.*) INTO result;
  IF result IS NULL THEN RAISE EXCEPTION 'Settings changed; refresh' USING ERRCODE='40001'; END IF;
 ELSIF p_kind='permissions' THEN
  IF NOT admin OR p_action NOT IN ('grant','revoke') THEN RAISE EXCEPTION 'Administrator required' USING ERRCODE='42501'; END IF;
  uid:=(p_data->>'user_id')::uuid; perm:=p_data->>'permission';
  IF NOT EXISTS(SELECT 1 FROM public.staff_profiles WHERE user_id=uid AND role='staff') OR perm IS NULL OR perm NOT IN ('table_assignment','waiter_table_assignment','table_session_management','join_split_tables','extra_chairs_requests','chairs_management','reservation_waiting_list','table_maintenance','table_reports','table_settings','table_permissions','table_alerts_notifications','table_history_audit','table_service_requests','table_cleaning','table_overview','guest_check_in_no_show','table_reservations','table_map','edit_manage_tables') THEN RAISE EXCEPTION 'Choose a staff member and supported table permission' USING ERRCODE='22023'; END IF;
  IF p_action='grant' THEN INSERT INTO public.staff_permissions(user_id,section_key,subcard_key,assigned_by) VALUES(uid,'tables_orders',perm,auth.uid()) ON CONFLICT DO NOTHING;
  ELSE
   IF EXISTS(SELECT 1 FROM public.staff_permissions WHERE user_id=uid AND section_key='tables_orders' AND subcard_key='*') THEN RAISE EXCEPTION 'Section-wide access remains; manage wildcard access in staff administration' USING ERRCODE='22023'; END IF;
   DELETE FROM public.staff_permissions WHERE user_id=uid AND section_key='tables_orders' AND subcard_key=perm;
  END IF;
  result:=jsonb_build_object('ok',true);
 ELSE
  IF p_action='create' THEN
   target:=nullif(p_data->>'table_id','')::uuid; other:=nullif(p_data->>'other_table_id','')::uuid;
   IF p_kind<>'waiting' AND target IS NULL THEN RAISE EXCEPTION 'Select a table' USING ERRCODE='22023'; END IF;
   PERFORM 1 FROM public.cafe_dining_tables WHERE id IN (target,other) ORDER BY id FOR UPDATE;
   IF p_kind='group' THEN
    IF other IS NULL OR target=other OR (SELECT count(*) FROM public.cafe_table_visits WHERE table_id IN(target,other) AND closed_at IS NULL)<>2 THEN RAISE EXCEPTION 'Select two distinct occupied tables' USING ERRCODE='22023'; END IF;
    IF EXISTS(SELECT 1 FROM public.cafe_table_tasks WHERE kind='group' AND status='open' AND (table_id IN(target,other) OR other_table_id IN(target,other))) THEN RAISE EXCEPTION 'Separate the existing group first' USING ERRCODE='22023'; END IF;
   END IF;
   INSERT INTO public.cafe_table_tasks(kind,table_id,other_table_id,title,details,quantity,created_by)
   VALUES(p_kind,target,other,trim(p_data->>'title'),coalesce(p_data->>'details',''),coalesce((p_data->>'quantity')::int,1),auth.uid()) RETURNING * INTO r;
  ELSE
   SELECT * INTO r FROM public.cafe_table_tasks WHERE id=p_id AND kind=p_kind FOR UPDATE;
   IF r.id IS NULL OR p_version IS NULL OR r.version<>p_version THEN RAISE EXCEPTION 'Record changed; refresh' USING ERRCODE='40001'; END IF;
   oldrow:=to_jsonb(r);
   IF p_action='assign' THEN
    IF NOT admin OR r.status IN('resolved','cancelled','delivered','seated','separated') THEN RAISE EXCEPTION 'Cannot assign this record' USING ERRCODE='42501'; END IF;
    uid:=(p_data->>'assigned_to')::uuid;
    IF NOT EXISTS(SELECT 1 FROM public.staff_profiles WHERE user_id=uid) THEN RAISE EXCEPTION 'Select employee' USING ERRCODE='22023'; END IF;
    r.assigned_to:=uid;
   ELSE
    nxt:=p_action;
    IF p_kind='maintenance' THEN
     IF NOT ((r.status='open' AND nxt='in_progress') OR (r.status='in_progress' AND nxt='review') OR (r.status='review' AND nxt='resolved' AND admin) OR (r.status IN ('open','in_progress','review') AND nxt='cancelled' AND admin)) THEN RAISE EXCEPTION 'Invalid maintenance transition or approval' USING ERRCODE='22023'; END IF;
    ELSIF p_kind='chairs' THEN
     IF NOT ((r.status='open' AND nxt IN('approved','cancelled') AND admin) OR (r.status='approved' AND nxt='delivered')) THEN RAISE EXCEPTION 'Invalid chair request transition' USING ERRCODE='22023'; END IF;
     IF nxt='approved' THEN
      r.other_table_id:=nullif(p_data->>'other_table_id','')::uuid;
      IF r.other_table_id IS NULL OR r.other_table_id=r.table_id THEN RAISE EXCEPTION 'Choose a different source table' USING ERRCODE='22023'; END IF;
     ELSIF nxt='delivered' THEN
      PERFORM public.move_cafe_table_chairs(p_request_id,'transfer',r.other_table_id,r.table_id,r.quantity,'Approved request: '||r.title);
     END IF;
    ELSIF p_kind='group' THEN
     IF r.status<>'open' OR nxt<>'separated' THEN RAISE EXCEPTION 'Invalid group transition' USING ERRCODE='22023'; END IF;
    ELSIF p_kind='waiting' THEN
     IF NOT ((r.status='open' AND nxt IN('offered','cancelled')) OR (r.status='offered' AND nxt IN('accepted','open','cancelled')) OR (r.status='accepted' AND nxt IN('arrived','open','cancelled')) OR (r.status='arrived' AND nxt IN('seated','cancelled'))) THEN RAISE EXCEPTION 'Invalid waiting-list transition' USING ERRCODE='22023'; END IF;
     IF nxt='offered' THEN
      target:=(p_data->>'table_id')::uuid;
      PERFORM 1 FROM public.cafe_dining_tables WHERE id=target FOR UPDATE;
      IF NOT EXISTS(SELECT 1 FROM public.cafe_dining_tables WHERE id=target AND status='available' AND seats>=r.quantity) OR EXISTS(SELECT 1 FROM public.cafe_table_reservations WHERE table_id=target AND status='confirmed' AND ends_at>now() AND starts_at<now()+interval '2 hours') OR EXISTS(SELECT 1 FROM public.cafe_table_tasks WHERE kind='maintenance' AND table_id=target AND status NOT IN('resolved','cancelled')) THEN RAISE EXCEPTION 'Table is unavailable or too small' USING ERRCODE='22023'; END IF;
      r.table_id:=target;
     ELSIF nxt='open' THEN r.table_id:=NULL;
     ELSIF nxt='seated' THEN
      PERFORM public.perform_cafe_table_action(p_request_id,r.table_id,'take',jsonb_build_object('guests',r.quantity,'name',r.title,'contact',''));
     END IF;
    END IF;
    r.status:=nxt;
   END IF;
   UPDATE public.cafe_table_tasks SET status=r.status,assigned_to=r.assigned_to,table_id=r.table_id,other_table_id=r.other_table_id,version=version+1,updated_at=now() WHERE id=r.id RETURNING * INTO r;
  END IF;
  result:=to_jsonb(r);
 END IF;
 INSERT INTO public.cafe_table_task_events(task_id,actor,action,previous,current) VALUES(r.id,auth.uid(),p_kind||':'||p_action,oldrow,result||CASE WHEN p_kind='permissions' THEN p_data ELSE '{}'::jsonb END);
 INSERT INTO public.cafe_table_task_commands(request_id,actor,signature,result) VALUES(p_request_id,auth.uid(),sig,result);
 RETURN result;
END $$;
CREATE FUNCTION public.get_cafe_table_task_workspace(p_kind text) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.table_task_workspace(p_kind) $$;
CREATE FUNCTION public.perform_cafe_table_task_command(p_request_id uuid,p_kind text,p_action text,p_id uuid,p_version integer,p_data jsonb) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.table_task_command(p_request_id,p_kind,p_action,p_id,p_version,p_data) $$;
REVOKE ALL ON FUNCTION cafe_private.table_task_card(text),cafe_private.table_task_workspace(text),cafe_private.table_task_command(uuid,text,text,uuid,integer,jsonb),public.get_cafe_table_task_workspace(text),public.perform_cafe_table_task_command(uuid,text,text,uuid,integer,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION cafe_private.table_task_card(text),cafe_private.table_task_workspace(text),cafe_private.table_task_command(uuid,text,text,uuid,integer,jsonb),public.get_cafe_table_task_workspace(text),public.perform_cafe_table_task_command(uuid,text,text,uuid,integer,jsonb) TO authenticated;
-- Allow the displayed assignment and alerts card names to use the existing services.
DO $patch$ DECLARE f text; BEGIN
 SELECT pg_get_functiondef('cafe_private.table_access(text)'::regprocedure) INTO f;
 f:=replace(f,"public.has_workspace_access('tables_orders',p_card)","(public.has_workspace_access('tables_orders',p_card) OR (p_card='waiter_table_assignment' AND public.has_workspace_access('tables_orders','table_assignment')) OR (p_card='table_service_requests' AND public.has_workspace_access('tables_orders','table_alerts_notifications')))");
 EXECUTE f;
 SELECT pg_get_functiondef('cafe_private.table_overview()'::regprocedure) INTO f;
 f:=replace(f,"'seats',t.seats,'status',t.status", "'seats',t.seats,'maintenance_blocked',EXISTS(SELECT 1 FROM public.cafe_table_tasks task WHERE task.table_id=t.id AND task.kind='maintenance' AND task.status NOT IN ('resolved','cancelled')),'group_label',(SELECT task.title FROM public.cafe_table_tasks task WHERE task.kind='group' AND task.status='open' AND (task.table_id=t.id OR task.other_table_id=t.id) LIMIT 1),'status',t.status");
 EXECUTE f;
END $patch$;
CREATE UNIQUE INDEX cafe_waiting_active_offer_idx ON public.cafe_table_tasks(table_id) WHERE kind='waiting' AND status IN ('offered','accepted','arrived');
NOTIFY pgrst,'reload schema';
COMMIT;
