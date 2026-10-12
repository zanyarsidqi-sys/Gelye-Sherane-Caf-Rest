-- OPTIONAL: Apply after 001; review your employee permission schema first.
-- Controlled product creation. No direct table INSERT policy is granted.
create or replace function public.gs_create_menu_product(
 p_name text, p_barcode text, p_normal_price_iqd bigint,
 p_tourism_price_iqd bigint)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('menu','can_create') then
  raise exception 'Not authorized to create menu products';
 end if;
 if p_name is null or length(trim(p_name)) < 1 or length(trim(p_name)) > 150 then
  raise exception 'Invalid product name';
 end if;
 if p_barcode is null or length(trim(p_barcode)) < 1 or length(trim(p_barcode)) > 80 then
  raise exception 'Invalid barcode';
 end if;
 if p_normal_price_iqd is null or p_tourism_price_iqd is null
  or p_normal_price_iqd < 0 or p_tourism_price_iqd < 0
  or p_normal_price_iqd > 1000000000 or p_tourism_price_iqd > 1000000000 then
  raise exception 'Invalid IQD prices';
 end if;
 insert into public.gs_menu_products(name,barcode,normal_price_iqd,tourism_price_iqd)
 values(trim(p_name),trim(p_barcode),p_normal_price_iqd,p_tourism_price_iqd)
 returning id into v_id;
 return v_id;
end;
$$;
revoke all on function public.gs_create_menu_product(text,text,bigint,bigint) from public;
grant execute on function public.gs_create_menu_product(text,text,bigint,bigint) to authenticated;
