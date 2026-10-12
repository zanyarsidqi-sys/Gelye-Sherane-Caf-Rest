-- Upgrade 256: authorized staff-only, read-only per-item order board.
-- Requires migrations 001, 051, 178, 186 and table visit linkage.
create or replace function public.gs_staff_table_order_board()
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
 limit 500;
end; $$;
revoke all on function public.gs_staff_table_order_board() from public, anon;
grant execute on function public.gs_staff_table_order_board() to authenticated;
