begin;

create table if not exists public.gs_employee_device_presence (
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid not null,
  device_label text not null check (length(device_label) between 1 and 80),
  user_agent text not null default '' check (length(user_agent) <= 400),
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id),
  primary key (user_id, session_id)
);

alter table public.gs_employee_device_presence enable row level security;
revoke all on public.gs_employee_device_presence from public, anon, authenticated;

create index if not exists gs_employee_device_presence_online_idx
  on public.gs_employee_device_presence(last_seen_at desc)
  where revoked_at is null;

-- A revoked employee session immediately loses all access routed through this
-- shared permission gate; its app also signs out on its next heartbeat.
create or replace function public.gs_can_access(
  p_section text,
  p_action text default 'can_view'
) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
      from public.employee_profiles ep
      join public.employee_section_permissions perm on perm.user_id = ep.user_id
     where ep.user_id = (select auth.uid())
       and ep.is_active = true
       and perm.section_key = p_section
       and case p_action
         when 'can_view' then perm.can_view
         when 'can_create' then perm.can_create
         when 'can_edit' then perm.can_edit
         else false
       end = true
  )
  and not exists (
    select 1
      from public.gs_employee_device_presence device
     where device.user_id = (select auth.uid())
       and device.session_id =
           nullif((select auth.jwt() ->> 'session_id'), '')::uuid
       and device.revoked_at is not null
  );
$$;
revoke all on function public.gs_can_access(text, text) from public;
grant execute on function public.gs_can_access(text, text) to authenticated;

create or replace function public.gs_employee_device_manager_allowed(p_action text)
returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null
     and coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
     and exists (
       select 1
         from public.employee_profiles employee
        where employee.user_id = auth.uid()
          and employee.is_active = true
          and lower(btrim(coalesce(employee.role, ''))) in ('owner', 'manager')
     )
     and public.gs_can_access('security_access_control', p_action);
$$;
revoke all on function public.gs_employee_device_manager_allowed(text)
  from public, anon, authenticated;

create or replace function public.gs_employee_device_heartbeat(
  p_device_label text,
  p_user_agent text default ''
) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_session uuid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
  v_label text := nullif(btrim(coalesce(p_device_label, '')), '');
  v_user_agent text := left(
    regexp_replace(coalesce(p_user_agent, ''), '[[:cntrl:]]', '', 'g'),
    400
  );
  v_rows integer;
begin
  if v_user is null
     or v_session is null
     or coalesce(auth.jwt() ->> 'aal', '') <> 'aal2'
     or v_label is null
     or length(v_label) > 80
     or not exists (
       select 1 from public.employee_profiles employee
        where employee.user_id = v_user and employee.is_active = true
     ) then
    raise exception 'Active MFA employee session required'
      using errcode = '42501';
  end if;

  insert into public.gs_employee_device_presence as existing(
    user_id, session_id, device_label, user_agent, last_seen_at
  ) values (
    v_user, v_session, v_label, v_user_agent, now()
  )
  on conflict (user_id, session_id) do update
    set device_label = excluded.device_label,
        user_agent = excluded.user_agent,
        last_seen_at = now()
    where existing.revoked_at is null;

  get diagnostics v_rows = row_count;
  return v_rows = 1;
end;
$$;
revoke all on function public.gs_employee_device_heartbeat(text, text)
  from public, anon;
grant execute on function public.gs_employee_device_heartbeat(text, text)
  to authenticated;

create or replace function public.gs_list_online_employee_devices()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_result jsonb;
begin
  if not public.gs_employee_device_manager_allowed('can_view') then
    raise exception 'Owner or manager access to active devices required'
      using errcode = '42501';
  end if;

  select jsonb_build_object(
    'online_count', count(*),
    'can_revoke',
      coalesce(bool_or(public.gs_employee_device_manager_allowed('can_edit')), false),
    'devices', coalesce(
      jsonb_agg(
        jsonb_build_object(
          'user_id', online.user_id,
          'employee_name', online.employee_name,
          'role', online.role,
          'session_id', online.session_id,
          'device_label', online.device_label,
          'user_agent', online.user_agent,
          'last_seen_at', online.last_seen_at,
          'is_current', online.user_id = auth.uid()
            and online.session_id =
                nullif(auth.jwt() ->> 'session_id', '')::uuid
        )
        order by lower(online.employee_name), online.last_seen_at desc
      ),
      '[]'::jsonb
    )
  )
  into v_result
  from (
    select device.user_id,
           coalesce(nullif(btrim(employee.full_name), ''), 'Employee')::text
             as employee_name,
           coalesce(nullif(btrim(employee.role), ''), 'Staff')::text as role,
           device.session_id,
           device.device_label,
           device.user_agent,
           device.last_seen_at
      from public.gs_employee_device_presence device
      join public.employee_profiles employee
        on employee.user_id = device.user_id and employee.is_active = true
     where device.revoked_at is null
       and device.last_seen_at >= now() - interval '2 minutes'
     order by lower(coalesce(employee.full_name, '')), device.last_seen_at desc
  ) online;

  return v_result;
end;
$$;
revoke all on function public.gs_list_online_employee_devices()
  from public, anon;
grant execute on function public.gs_list_online_employee_devices()
  to authenticated;

create or replace function public.gs_revoke_employee_device(
  p_user_id uuid,
  p_session_id uuid
) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_device public.gs_employee_device_presence%rowtype;
begin
  if not public.gs_employee_device_manager_allowed('can_edit') then
    raise exception 'Owner or manager device-management permission required'
      using errcode = '42501';
  end if;
  if p_user_id is null or p_session_id is null then
    raise exception 'Employee device is required';
  end if;
  if p_user_id = auth.uid()
     and p_session_id = nullif(auth.jwt() ->> 'session_id', '')::uuid then
    raise exception 'Use another authorized device to sign out this session';
  end if;

  update public.gs_employee_device_presence
     set revoked_at = now(), revoked_by = auth.uid()
   where user_id = p_user_id
     and session_id = p_session_id
     and revoked_at is null
     and last_seen_at >= now() - interval '2 minutes'
   returning * into v_device;
  if not found then return false; end if;

  insert into public.gs_system_audit_events(
    actor_id, section, action, record_id, before_data, after_data
  ) values (
    auth.uid(),
    'security_access_control',
    'revoke_employee_device',
    p_session_id::text,
    jsonb_build_object(
      'employee_user_id', v_device.user_id,
      'device_label', v_device.device_label,
      'last_seen_at', v_device.last_seen_at
    ),
    jsonb_build_object('revoked_at', v_device.revoked_at, 'revoked_by', auth.uid())
  );
  return true;
end;
$$;
revoke all on function public.gs_revoke_employee_device(uuid, uuid)
  from public, anon;
grant execute on function public.gs_revoke_employee_device(uuid, uuid)
  to authenticated;

create or replace function public.gs_revoke_other_online_employee_devices()
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_current_session uuid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
  v_count integer;
begin
  if not public.gs_employee_device_manager_allowed('can_edit') then
    raise exception 'Owner or manager device-management permission required'
      using errcode = '42501';
  end if;

  update public.gs_employee_device_presence
     set revoked_at = now(), revoked_by = auth.uid()
   where revoked_at is null
     and last_seen_at >= now() - interval '2 minutes'
     and not (user_id = auth.uid() and session_id = v_current_session);
  get diagnostics v_count = row_count;

  if v_count > 0 then
    insert into public.gs_system_audit_events(
      actor_id, section, action, record_id, before_data, after_data
    ) values (
      auth.uid(),
      'security_access_control',
      'revoke_other_online_employee_devices',
      'online_employee_sessions',
      jsonb_build_object('sessions_revoked', v_count),
      jsonb_build_object(
        'sessions_revoked', v_count,
        'current_session_preserved', true
      )
    );
  end if;
  return v_count;
end;
$$;
revoke all on function public.gs_revoke_other_online_employee_devices()
  from public, anon;
grant execute on function public.gs_revoke_other_online_employee_devices()
  to authenticated;

commit;
