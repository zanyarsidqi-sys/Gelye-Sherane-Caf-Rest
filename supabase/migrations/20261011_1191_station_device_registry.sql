-- Upgrade 1191: supervisor-controlled station device inventory.
-- This is an administrative registry, NOT cryptographic device authentication.
create table if not exists public.gs_cafe_station_devices (
 id uuid primary key default gen_random_uuid(),
 station_key text not null references public.gs_cafe_preparation_stations(station_key),
 display_name text not null check (char_length(btrim(display_name)) between 1 and 100),
 device_type text not null check (device_type in ('tablet','screen','printer','pos','other')),
 device_reference text check (device_reference is null or char_length(device_reference) <= 160),
 enabled boolean not null default true,
 created_by uuid references auth.users(id),
 created_at timestamptz not null default transaction_timestamp(),
 updated_at timestamptz not null default transaction_timestamp()
);
create index if not exists gs_station_devices_station_idx on public.gs_cafe_station_devices(station_key,enabled);
alter table public.gs_cafe_station_devices enable row level security;
revoke all on public.gs_cafe_station_devices from public,anon,authenticated;

create or replace function public.gs_manage_station_device(
 p_id uuid, p_station_key text, p_name text, p_type text,
 p_reference text default null, p_enabled boolean default true
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_name text := btrim(coalesce(p_name,''));
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit')
    or not exists(select 1 from public.gs_cafe_station_supervisors s
                  where s.employee_id=auth.uid() and s.active) then
   raise exception 'Station supervisor permission required';
 end if;
 if p_station_key is null or not exists(select 1 from public.gs_cafe_preparation_stations
         where station_key=p_station_key and enabled)
    or char_length(v_name) not between 1 and 100
    or p_type is null or p_type not in ('tablet','screen','printer','pos','other')
    or char_length(coalesce(p_reference,'')) > 160 or p_enabled is null then
   raise exception 'Invalid station device details';
 end if;
 if p_id is null then
   insert into public.gs_cafe_station_devices(station_key,display_name,device_type,device_reference,enabled,created_by)
   values(p_station_key,v_name,p_type,nullif(btrim(p_reference),''),p_enabled,auth.uid()) returning id into v_id;
 else
   update public.gs_cafe_station_devices
      set station_key=p_station_key, display_name=v_name, device_type=p_type,
          device_reference=nullif(btrim(p_reference),''), enabled=p_enabled,
          updated_at=transaction_timestamp()
    where id=p_id returning id into v_id;
   if v_id is null then raise exception 'Device not found'; end if;
 end if;
 return v_id;
end;
$$;
revoke all on function public.gs_manage_station_device(uuid,text,text,text,text,boolean) from public,anon;
grant execute on function public.gs_manage_station_device(uuid,text,text,text,text,boolean) to authenticated;

create or replace function public.gs_station_device_directory()
returns table(id uuid,station_key text,station_name text,display_name text,device_type text,
 device_reference text,enabled boolean,updated_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit')
    or not exists(select 1 from public.gs_cafe_station_supervisors s
                  where s.employee_id=auth.uid() and s.active) then
   raise exception 'Station supervisor permission required';
 end if;
 return query select d.id,d.station_key,s.display_name,d.display_name,d.device_type,
                     d.device_reference,d.enabled,d.updated_at
 from public.gs_cafe_station_devices d
 join public.gs_cafe_preparation_stations s on s.station_key=d.station_key
 order by s.display_name,d.display_name;
end;
$$;
revoke all on function public.gs_station_device_directory() from public,anon;
grant execute on function public.gs_station_device_directory() to authenticated;
