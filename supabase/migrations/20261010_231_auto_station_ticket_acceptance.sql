-- Upgrade 231: automatically stage station tickets at the authoritative kitchen acceptance transition.
-- The trigger runs in the same transaction as NEW -> PREPARING, so failed routing
-- rejects acceptance instead of silently losing kitchen / beverage / shisha tickets.
-- No external printer, SUNMI, or network I/O occurs in a database trigger.
create or replace function public.gs_auto_route_order_on_acceptance()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_count integer;
begin
  if old.status = 'new' and new.status = 'preparing' then
    -- The underlying RPC checks auth.uid and kitchen/table-order edit permissions.
    -- A failed configuration aborts the status update and its ticket staging.
    v_count := public.gs_route_confirmed_order(new.id);
    if v_count = 0 then
      raise exception 'Order % has no routed preparation tickets; acceptance aborted', new.id;
    end if;
  end if;
  return new;
end $$;
revoke all on function public.gs_auto_route_order_on_acceptance() from public, anon, authenticated;
drop trigger if exists gs_auto_route_order_on_acceptance_trg on public.gs_orders;
create trigger gs_auto_route_order_on_acceptance_trg
 after update of status on public.gs_orders
 for each row
 when (old.status = 'new' and new.status = 'preparing')
 execute function public.gs_auto_route_order_on_acceptance();

-- Authorized diagnostic for staff to inspect staged tickets without exposing raw tables.
create or replace function public.gs_list_order_station_tickets(p_order_id bigint)
returns table(ticket_id bigint, station_key text, delivery_method text,
 pos_device_id bigint, printer_id bigint, ticket_status text, item_count bigint,
 total_quantity bigint, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not (
  public.gs_can_access('table_orders','can_view') or
  public.gs_can_access('kitchen','can_view') or
  public.gs_can_access('tables','can_view')) then
   raise exception 'Ticket viewing permission required';
 end if;
 return query
 select t.id,t.station_key,t.delivery_method,t.pos_device_id,t.printer_id,
        t.status,count(i.order_item_id)::bigint,
        coalesce(sum(i.quantity),0)::bigint,t.created_at
 from public.gs_cafe_order_station_tickets t
 left join public.gs_cafe_order_station_ticket_items i on i.ticket_id=t.id
 where t.order_id=p_order_id
 group by t.id,t.station_key,t.delivery_method,t.pos_device_id,t.printer_id,t.status,t.created_at
 order by t.created_at,t.id;
end $$;
revoke all on function public.gs_list_order_station_tickets(bigint) from public,anon;
grant execute on function public.gs_list_order_station_tickets(bigint) to authenticated;
