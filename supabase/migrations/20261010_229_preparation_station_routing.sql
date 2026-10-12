-- Upgrade 229: preparation-station mapping and single active ONLINE destination.
-- This migration configures routing only; it does NOT claim physical printing.
-- No default department: an unmapped product cannot be silently sent to Kitchen.
create table if not exists public.gs_cafe_preparation_stations (
 station_key text primary key check (station_key ~ '^[a-z][a-z0-9_]{1,39}$'),
 display_name text not null check (length(trim(display_name)) between 1 and 100),
 enabled boolean not null default true,
 online_method text not null default 'printer' check (online_method in ('pos','printer')),
 pos_device_id bigint references public.gs_cafe_pos_devices(id),
 printer_id bigint references public.gs_cafe_printers(id),
 offline_printer_id bigint references public.gs_cafe_printers(id),
 updated_by uuid references auth.users(id),
 updated_at timestamptz not null default now(),
 constraint gs_station_online_target check (
   (online_method='pos' and pos_device_id is not null) or
   (online_method='printer' and printer_id is not null))
);
create table if not exists public.gs_cafe_product_preparation (
 product_id bigint primary key references public.gs_menu_products(id) on delete cascade,
 station_key text not null references public.gs_cafe_preparation_stations(station_key),
 updated_by uuid references auth.users(id),
 updated_at timestamptz not null default now()
);
create table if not exists public.gs_cafe_order_station_tickets (
 id bigint generated always as identity primary key,
 order_id bigint not null references public.gs_orders(id),
 station_key text not null references public.gs_cafe_preparation_stations(station_key),
 delivery_method text not null check(delivery_method in ('pos','printer')),
 pos_device_id bigint references public.gs_cafe_pos_devices(id),
 printer_id bigint references public.gs_cafe_printers(id),
 status text not null default 'queued' check(status in ('queued','received','printed','failed','unknown')),
 created_at timestamptz not null default now(),
 unique(order_id,station_key),
 constraint gs_ticket_target_check check (
  (delivery_method='pos' and pos_device_id is not null and printer_id is null) or
  (delivery_method='printer' and printer_id is not null and pos_device_id is null))
);
create table if not exists public.gs_cafe_order_station_ticket_items (
 ticket_id bigint not null references public.gs_cafe_order_station_tickets(id) on delete cascade,
 order_item_id bigint not null unique references public.gs_order_items(id),
 quantity integer not null check(quantity > 0),
 primary key(ticket_id,order_item_id)
);
create index if not exists gs_station_ticket_queue_idx on public.gs_cafe_order_station_tickets(status,created_at);
-- Restricted tables; never expose device queues directly to public clients.
do $$ declare t text; begin
 foreach t in array array['gs_cafe_preparation_stations','gs_cafe_product_preparation',
 'gs_cafe_order_station_tickets','gs_cafe_order_station_ticket_items'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated',t);
 end loop;
end $$;
create or replace function public.gs_set_product_preparation_station(p_product_id bigint,p_station_key text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('menu','can_edit') then
  raise exception 'Menu edit permission required'; end if;
 if not exists(select 1 from public.gs_menu_products where id=p_product_id) then
  raise exception 'Product not found'; end if;
 if not exists(select 1 from public.gs_cafe_preparation_stations where station_key=p_station_key and enabled) then
  raise exception 'Active preparation station required'; end if;
 insert into public.gs_cafe_product_preparation(product_id,station_key,updated_by)
 values(p_product_id,p_station_key,auth.uid()) on conflict(product_id)
 do update set station_key=excluded.station_key,updated_by=excluded.updated_by,updated_at=now();
end $$;
create or replace function public.gs_set_preparation_station(
 p_station_key text,p_name text,p_online_method text,p_pos_device_id bigint,
 p_printer_id bigint,p_offline_printer_id bigint)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Tables manager permission required'; end if;
 if p_station_key is null or p_station_key !~ '^[a-z][a-z0-9_]{1,39}$' or
  p_name is null or length(trim(p_name)) not between 1 and 100 or
  p_online_method not in ('pos','printer') then raise exception 'Invalid station'; end if;
 if p_online_method='pos' then
  if p_pos_device_id is null or p_printer_id is not null or not exists(
   select 1 from public.gs_cafe_pos_devices where id=p_pos_device_id and enabled) then
   raise exception 'One enabled POS device required'; end if;
 else
  if p_printer_id is null or p_pos_device_id is not null or not exists(
   select 1 from public.gs_cafe_printers where id=p_printer_id and is_enabled) then
   raise exception 'One enabled printer required'; end if;
 end if;
 if p_offline_printer_id is not null and not exists(
  select 1 from public.gs_cafe_printers where id=p_offline_printer_id and is_enabled
  and connection_type in ('wifi','lan','bluetooth','usb')) then
  raise exception 'Offline printer must support local connectivity'; end if;
 insert into public.gs_cafe_preparation_stations(
  station_key,display_name,online_method,pos_device_id,printer_id,offline_printer_id,updated_by)
 values(p_station_key,trim(p_name),p_online_method,p_pos_device_id,p_printer_id,p_offline_printer_id,auth.uid())
 on conflict(station_key) do update set display_name=excluded.display_name,
 online_method=excluded.online_method,pos_device_id=excluded.pos_device_id,
 printer_id=excluded.printer_id,offline_printer_id=excluded.offline_printer_id,
 updated_by=excluded.updated_by,updated_at=now();
end $$;
create or replace function public.gs_list_preparation_routing()
returns table(station_key text,display_name text,online_method text,pos_device_id bigint,
 printer_id bigint,offline_printer_id bigint,product_count bigint)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (public.gs_can_access('tables','can_view') or public.gs_can_access('menu','can_view')) then
  raise exception 'View permission required'; end if;
 return query select s.station_key,s.display_name,s.online_method,s.pos_device_id,
 s.printer_id,s.offline_printer_id,count(m.product_id)::bigint
 from public.gs_cafe_preparation_stations s
 left join public.gs_cafe_product_preparation m on m.station_key=s.station_key
 group by s.station_key,s.display_name,s.online_method,s.pos_device_id,s.printer_id,s.offline_printer_id
 order by s.display_name;
end $$;
-- Explicit idempotent dispatch: call only after the order has been accepted for preparation.
-- All items must be mapped; transaction aborts if any item has no active destination.
create or replace function public.gs_route_confirmed_order(p_order_id bigint)
returns integer language plpgsql security definer set search_path='' as $$
declare v_order public.gs_orders%rowtype; v_unmapped integer; v_station record; v_ticket bigint; v_count integer:=0;
begin
 if auth.uid() is null or not (public.gs_can_access('table_orders','can_edit') or
  public.gs_can_access('kitchen','can_edit')) then raise exception 'Order routing permission required'; end if;
 select * into v_order from public.gs_orders where id=p_order_id for update;
 if not found or v_order.status not in ('preparing','ready','served') then
  raise exception 'Only accepted orders may be routed'; end if;
 select count(*) into v_unmapped from public.gs_order_items i
 left join public.gs_cafe_product_preparation m on m.product_id=i.product_id
 left join public.gs_cafe_preparation_stations s on s.station_key=m.station_key and s.enabled
 where i.order_id=p_order_id and s.station_key is null;
 if v_unmapped>0 then raise exception '% order items lack an active preparation station',v_unmapped; end if;
 for v_station in
  select distinct s.station_key,s.online_method,s.pos_device_id,s.printer_id
  from public.gs_order_items i
  join public.gs_cafe_product_preparation m on m.product_id=i.product_id
  join public.gs_cafe_preparation_stations s on s.station_key=m.station_key
  where i.order_id=p_order_id
 loop
  if (v_station.online_method='pos' and not exists(
   select 1 from public.gs_cafe_pos_devices where id=v_station.pos_device_id and enabled)) or
   (v_station.online_method='printer' and not exists(
   select 1 from public.gs_cafe_printers where id=v_station.printer_id and is_enabled)) then
   raise exception 'Configured destination unavailable for %',v_station.station_key; end if;
  insert into public.gs_cafe_order_station_tickets(order_id,station_key,delivery_method,pos_device_id,printer_id)
  values(p_order_id,v_station.station_key,v_station.online_method,v_station.pos_device_id,v_station.printer_id)
  on conflict(order_id,station_key) do nothing;
  select id into v_ticket from public.gs_cafe_order_station_tickets
   where order_id=p_order_id and station_key=v_station.station_key;
  insert into public.gs_cafe_order_station_ticket_items(ticket_id,order_item_id,quantity)
  select v_ticket,i.id,i.quantity from public.gs_order_items i
  join public.gs_cafe_product_preparation m on m.product_id=i.product_id
  where i.order_id=p_order_id and m.station_key=v_station.station_key
  on conflict(order_item_id) do nothing;
  v_count:=v_count+1;
 end loop;
 return v_count;
end $$;
revoke all on function public.gs_set_product_preparation_station(bigint,text) from public,anon;
revoke all on function public.gs_set_preparation_station(text,text,text,bigint,bigint,bigint) from public,anon;
revoke all on function public.gs_list_preparation_routing() from public,anon;
revoke all on function public.gs_route_confirmed_order(bigint) from public,anon;
grant execute on function public.gs_set_product_preparation_station(bigint,text) to authenticated;
grant execute on function public.gs_set_preparation_station(text,text,text,bigint,bigint,bigint) to authenticated;
grant execute on function public.gs_list_preparation_routing() to authenticated;
grant execute on function public.gs_route_confirmed_order(bigint) to authenticated;
