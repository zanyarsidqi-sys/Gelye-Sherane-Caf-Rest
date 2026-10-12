-- Upgrade 1209: read-only, staff-scoped replacement handoff view.
-- This RPC never changes correction, invoice, payment, or delivery state.
create or replace function public.gs_table_orders_replacement_delivery_progress(p_order_id bigint default null)
returns table(revision_id bigint, order_id bigint, correction_id bigint, station_key text,
 product_name text, quantity integer, preparation_state text, prepared_at timestamptz,
 delivery_status text, assigned_employee text, assigned_at timestamptz,
 accepted_at timestamptz, picked_up_at timestamptz, delivered_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view') then
   raise exception 'Table Orders view permission required';
 end if;
 if p_order_id is not null and p_order_id <= 0 then
   raise exception 'Invalid order identifier';
 end if;
 return query
 select r.id, r.order_id, r.correction_id, r.station_key,
   p.name::text, r.quantity, r.preparation_state::text, r.preparation_ready_at,
   (case when d.delivered_at is not null then 'Delivered'
         when d.picked_up_at is not null then 'Out for delivery'
         when d.accepted_at is not null then 'Awaiting pickup'
         when d.assigned_to is not null then 'Awaiting acceptance'
         when r.preparation_state = 'ready' then 'Awaiting assignment'
         else 'Preparing' end)::text,
   (case when d.assigned_to is null then null
     else coalesce(nullif(ep.full_name,''),'Assigned employee') end)::text,
   d.assigned_at, d.accepted_at, d.picked_up_at, d.delivered_at
 from public.gs_cafe_correction_station_revisions r
 join public.gs_order_items i on i.id = r.order_item_id
 join public.gs_menu_products p on p.id = i.product_id
 left join public.gs_cafe_replacement_delivery_tasks d on d.revision_id = r.id
 left join public.employee_profiles ep on ep.user_id = d.assigned_to
 where r.revision_kind = 'prepare_replacement'
   and (p_order_id is null or r.order_id = p_order_id)
 order by r.created_at desc, r.id desc limit 150;
end; $$;
revoke all on function public.gs_table_orders_replacement_delivery_progress(bigint) from public, anon;
grant execute on function public.gs_table_orders_replacement_delivery_progress(bigint) to authenticated;
