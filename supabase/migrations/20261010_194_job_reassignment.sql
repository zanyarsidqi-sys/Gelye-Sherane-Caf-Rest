-- Upgrade 194: manager-controlled reassignment with atomic locking and audit.
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
