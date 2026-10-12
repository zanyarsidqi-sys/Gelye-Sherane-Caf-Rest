-- Upgrade 1246: explicit per-station administrative scope.
-- Fail closed until a trusted database administrator provisions grants.
-- No self-grant RPC; bootstrap via reviewed SQL under database administrator control.
create table if not exists public.gs_cafe_station_scope_admins (
 employee_id uuid not null references auth.users(id),
 station_key text references public.gs_cafe_preparation_stations(station_key),
 can_create boolean not null default false,
 active boolean not null default true,
 granted_at timestamptz not null default now(),
 primary key(employee_id,station_key)
);
-- A global creator row needs a non-null key due to PK, so use separate table.
create table if not exists public.gs_cafe_station_creation_admins (
 employee_id uuid primary key references auth.users(id),
 active boolean not null default true,
 granted_at timestamptz not null default now()
);
alter table public.gs_cafe_station_scope_admins enable row level security;
alter table public.gs_cafe_station_creation_admins enable row level security;
revoke all on public.gs_cafe_station_scope_admins,public.gs_cafe_station_creation_admins from public,anon,authenticated;
create or replace function public.gs_1246_can_manage_station(p_station_key text)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and coalesce(auth.jwt()->>'aal','')='aal2'
 and public.gs_can_access('kitchen','can_edit')
 and exists(select 1 from public.gs_cafe_station_supervisors s where s.employee_id=auth.uid() and s.active)
 and exists(select 1 from public.gs_cafe_station_scope_admins a where a.employee_id=auth.uid() and a.station_key=p_station_key and a.active);
$$;
revoke all on function public.gs_1246_can_manage_station(text) from public,anon;
grant execute on function public.gs_1246_can_manage_station(text) to authenticated;
create or replace function public.gs_manage_station_device(
 p_id uuid, p_station_key text, p_name text, p_type text,
 p_reference text default null, p_enabled boolean default true
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_name text := btrim(coalesce(p_name,''));
begin
 if not public.gs_1246_can_manage_station(p_station_key) then
   raise exception 'Station supervisor permission required';
 end if;
 if p_station_key is null or not exists(select 1 from public.gs_cafe_preparation_stations
         where station_key=p_station_key and enabled)
    or char_length(v_name) not between 1 and 100
    or p_type is null or p_type not in ('tablet','screen','printer','pos','other')
    or char_length(coalesce(p_reference,'')) > 160 or p_enabled is null then
   raise exception 'Invalid station device details';
 end if;
 if p_id is not null and (not exists (select 1 from public.gs_cafe_station_devices d where d.id=p_id and d.station_key=p_station_key) or exists (select 1 from public.gs_cafe_station_device_users u where u.device_id=p_id and u.active and not p_enabled)) then
   raise exception 'Device station changes or disabling assigned devices require explicit deauthorization first';
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

create or replace function public.gs_assign_station_device_user(
 p_device_id uuid,p_employee_id uuid,p_active boolean default true)
returns void language plpgsql security definer set search_path = '' as $$
declare v_station text;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_device_id is null or p_employee_id is null or p_active is null then
   raise exception 'Device, employee and active flag required';
 end if;
 select d.station_key into v_station from public.gs_cafe_station_devices d
 join public.gs_cafe_preparation_stations s on s.station_key=d.station_key
 where d.id=p_device_id and d.enabled and s.enabled for update of d;
 if v_station is null then raise exception 'Enabled station device required'; end if;
 if not public.gs_1246_can_manage_station(v_station) then raise exception 'Not authorized for this station'; end if;
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

create or replace function public.gs_set_product_preparation_station(p_product_id bigint,p_station_key text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('menu','can_edit') or not public.gs_1246_can_manage_station(p_station_key) then
  raise exception 'Menu edit permission required'; end if;
 if not exists(select 1 from public.gs_menu_products where id=p_product_id) then
  raise exception 'Product not found'; end if;
 if not exists(select 1 from public.gs_cafe_preparation_stations where station_key=p_station_key and enabled) then
  raise exception 'Active preparation station required'; end if;
 insert into public.gs_cafe_product_preparation(product_id,station_key,updated_by)
 values(p_product_id,p_station_key,auth.uid()) on conflict(product_id)
 do update set station_key=excluded.station_key,updated_by=excluded.updated_by,updated_at=now();
end $$;

create or replace function public.gs_1242_create_station(
 p_key text, p_name text, p_method text, p_target_id bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare v_name text := btrim(coalesce(p_name,''));
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'aal','') <> 'aal2'
    or not public.gs_can_access('kitchen','can_edit')
    or not exists (select 1 from public.gs_cafe_station_supervisors s
                   where s.employee_id=auth.uid() and s.active) then
   raise exception 'MFA and kitchen supervisor permission required';
 end if;
 if p_key is null or p_key !~ '^[a-z][a-z0-9_]{1,39}$'
    or char_length(v_name) not between 1 and 100
    or p_method is null or p_method not in ('pos','printer')
    or p_target_id is null or p_target_id <= 0 then
   raise exception 'Invalid station details';
 end if;
 if p_method='printer' and not exists(
    select 1 from public.gs_cafe_printers p
    where p.id=p_target_id and p.is_enabled) then
   raise exception 'An enabled printer must be configured first';
 end if;
 if p_method='pos' and not exists(
    select 1 from public.gs_cafe_pos_devices d where d.id=p_target_id) then
   raise exception 'An existing POS device must be configured first';
 end if;
 -- Creation is restricted to explicitly designated global station administrators.
 if not exists(select 1 from public.gs_cafe_station_creation_admins a where a.employee_id=auth.uid() and a.active) then raise exception 'Station creation administrator required'; end if;
 insert into public.gs_cafe_preparation_stations(
   station_key,display_name,enabled,online_method,pos_device_id,printer_id,updated_by)
 values (p_key,v_name,true,p_method,
   case when p_method='pos' then p_target_id else null end,
   case when p_method='printer' then p_target_id else null end,
   auth.uid());
end $$;

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
 where public.gs_1246_can_manage_station(d.station_key)
 order by s.display_name,d.display_name;
end;
$$;

create or replace function public.gs_1222_upsert_station_account(
 p_station_key text,p_username text,p_password text,
 p_order_print boolean default true,p_bill_print boolean default false
) returns void language plpgsql security definer set search_path='' as $$
declare v_username text:=lower(btrim(coalesce(p_username,'')));
begin
 if not public.gs_1246_can_manage_station(p_station_key) then
  raise exception 'Station supervisor permission required';
 end if;
 if not exists(select 1 from public.gs_cafe_preparation_stations s
   where s.station_key=p_station_key and s.enabled) then
  raise exception 'Create and enable station with a printing destination first';
 end if;
 if v_username !~ '^[a-z][a-z0-9_.-]{3,63}$'
   or p_password is null or length(p_password) < 12 or length(p_password) > 128
   or p_order_print is null or p_bill_print is null then
  raise exception 'Invalid station credentials or printing permissions';
 end if;
 insert into public.gs_cafe_station_accounts
   (station_key,username,password_hash,allow_order_print,allow_bill_print,created_by)
 values (p_station_key,v_username,
   extensions.crypt(p_password,extensions.gen_salt('bf',12)),
   p_order_print,p_bill_print,auth.uid())
 on conflict(station_key) do update set
   username=excluded.username,password_hash=excluded.password_hash,
   allow_order_print=excluded.allow_order_print,
   allow_bill_print=excluded.allow_bill_print,
   credential_version=gs_cafe_station_accounts.credential_version+1,
   updated_at=now();
 -- Password reset invalidates all previous device sessions.
 update public.gs_cafe_station_device_sessions
 set revoked_at=coalesce(revoked_at,now())
 where station_key=p_station_key and revoked_at is null;
end $$;

create or replace function public.gs_1245_kitchen_station_account_setup_directory()
returns table(station_key text,station_name text,username text,enabled boolean,
 order_print boolean,bill_print boolean,online boolean)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit')
   or not exists(select 1 from public.gs_cafe_station_supervisors x
     where x.employee_id=auth.uid() and x.active) then
   raise exception 'Kitchen station supervisor required';
 end if;
 return query select s.station_key,s.display_name,a.username,s.enabled,
   coalesce(a.allow_order_print,false),coalesce(a.allow_bill_print,false),
   coalesce(exists(select 1 from public.gs_cafe_station_device_sessions d
     where d.station_key=s.station_key and d.revoked_at is null
       and d.expires_at>now() and d.last_seen_at>now()-interval '90 seconds'),false)
 from public.gs_cafe_preparation_stations s
 left join public.gs_cafe_station_accounts a on a.station_key=s.station_key
 where public.gs_1246_can_manage_station(s.station_key)
 order by s.display_name;
end $$;
-- Existing legacy station-setting RPC bypasses Kitchen station scope: disable client execution.
revoke execute on function public.gs_set_preparation_station(text,text,text,bigint,bigint,bigint) from public,anon,authenticated;
-- Explicit station grants and creation grants must be provisioned before use.
