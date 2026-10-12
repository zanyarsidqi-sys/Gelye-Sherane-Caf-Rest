-- Kitchen-safe item names and preparation locations; read-only.
-- No customer names are invented: customer-to-item association is a separate
-- workflow requiring a validated source and explicit privacy controls.
create or replace function public.gs_kitchen_order_item_details(p_order_id bigint)
returns table(product_id bigint, quantity integer, unit_price_iqd bigint,
              line_total_iqd bigint, product_name text, station_name text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then
    raise exception 'Kitchen view permission required';
  end if;
  if p_order_id is null or p_order_id <= 0 then
    raise exception 'Valid order required';
  end if;
  return query
    select i.product_id, i.quantity, i.unit_price_iqd, i.line_total_iqd,
           p.name, coalesce(s.display_name, 'Unassigned preparation station')
    from public.gs_order_items i
    join public.gs_menu_products p on p.id = i.product_id
    left join public.gs_cafe_product_preparation route on route.product_id = i.product_id
    left join public.gs_cafe_preparation_stations s on s.station_key = route.station_key
    where i.order_id = p_order_id
    order by i.id;
end;
$$;
revoke all on function public.gs_kitchen_order_item_details(bigint) from public, anon;
grant execute on function public.gs_kitchen_order_item_details(bigint) to authenticated;
