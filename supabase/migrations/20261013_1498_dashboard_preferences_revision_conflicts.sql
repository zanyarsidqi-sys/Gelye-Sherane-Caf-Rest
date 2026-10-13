-- Dashboard card layouts must either synchronize to the authenticated
-- employee's account or report that they remain device-only. Revision checks
-- prevent simultaneous phone/desktop edits from silently overwriting each
-- other. Apply to staging and verify before any production release.

create table if not exists public.gs_dashboard_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  preferences jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.gs_dashboard_preferences
  add column if not exists revision bigint not null default 0;

alter table public.gs_dashboard_preferences enable row level security;
revoke all on public.gs_dashboard_preferences from public, anon, authenticated;

create or replace function public.gs_dashboard_preferences_get()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_preferences jsonb;
  v_revision bigint;
  v_updated_at timestamptz;
begin
  if auth.uid() is null
     or not coalesce(public.gs_can_access('dashboard'), false) then
    raise exception 'Dashboard access denied' using errcode = '42501';
  end if;

  select p.preferences, p.revision, p.updated_at
    into v_preferences, v_revision, v_updated_at
    from public.gs_dashboard_preferences p
   where p.user_id = auth.uid();

  if not found then
    return jsonb_build_object(
      'preferences', '{}'::jsonb,
      'revision', 0,
      'updated_at', null
    );
  end if;

  return jsonb_build_object(
    'preferences', v_preferences,
    'revision', v_revision,
    'updated_at', v_updated_at
  );
end;
$$;

drop function if exists public.gs_dashboard_preferences_save(jsonb);

create or replace function public.gs_dashboard_preferences_save(
  p_preferences jsonb,
  p_expected_revision bigint
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_revision bigint;
  v_updated_at timestamptz;
begin
  if v_user_id is null
     or not coalesce(public.gs_can_access('dashboard'), false) then
    raise exception 'Dashboard access denied' using errcode = '42501';
  end if;

  if jsonb_typeof(p_preferences) is distinct from 'object'
     or pg_column_size(p_preferences) > 16384
     or p_expected_revision is null
     or p_expected_revision < 0 then
    raise exception 'Invalid Dashboard preferences';
  end if;

  -- Insert a revision-zero row if this employee has never customized the
  -- Dashboard. The unique user key serializes simultaneous first saves.
  insert into public.gs_dashboard_preferences
    (user_id, preferences, updated_at, revision)
  values (v_user_id, '{}'::jsonb, now(), 0)
  on conflict (user_id) do nothing;

  select p.revision into v_revision
    from public.gs_dashboard_preferences p
   where p.user_id = v_user_id
   for update;

  if p_expected_revision <> v_revision then
    raise exception 'Dashboard preferences changed on another device'
      using errcode = '40001';
  end if;

  update public.gs_dashboard_preferences
     set preferences = p_preferences,
         updated_at = now(),
         revision = revision + 1
   where user_id = v_user_id
  returning revision, updated_at into v_revision, v_updated_at;

  return jsonb_build_object(
    'preferences', p_preferences,
    'revision', v_revision,
    'updated_at', v_updated_at
  );
end;
$$;

revoke all on function public.gs_dashboard_preferences_get()
  from public, anon;
revoke all on function public.gs_dashboard_preferences_save(jsonb, bigint)
  from public, anon;
grant execute on function public.gs_dashboard_preferences_get()
  to authenticated;
grant execute on function public.gs_dashboard_preferences_save(jsonb, bigint)
  to authenticated;
