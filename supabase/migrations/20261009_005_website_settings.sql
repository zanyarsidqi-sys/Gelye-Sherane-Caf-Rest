-- Apply using Supabase SQL editor or migration runner. No public policies.
create table if not exists public.cafe_website_settings (
 id integer primary key default 1 check (id = 1),
 title text not null check (char_length(title) between 1 and 100),
 description text not null default '' check (char_length(description) <= 300),
 menu_enabled boolean not null default true,
 ordering_requested boolean not null default false,
 reservations_requested boolean not null default false,
 updated_at timestamptz not null default now(),
 updated_by uuid references auth.users(id)
);
insert into public.cafe_website_settings (id,title) values (1,'Gelye Sherane Café & Restaurant') on conflict (id) do nothing;
alter table public.cafe_website_settings enable row level security;
revoke all on public.cafe_website_settings from anon;
grant select, update on public.cafe_website_settings to authenticated;
create or replace function public.cafe_can_manage_website(required_action text)
returns boolean language sql stable security definer set search_path = '' as $$
 select exists (
  select 1 from public.employee_profiles ep
  join public.employee_section_permissions esp on esp.user_id = ep.user_id
  where ep.user_id = (select auth.uid()) and ep.is_active = true
    and esp.section_key = 'websites_management'
    and esp.can_view = true
    and (required_action = 'view' or (required_action = 'edit' and esp.can_edit = true))
 );
$$;
revoke all on function public.cafe_can_manage_website(text) from public;
grant execute on function public.cafe_can_manage_website(text) to authenticated;
create policy "Website management read" on public.cafe_website_settings
 for select to authenticated using (public.cafe_can_manage_website('view'));
create policy "Website management edit" on public.cafe_website_settings
 for update to authenticated using (public.cafe_can_manage_website('edit'))
 with check (public.cafe_can_manage_website('edit'));
create or replace function public.cafe_website_settings_audit()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 new.updated_at = now(); new.updated_by = auth.uid(); return new;
end $$;
drop trigger if exists cafe_website_settings_audit_trigger on public.cafe_website_settings;
create trigger cafe_website_settings_audit_trigger before update on public.cafe_website_settings
 for each row execute function public.cafe_website_settings_audit();
