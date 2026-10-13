-- Public website images are intentionally public; only MFA-verified staff with
-- edit access to Website Management may upload, replace, or remove them.
alter table public.cafe_website_settings
  add column if not exists website_logo_path text not null default '',
  add column if not exists website_hero_path text not null default '';

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'cafe-website-assets',
  'cafe-website-assets',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists cafe_website_assets_public_read on storage.objects;
create policy cafe_website_assets_public_read
  on storage.objects for select
  to anon, authenticated
  using (
    bucket_id = 'cafe-website-assets'
    and (storage.foldername(name))[1] = 'site'
  );

drop policy if exists cafe_website_assets_staff_insert on storage.objects;
create policy cafe_website_assets_staff_insert
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'cafe-website-assets'
    and (storage.foldername(name))[1] = 'site'
    and public.cafe_can_manage_website(true)
  );

drop policy if exists cafe_website_assets_staff_update on storage.objects;
create policy cafe_website_assets_staff_update
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'cafe-website-assets'
    and (storage.foldername(name))[1] = 'site'
    and public.cafe_can_manage_website(true)
  )
  with check (
    bucket_id = 'cafe-website-assets'
    and (storage.foldername(name))[1] = 'site'
    and public.cafe_can_manage_website(true)
  );

drop policy if exists cafe_website_assets_staff_delete on storage.objects;
create policy cafe_website_assets_staff_delete
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'cafe-website-assets'
    and (storage.foldername(name))[1] = 'site'
    and public.cafe_can_manage_website(true)
  );

create or replace function public.gs_public_website_branding()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'logo_path', nullif(pg_catalog.btrim(s.website_logo_path), ''),
    'hero_path', nullif(pg_catalog.btrim(s.website_hero_path), '')
  )
  from public.cafe_website_settings s
  where s.id = 1;
$$;

revoke all on function public.gs_public_website_branding()
  from public, anon, authenticated;
grant execute on function public.gs_public_website_branding()
  to anon, authenticated;
