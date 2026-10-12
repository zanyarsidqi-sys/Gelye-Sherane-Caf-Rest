-- Upgrade 1192: employee/device authorization registry, not hardware attestation.
-- A device ID is NOT a secret and must never authenticate an employee by itself.
create table if not exists public.gs_cafe_station_device_users (
 device_id uuid not null references public.gs_cafe_station_devices(id) on delete cascade,
 employee_id uuid not null references auth.users(id),
 active boolean not null default true,
 assigned_by uuid references auth.users(id),
 assigned_at timestamptz not null default transaction_timestamp(),
 primary key(device_id,employee_id)
);
alter table public.gs_cafe_station_device_users enable row level security;
revoke all on public.gs_cafe_station_device_users from public,anon,authenticated;

create or replace function public.gs_assign_station_device_user(
 p_device_id uuid,p_employee_id uuid,p_active boolean default true)
returns void language plpgsql security definer set search_path = '' as $$
declare v_station text;
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') or
    not exists(select 1 from public.gs_cafe_station_supervisors s
               where s.employee_id=auth.uid() and s.active) then
   raise exception 'Station supervisor permission required';
 end if;
 if p_device_id is null or p_employee_id is null or p_active is null then
   raise exception 'Device, employee and active flag required';
 end if;
 select d.station_key into v_station from public.gs_cafe_station_devices d
 join public.gs_cafe_preparation_stations s on s.station_key=d.station_key
 where d.id=p_device_id and d.enabled and s.enabled for update of d;
 if v_station is null then raise exception 'Enabled station device required'; end if;
 if p_active and not exists(
   select 1 from public.gs_cafe_station_employee_assignments a
   where a.station_key=v_station and a.employee_id=p_employee_id and a.active
 ) and not exists(
   select 1 from public.gs_cafe_station_supervisors s
   where s.employee_id=p_employee_id and s.active
 ) then raise exception 'Employee must be assigned to this station'; end if;
 insert into public.gs_cafe_station_device_users(device_id,employee_id,active,assigned_by)
 values(p_device_id,p_employee_id,p_active,auth.uid())
 on conflict(device_id,employee_id) do update set
 active=excluded.active,assigned_by=excluded.assigned_by,
 assigned_at=transaction_timestamp();
end;
$$;
revoke all on function public.gs_assign_station_device_user(uuid,uuid,boolean) from public,anon;
grant execute on function public.gs_assign_station_device_user(uuid,uuid,boolean) to authenticated;

create or replace function public.gs_my_authorized_station_devices()
returns table(device_id uuid,station_key text,display_name text,device_type text)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then
   raise exception 'Kitchen view permission required'; end if;
 return query select d.id,d.station_key,d.display_name,d.device_type
 from public.gs_cafe_station_devices d
 join public.gs_cafe_preparation_stations s on s.station_key=d.station_key and s.enabled
 join public.gs_cafe_station_device_users u on u.device_id=d.id
 where u.employee_id=auth.uid() and u.active and d.enabled and (
   exists(select 1 from public.gs_cafe_station_employee_assignments a
          where a.station_key=d.station_key and a.employee_id=auth.uid() and a.active)
   or exists(select 1 from public.gs_cafe_station_supervisors v
             where v.employee_id=auth.uid() and v.active)
 ) order by d.station_key,d.display_name;
end;
$$;
revoke all on function public.gs_my_authorized_station_devices() from public,anon;
grant execute on function public.gs_my_authorized_station_devices() to authenticated;

create or replace function public.gs_station_device_user_directory()
returns table(device_id uuid,employee_id uuid,active boolean,assigned_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') or
    not exists(select 1 from public.gs_cafe_station_supervisors s
               where s.employee_id=auth.uid() and s.active) then
   raise exception 'Station supervisor permission required'; end if;
 return query select u.device_id,u.employee_id,u.active,u.assigned_at
 from public.gs_cafe_station_device_users u order by u.assigned_at desc;
end;
$$;
revoke all on function public.gs_station_device_user_directory() from public,anon;
grant execute on function public.gs_station_device_user_directory() to authenticated;
