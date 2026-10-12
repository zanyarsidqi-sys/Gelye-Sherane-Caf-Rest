-- Upgrade 1223: station-device login, rate limiting and revocable sessions.
-- These RPCs are restricted to service_role. Edge Function owns the API surface.
create table if not exists public.gs_cafe_station_login_attempts (
 id bigint generated always as identity primary key,
 username text not null,
 attempt_at timestamptz not null default now(),
 success boolean not null default false
);
create index if not exists gs_station_attempt_window on public.gs_cafe_station_login_attempts(username,attempt_at desc);
alter table public.gs_cafe_station_login_attempts enable row level security;
revoke all on public.gs_cafe_station_login_attempts from public,anon,authenticated;

create or replace function public.gs_1223_device_login(p_username text,p_password text,p_token_hash text)
returns table(station_key text, session_id uuid, expires_at timestamptz,
 order_print boolean,bill_print boolean)
language plpgsql security definer set search_path='' as $$
declare a public.gs_cafe_station_accounts%rowtype; v_username text:=lower(btrim(coalesce(p_username,'')));
 v_session uuid; v_expires timestamptz:=now()+interval '30 days';
begin
 if current_user <> 'service_role' then raise exception 'Service access required'; end if;
 if length(v_username)>64 or length(coalesce(p_password,''))>128 or p_token_hash !~ '^[0-9a-f]{64}$' then
  raise exception 'Invalid login request'; end if;
 perform pg_advisory_xact_lock(hashtext(v_username));
 if (select count(*) from public.gs_cafe_station_login_attempts
     where username=v_username and attempt_at>now()-interval '15 minutes' and not success)>=5 then
  raise exception 'Too many login attempts'; end if;
 select * into a from public.gs_cafe_station_accounts x where x.username=v_username and x.enabled;
 if not found or extensions.crypt(coalesce(p_password,''),a.password_hash)<>a.password_hash then
  insert into public.gs_cafe_station_login_attempts(username,success) values(v_username,false);
  raise exception 'Invalid station credentials';
 end if;
 insert into public.gs_cafe_station_login_attempts(username,success) values(v_username,true);
 insert into public.gs_cafe_station_device_sessions(station_key,token_hash,credential_version,expires_at,last_seen_at)
 values(a.station_key,p_token_hash,a.credential_version,v_expires,now()) returning id into v_session;
 return query select a.station_key,v_session,v_expires,a.allow_order_print,a.allow_bill_print;
end $$;

create or replace function public.gs_1223_device_heartbeat(p_token_hash text,p_printer_ready boolean default false)
returns table(station_key text,order_print boolean,bill_print boolean,expires_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if current_user <> 'service_role' then raise exception 'Service access required'; end if;
 return query
 with active as (
  update public.gs_cafe_station_device_sessions s
  set last_seen_at=now(),printer_seen_at=case when p_printer_ready then now() else s.printer_seen_at end
  from public.gs_cafe_station_accounts a
  where s.token_hash=p_token_hash and s.station_key=a.station_key
    and s.revoked_at is null and s.expires_at>now() and a.enabled
    and a.credential_version=s.credential_version
  returning a.station_key,a.allow_order_print,a.allow_bill_print,s.expires_at
 ) select * from active;
end $$;

create or replace function public.gs_1223_revoke_station_sessions(p_station_key text)
returns integer language plpgsql security definer set search_path='' as $$
declare v_count integer;
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') or not exists(
  select 1 from public.gs_cafe_station_supervisors s where s.employee_id=auth.uid() and s.active
 ) then raise exception 'Station supervisor permission required'; end if;
 update public.gs_cafe_station_device_sessions set revoked_at=now()
 where station_key=p_station_key and revoked_at is null;
 get diagnostics v_count=row_count;
 return v_count;
end $$;
revoke all on function public.gs_1223_device_login(text,text,text) from public,anon,authenticated;
revoke all on function public.gs_1223_device_heartbeat(text,boolean) from public,anon,authenticated;
grant execute on function public.gs_1223_device_login(text,text,text) to service_role;
grant execute on function public.gs_1223_device_heartbeat(text,boolean) to service_role;
revoke all on function public.gs_1223_revoke_station_sessions(text) from public,anon;
grant execute on function public.gs_1223_revoke_station_sessions(text) to authenticated;
