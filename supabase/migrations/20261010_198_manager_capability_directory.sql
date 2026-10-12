-- Upgrade 198: read-only manager directory and capability list RPCs.
-- Writes continue through gs_set_table_worker_capability (Upgrade 197).
create or replace function public.gs_list_table_capability_employees()
returns table(user_id uuid, full_name text)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('employees','can_edit') then
  raise exception 'Employee management permission required';
 end if;
 return query select p.user_id, coalesce(nullif(p.full_name,''),'Employee')::text
 from public.employee_profiles p where p.is_active=true
 order by p.full_name nulls last, p.user_id limit 500;
end; $$;
revoke all on function public.gs_list_table_capability_employees() from public,anon;
grant execute on function public.gs_list_table_capability_employees() to authenticated;

create or replace function public.gs_list_table_worker_capabilities(p_employee uuid)
returns setof text language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('employees','can_edit') then
  raise exception 'Employee management permission required';
 end if;
 if not exists (select 1 from public.employee_profiles p
   where p.user_id=p_employee and p.is_active=true) then
  raise exception 'Employee is not active';
 end if;
 return query select c.job_kind from public.gs_table_worker_capabilities c
  where c.employee_user_id=p_employee order by c.job_kind;
end; $$;
revoke all on function public.gs_list_table_worker_capabilities(uuid) from public,anon;
grant execute on function public.gs_list_table_worker_capabilities(uuid) to authenticated;
