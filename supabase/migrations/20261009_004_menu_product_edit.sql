-- OPTIONAL migration 004. Review against your existing schema and permissions.
-- Product updates are performed by RPC; no direct client UPDATE grant is added.
create or replace function public.gs_update_menu_product(
 p_id bigint, p_name text, p_barcode text,
 p_normal_price_iqd bigint, p_tourism_price_iqd bigint, p_is_active boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('menu','can_edit') then
  raise exception 'Not authorized to edit menu products';
 end if;
 if p_id is null or p_name is null or length(trim(p_name)) not between 1 and 150
  or p_barcode is null or length(trim(p_barcode)) not between 1 and 80
  or p_normal_price_iqd is null or p_tourism_price_iqd is null
  or p_normal_price_iqd not between 0 and 1000000000
  or p_tourism_price_iqd not between 0 and 1000000000
  or p_is_active is null then
  raise exception 'Invalid product details';
 end if;
 update public.gs_menu_products
 set name=trim(p_name), barcode=trim(p_barcode),
 normal_price_iqd=p_normal_price_iqd, tourism_price_iqd=p_tourism_price_iqd,
 is_active=p_is_active
 where id=p_id;
 if not found then raise exception 'Product not found'; end if;
end;
$$;
revoke all on function public.gs_update_menu_product(bigint,text,text,bigint,bigint,boolean) from public;
grant execute on function public.gs_update_menu_product(bigint,text,text,bigint,bigint,boolean) to authenticated;
