-- Public menu is explicitly opt-in via cafe_website_settings.menu_enabled.
-- This function returns only public normal prices; no internal cost, barcode or tourism price.
create or replace function public.gs_public_menu()
returns table(name text, price_iqd bigint)
language sql stable security definer
set search_path = ''
as $$
  select p.name, p.normal_price_iqd
  from public.gs_menu_products p
  where p.is_active = true
    and exists (select 1 from public.cafe_website_settings s
                where s.id = 1 and s.menu_enabled = true)
  order by p.name
  limit 500;
$$;
revoke all on function public.gs_public_menu() from public;
grant execute on function public.gs_public_menu() to anon, authenticated;
