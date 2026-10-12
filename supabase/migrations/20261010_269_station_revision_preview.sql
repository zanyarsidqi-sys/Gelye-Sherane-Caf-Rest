-- Upgrade 269: permission-gated preparation-station revision preview.
-- READ ONLY. Does not dispatch or print. The worker must separately
-- authenticate, claim, and acknowledge a real queued revision ticket.
create or replace function public.gs_staff_revision_station_preview(p_order_id bigint)
returns table(revision_number integer, order_item_id bigint,
 station_key text, product_name text, change_type text,
 before_snapshot jsonb, after_snapshot jsonb, changed_at timestamptz,
 changed_by uuid, print_state text)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not (
  public.gs_can_access('table_orders','can_view') or
  public.gs_can_access('kitchen','can_view')) then
  raise exception 'Order revision preview permission required';
 end if;
 if not exists(select 1 from public.gs_orders o where o.id=p_order_id) then
  raise exception 'Order not found';
 end if;
 return query
 select e.revision_number, e.order_item_id,
        coalesce(st.station_key,'unassigned')::text,
        coalesce(p.name,'Unknown product')::text,
        e.change_type,e.before_snapshot,e.after_snapshot,
        e.changed_at,e.changed_by,
        coalesce(d.status,'not_queued')::text
 from public.gs_order_revision_events e
 left join public.gs_order_items i on i.id=e.order_item_id
 left join public.gs_menu_products p on p.id=i.product_id
 left join public.gs_cafe_product_preparation st on st.product_id=i.product_id
 left join public.gs_order_revision_dispatch d on d.revision_id=e.id
   and d.destination_type='station_print' and d.destination_key=st.station_key
 where e.order_id=p_order_id
 order by e.revision_number desc,e.changed_at desc
 limit 250;
end $$;
revoke all on function public.gs_staff_revision_station_preview(bigint) from public,anon;
grant execute on function public.gs_staff_revision_station_preview(bigint) to authenticated;
