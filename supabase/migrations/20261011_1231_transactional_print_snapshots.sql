-- Upgrade 1231: transactional immutable snapshots for standard routed orders.
-- Depends on migrations 229, 1182, 1227 and 1230.
-- Correction and replacement event creation requires separate explicit events;
-- existing UNIQUE(order_id,station_key) cannot represent multiple revision tickets.
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

  -- Freeze the complete set of routed lines in the same database transaction.
  -- Never overwrite an existing immutable snapshot on repeated routing.
  if not exists (
    select 1 from public.gs_cafe_station_ticket_snapshots_1230
    where ticket_id=v_ticket
  ) then
    insert into public.gs_cafe_station_ticket_snapshots_1230
      (ticket_id,station_key,order_id,kind,items)
    select v_ticket,v_station.station_key,p_order_id,'ORDER',
      jsonb_agg(jsonb_build_object(
        'order_item_id',ti.order_item_id,
        'product',ti.product_name_snapshot,
        'quantity',ti.quantity,
        'customer_name',nullif(trim(coalesce(oi.guest_label,'')),''),
        'note',coalesce(oi.preparation_notes,'')
      ) order by ti.order_item_id)
    from public.gs_cafe_order_station_ticket_items ti
    join public.gs_order_items oi on oi.id=ti.order_item_id
    where ti.ticket_id=v_ticket
    having count(*)>0;
    if not found then
      raise exception 'Cannot queue a station ticket without printable items';
    end if;
  end if;
  v_count:=v_count+1;
 end loop;
 return v_count;
end $$;

revoke all on function public.gs_route_confirmed_order(bigint) from public,anon;
grant execute on function public.gs_route_confirmed_order(bigint) to authenticated;

create or replace function public.gs_1227_device_claim_print(
 p_token_hash text)
returns table(ticket_id bigint,order_id bigint,station_key text,attempt integer,lease_until timestamptz)
language plpgsql security definer set search_path='' as $$
declare v_station text; v_ticket bigint; v_order bigint; v_attempt integer; v_lease timestamptz;
begin

 if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$' then
  raise exception 'Invalid device session'; end if;
 select a.station_key into v_station
 from public.gs_cafe_station_device_sessions s
 join public.gs_cafe_station_accounts a on a.station_key=s.station_key
 where s.token_hash=p_token_hash and s.revoked_at is null and s.expires_at>now()
   and s.credential_version=a.credential_version and a.enabled and a.allow_order_print
   and s.last_seen_at>now()-interval '2 minutes';
 if v_station is null then raise exception 'Active order-printing device required'; end if;
 -- Skip locked prevents competing workers from claiming the same ticket.
 select t.id into v_ticket from public.gs_cafe_order_station_tickets t
 where t.station_key=v_station and t.status='queued'
 and exists (select 1 from public.gs_cafe_station_ticket_snapshots_1230 snap where snap.ticket_id=t.id)
 order by t.created_at,t.id
 for update skip locked limit 1;
 if v_ticket is null then return; end if;
 update public.gs_cafe_order_station_tickets t
 set status='unknown',dispatch_attempts=t.dispatch_attempts+1,
     lease_expires_at=now()+interval '90 seconds',
     dispatched_at=now(),last_error=null
 where t.id=v_ticket
 returning t.order_id,t.dispatch_attempts,t.lease_expires_at
 into v_order,v_attempt,v_lease;
 return query select v_ticket,v_order,v_station,v_attempt,v_lease;
end $$;


revoke all on function public.gs_1227_device_claim_print(text) from public,anon,authenticated;
grant execute on function public.gs_1227_device_claim_print(text) to service_role;

-- Dedicated revision event ledger. Separate from original unique order/station ticket.
-- This does not yet create printable correction tickets automatically.
create table if not exists public.gs_cafe_station_print_revision_events_1231 (
 id bigint generated always as identity primary key,
 original_ticket_id bigint not null references public.gs_cafe_order_station_tickets(id),
 station_key text not null references public.gs_cafe_preparation_stations(station_key),
 kind text not null check(kind in ('CORRECTION','REPLACEMENT','CANCELLATION')),
 reason text not null check(length(trim(reason)) between 1 and 500),
 items jsonb not null check(jsonb_typeof(items)='array' and jsonb_array_length(items)>0),
 created_by uuid references auth.users(id),
 created_at timestamptz not null default now()
);
alter table public.gs_cafe_station_print_revision_events_1231 enable row level security;
revoke all on public.gs_cafe_station_print_revision_events_1231 from public,anon,authenticated;
create or replace function public.gs_1231_revision_immutable()
returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Print revision events are append-only'; end $$;
create trigger gs_1231_revision_immutable before update or delete
on public.gs_cafe_station_print_revision_events_1231
for each row execute function public.gs_1231_revision_immutable();
