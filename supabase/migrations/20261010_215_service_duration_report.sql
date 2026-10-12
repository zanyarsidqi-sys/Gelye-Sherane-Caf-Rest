-- Upgrade 215: manager-only service duration reporting for completed jobs.
-- No changes to job lifecycle or employee permissions.
create or replace function public.gs_manager_table_service_duration_report(
  p_days integer default 30)
returns table(job_id bigint, table_number integer, kind text,
  assigned_to uuid, employee_name text, created_at timestamptz,
  claimed_at timestamptz, completed_at timestamptz,
  response_minutes numeric, service_minutes numeric,
  completed_after_due boolean)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Table manager permission required';
 end if;
 if p_days not in (7,30,90) then
  raise exception 'Reporting period must be 7, 30, or 90 days';
 end if;
 return query
 select j.id,j.table_number,j.kind,j.assigned_to,
  coalesce(nullif(p.full_name,''),'Employee')::text,
  j.created_at,j.claimed_at,j.completed_at,
  case when j.claimed_at is not null and j.claimed_at >= j.created_at
   then round((extract(epoch from (j.claimed_at-j.created_at))/60)::numeric,1)
   else null::numeric end,
  case when j.claimed_at is not null and j.completed_at >= j.claimed_at
   then round((extract(epoch from (j.completed_at-j.claimed_at))/60)::numeric,1)
   else null::numeric end,
  (j.due_at is not null and j.completed_at > j.due_at)
 from public.gs_table_service_jobs j
 left join public.employee_profiles p on p.user_id=j.assigned_to
 where j.status='completed' and j.completed_at is not null
  and j.completed_at >= now() - make_interval(days => p_days)
 order by j.completed_at desc, j.id desc limit 500;
end; $$;
revoke all on function public.gs_manager_table_service_duration_report(integer)
 from public,anon;
grant execute on function public.gs_manager_table_service_duration_report(integer)
 to authenticated;
