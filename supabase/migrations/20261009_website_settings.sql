-- Run in the Supabase SQL editor after reviewing your existing schema.
-- No public write access. Staff must pass authenticated MFA and explicit section permission.
create table if not exists public.cafe_website_settings (
  id integer primary key default 1 check (id = 1),
  business_name text not null default 'Gelye Sherane Café & Restaurant',
  description text not null default '',
  phone text not null default '',
  address text not null default '',
  opening_hours text not null default '',
  menu_published boolean not null default false,
  online_orders_enabled boolean not null default false,
  reservations_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);
insert into public.cafe_website_settings (id) values (1) on conflict (id) do nothing;
alter table public.cafe_website_settings enable row level security;
create or replace function public.cafe_can_manage_website(require_edit boolean)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null
    and (auth.jwt()->>'aal') = 'aal2'
    and exists (
      select 1 from public.employee_profiles p
      join public.employee_section_permissions s on s.user_id = p.user_id
      where p.user_id = auth.uid() and p.is_active = true
        and s.section_key = 'websites_management' and s.can_view = true
        and (not require_edit or s.can_edit = true)
    );
$$;
revoke all on function public.cafe_can_manage_website(boolean) from public;
grant execute on function public.cafe_can_manage_website(boolean) to authenticated;
create policy website_staff_read on public.cafe_website_settings
  for select to authenticated using (public.cafe_can_manage_website(false));
create policy website_staff_update on public.cafe_website_settings
  for update to authenticated using (public.cafe_can_manage_website(true))
  with check (public.cafe_can_manage_website(true));
grant select, update on public.cafe_website_settings to authenticated;
