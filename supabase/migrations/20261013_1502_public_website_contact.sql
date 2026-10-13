-- Expose only owner-managed public contact details; the settings table itself
-- remains protected by its existing employee-only RLS policies.
alter table public.cafe_website_settings
  add column if not exists phone text not null default '',
  add column if not exists email text not null default '',
  add column if not exists address text not null default '',
  add column if not exists opening_hours text not null default '';

create or replace function public.gs_public_website_contact()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'business_name', nullif(pg_catalog.btrim(s.title), ''),
    'description', nullif(pg_catalog.btrim(s.description), ''),
    'phone', nullif(pg_catalog.btrim(s.phone), ''),
    'email', nullif(pg_catalog.btrim(s.email), ''),
    'address', nullif(pg_catalog.btrim(s.address), ''),
    'opening_hours', nullif(pg_catalog.btrim(s.opening_hours), '')
  )
  from public.cafe_website_settings s
  where s.id = 1;
$$;

revoke all on function public.gs_public_website_contact() from public, anon, authenticated;
grant execute on function public.gs_public_website_contact() to anon, authenticated;
