-- Upgrade 212: read-only, permission-scoped manager overview.
-- Do not expose this RPC to employees without table-edit permission.
create or replace function public.gs_manager_table_job_overview()
returns table(job_id bigint, table_number integer, kind text, details text,
 priority text, status text, assigned_to uuid, employee_name text,
 due_at timestamptz, created_at timestamptz, claimed_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Table manager permission required';
 end if;
 return query
 select j.id, j.table_number, j.kind, j.details, j.priority, j.status,
  j.assigned_to, coalesce(nullif(p.full_name,''),'Employee')::text,
  j.due_at, j.created_at, j.claimed_at
 from public.gs_table_service_jobs j
 left join public.employee_profiles p on p.user_id=j.assigned_to
 where j.status in ('unassigned','assigned','in_progress')
 order by case j.priority when 'urgent' then 0 when 'high' then 1 else 2 end,
  j.due_at nulls last, j.created_at
 limit 500;
end; $$;
revoke all on function public.gs_manager_table_job_overview() from public,anon;
grant execute on function public.gs_manager_table_job_overview() to authenticated;
