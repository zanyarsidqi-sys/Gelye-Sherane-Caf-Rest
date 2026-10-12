-- Upgrade 216: database-side employee performance aggregates (not capped at 500 jobs).
-- Averages exclude missing/invalid timestamps; late rate excludes jobs without a due date.
create or replace function public.gs_manager_table_employee_performance(p_days integer default 30)
returns table(employee_id uuid, employee_name text, completed_jobs bigint,
 measured_responses bigint, avg_response_minutes numeric,
 measured_services bigint, avg_service_minutes numeric,
 jobs_with_deadline bigint, late_jobs bigint, late_percent numeric)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Table manager permission required';
 end if;
 if p_days not in (7,30,90) then
  raise exception 'Reporting period must be 7, 30, or 90 days';
 end if;
 return query
 with jobs as (
  select j.assigned_to as worker, j.created_at, j.claimed_at,
   j.completed_at, j.due_at
  from public.gs_table_service_jobs j
  where j.status='completed' and j.completed_at is not null
   and j.assigned_to is not null
   and j.completed_at >= now()-make_interval(days=>p_days)
 ), stats as (
  select worker, count(*) as completed,
   count(*) filter(where claimed_at is not null and claimed_at>=created_at) as responses,
   round(avg(extract(epoch from (claimed_at-created_at))/60)
    filter(where claimed_at is not null and claimed_at>=created_at)::numeric,1) as avg_response,
   count(*) filter(where claimed_at is not null and completed_at>=claimed_at) as services,
   round(avg(extract(epoch from (completed_at-claimed_at))/60)
    filter(where claimed_at is not null and completed_at>=claimed_at)::numeric,1) as avg_service,
   count(*) filter(where due_at is not null) as deadline_count,
   count(*) filter(where due_at is not null and completed_at>due_at) as late_count
  from jobs group by worker
 )
 select s.worker,coalesce(nullif(p.full_name,''),'Employee')::text,
  s.completed,s.responses,s.avg_response,s.services,s.avg_service,
  s.deadline_count,s.late_count,
  case when s.deadline_count>0 then
   round(100.0*s.late_count/s.deadline_count,1)
   else null::numeric end
 from stats s left join public.employee_profiles p on p.user_id=s.worker
 order by s.late_count desc,s.completed desc,s.worker;
end; $$;
revoke all on function public.gs_manager_table_employee_performance(integer) from public,anon;
grant execute on function public.gs_manager_table_employee_performance(integer) to authenticated;
