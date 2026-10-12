-- Upgrade 1222: administrator-provisioned station credentials.
-- A station account is a device identity, never an employee identity.
-- Password verification/session issuance must be done by a rate-limited trusted
-- Edge Function, not by an anonymously executable PostgreSQL RPC.
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.gs_cafe_station_accounts (
 station_key text primary key references public.gs_cafe_preparation_stations(station_key),
 username text not null unique check (username ~ '^[a-z][a-z0-9_.-]{3,63}$'),
 password_hash text not null,
 enabled boolean not null default true,
 allow_order_print boolean not null default true,
 allow_bill_print boolean not null default false,
 credential_version integer not null default 1 check (credential_version > 0),
 created_by uuid references auth.users(id),
 updated_at timestamptz not null default now()
);
create table if not exists public.gs_cafe_station_device_sessions (
 id uuid primary key default gen_random_uuid(),
 station_key text not null references public.gs_cafe_station_accounts(station_key),
 device_id uuid references public.gs_cafe_station_devices(id),
 token_hash text not null unique,
 credential_version integer not null,
 revoked_at timestamptz,
 expires_at timestamptz not null,
 last_seen_at timestamptz,
 printer_seen_at timestamptz,
 created_at timestamptz not null default now()
);
create index if not exists gs_station_sessions_status_idx
 on public.gs_cafe_station_device_sessions(station_key,expires_at,last_seen_at);
alter table public.gs_cafe_station_accounts enable row level security;
alter table public.gs_cafe_station_device_sessions enable row level security;
revoke all on public.gs_cafe_station_accounts from public,anon,authenticated;
revoke all on public.gs_cafe_station_device_sessions from public,anon,authenticated;

-- Authenticated manager only; no credential hashes returned to the UI.
create or replace function public.gs_1222_upsert_station_account(
 p_station_key text,p_username text,p_password text,
 p_order_print boolean default true,p_bill_print boolean default false
) returns void language plpgsql security definer set search_path='' as $$
declare v_username text:=lower(btrim(coalesce(p_username,'')));
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit')
   or not exists(select 1 from public.gs_cafe_station_supervisors s
     where s.employee_id=auth.uid() and s.active) then
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

create or replace function public.gs_1222_station_account_directory()
returns table(station_key text,station_name text,username text,enabled boolean,
 order_print boolean,bill_print boolean,last_seen_at timestamptz,
 online boolean)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit')
   or not exists(select 1 from public.gs_cafe_station_supervisors s
     where s.employee_id=auth.uid() and s.active) then
  raise exception 'Station supervisor permission required';
 end if;
 return query
 select a.station_key,s.display_name,a.username,a.enabled,
        a.allow_order_print,a.allow_bill_print,max(d.last_seen_at),
        coalesce(bool_or(d.revoked_at is null and d.expires_at>now()
          and d.last_seen_at>now()-interval '90 seconds'),false)
 from public.gs_cafe_station_accounts a
 join public.gs_cafe_preparation_stations s on s.station_key=a.station_key
 left join public.gs_cafe_station_device_sessions d on d.station_key=a.station_key
 group by a.station_key,s.display_name,a.username,a.enabled,
          a.allow_order_print,a.allow_bill_print
 order by s.display_name;
end $$;
revoke all on function public.gs_1222_upsert_station_account(text,text,text,boolean,boolean) from public,anon;
revoke all on function public.gs_1222_station_account_directory() from public,anon;
grant execute on function public.gs_1222_upsert_station_account(text,text,text,boolean,boolean) to authenticated;
grant execute on function public.gs_1222_station_account_directory() to authenticated;
