-- Upgrade 233: read-only dispatch center feed, authorized and capped.
-- Physical device printing remains outside the database.
create or replace function public.gs_list_station_dispatch_tickets()
returns table(ticket_id bigint,order_id bigint,station_key text,status text,
 delivery_method text,destination_label text,attempts integer,last_error text,
 created_at timestamptz,dispatched_at timestamptz,acknowledged_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (
  public.gs_can_access('tables','can_view') or
  public.gs_can_access('kitchen','can_view')) then
  raise exception 'Station dispatch viewing permission required';
 end if;
 return query select t.id,t.order_id,t.station_key,t.status,t.delivery_method,
  case when t.delivery_method='pos' then d.name else p.name end,
  t.dispatch_attempts,t.last_error,t.created_at,t.dispatched_at,t.acknowledged_at
 from public.gs_cafe_order_station_tickets t
 left join public.gs_cafe_pos_devices d on d.id=t.pos_device_id
 left join public.gs_cafe_printers p on p.id=t.printer_id
 order by t.created_at desc,t.id desc limit 200;
end $$;
revoke all on function public.gs_list_station_dispatch_tickets() from public,anon;
grant execute on function public.gs_list_station_dispatch_tickets() to authenticated;
