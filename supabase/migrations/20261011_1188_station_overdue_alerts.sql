-- Upgrade 1188: server-derived overdue alerts for station employees and supervisors.
-- This is an in-app alert feed, not a push notification service.
create or replace function public.gs_kitchen_overdue_station_alerts()
returns table(ticket_id bigint, order_id bigint, station_key text,
 station_name text, accepted_by uuid, estimated_ready_at timestamptz,
 overdue_minutes integer, audience text)
language plpgsql stable security definer set search_path = '' as $$
declare v_user uuid := auth.uid();
declare v_manager boolean;
begin
 if v_user is null or not public.gs_can_access('kitchen','can_view') then
   raise exception 'Kitchen view permission required';
 end if;
 -- Kitchen editors can supervise the entire queue; view-only employees
 -- receive alerts only for tickets they accepted.
 v_manager := public.gs_can_access('kitchen','can_edit');
 return query
 select t.id,t.order_id,t.station_key,s.display_name,p.accepted_by,
   p.estimated_ready_at,
   greatest(0,floor(extract(epoch from (transaction_timestamp()-p.estimated_ready_at))/60))::integer,
   case when p.accepted_by=v_user then 'responsible' else 'supervisor' end
 from public.gs_cafe_station_preparation p
 join public.gs_cafe_order_station_tickets t on t.id=p.ticket_id
 join public.gs_cafe_preparation_stations s on s.station_key=t.station_key
 join public.gs_orders o on o.id=t.order_id
 where p.state='preparing'
   and p.estimated_ready_at < transaction_timestamp()
   and o.status in ('preparing','ready')
   and (p.accepted_by=v_user or v_manager)
 order by p.estimated_ready_at,t.id limit 100;
end;
$$;
revoke all on function public.gs_kitchen_overdue_station_alerts() from public,anon;
grant execute on function public.gs_kitchen_overdue_station_alerts() to authenticated;
