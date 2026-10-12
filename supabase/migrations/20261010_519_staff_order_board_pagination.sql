-- Upgrade 519: permission-scoped paginated staff order board.
-- Retains the same authorization and open-visit filters as Upgrade 256.
create or replace function public.gs_staff_table_order_board_page(p_offset integer default 0, p_limit integer default 250)
returns table(order_item_id bigint, order_id bigint, table_number integer,
 product_name text, quantity integer, status text, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not (
  public.gs_can_access('table_orders','can_view') or
  public.gs_can_access('kitchen','can_view') or
  public.gs_can_access('tables','can_view')) then
  raise exception 'Not authorized to view table orders';
 end if;
 if p_offset is null or p_offset < 0 or p_offset > 5000 or
    p_limit is null or p_limit < 1 or p_limit > 250 then
  raise exception 'Invalid pagination request';
 end if;
 return query
 select i.id, o.id, t.table_number, p.name, i.quantity,
   coalesce(f.status,'not_accepted')::text, o.created_at
 from public.gs_orders o
 join public.gs_table_visits v on v.id=o.table_visit_id
 join public.gs_cafe_tables t on t.id=v.table_id
 join public.gs_order_items i on i.order_id=o.id
 join public.gs_menu_products p on p.id=i.product_id
 left join public.gs_table_item_fulfillment f on f.order_item_id=i.id
 where o.is_motel=false and o.status not in ('cancelled','draft')
   and v.status='open'
 order by o.created_at desc, i.id desc
 limit p_limit offset p_offset;
end; $$;
revoke all on function public.gs_staff_table_order_board_page(integer,integer) from public, anon;
grant execute on function public.gs_staff_table_order_board_page(integer,integer) to authenticated;
