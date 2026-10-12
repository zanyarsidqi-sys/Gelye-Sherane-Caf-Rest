-- Upgrade 235: immutable preparation-instruction snapshots for station tickets.
-- Instructions belong to an order line, not the menu product; existing printed
-- tickets must never change when staff later edit an order line.
alter table public.gs_order_items
 add column if not exists preparation_instructions text;
alter table public.gs_order_items
 drop constraint if exists gs_order_item_instruction_limit;
alter table public.gs_order_items
 add constraint gs_order_item_instruction_limit
 check (preparation_instructions is null or
  (length(preparation_instructions) <= 500 and
   length(btrim(preparation_instructions)) > 0));
alter table public.gs_cafe_order_station_ticket_items
 add column if not exists preparation_instructions_snapshot text;

-- Backfill once; do not overwrite previously captured ticket instructions.
update public.gs_cafe_order_station_ticket_items ti
set preparation_instructions_snapshot=oi.preparation_instructions
from public.gs_order_items oi
where ti.order_item_id=oi.id
 and ti.preparation_instructions_snapshot is null;

-- Snapshot line notes at ticket creation. Existing trigger for product names remains.
create or replace function public.gs_snapshot_station_ticket_instructions()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 select oi.preparation_instructions into new.preparation_instructions_snapshot
 from public.gs_order_items oi where oi.id=new.order_item_id;
 return new;
end $$;
drop trigger if exists gs_station_ticket_instructions_snapshot_trg
 on public.gs_cafe_order_station_ticket_items;
create trigger gs_station_ticket_instructions_snapshot_trg
 before insert on public.gs_cafe_order_station_ticket_items
 for each row execute function public.gs_snapshot_station_ticket_instructions();
revoke all on function public.gs_snapshot_station_ticket_instructions()
 from public,anon,authenticated;

-- Explicit authorized line-level update, only while order remains NEW.
-- Reject edits after ticket staging to preserve kitchen audit integrity.
create or replace function public.gs_set_order_item_preparation_instructions(
 p_order_item_id bigint,p_instructions text)
returns void language plpgsql security definer set search_path='' as $$
declare v_status text; v_note text;
begin
 if auth.uid() is null or not (
  public.gs_can_access('table_orders','can_edit') or
  public.gs_can_access('motel_orders','can_edit')) then
  raise exception 'Order editing permission required';
 end if;
 v_note:=nullif(btrim(p_instructions),'');
 if v_note is not null and length(v_note)>500 then
  raise exception 'Preparation instructions cannot exceed 500 characters';
 end if;
 select o.status into v_status from public.gs_order_items i
 join public.gs_orders o on o.id=i.order_id
 where i.id=p_order_item_id for update of o;
 if not found then raise exception 'Order item not found'; end if;
 if v_status <> 'new' then
  raise exception 'Preparation instructions can only change before order acceptance';
 end if;
 if exists(select 1 from public.gs_cafe_order_station_ticket_items
           where order_item_id=p_order_item_id) then
  raise exception 'Ticket already created; instructions are locked';
 end if;
 update public.gs_order_items
 set preparation_instructions=v_note where id=p_order_item_id;
end $$;
revoke all on function public.gs_set_order_item_preparation_instructions(bigint,text)
 from public,anon;
grant execute on function public.gs_set_order_item_preparation_instructions(bigint,text)
 to authenticated;

-- Preserve the signature consumed by the Dispatch Center; return actual notes
-- snapshotted for each station-specific ticket line.
create or replace function public.gs_get_station_ticket_content(p_ticket_id bigint)
returns table(ticket_id bigint,order_id bigint,station_key text,order_destination text,
 order_created_at timestamptz,ticket_status text,delivery_method text,
 product_name text,quantity integer,special_instructions text,order_item_id bigint)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (
  public.gs_can_access('tables','can_view') or
  public.gs_can_access('kitchen','can_view') or
  public.gs_can_access('table_orders','can_view')) then
  raise exception 'Station ticket viewing permission required';
 end if;
 if not exists(select 1 from public.gs_cafe_order_station_tickets
               where id=p_ticket_id) then
  raise exception 'Ticket not found';
 end if;
 return query select t.id,t.order_id,t.station_key,o.destination,o.created_at,
  t.status,t.delivery_method,ti.product_name_snapshot,ti.quantity,
  ti.preparation_instructions_snapshot,ti.order_item_id
 from public.gs_cafe_order_station_tickets t
 join public.gs_orders o on o.id=t.order_id
 join public.gs_cafe_order_station_ticket_items ti on ti.ticket_id=t.id
 where t.id=p_ticket_id order by ti.order_item_id;
end $$;
revoke all on function public.gs_get_station_ticket_content(bigint) from public,anon;
grant execute on function public.gs_get_station_ticket_content(bigint) to authenticated;
