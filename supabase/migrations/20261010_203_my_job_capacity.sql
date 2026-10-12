-- Upgrade 203: per-user job capacity for the available-jobs picker.
-- Never expose other employees' workload. Claims remain validated by server triggers.
create or replace function public.gs_my_table_job_capacity()
returns table(job_kind text, eligible boolean, active_jobs bigint, max_active integer, remaining_slots bigint)
language plpgsql stable security definer set search_path='' as $$
declare v_user uuid;
begin
 v_user := auth.uid();
 if v_user is null or not public.gs_can_access('tables','can_view') then
  raise exception 'Table view permission required';
 end if;
 return query
 select l.job_kind,
  public.gs_can_work_table_job(v_user,l.job_kind),
  (select count(*) from public.gs_table_service_jobs j
    where j.assigned_to=v_user and j.kind=l.job_kind
      and j.status in ('assigned','in_progress'))::bigint,
  l.max_active,
  greatest(0,l.max_active::bigint -
   (select count(*) from public.gs_table_service_jobs j
    where j.assigned_to=v_user and j.kind=l.job_kind
      and j.status in ('assigned','in_progress'))::bigint)
 from public.gs_table_job_workload_limits l
 order by l.job_kind;
end; $$;
revoke all on function public.gs_my_table_job_capacity() from public,anon;
grant execute on function public.gs_my_table_job_capacity() to authenticated;
