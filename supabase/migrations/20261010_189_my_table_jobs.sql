-- Upgrade 189: employee-owned job listing and guarded lifecycle transitions.
create or replace function public.gs_list_my_table_jobs()
returns table(job_id bigint,table_number integer,kind text,details text,
 priority text,status text,due_at timestamptz,claimed_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_view') then
  raise exception 'Not authorized to view table jobs';
 end if;
 return query select j.id,j.table_number,j.kind,j.details,j.priority,
 j.status,j.due_at,j.claimed_at from public.gs_table_service_jobs j
 where j.assigned_to=auth.uid() and j.status in ('assigned','in_progress')
 order by case j.priority when 'urgent' then 0 when 'high' then 1 else 2 end,
 j.due_at nulls last,j.claimed_at desc limit 200;
end; $$;
revoke all on function public.gs_list_my_table_jobs() from public,anon;
grant execute on function public.gs_list_my_table_jobs() to authenticated;

create or replace function public.gs_update_my_table_job(p_job_id bigint,p_action text)
returns text language plpgsql volatile security definer set search_path='' as $$
declare v_job public.gs_table_service_jobs%rowtype; v_next text;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_view') then
  raise exception 'Not authorized to update table jobs';
 end if;
 select * into v_job from public.gs_table_service_jobs
 where id=p_job_id for update;
 if not found or v_job.assigned_to is distinct from auth.uid() then
  raise exception 'Job not assigned to this employee';
 end if;
 if p_action='start' and v_job.status='assigned' then
  v_next:='in_progress';
 elsif p_action='complete' and v_job.status='in_progress' then
  -- Delivery jobs require verified fulfillment by the dedicated
  -- order-item workflow; closing the generic job must not imply delivery.
  if v_job.kind='deliver_items' then
   raise exception 'Delivery jobs must be completed via item delivery confirmation';
  end if;
  v_next:='completed';
 else
  raise exception 'Invalid job state transition';
 end if;
 update public.gs_table_service_jobs set status=v_next,
 completed_at=case when v_next='completed' then now() else completed_at end
 where id=v_job.id;
 insert into public.gs_table_service_job_events(
 job_id,event_kind,actor,recipient,details)
 values(v_job.id,'job_'||v_next,auth.uid(),v_job.created_by,
 jsonb_build_object('table_number',v_job.table_number,'kind',v_job.kind));
 return v_next;
end; $$;
revoke all on function public.gs_update_my_table_job(bigint,text) from public,anon;
grant execute on function public.gs_update_my_table_job(bigint,text) to authenticated;
