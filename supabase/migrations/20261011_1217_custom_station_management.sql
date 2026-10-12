-- Upgrade 1217: configurable stations and safe routing controls.
-- Retain historical ticket.station_key snapshots and existing station device routing.
create or replace function public.gs_1217_station_directory()
returns table(station_key text,display_name text,enabled boolean,product_count bigint)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (public.gs_can_access('kitchen','can_view') or public.gs_can_access('menu','can_view') or public.gs_can_access('products_inventory','can_view')) then
   raise exception 'Station directory access denied'; end if;
 return query select s.station_key,s.display_name,s.enabled,count(m.product_id)::bigint
 from public.gs_cafe_preparation_stations s
 left join public.gs_cafe_product_preparation m on m.station_key=s.station_key
 group by s.station_key,s.display_name,s.enabled order by s.display_name;
end $$;
create or replace function public.gs_1217_save_station(p_key text,p_name text,p_enabled boolean default true)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') or not exists(
  select 1 from public.gs_cafe_station_supervisors where employee_id=auth.uid() and active) then
  raise exception 'Station supervisor required'; end if;
 if p_key is null or p_key !~ '^[a-z][a-z0-9_]{1,39}$' or p_name is null or length(btrim(p_name)) not between 1 and 100 or p_enabled is null then
  raise exception 'Invalid station configuration'; end if;
 if not exists(select 1 from public.gs_cafe_preparation_stations where station_key=p_key) then
  -- Existing dispatch requires an online device target; do not invent one.
  raise exception 'Create station with an enabled POS/printer using existing device configuration first';
 end if;
 if not p_enabled and exists(select 1 from public.gs_cafe_order_station_tickets
    where station_key=p_key and status in ('queued','received','failed','unknown')) then
   raise exception 'Station has pending tickets; reassign/complete before deactivation'; end if;
 update public.gs_cafe_preparation_stations set display_name=btrim(p_name),enabled=p_enabled,updated_by=auth.uid(),updated_at=now()
 where station_key=p_key;
end $$;
create or replace function public.gs_1217_product_station_directory()
returns table(product_id bigint,product_name text,station_key text,station_name text)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (public.gs_can_access('menu','can_view') or public.gs_can_access('products_inventory','can_view')) then
  raise exception 'Product directory permission required'; end if;
 return query select p.id,p.name::text,m.station_key,s.display_name
 from public.gs_menu_products p
 left join public.gs_cafe_product_preparation m on m.product_id=p.id
 left join public.gs_cafe_preparation_stations s on s.station_key=m.station_key
 order by p.name,p.id limit 5000;
end $$;
revoke all on function public.gs_1217_station_directory(), public.gs_1217_save_station(text,text,boolean), public.gs_1217_product_station_directory() from public,anon;
grant execute on function public.gs_1217_station_directory(), public.gs_1217_save_station(text,text,boolean), public.gs_1217_product_station_directory() to authenticated;
