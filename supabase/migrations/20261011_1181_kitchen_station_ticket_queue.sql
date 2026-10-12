-- Upgrade 1181: permission-checked station ticket queue; read-only.
-- Tickets and routing already exist from migration 229. No automatic
-- per-station status transitions or physical device delivery is implied.
create or replace function public.gs_kitchen_station_ticket_queue()
returns table(ticket_id bigint, order_id bigint, station_key text,
 station_name text, ticket_status text, delivery_method text,
 created_at timestamptz, item_count bigint, item_quantity bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then
   raise exception 'Kitchen view permission required';
 end if;
 return query
 select t.id, t.order_id, t.station_key, s.display_name, t.status,
        t.delivery_method, t.created_at,
        count(ti.order_item_id)::bigint,
        coalesce(sum(ti.quantity),0)::bigint
 from public.gs_cafe_order_station_tickets t
 join public.gs_cafe_preparation_stations s on s.station_key=t.station_key
 left join public.gs_cafe_order_station_ticket_items ti on ti.ticket_id=t.id
 where t.status in ('queued','received','failed','unknown')
 group by t.id,t.order_id,t.station_key,s.display_name,t.status,t.delivery_method,t.created_at
 order by t.created_at asc,t.id asc
 limit 250;
end;
$$;
revoke all on function public.gs_kitchen_station_ticket_queue() from public,anon;
grant execute on function public.gs_kitchen_station_ticket_queue() to authenticated;
