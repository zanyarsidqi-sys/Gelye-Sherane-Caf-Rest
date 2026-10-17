
\set ON_ERROR_STOP on
-- Isolated contract fixture only. Never run against a deployed application database.
DO $$ BEGIN
 IF current_database()<>'task_workflow_test' THEN RAISE EXCEPTION 'Isolated test database required'; END IF;
END $$;
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA auth;
CREATE SCHEMA cafe_private;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT nullif(current_setting('test.actor',true),'')::uuid
$$;
CREATE TABLE public.staff_profiles(user_id uuid PRIMARY KEY REFERENCES auth.users, role text, email text);
CREATE TABLE public.staff_permissions(user_id uuid,section_key text,subcard_key text,assigned_by uuid,
 UNIQUE(user_id,section_key,subcard_key));
CREATE TABLE public.cafe_dining_tables(id uuid PRIMARY KEY,name text,area text,seats integer,status text);
CREATE TABLE public.cafe_table_visits(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),table_id uuid,closed_at timestamptz);
CREATE TABLE public.cafe_table_reservations(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),table_id uuid,
 status text,starts_at timestamptz,ends_at timestamptz);
CREATE FUNCTION public.has_workspace_access(section text,card text) RETURNS boolean LANGUAGE sql AS $$
 SELECT EXISTS(SELECT 1 FROM public.staff_profiles WHERE user_id=auth.uid() AND role='admin')
 OR EXISTS(SELECT 1 FROM public.staff_permissions WHERE user_id=auth.uid() AND section_key=section AND subcard_key=card)
$$;
-- Auth/MFA and seating/moving are fixture boundaries, not integration coverage.
CREATE FUNCTION cafe_private.table_access(p_card text) RETURNS boolean LANGUAGE sql AS $$
 SELECT auth.uid() IS NOT NULL AND public.has_workspace_access('tables_orders',p_card)
$$;
CREATE FUNCTION cafe_private.table_overview() RETURNS jsonb LANGUAGE sql AS $$
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',t.id,'seats',t.seats,'status',t.status)),'[]')
 FROM public.cafe_dining_tables t
$$;
CREATE FUNCTION public.perform_cafe_table_action(uuid,uuid,text,jsonb) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION public.move_cafe_table_chairs(uuid,text,uuid,uuid,integer,text) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;
GRANT USAGE ON SCHEMA public,cafe_private,auth TO authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;
\i supabase/migrations/20261017092728_cafe_table_card_workflows.sql

INSERT INTO auth.users VALUES('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000002');
INSERT INTO public.staff_profiles VALUES
 ('00000000-0000-0000-0000-000000000001','admin','admin@example.test'),
 ('00000000-0000-0000-0000-000000000002','staff','staff@example.test');
INSERT INTO public.cafe_dining_tables VALUES('10000000-0000-0000-0000-000000000001','Table 1','Main',4,'available');
SELECT set_config('test.actor','00000000-0000-0000-0000-000000000001',false);

DO $$ DECLARE r jsonb; repeated jsonb; task_id uuid; req uuid:=gen_random_uuid(); BEGIN
 r:=public.perform_cafe_table_task_command(req,'maintenance','create',null,null,
   '{"table_id":"10000000-0000-0000-0000-000000000001","title":"Repair chair","quantity":1}');
 repeated:=public.perform_cafe_table_task_command(req,'maintenance','create',null,null,
   '{"table_id":"10000000-0000-0000-0000-000000000001","title":"Repair chair","quantity":1}');
 IF r<>repeated OR (SELECT count(*) FROM public.cafe_table_tasks)<>1 THEN RAISE EXCEPTION 'Create retry duplicated task'; END IF;
 task_id:=(r->>'id')::uuid;
 IF public.get_cafe_table_task_workspace('maintenance')->'can_approve'<>'true'::jsonb THEN RAISE EXCEPTION 'Admin capability missing'; END IF;
 IF cafe_private.table_overview()->0->'maintenance_blocked'<>'true'::jsonb THEN RAISE EXCEPTION 'Overview patch missing'; END IF;
 BEGIN
  INSERT INTO public.cafe_table_visits(table_id) VALUES('10000000-0000-0000-0000-000000000001');
  RAISE EXCEPTION 'Maintenance allowed seating';
 EXCEPTION WHEN sqlstate '22023' THEN NULL; END;
 req:=gen_random_uuid();
 r:=public.perform_cafe_table_task_command(req,'maintenance','assign',task_id,1,
   '{"assigned_to":"00000000-0000-0000-0000-000000000002"}');
 repeated:=public.perform_cafe_table_task_command(req,'maintenance','assign',task_id,1,
   '{"assigned_to":"00000000-0000-0000-0000-000000000002"}');
 IF r<>repeated OR (r->>'version')::int<>2 THEN RAISE EXCEPTION 'Assignment retry changed version'; END IF;
 BEGIN
  PERFORM public.perform_cafe_table_task_command(gen_random_uuid(),'maintenance','in_progress',task_id,1,'{}');
  RAISE EXCEPTION 'Stale version accepted';
 EXCEPTION WHEN serialization_failure THEN NULL; END;
 PERFORM public.perform_cafe_table_task_command(gen_random_uuid(),'maintenance','in_progress',task_id,2,'{}');
 PERFORM public.perform_cafe_table_task_command(gen_random_uuid(),'maintenance','review',task_id,3,'{}');
 PERFORM set_config('test.actor','00000000-0000-0000-0000-000000000002',false);
 BEGIN
  PERFORM public.get_cafe_table_task_workspace('maintenance');
  RAISE EXCEPTION 'Unassigned source access allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 INSERT INTO public.staff_permissions VALUES(auth.uid(),'tables_orders','table_maintenance',null);
 BEGIN
  PERFORM public.perform_cafe_table_task_command(gen_random_uuid(),'maintenance','resolved',task_id,4,'{}');
  RAISE EXCEPTION 'Staff approved repair';
 EXCEPTION WHEN sqlstate '22023' THEN NULL; END;
 BEGIN
  PERFORM public.perform_cafe_table_task_command(gen_random_uuid(),'maintenance','assign',task_id,4,
    '{"assigned_to":"00000000-0000-0000-0000-000000000002"}');
  RAISE EXCEPTION 'Staff assigned task';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('test.actor','00000000-0000-0000-0000-000000000001',false);
 PERFORM public.perform_cafe_table_task_command(gen_random_uuid(),'maintenance','resolved',task_id,4,'{}');
 IF cafe_private.table_overview()->0->'maintenance_blocked'<>'false'::jsonb THEN RAISE EXCEPTION 'Repair did not unblock'; END IF;
 INSERT INTO public.cafe_table_visits(table_id) VALUES('10000000-0000-0000-0000-000000000001');
 IF (SELECT count(*) FROM public.cafe_table_task_events WHERE cafe_table_task_events.task_id=task_id)<>5 THEN
  RAISE EXCEPTION 'Expected one audit entry for each distinct command';
 END IF;
 IF has_function_privilege('anon','public.get_cafe_table_task_workspace(text)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous RPC access'; END IF;
 IF has_table_privilege('authenticated','public.cafe_table_tasks','UPDATE') THEN RAISE EXCEPTION 'Direct task write allowed'; END IF;
END $$;

SELECT 'Task migration contract checks passed' AS result;
