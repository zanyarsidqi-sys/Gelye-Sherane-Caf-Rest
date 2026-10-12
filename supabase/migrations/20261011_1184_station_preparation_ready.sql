-- Upgrade 1184: finish a station ticket independently of the whole customer order.
create or replace function public.gs_complete_station_preparation(p_ticket_id bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare v_ticket public.gs_cafe_order_station_tickets%rowtype;
declare v_state text;
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') then
  raise exception 'Kitchen edit permission required';
 end if;
 if p_ticket_id is null or p_ticket_id <= 0 then
  raise exception 'Valid station ticket required';
 end if;
 select * into v_ticket from public.gs_cafe_order_station_tickets
 where id=p_ticket_id for update;
 if not found then raise exception 'Station ticket not found'; end if;
 if not exists(select 1 from public.gs_orders
   where id=v_ticket.order_id and status in ('preparing','ready')) then
  raise exception 'Parent order is no longer active';
 end if;
 select state into v_state from public.gs_cafe_station_preparation
 where ticket_id=p_ticket_id for update;
 if not found or v_state <> 'preparing' then
  raise exception 'Only accepted preparing tickets can be marked ready';
 end if;
 update public.gs_cafe_station_preparation
 set state='ready', ready_by=auth.uid(), ready_at=transaction_timestamp(),
     updated_at=transaction_timestamp()
 where ticket_id=p_ticket_id;
 insert into public.gs_cafe_station_preparation_events
   (ticket_id,actor_id,event_kind)
 values (p_ticket_id,auth.uid(),'ready');
end;
$$;
revoke all on function public.gs_complete_station_preparation(bigint) from public,anon;
grant execute on function public.gs_complete_station_preparation(bigint) to authenticated;

-- Recreate the read function to include the employee who marked the station ready.
create or replace function public.gs_kitchen_station_preparation_queue()
returns table(ticket_id bigint,order_id bigint,station_key text,station_name text,
 preparation_state text,accepted_at timestamptz,estimated_minutes integer,
 estimated_ready_at timestamptz,accepted_by uuid,ready_at timestamptz,
 item_count bigint,item_quantity bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then
  raise exception 'Kitchen view permission required'; end if;
 return query select t.id,t.order_id,t.station_key,s.display_name,
  coalesce(p.state,'pending'),p.accepted_at,p.estimated_minutes,
  p.estimated_ready_at,p.accepted_by,p.ready_at,
  count(ti.order_item_id)::bigint,coalesce(sum(ti.quantity),0)::bigint
 from public.gs_cafe_order_station_tickets t
 join public.gs_cafe_preparation_stations s on s.station_key=t.station_key
 join public.gs_orders o on o.id=t.order_id
 left join public.gs_cafe_station_preparation p on p.ticket_id=t.id
 left join public.gs_cafe_order_station_ticket_items ti on ti.ticket_id=t.id
 where o.status in ('preparing','ready')
 group by t.id,t.order_id,t.station_key,s.display_name,p.state,p.accepted_at,
  p.estimated_minutes,p.estimated_ready_at,p.accepted_by,p.ready_at
 order by t.created_at,t.id limit 250;
end;
$$;
-- Read readiness actor separately to preserve the queue's existing return signature.
create or replace function public.gs_station_ready_details(p_ticket_id bigint)
returns table(ready_at timestamptz,ready_by uuid)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then
  raise exception 'Kitchen view permission required'; end if;
 return query select p.ready_at,p.ready_by
 from public.gs_cafe_station_preparation p where p.ticket_id=p_ticket_id;
end;
$$;
revoke all on function public.gs_station_ready_details(bigint) from public,anon;
grant execute on function public.gs_station_ready_details(bigint) to authenticated;
