-- Upgrade 218: read-only, assigned-employee delivery quantity snapshot.
-- Do not expose the underlying quantity ledger directly to clients.
create or replace function public.gs_my_table_delivery_quantity_status(p_job_id bigint)
returns table(order_item_id bigint, ordered_quantity integer,
 picked_quantity integer, delivered_quantity integer,
 remaining_to_pick integer, available_to_deliver integer,
 remaining_to_deliver integer)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (
   public.gs_can_access('tables','can_edit') or
   public.gs_can_access('table_orders','can_edit')) then
  raise exception 'Not authorized to view delivery quantities';
 end if;
 return query
 select i.id,i.quantity::integer,
   coalesce(q.picked_quantity,0)::integer,
   coalesce(q.delivered_quantity,0)::integer,
   (i.quantity-coalesce(q.picked_quantity,0))::integer,
   (coalesce(q.picked_quantity,0)-coalesce(q.delivered_quantity,0))::integer,
   (i.quantity-coalesce(q.delivered_quantity,0))::integer
 from public.gs_table_service_jobs j
 join public.gs_order_items i on i.id=j.order_item_id
 left join public.gs_table_item_delivery_quantities q on q.order_item_id=i.id
 where j.id=p_job_id and j.kind='deliver_items'
   and j.status in ('assigned','in_progress')
   and j.assigned_to=auth.uid();
end; $$;
revoke all on function public.gs_my_table_delivery_quantity_status(bigint)
 from public,anon;
grant execute on function public.gs_my_table_delivery_quantity_status(bigint)
 to authenticated;
