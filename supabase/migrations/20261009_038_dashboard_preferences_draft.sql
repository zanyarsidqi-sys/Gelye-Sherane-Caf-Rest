-- DRAFT: Deploy and verify with authenticated test users before enabling in production.
-- Server-owned per-user Dashboard preferences, with a bounded JSON payload.
create table if not exists public.gs_dashboard_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  preferences jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.gs_dashboard_preferences enable row level security;
revoke all on public.gs_dashboard_preferences from anon, authenticated;

create or replace function public.gs_dashboard_preferences_get()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if auth.uid() is null or not public.gs_can_access('dashboard') then
    raise exception 'Dashboard access denied';
  end if;
  select jsonb_build_object('preferences', p.preferences,
         'updated_at', p.updated_at) into result
    from public.gs_dashboard_preferences p where p.user_id = auth.uid();
  return result;
end; $$;

create or replace function public.gs_dashboard_preferences_save(p_preferences jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.gs_can_access('dashboard') then
    raise exception 'Dashboard access denied';
  end if;
  if jsonb_typeof(p_preferences) is distinct from 'object'
     or pg_column_size(p_preferences) > 16384 then
    raise exception 'Invalid Dashboard preferences';
  end if;
  insert into public.gs_dashboard_preferences(user_id, preferences, updated_at)
    values(auth.uid(), p_preferences, now())
    on conflict (user_id) do update set preferences = excluded.preferences,
      updated_at = excluded.updated_at;
end; $$;
revoke all on function public.gs_dashboard_preferences_get() from public, anon;
revoke all on function public.gs_dashboard_preferences_save(jsonb) from public, anon;
grant execute on function public.gs_dashboard_preferences_get() to authenticated;
grant execute on function public.gs_dashboard_preferences_save(jsonb) to authenticated;
-- Conflict handling currently uses last-write-wins. Offline saves remain local;
-- automatic retry, version conflict resolution, and multi-device tests pending.
