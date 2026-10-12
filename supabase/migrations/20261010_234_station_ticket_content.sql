-- Upgrade 234: read-only, station-scoped preparation ticket payload.
-- Product names and quantities are snapshotted at routing time to preserve
-- the original kitchen ticket even if menu names change later.
alter table public.gs_cafe_order_station_ticket_items
 add column if not exists product_name_snapshot text;
update public.gs_cafe_order_station_ticket_items ti
set product_name_snapshot=p.name
from public.gs_order_items oi join public.gs_menu_products p on p.id=oi.product_id
where oi.id=ti.order_item_id and ti.product_name_snapshot is null;
-- New ticket lines get their display name at creation, before dispatch.
create or replace function public.gs_snapshot_station_ticket_item_name()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.product_name_snapshot is null then
  select p.name into new.product_name_snapshot
  from public.gs_order_items oi join public.gs_menu_products p on p.id=oi.product_id
  where oi.id=new.order_item_id;
 end if;
 if new.product_name_snapshot is null then raise exception 'Ticket item product not found'; end if;
 return new;
end $$;
drop trigger if exists gs_station_ticket_item_snapshot_trg on public.gs_cafe_order_station_ticket_items;
create trigger gs_station_ticket_item_snapshot_trg before insert on public.gs_cafe_order_station_ticket_items
for each row execute function public.gs_snapshot_station_ticket_item_name();
revoke all on function public.gs_snapshot_station_ticket_item_name() from public,anon,authenticated;

-- Structured payload for a *single* ticket; never return other station lines.
-- Order destination is the recorded table/motel destination text. Special
-- instructions are NULL because the foundation order-item schema lacks a
-- verified instructions field. Do not fabricate customer notes.
create or replace function public.gs_get_station_ticket_content(p_ticket_id bigint)
returns table(ticket_id bigint,order_id bigint,station_key text,order_destination text,
 order_created_at timestamptz,ticket_status text,delivery_method text,
 product_name text,quantity integer,special_instructions text,order_item_id bigint)
language plpgsql stable security definer set search_path='' as $$
declare v_ticket public.gs_cafe_order_station_tickets%rowtype;
begin
 if auth.uid() is null or not (
  public.gs_can_access('tables','can_view') or
  public.gs_can_access('kitchen','can_view') or
  public.gs_can_access('table_orders','can_view')) then
  raise exception 'Station ticket viewing permission required';
 end if;
 select * into v_ticket from public.gs_cafe_order_station_tickets t where t.id=p_ticket_id;
 if not found then raise exception 'Ticket not found'; end if;
 return query select t.id,t.order_id,t.station_key,o.destination,o.created_at,
  t.status,t.delivery_method,ti.product_name_snapshot,ti.quantity,
  null::text,ti.order_item_id
 from public.gs_cafe_order_station_tickets t
 join public.gs_orders o on o.id=t.order_id
 join public.gs_cafe_order_station_ticket_items ti on ti.ticket_id=t.id
 where t.id=p_ticket_id
 order by ti.order_item_id;
end $$;
revoke all on function public.gs_get_station_ticket_content(bigint) from public,anon;
grant execute on function public.gs_get_station_ticket_content(bigint) to authenticated;
