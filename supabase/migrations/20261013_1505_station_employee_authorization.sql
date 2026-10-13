-- Bind a station-device session to the verified employee Supabase session.
-- Existing rows remain intact and bind only when an AAL2 employee first uses
-- them after this migration; business records and station credentials are not
-- modified.
alter table public.gs_cafe_station_device_sessions
  add column if not exists employee_user_id uuid,
  add column if not exists employee_auth_session_id uuid;

do $migration$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.gs_cafe_station_device_sessions'::regclass
      and conname = 'gs_station_session_employee_binding_pair'
  ) then
    alter table public.gs_cafe_station_device_sessions
      add constraint gs_station_session_employee_binding_pair
      check ((employee_user_id is null) = (employee_auth_session_id is null));
  end if;
end;
$migration$;

create or replace function public.gs_1256_employee_can_use_station(
  p_employee_user_id uuid
) returns boolean
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'Service access required';
  end if;
  if p_employee_user_id is null then return false; end if;
  return exists (
    select 1
    from public.employee_profiles profile
    join public.employee_section_permissions permission
      on permission.user_id = profile.user_id
    where profile.user_id = p_employee_user_id
      and profile.is_active is true
      and permission.section_key = 'dashboard'
      and permission.can_view is true
  );
end;
$$;

create or replace function public.gs_1256_station_employee_session_access(
  p_token_hash text,
  p_employee_user_id uuid,
  p_employee_auth_session_id uuid
) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_session public.gs_cafe_station_device_sessions%rowtype;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'Service access required';
  end if;
  if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$'
     or p_employee_user_id is null
     or p_employee_auth_session_id is null then
    return 'employee_invalid';
  end if;
  if not public.gs_1256_employee_can_use_station(p_employee_user_id) then
    return 'employee_invalid';
  end if;

  select station_session.* into v_session
  from public.gs_cafe_station_device_sessions station_session
  join public.gs_cafe_station_accounts account
    on account.station_key = station_session.station_key
  where station_session.token_hash = p_token_hash
    and station_session.revoked_at is null
    and station_session.expires_at > now()
    and station_session.credential_version = account.credential_version
    and account.enabled is true
  for update of station_session;

  if not found then return 'station_invalid'; end if;

  -- Keep already-issued station devices working, but only bind an unbound
  -- session when an active employee has just passed AAL2 and server permission
  -- checks. The binding cannot be transferred to another employee session.
  if v_session.employee_user_id is null
     and v_session.employee_auth_session_id is null then
    update public.gs_cafe_station_device_sessions
      set employee_user_id = p_employee_user_id,
          employee_auth_session_id = p_employee_auth_session_id
      where id = v_session.id
        and employee_user_id is null
        and employee_auth_session_id is null;
    if found then return 'authorized'; end if;
  end if;

  if v_session.employee_user_id = p_employee_user_id
     and v_session.employee_auth_session_id = p_employee_auth_session_id then
    return 'authorized';
  end if;
  return 'employee_mismatch';
end;
$$;

comment on column public.gs_cafe_station_device_sessions.employee_user_id is
  'Employee account that completed AAL2 before this station session was used.';
comment on column public.gs_cafe_station_device_sessions.employee_auth_session_id is
  'Supabase auth session binding; prevents station access after employee sign-out or reauthentication.';

revoke all on function public.gs_1256_employee_can_use_station(uuid)
  from public, anon, authenticated;
revoke all on function public.gs_1256_station_employee_session_access(text, uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.gs_1256_employee_can_use_station(uuid)
  to service_role;
grant execute on function public.gs_1256_station_employee_session_access(text, uuid, uuid)
  to service_role;
