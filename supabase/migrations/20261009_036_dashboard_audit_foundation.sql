-- Dashboard audit foundation: deploy and verify before enabling in production.
create table if not exists public.gs_system_audit_events (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  actor_id uuid,
  section text not null,
  action text not null,
  record_id text,
  before_data jsonb,
  after_data jsonb
);
create index if not exists gs_system_audit_events_created_idx on public.gs_system_audit_events(created_at desc);
create index if not exists gs_system_audit_events_actor_idx on public.gs_system_audit_events(actor_id, created_at desc);
alter table public.gs_system_audit_events enable row level security;
revoke all on public.gs_system_audit_events from anon, authenticated;

create or replace function public.gs_dashboard_audit_events(p_limit integer default 100)
returns setof public.gs_system_audit_events
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.gs_can_access('dashboard')
     or not public.gs_can_access('security_access_control') then
    raise exception 'Audit history access denied';
  end if;
  return query select e.* from public.gs_system_audit_events e
    order by e.created_at desc, e.id desc limit least(greatest(coalesce(p_limit, 100), 1), 200);
end; $$;
revoke all on function public.gs_dashboard_audit_events(integer) from public, anon;
grant execute on function public.gs_dashboard_audit_events(integer) to authenticated;
-- NOTE: This migration establishes protected storage and read-only UI.
-- Producers/triggers across all 35 sections, data redaction and immutable audit
-- writer are not yet implemented. Do not treat an empty log as full coverage.
