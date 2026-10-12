-- Upgrade 1180: controlled order/item lookup for staff guest and notes editor.
create or replace function public.gs_staff_table_order_items(p_order_id bigint)
returns table(item_id bigint, product_name text, quantity integer,
              guest_label text, preparation_notes text, order_status text)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view') then
   raise exception 'Table Orders view permission required';
 end if;
 if p_order_id is null or p_order_id <= 0 then raise exception 'Valid order required'; end if;
 return query select i.id, p.name, i.quantity, i.guest_label,
   i.preparation_notes, o.status
 from public.gs_orders o
 join public.gs_order_items i on i.order_id=o.id
 join public.gs_menu_products p on p.id=i.product_id
 where o.id=p_order_id and not o.is_motel order by i.id;
end;
$$;
revoke all on function public.gs_staff_table_order_items(bigint) from public,anon;
grant execute on function public.gs_staff_table_order_items(bigint) to authenticated;
