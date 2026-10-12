-- Upgrade 196: server-side employee eligibility checks for all assignment paths.
-- SECURITY DEFINER functions must never rely solely on the Flutter employee picker.
create or replace function public.gs_is_active_table_worker(p_user_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select p_user_id is not null and exists (
  select 1 from public.employee_profiles ep
  where ep.user_id=p_user_id and ep.is_active is true
 ) and exists(select 1 from auth.users au where au.id=p_user_id);
$$;
revoke all on function public.gs_is_active_table_worker(uuid) from public,anon,authenticated;
-- Permission checks remain in the calling RPC; eligibility does not grant access.

create or replace function public.gs_claim_table_service_job(p_job_id bigint)
returns table(job_id bigint,assigned_employee uuid,new_status text,event_id bigint)
language plpgsql volatile security definer set search_path='' as $$
declare v_job public.gs_table_service_jobs%rowtype;
 v_event bigint;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_view') then
  raise exception 'Not authorized to claim table jobs';
 end if;
 select * into v_job from public.gs_table_service_jobs
 where id=p_job_id for update;
 if not found then raise exception 'Job not found'; end if;
 if not public.gs_is_active_table_worker(auth.uid()) then
  raise exception 'Active employee profile required to claim jobs';
 end if;
 if v_job.status<>'unassigned' or v_job.assigned_to is not null then
  raise exception 'Job is no longer available';
 end if;
 update public.gs_table_service_jobs
 set status='assigned',assigned_to=auth.uid(),claimed_at=now()
 where id=v_job.id;
 insert into public.gs_table_service_job_events(
  job_id,event_kind,actor,recipient,details)
 values(v_job.id,'job_claimed',auth.uid(),v_job.created_by,
  jsonb_build_object('table_number',v_job.table_number,
                     'kind',v_job.kind,'claimed_by',auth.uid()))
 returning id into v_event;
 return query select v_job.id,auth.uid(),'assigned'::text,v_event;
end; $$;
revoke all on function public.gs_claim_table_service_job(bigint) from public,anon;
grant execute on function public.gs_claim_table_service_job(bigint) to authenticated;


create or replace function public.gs_reassign_table_service_job(
 p_job_id bigint,p_new_employee uuid,p_reason text)
returns text language plpgsql volatile security definer set search_path='' as $$
declare v_job public.gs_table_service_jobs%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Not authorized to reassign jobs';
 end if;
 if p_new_employee is null or length(trim(coalesce(p_reason,''))) not between 3 and 500 then
  raise exception 'A new employee and a reason are required';
 end if;
 select * into v_job from public.gs_table_service_jobs
 where id=p_job_id for update;
 if not found then raise exception 'Job not found'; end if;
 if v_job.status not in ('assigned','in_progress') then
  raise exception 'Only active assigned jobs can be reassigned';
 end if;
 if v_job.assigned_to=p_new_employee then
  raise exception 'The employee is already assigned';
 end if;
 if not public.gs_is_active_table_worker(p_new_employee) then
  raise exception 'Target must be an active employee with Tables access';
 end if;
 if not exists(select 1 from auth.users u where u.id=p_new_employee) then
  raise exception 'Employee account not found';
 end if;
 -- Reassigning an in-progress delivery is blocked: physical custody
 -- must be resolved through a dedicated handoff procedure.
 if v_job.kind='deliver_items' and v_job.status='in_progress' then
  raise exception 'Delivery already in progress: use verified handoff workflow';
 end if;
 update public.gs_table_service_jobs set assigned_to=p_new_employee,
 status='assigned',claimed_at=now() where id=p_job_id;
 -- Notify new assignee (via existing Upgrade 193 trigger), and creator.
 insert into public.gs_table_service_job_events(
 job_id,event_kind,actor,recipient,details)
 values(p_job_id,'job_reassigned',auth.uid(),v_job.created_by,
 jsonb_build_object('previous_employee',v_job.assigned_to,
 'new_employee',p_new_employee,'reason',trim(p_reason),
 'table_number',v_job.table_number));
 -- Notify previous employee separately, without changing current assignee.
 insert into public.gs_table_service_job_events(
 job_id,event_kind,actor,recipient,details)
 values(p_job_id,'job_reassignment_removed',auth.uid(),v_job.assigned_to,
 jsonb_build_object('previous_employee',v_job.assigned_to,
 'new_employee',p_new_employee,'reason',trim(p_reason),
 'table_number',v_job.table_number));
 return 'assigned';
end; $$;
revoke all on function public.gs_reassign_table_service_job(bigint,uuid,text)
 from public,anon;
grant execute on function public.gs_reassign_table_service_job(bigint,uuid,text)
 to authenticated;
