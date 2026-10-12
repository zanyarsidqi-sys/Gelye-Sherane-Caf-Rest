-- Upgrade 1182: station-scoped, permission-checked ticket line details.
-- Read-only. Does not accept orders or acknowledge device printing.
create or replace function public.gs_kitchen_station_ticket_details(p_ticket_id bigint)
returns table(order_item_id bigint, product_name text, quantity integer,
 guest_label text, preparation_notes text, station_name text)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then
   raise exception 'Kitchen view permission required';
 end if;
 if p_ticket_id is null or p_ticket_id <= 0 then
   raise exception 'Valid station ticket required';
 end if;
 if not exists (select 1 from public.gs_cafe_order_station_tickets
                where id = p_ticket_id) then
   raise exception 'Station ticket not found';
 end if;
 return query
 select ti.order_item_id, ti.product_name_snapshot, ti.quantity,
        oi.guest_label, oi.preparation_notes, s.display_name
 from public.gs_cafe_order_station_ticket_items ti
 join public.gs_cafe_order_station_tickets t on t.id = ti.ticket_id
 join public.gs_cafe_preparation_stations s on s.station_key = t.station_key
 join public.gs_order_items oi on oi.id = ti.order_item_id
 where ti.ticket_id = p_ticket_id
 order by ti.order_item_id;
end;
$$;
revoke all on function public.gs_kitchen_station_ticket_details(bigint) from public, anon;
grant execute on function public.gs_kitchen_station_ticket_details(bigint) to authenticated;
