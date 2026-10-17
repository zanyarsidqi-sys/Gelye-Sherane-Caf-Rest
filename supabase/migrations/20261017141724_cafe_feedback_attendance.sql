
BEGIN;
CREATE TABLE public.cafe_customer_feedback (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 title text NOT NULL CHECK(length(trim(title)) BETWEEN 1 AND 120),
 details text NOT NULL DEFAULT '' CHECK(length(details)<=2000),
 customer_name text NOT NULL DEFAULT '' CHECK(length(customer_name)<=120),
 category text NOT NULL CHECK(category IN ('complaint','suggestion','compliment')),
 rating integer CHECK(rating BETWEEN 1 AND 5),
 status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','in_review','resolved','dismissed')),
 resolution text NOT NULL DEFAULT '' CHECK(length(resolution)<=1000),
 version integer NOT NULL DEFAULT 1,
 created_by uuid NOT NULL REFERENCES auth.users,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX cafe_feedback_date_idx ON public.cafe_customer_feedback(created_at DESC,id);
CREATE INDEX cafe_feedback_creator_idx ON public.cafe_customer_feedback(created_by);
CREATE TABLE public.cafe_staff_attendance (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 staff_id uuid NOT NULL REFERENCES public.staff_profiles(user_id),
 clocked_in_at timestamptz NOT NULL DEFAULT now(),
 clocked_out_at timestamptz,
 version integer NOT NULL DEFAULT 1,
 CHECK(clocked_out_at IS NULL OR clocked_out_at>=clocked_in_at)
);
CREATE UNIQUE INDEX cafe_attendance_one_open_idx ON public.cafe_staff_attendance(staff_id) WHERE clocked_out_at IS NULL;
CREATE INDEX cafe_attendance_staff_date_idx ON public.cafe_staff_attendance(staff_id,clocked_in_at DESC);
CREATE INDEX cafe_attendance_date_idx ON public.cafe_staff_attendance(clocked_in_at DESC);
CREATE TABLE cafe_private.people_commands(
 request_id uuid PRIMARY KEY, actor uuid NOT NULL REFERENCES auth.users,
 signature jsonb NOT NULL,result jsonb NOT NULL,created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX cafe_people_commands_actor_idx ON cafe_private.people_commands(actor);
CREATE TABLE cafe_private.people_events(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,kind text NOT NULL,entity_id uuid NOT NULL,
 actor uuid NOT NULL REFERENCES auth.users,action text NOT NULL,previous jsonb,current jsonb,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX cafe_people_events_entity_idx ON cafe_private.people_events(kind,entity_id,created_at DESC);
CREATE INDEX cafe_people_events_actor_idx ON cafe_private.people_events(actor);
ALTER TABLE public.cafe_customer_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_staff_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE cafe_private.people_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE cafe_private.people_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.cafe_customer_feedback,public.cafe_staff_attendance,cafe_private.people_commands,cafe_private.people_events FROM PUBLIC,anon,authenticated;
REVOKE ALL ON SEQUENCE cafe_private.people_events_id_seq FROM PUBLIC,anon,authenticated;

CREATE FUNCTION cafe_private.people_access(p_kind text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT auth.uid() IS NOT NULL AND auth.jwt()->>'aal'='aal2'
 AND EXISTS(SELECT 1 FROM public.staff_profiles WHERE user_id=auth.uid() AND role IN ('admin','staff'))
 AND CASE p_kind
 WHEN 'feedback' THEN public.has_workspace_access('dashboard','customer_feedback') OR public.has_workspace_access('dashboard','feedback')
 WHEN 'attendance' THEN public.has_workspace_access('dashboard','employee_attendance') OR public.has_workspace_access('dashboard','attendance')
 ELSE false END
$$;

CREATE FUNCTION cafe_private.people_workspace(p_kind text,p_from date,p_to date) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE admin boolean; start_at timestamptz; end_at timestamptz; result_rows jsonb; event_rows jsonb;
 row_count bigint; active_row jsonb; snapshot timestamptz:=now();
BEGIN
 IF cafe_private.people_access(p_kind) IS DISTINCT FROM true THEN RAISE EXCEPTION 'Card permission and MFA required' USING ERRCODE='42501'; END IF;
 IF p_from IS NULL OR p_to IS NULL OR p_to<p_from OR p_to-p_from>30 THEN RAISE EXCEPTION 'Select at most 31 Baghdad dates' USING ERRCODE='22023'; END IF;
 SELECT role='admin' INTO admin FROM public.staff_profiles WHERE user_id=auth.uid();
 start_at:=p_from::timestamp AT TIME ZONE 'Asia/Baghdad';
 end_at:=(p_to+1)::timestamp AT TIME ZONE 'Asia/Baghdad';
 IF p_kind='feedback' THEN
  SELECT count(*) INTO row_count FROM public.cafe_customer_feedback WHERE created_at>=start_at AND created_at<end_at;
  SELECT coalesce(jsonb_agg(x ORDER BY x.created_at DESC,x.id),'[]') INTO result_rows FROM
   (SELECT * FROM public.cafe_customer_feedback WHERE created_at>=start_at AND created_at<end_at ORDER BY created_at DESC,id LIMIT 500) x;
 ELSE
  SELECT count(*) INTO row_count FROM public.cafe_staff_attendance
   WHERE (admin OR staff_id=auth.uid()) AND clocked_in_at<end_at AND coalesce(clocked_out_at,snapshot)>start_at;
  SELECT coalesce(jsonb_agg(x ORDER BY x.clocked_in_at DESC,x.id),'[]') INTO result_rows FROM (
   SELECT a.*,s.email employee_name,
    greatest(0,floor(extract(epoch FROM (least(coalesce(a.clocked_out_at,snapshot),end_at)-greatest(a.clocked_in_at,start_at)))))::bigint period_seconds
   FROM public.cafe_staff_attendance a JOIN public.staff_profiles s ON s.user_id=a.staff_id
   WHERE (admin OR a.staff_id=auth.uid()) AND a.clocked_in_at<end_at AND coalesce(a.clocked_out_at,snapshot)>start_at
   ORDER BY a.clocked_in_at DESC,a.id LIMIT 500) x;
  SELECT to_jsonb(a) INTO active_row FROM public.cafe_staff_attendance a WHERE staff_id=auth.uid() AND clocked_out_at IS NULL;
 END IF;
 SELECT coalesce(jsonb_agg(x ORDER BY x.created_at DESC,x.id DESC),'[]') INTO event_rows FROM (
  SELECT e.id,e.entity_id,e.action,e.created_at,e.actor,e.previous,e.current
  FROM cafe_private.people_events e WHERE e.kind=p_kind
   AND e.entity_id IN (SELECT (value->>'id')::uuid FROM jsonb_array_elements(result_rows))
  ORDER BY e.created_at DESC,e.id DESC LIMIT 100) x;
 RETURN jsonb_build_object('rows',result_rows,'total_count',row_count,'truncated',row_count>500,
  'events',event_rows,'active',active_row,'can_admin',admin,'server_time',snapshot,'from',p_from,'to',p_to);
END $$;

CREATE FUNCTION cafe_private.people_command(p_request_id uuid,p_kind text,p_action text,p_id uuid,p_version integer,p_data jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE admin boolean; signature jsonb; prior cafe_private.people_commands; result jsonb;
 before_row jsonb; entity uuid; f public.cafe_customer_feedback; a public.cafe_staff_attendance; note text;
BEGIN
 IF cafe_private.people_access(p_kind) IS DISTINCT FROM true THEN RAISE EXCEPTION 'Card permission and MFA required' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL OR p_action IS NULL OR p_data IS NULL OR jsonb_typeof(p_data)<>'object' OR octet_length(p_data::text)>16000 THEN
  RAISE EXCEPTION 'Invalid command' USING ERRCODE='22023'; END IF;
 SELECT role='admin' INTO admin FROM public.staff_profiles WHERE user_id=auth.uid();
 signature:=jsonb_build_object('kind',p_kind,'action',p_action,'id',p_id,'version',p_version,'data',p_data);
 PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,261017));
 SELECT * INTO prior FROM cafe_private.people_commands WHERE request_id=p_request_id;
 IF FOUND THEN
  IF prior.actor=auth.uid() AND prior.signature=signature THEN RETURN prior.result; END IF;
  RAISE EXCEPTION 'Request identity already used' USING ERRCODE='23505';
 END IF;
 IF p_kind='feedback' THEN
  IF p_action='create' THEN
   IF p_id IS NOT NULL OR p_version IS NOT NULL THEN RAISE EXCEPTION 'New feedback cannot specify a record' USING ERRCODE='22023'; END IF;
   INSERT INTO public.cafe_customer_feedback(title,details,customer_name,category,rating,created_by)
   VALUES(trim(p_data->>'title'),coalesce(p_data->>'details',''),trim(coalesce(p_data->>'customer_name','')),
    p_data->>'category',(p_data->>'rating')::integer,auth.uid()) RETURNING * INTO f;
  ELSE
   SELECT * INTO f FROM public.cafe_customer_feedback WHERE id=p_id FOR UPDATE;
   IF f.id IS NULL OR p_version IS NULL OR f.version<>p_version THEN RAISE EXCEPTION 'Feedback changed; refresh' USING ERRCODE='40001'; END IF;
   before_row:=to_jsonb(f);
   IF NOT ((f.status='open' AND p_action='in_review') OR (f.status='in_review' AND p_action='resolved')
     OR (admin AND f.status IN ('open','in_review') AND p_action='dismissed')
     OR (admin AND f.status IN ('resolved','dismissed') AND p_action='open')) THEN
    RAISE EXCEPTION 'Invalid review transition or permission' USING ERRCODE='22023';
   END IF;
   note:=trim(coalesce(p_data->>'resolution',''));
   IF p_action IN ('resolved','dismissed','open') AND length(note) NOT BETWEEN 3 AND 1000 THEN
    RAISE EXCEPTION 'Explain resolution, dismissal or reopening in 3-1000 characters' USING ERRCODE='22023'; END IF;
   UPDATE public.cafe_customer_feedback SET status=p_action,resolution=note,version=version+1,updated_at=now()
    WHERE id=f.id RETURNING * INTO f;
  END IF;
  entity:=f.id;result:=to_jsonb(f);
 ELSE
  -- Serializes distinct clock requests for this employee as well as identical retries.
  PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text,261018));
  IF p_action='clock_in' THEN
   IF p_id IS NOT NULL OR p_version IS NOT NULL OR p_data<>'{}'::jsonb THEN
    RAISE EXCEPTION 'Clock-in uses server identity and time only' USING ERRCODE='22023'; END IF;
   IF EXISTS(SELECT 1 FROM public.cafe_staff_attendance WHERE staff_id=auth.uid() AND clocked_out_at IS NULL) THEN
    RAISE EXCEPTION 'Already clocked in; refresh' USING ERRCODE='23505'; END IF;
   INSERT INTO public.cafe_staff_attendance(staff_id) VALUES(auth.uid()) RETURNING * INTO a;
  ELSIF p_action='clock_out' THEN
   SELECT * INTO a FROM public.cafe_staff_attendance WHERE id=p_id AND staff_id=auth.uid() FOR UPDATE;
   IF a.id IS NULL THEN RAISE EXCEPTION 'Only your own attendance can be changed' USING ERRCODE='42501'; END IF;
   IF a.clocked_out_at IS NOT NULL OR p_version IS NULL OR a.version<>p_version THEN
    RAISE EXCEPTION 'Attendance changed; refresh' USING ERRCODE='40001'; END IF;
   IF p_data<>'{}'::jsonb THEN RAISE EXCEPTION 'Clock-out uses server time only' USING ERRCODE='22023'; END IF;
   before_row:=to_jsonb(a);
   UPDATE public.cafe_staff_attendance SET clocked_out_at=greatest(now(),clocked_in_at),version=version+1 WHERE id=a.id RETURNING * INTO a;
  ELSE RAISE EXCEPTION 'Unknown attendance action' USING ERRCODE='22023';
  END IF;
  entity:=a.id;result:=to_jsonb(a);
 END IF;
 INSERT INTO cafe_private.people_events(kind,entity_id,actor,action,previous,current)
 VALUES(p_kind,entity,auth.uid(),p_action,before_row,result);
 INSERT INTO cafe_private.people_commands(request_id,actor,signature,result) VALUES(p_request_id,auth.uid(),signature,result);
 RETURN result;
END $$;
CREATE FUNCTION public.get_cafe_people_workspace(p_kind text,p_from date,p_to date) RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.people_workspace(p_kind,p_from,p_to) $$;
CREATE FUNCTION public.perform_cafe_people_command(p_request_id uuid,p_kind text,p_action text,p_id uuid,p_version integer,p_data jsonb) RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.people_command(p_request_id,p_kind,p_action,p_id,p_version,p_data) $$;
REVOKE ALL ON FUNCTION cafe_private.people_access(text),cafe_private.people_workspace(text,date,date),cafe_private.people_command(uuid,text,text,uuid,integer,jsonb),
 public.get_cafe_people_workspace(text,date,date),public.perform_cafe_people_command(uuid,text,text,uuid,integer,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION cafe_private.people_workspace(text,date,date),cafe_private.people_command(uuid,text,text,uuid,integer,jsonb),
 public.get_cafe_people_workspace(text,date,date),public.perform_cafe_people_command(uuid,text,text,uuid,integer,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
