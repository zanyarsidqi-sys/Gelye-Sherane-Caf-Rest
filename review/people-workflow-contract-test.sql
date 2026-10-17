
\set ON_ERROR_STOP on
-- Run after table-task-contract-test.sql in the isolated CI database.
DO $$ BEGIN IF current_database()<>'task_workflow_test' THEN RAISE EXCEPTION 'Isolated database required'; END IF; END $$;
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT jsonb_build_object('aal',coalesce(nullif(current_setting('test.aal',true),''),'aal2'))
$$;
\i supabase/migrations/20261017141724_cafe_feedback_attendance.sql
SELECT set_config('test.actor','00000000-0000-0000-0000-000000000001',false);
DO $$ DECLARE r jsonb; duplicate jsonb; fid uuid; aid uuid; req uuid; day date:=(now() AT TIME ZONE 'Asia/Baghdad')::date; BEGIN
 PERFORM set_config('test.aal','aal1',false);
 BEGIN
  PERFORM public.get_cafe_people_workspace('feedback',day,day);
  RAISE EXCEPTION 'MFA bypass';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('test.aal','aal2',false);
 req:=gen_random_uuid();
 r:=public.perform_cafe_people_command(req,'feedback','create',null,null,'{"title":"Cold tea","category":"complaint","rating":2}');
 duplicate:=public.perform_cafe_people_command(req,'feedback','create',null,null,'{"title":"Cold tea","category":"complaint","rating":2}');
 IF r<>duplicate OR (SELECT count(*) FROM public.cafe_customer_feedback)<>1 THEN RAISE EXCEPTION 'Feedback duplicated'; END IF;
 fid:=(r->>'id')::uuid;
 BEGIN
  PERFORM public.perform_cafe_people_command(req,'feedback','create',null,null,'{"title":"Changed","category":"complaint"}');
  RAISE EXCEPTION 'Reused identity accepted';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 BEGIN
  PERFORM public.perform_cafe_people_command(gen_random_uuid(),'feedback','create',null,null,'{"title":"Invalid","category":"complaint","rating":6}');
  RAISE EXCEPTION 'Invalid rating accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM public.perform_cafe_people_command(gen_random_uuid(),'feedback','in_review',fid,1,'{}');
 BEGIN
  PERFORM public.perform_cafe_people_command(gen_random_uuid(),'feedback','resolved',fid,1,'{"resolution":"Replaced tea"}');
  RAISE EXCEPTION 'Stale feedback accepted';
 EXCEPTION WHEN serialization_failure THEN NULL; END;
 BEGIN
  PERFORM public.perform_cafe_people_command(gen_random_uuid(),'feedback','resolved',fid,2,'{}');
  RAISE EXCEPTION 'Resolution without note accepted';
 EXCEPTION WHEN sqlstate '22023' THEN NULL; END;
 PERFORM public.perform_cafe_people_command(gen_random_uuid(),'feedback','resolved',fid,2,'{"resolution":"Replaced tea"}');
 PERFORM public.perform_cafe_people_command(gen_random_uuid(),'feedback','open',fid,3,'{"resolution":"Customer requested review"}');
 IF (SELECT count(*) FROM cafe_private.people_events WHERE entity_id=fid)<>4 THEN RAISE EXCEPTION 'Feedback audit missing'; END IF;

 req:=gen_random_uuid();
 r:=public.perform_cafe_people_command(req,'attendance','clock_in',null,null,'{}');
 aid:=(r->>'id')::uuid;
 duplicate:=public.perform_cafe_people_command(req,'attendance','clock_in',null,null,'{}');
 IF r<>duplicate THEN RAISE EXCEPTION 'Clock-in retry differs'; END IF;
 BEGIN
  PERFORM public.perform_cafe_people_command(gen_random_uuid(),'attendance','clock_in',null,null,'{}');
  RAISE EXCEPTION 'Second open shift accepted';
 EXCEPTION WHEN unique_violation THEN NULL; END;

 PERFORM set_config('test.actor','00000000-0000-0000-0000-000000000002',false);
 BEGIN
  PERFORM public.get_cafe_people_workspace('attendance',day,day);
  RAISE EXCEPTION 'Attendance without card permission accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 INSERT INTO public.staff_permissions VALUES(auth.uid(),'dashboard','attendance',null),(auth.uid(),'dashboard','feedback',null);
 BEGIN
  PERFORM public.perform_cafe_people_command(req,'attendance','clock_in',null,null,'{}');
  RAISE EXCEPTION 'Another actor replayed a command';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 IF jsonb_array_length(public.get_cafe_people_workspace('attendance',day,day)->'rows')<>0 THEN
  RAISE EXCEPTION 'Employee saw another attendance record'; END IF;
 BEGIN
  PERFORM public.perform_cafe_people_command(gen_random_uuid(),'attendance','clock_out',aid,1,'{}');
  RAISE EXCEPTION 'Employee closed another attendance';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.perform_cafe_people_command(gen_random_uuid(),'feedback','dismissed',fid,4,'{"resolution":"Not needed"}');
  RAISE EXCEPTION 'Staff dismissed feedback';
 EXCEPTION WHEN sqlstate '22023' THEN NULL; END;
 BEGIN
  PERFORM public.perform_cafe_people_command(gen_random_uuid(),'attendance','clock_in',null,null,'{"clocked_in_at":"2020-01-01"}');
  RAISE EXCEPTION 'Client supplied clock accepted';
 EXCEPTION WHEN sqlstate '22023' THEN NULL; END;
 r:=public.perform_cafe_people_command(gen_random_uuid(),'attendance','clock_in',null,null,'{}');
 IF jsonb_array_length(public.get_cafe_people_workspace('attendance',day,day)->'rows')<>1 THEN RAISE EXCEPTION 'Own record missing'; END IF;
 PERFORM set_config('test.actor','00000000-0000-0000-0000-000000000001',false);
 IF jsonb_array_length(public.get_cafe_people_workspace('attendance',day,day)->'rows')<>2 THEN RAISE EXCEPTION 'Admin records missing'; END IF;
 req:=gen_random_uuid();
 r:=public.perform_cafe_people_command(req,'attendance','clock_out',aid,1,'{}');
 duplicate:=public.perform_cafe_people_command(req,'attendance','clock_out',aid,1,'{}');
 IF r<>duplicate OR (r->>'version')::int<>2 THEN RAISE EXCEPTION 'Clock-out retry differs'; END IF;
 IF public.get_cafe_people_workspace('attendance',day,day)->'active'<>'null'::jsonb THEN RAISE EXCEPTION 'Closed shift still active'; END IF;
 BEGIN
  PERFORM public.get_cafe_people_workspace('feedback',day-31,day);
  RAISE EXCEPTION 'Unbounded date range accepted';
 EXCEPTION WHEN sqlstate '22023' THEN NULL; END;
 IF has_table_privilege('authenticated','public.cafe_staff_attendance','UPDATE') OR
    has_table_privilege('anon','public.cafe_customer_feedback','SELECT') OR
    has_function_privilege('anon','public.perform_cafe_people_command(uuid,text,text,uuid,integer,jsonb)','EXECUTE') THEN
  RAISE EXCEPTION 'Direct or anonymous access granted'; END IF;
END $$;

-- Check Baghdad midnight clipping without changing production data.
DO $ DECLARE crossing uuid:=gen_random_uuid(); boundary uuid:=gen_random_uuid(); workspace jsonb; seconds bigint; BEGIN
 INSERT INTO public.cafe_staff_attendance(id,staff_id,clocked_in_at,clocked_out_at) VALUES
  (crossing,'00000000-0000-0000-0000-000000000001','2026-10-16T20:30:00Z','2026-10-16T22:30:00Z'),
  (boundary,'00000000-0000-0000-0000-000000000001','2026-10-16T19:00:00Z','2026-10-16T21:00:00Z');
 workspace:=public.get_cafe_people_workspace('attendance','2026-10-17','2026-10-17');
 SELECT (value->>'period_seconds')::bigint INTO seconds FROM jsonb_array_elements(workspace->'rows') WHERE value->>'id'=crossing::text;
 IF seconds IS DISTINCT FROM 5400 THEN RAISE EXCEPTION 'Baghdad date clipping failed: %',seconds; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(workspace->'rows') WHERE value->>'id'=boundary::text) THEN RAISE EXCEPTION 'Exclusive date boundary failed'; END IF;
 INSERT INTO public.cafe_customer_feedback(title,category,created_by,created_at)
 SELECT 'Limit test','suggestion','00000000-0000-0000-0000-000000000001','2030-01-01T10:00:00Z' FROM generate_series(1,501);
 workspace:=public.get_cafe_people_workspace('feedback','2030-01-01','2030-01-01');
 IF workspace->'truncated'<>'true'::jsonb OR workspace->>'total_count'<>'501' OR jsonb_array_length(workspace->'rows')<>500 THEN
  RAISE EXCEPTION 'Bounded list or coverage indicator failed'; END IF;
END $;

-- Also execute the public invoker wrapper as the application role.
SET ROLE authenticated;
SELECT public.get_cafe_people_workspace('feedback',(now() AT TIME ZONE 'Asia/Baghdad')::date,(now() AT TIME ZONE 'Asia/Baghdad')::date);
RESET ROLE;
SELECT 'Feedback and attendance contract checks passed' AS result;
