-- Upgrade 1190: supervisor-only station and assignment directory.
-- No direct table grants. Do not expose all auth.users.
create or replace function public.gs_station_assignment_directory()
returns table(station_key text, station_name text, employee_id uuid, active boolean, assigned_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') or not exists (
    select 1 from public.gs_cafe_station_supervisors s
    where s.employee_id = auth.uid() and s.active
  ) then
    raise exception 'Station supervisor authorization required';
  end if;
  return query
  select st.station_key, st.display_name, a.employee_id, coalesce(a.active,false), a.assigned_at
  from public.gs_cafe_preparation_stations st
  left join public.gs_cafe_station_employee_assignments a on a.station_key = st.station_key
  where st.enabled
  order by st.display_name, a.assigned_at desc nulls last;
end;
$$;
revoke all on function public.gs_station_assignment_directory() from public, anon;
grant execute on function public.gs_station_assignment_directory() to authenticated;

create or replace function public.gs_is_station_supervisor()
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and public.gs_can_access('kitchen','can_edit') and exists (
    select 1 from public.gs_cafe_station_supervisors s
    where s.employee_id = auth.uid() and s.active
  );
$$;
revoke all on function public.gs_is_station_supervisor() from public, anon;
grant execute on function public.gs_is_station_supervisor() to authenticated;
