-- Upgrade 1247: close legacy cross-station administrative access.
-- Review in staging before applying. No service-role login contract is changed.
create or replace function public.gs_1217_save_station(p_key text,p_name text,p_enabled boolean default true)
returns void language plpgsql security definer set search_path='' as $$
begin
 if p_key is null or not public.gs_1246_can_manage_station(p_key) then
  raise exception 'Not authorized for this station'; end if;
 if p_key !~ '^[a-z][a-z0-9_]{1,39}$' or p_name is null
  or length(btrim(p_name)) not between 1 and 100 or p_enabled is null then
  raise exception 'Invalid station configuration'; end if;
 perform 1 from public.gs_cafe_preparation_stations where station_key=p_key for update;
 if not found then raise exception 'Station not found'; end if;
 if not p_enabled and exists(select 1 from public.gs_cafe_order_station_tickets
    where station_key=p_key and status in ('queued','received','failed','unknown')) then
   raise exception 'Station has pending tickets'; end if;
 update public.gs_cafe_preparation_stations set display_name=btrim(p_name),
  enabled=p_enabled,updated_by=auth.uid(),updated_at=now() where station_key=p_key;
end $$;

create or replace function public.gs_assign_station_employee(
 p_station_key text,p_employee_id uuid,p_active boolean default true)
returns void language plpgsql security definer set search_path='' as $$
begin
 if p_station_key is null or not public.gs_1246_can_manage_station(p_station_key) then
  raise exception 'Not authorized for this station'; end if;
 if p_employee_id is null or p_active is null or not exists(
  select 1 from public.gs_cafe_preparation_stations where station_key=p_station_key and enabled)
  or not exists(select 1 from auth.users where id=p_employee_id) then
  raise exception 'Valid active station and employee required'; end if;
 insert into public.gs_cafe_station_employee_assignments(station_key,employee_id,assigned_by,active)
 values(p_station_key,p_employee_id,auth.uid(),p_active)
 on conflict(station_key,employee_id) do update set
 active=excluded.active,assigned_by=excluded.assigned_by,assigned_at=transaction_timestamp();
 -- Revoking a station assignment also removes that employee's device authorization there.
 if not p_active then
  update public.gs_cafe_station_device_users u set active=false,assigned_by=auth.uid(),
   assigned_at=transaction_timestamp()
  from public.gs_cafe_station_devices d
  where u.device_id=d.id and d.station_key=p_station_key and u.employee_id=p_employee_id;
 end if;
end $$;

create or replace function public.gs_station_assignment_directory()
returns table(station_key text,station_name text,employee_id uuid,active boolean,assigned_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') then
  raise exception 'Kitchen edit permission required'; end if;
 return query select st.station_key,st.display_name,a.employee_id,coalesce(a.active,false),a.assigned_at
 from public.gs_cafe_preparation_stations st
 left join public.gs_cafe_station_employee_assignments a on a.station_key=st.station_key
 where public.gs_1246_can_manage_station(st.station_key)
 order by st.display_name,a.assigned_at desc nulls last;
end $$;

create or replace function public.gs_station_device_user_directory()
returns table(device_id uuid,employee_id uuid,active boolean,assigned_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') then
  raise exception 'Kitchen edit permission required'; end if;
 return query select u.device_id,u.employee_id,u.active,u.assigned_at
 from public.gs_cafe_station_device_users u
 join public.gs_cafe_station_devices d on d.id=u.device_id
 where public.gs_1246_can_manage_station(d.station_key)
 order by u.assigned_at desc;
end $$;

create or replace function public.gs_1223_revoke_station_sessions(p_station_key text)
returns integer language plpgsql security definer set search_path='' as $$
declare v_count integer;
begin
 if p_station_key is null or not public.gs_1246_can_manage_station(p_station_key) then
  raise exception 'Not authorized for this station'; end if;
 update public.gs_cafe_station_device_sessions set revoked_at=now()
 where station_key=p_station_key and revoked_at is null;
 get diagnostics v_count=row_count;
 return v_count;
end $$;

-- Service-role-only RPCs are never exposed to regular client roles.
revoke all on function public.gs_1223_device_login(text,text,text) from public,anon,authenticated;
revoke all on function public.gs_1223_device_heartbeat(text,boolean) from public,anon,authenticated;
revoke all on function public.gs_1226_device_logout(text) from public,anon,authenticated;
revoke all on function public.gs_1217_save_station(text,text,boolean) from public,anon;
revoke all on function public.gs_assign_station_employee(text,uuid,boolean) from public,anon;
revoke all on function public.gs_station_assignment_directory() from public,anon;
revoke all on function public.gs_station_device_user_directory() from public,anon;
revoke all on function public.gs_1223_revoke_station_sessions(text) from public,anon;
grant execute on function public.gs_1217_save_station(text,text,boolean),
 public.gs_assign_station_employee(text,uuid,boolean),
 public.gs_station_assignment_directory(),public.gs_station_device_user_directory(),
 public.gs_1223_revoke_station_sessions(text) to authenticated;
