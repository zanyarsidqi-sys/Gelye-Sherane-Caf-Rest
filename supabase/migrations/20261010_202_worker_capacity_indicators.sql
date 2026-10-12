-- Upgrade 202: display authoritative workload limits alongside eligible workers.
-- Includes full-capacity workers for visibility but the Flutter picker disables them.
-- Reassignment enforcement remains server-side in the Upgrade 201 trigger.
create or replace function public.gs_list_eligible_table_job_workers(p_job_id bigint)
returns table(user_id uuid, full_name text, job_kind text, active_jobs bigint,
 kind_jobs bigint, max_active integer, remaining_slots bigint, capacity_state text)
language plpgsql stable security definer set search_path='' as $$
declare v_kind text; v_assigned uuid; v_status text; v_limit integer;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Table manager permission required';
 end if;
 select j.kind,j.assigned_to,j.status into v_kind,v_assigned,v_status
 from public.gs_table_service_jobs j where j.id=p_job_id;
 if not found then raise exception 'Job not found'; end if;
 if v_status not in ('assigned','in_progress') then
  raise exception 'Only active assigned jobs can be reassigned';
 end if;
 if v_kind='deliver_items' and v_status='in_progress' then
  raise exception 'Delivery in progress requires verified handoff';
 end if;
 select l.max_active into v_limit from public.gs_table_job_workload_limits l
 where l.job_kind=v_kind;
 if v_limit is null then raise exception 'Job workload limit is not configured'; end if;
 return query
 with workers as (
  select p.user_id, coalesce(nullif(p.full_name,''),'Employee')::text as full_name,
   (select count(*) from public.gs_table_service_jobs j
    where j.assigned_to=p.user_id and j.status in ('assigned','in_progress'))::bigint as active_jobs,
   (select count(*) from public.gs_table_service_jobs j
    where j.assigned_to=p.user_id and j.kind=v_kind
      and j.status in ('assigned','in_progress'))::bigint as kind_jobs
  from public.employee_profiles p
  where p.is_active=true and p.user_id is distinct from v_assigned
    and public.gs_can_work_table_job(p.user_id,v_kind)
 )
 select w.user_id,w.full_name,v_kind,w.active_jobs,w.kind_jobs,v_limit,
  greatest(0,v_limit::bigint-w.kind_jobs),
  case when w.kind_jobs>=v_limit then 'full'
       when w.kind_jobs>=greatest(0,v_limit-1) then 'near_limit'
       else 'available' end::text
 from workers w
 order by (w.kind_jobs>=v_limit),w.kind_jobs,w.active_jobs,w.full_name,w.user_id
 limit 500;
end; $$;
revoke all on function public.gs_list_eligible_table_job_workers(bigint) from public,anon;
grant execute on function public.gs_list_eligible_table_job_workers(bigint) to authenticated;
