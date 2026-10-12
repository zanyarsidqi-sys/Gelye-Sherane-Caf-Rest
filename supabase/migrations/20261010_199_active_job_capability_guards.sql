-- Upgrade 199: prevent permission revocation while work remains assigned.
-- The active-job list is manager-only and does not expose customer details.
create or replace function public.gs_list_table_worker_active_job_counts(p_employee uuid)
returns table(job_kind text, active_count bigint)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('employees','can_edit') then
  raise exception 'Employee management permission required';
 end if;
 return query select j.kind, count(*)::bigint
 from public.gs_table_service_jobs j
 where j.assigned_to=p_employee and j.status in ('assigned','in_progress')
 group by j.kind order by j.kind;
end; $$;
revoke all on function public.gs_list_table_worker_active_job_counts(uuid) from public,anon;
grant execute on function public.gs_list_table_worker_active_job_counts(uuid) to authenticated;

-- Existing RPC signature retained for compatibility with Upgrade 198 UI.
-- Row locks ensure a concurrent job claim/reassignment cannot slip through
-- a permission revocation: both paths touch the employee's job rows.
create or replace function public.gs_set_table_worker_capability(
 p_employee uuid,p_kind text,p_enabled boolean)
returns void language plpgsql volatile security definer set search_path='' as $$
declare v_active bigint;
begin
 if auth.uid() is null or not public.gs_can_access('employees','can_edit') then
  raise exception 'Employee management permission required';
 end if;
 if p_kind not in ('take_order','deliver_items','clean','shisha_service',
                   'tea_service','bring_bill','other') or p_enabled is null then
  raise exception 'Invalid job capability';
 end if;
 if not public.gs_is_active_table_worker(p_employee) then
  raise exception 'Employee must be active';
 end if;
 -- Serialize grant updates for this employee and kind.
 perform pg_advisory_xact_lock(hashtextextended(p_employee::text || ':' || p_kind,0));
 if p_enabled then
  insert into public.gs_table_worker_capabilities(employee_user_id,job_kind,granted_by)
  values(p_employee,p_kind,auth.uid()) on conflict do nothing;
 else
  -- Fail closed until the manager reassigns or completes all active jobs.
  select count(*) into v_active from public.gs_table_service_jobs j
  where j.assigned_to=p_employee and j.kind=p_kind
    and j.status in ('assigned','in_progress');
  if v_active>0 then
   raise exception 'Cannot revoke %: employee has % active job(s). Reassign or complete them first.',p_kind,v_active;
  end if;
  delete from public.gs_table_worker_capabilities
  where employee_user_id=p_employee and job_kind=p_kind;
 end if;
 insert into public.gs_table_worker_capability_events(
  employee_user_id,job_kind,enabled,actor)
 values(p_employee,p_kind,p_enabled,auth.uid());
end; $$;
revoke all on function public.gs_set_table_worker_capability(uuid,text,boolean) from public,anon;
grant execute on function public.gs_set_table_worker_capability(uuid,text,boolean) to authenticated;

-- Database invariant: no existing active assignment may lose its capability.
-- Restrict direct capability deletion too (not just the management RPC).
create or replace function public.gs_guard_active_table_capability_revoke()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists (select 1 from public.gs_table_service_jobs j
   where j.assigned_to=old.employee_user_id and j.kind=old.job_kind
     and j.status in ('assigned','in_progress')) then
  raise exception 'Active table jobs must be reassigned before capability revocation';
 end if;
 return old;
end; $$;
drop trigger if exists gs_guard_active_table_capability_revoke_trg
 on public.gs_table_worker_capabilities;
create trigger gs_guard_active_table_capability_revoke_trg
 before delete on public.gs_table_worker_capabilities
 for each row execute function public.gs_guard_active_table_capability_revoke();
