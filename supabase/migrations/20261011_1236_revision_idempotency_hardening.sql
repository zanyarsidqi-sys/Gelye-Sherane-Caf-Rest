-- Upgrade 1236: revision request idempotency hardening.
-- This replaces only the idempotency comparison in the existing routine.
-- Source of truth: migration 1232 with an additional normalized item check.
create or replace function public.gs_1232_submit_station_revision(
 p_original_ticket_id bigint, p_kind text, p_reason text,
 p_items jsonb, p_request_key uuid)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_ticket public.gs_cafe_order_station_tickets%rowtype;
 v_event bigint; v_item jsonb; v_id bigint; v_station text;
begin
 if auth.uid() is null or not (
  public.gs_can_access('table_orders','can_edit') or
  public.gs_can_access('kitchen','can_edit')) then
  raise exception 'Station correction permission required'; end if;
 if p_request_key is null or p_kind not in ('CORRECTION','REPLACEMENT','CANCELLATION')
 or p_reason is null or length(trim(p_reason)) not between 1 and 500
 or p_items is null or jsonb_typeof(p_items)<>'array'
 or jsonb_array_length(p_items) not between 1 and 100 then
  raise exception 'Invalid correction request'; end if;
 select * into v_ticket from public.gs_cafe_order_station_tickets
 where id=p_original_ticket_id for update;
 if not found then raise exception 'Original station ticket not found'; end if;
 -- Validate each line against the original ticket, not mutable product mappings.
 for v_item in select value from jsonb_array_elements(p_items) loop
  if jsonb_typeof(v_item)<>'object' or
     jsonb_typeof(v_item->'order_item_id')<>'number' or
     jsonb_typeof(v_item->'quantity')<>'number' or
     (v_item->>'order_item_id') !~ '^[0-9]+$' or
     (v_item->>'quantity') !~ '^[1-9][0-9]*$' or
     (v_item->>'quantity')::bigint>100000 then
    raise exception 'Invalid revision item'; end if;
  v_id := (v_item->>'order_item_id')::bigint;
  if not exists(select 1 from public.gs_cafe_order_station_ticket_items ti
    where ti.ticket_id=p_original_ticket_id and ti.order_item_id=v_id) then
    raise exception 'Item not part of original station ticket'; end if;
 end loop;
 -- No client-supplied product name or guest identity is trusted for printing.
 -- Use original immutable snapshots; capture requested quantities only.
 select e.id into v_event from public.gs_cafe_station_print_revision_events_1231 e
 where e.request_key=p_request_key;
 if v_event is not null then
  if not exists(select 1 from public.gs_cafe_station_print_revision_events_1231 e
     where e.id=v_event and e.original_ticket_id=p_original_ticket_id
       and e.kind=p_kind and e.reason=trim(p_reason)
       and (select jsonb_agg(jsonb_build_object(
         'order_item_id',(v->>'order_item_id')::bigint,
         'quantity',(v->>'quantity')::integer)
         order by (v->>'order_item_id')::bigint)
         from jsonb_array_elements(e.items) v)
       is not distinct from
       (select jsonb_agg(jsonb_build_object(
         'order_item_id',(v->>'order_item_id')::bigint,
         'quantity',(v->>'quantity')::integer)
         order by (v->>'order_item_id')::bigint)
         from jsonb_array_elements(p_items) v)) then
   raise exception 'Idempotency key reused for a different correction'; end if;
  return v_event;
 end if;
 insert into public.gs_cafe_station_print_revision_events_1231(
   original_ticket_id,station_key,kind,reason,items,created_by,request_key)
 values(p_original_ticket_id,v_ticket.station_key,p_kind,trim(p_reason),
   (select jsonb_agg(jsonb_build_object(
     'order_item_id',(x->>'order_item_id')::bigint,
     'quantity',(x->>'quantity')::integer,
     'product',s.item->>'product',
     'customer_name',s.item->>'customer_name',
     'note',s.item->>'note') order by (x->>'order_item_id')::bigint)
    from jsonb_array_elements(p_items) x
    join public.gs_cafe_station_ticket_snapshots_1230 snap
      on snap.ticket_id=p_original_ticket_id
    cross join lateral jsonb_array_elements(snap.items) s(item)
    where (s.item->>'order_item_id')::bigint=(x->>'order_item_id')::bigint),
   auth.uid(),p_request_key)
 returning id into v_event;
 insert into public.gs_cafe_station_revision_dispatch_1232(
   revision_event_id,station_key,order_id)
 values(v_event,v_ticket.station_key,v_ticket.order_id);
 return v_event;
end $$;

-- Existing access grants from 1232 remain unchanged.
