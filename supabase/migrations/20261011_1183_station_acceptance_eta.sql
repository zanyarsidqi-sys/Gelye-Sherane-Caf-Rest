-- Upgrade 1183: station-specific acceptance and mandatory ETA.
-- Station preparation status is independent of device delivery status and order status.
create table if not exists public.gs_cafe_station_preparation (
 ticket_id bigint primary key references public.gs_cafe_order_station_tickets(id) on delete cascade,
 state text not null default 'pending' check (state in ('pending','preparing','ready')),
 accepted_by uuid references auth.users(id),
 accepted_at timestamptz,
 estimated_minutes integer check (estimated_minutes between 1 and 480),
 estimated_ready_at timestamptz,
 ready_by uuid references auth.users(id),
 ready_at timestamptz,
 updated_at timestamptz not null default now(),
 constraint gs_station_acceptance_complete check (
   (state='pending' and accepted_at is null and accepted_by is null and estimated_minutes is null and estimated_ready_at is null)
   or (state in ('preparing','ready') and accepted_at is not null and accepted_by is not null
       and estimated_minutes is not null and estimated_ready_at is not null)),
 constraint gs_station_ready_complete check (
   (state <> 'ready' and ready_at is null and ready_by is null)
   or (state = 'ready' and ready_at is not null and ready_by is not null))
);
alter table public.gs_cafe_station_preparation enable row level security;
revoke all on public.gs_cafe_station_preparation from public,anon,authenticated;
create table if not exists public.gs_cafe_station_preparation_events (
 id bigint generated always as identity primary key,
 ticket_id bigint not null references public.gs_cafe_order_station_tickets(id),
 actor_id uuid not null references auth.users(id),
 event_kind text not null check(event_kind in ('accepted','ready')),
 estimated_minutes integer,
 occurred_at timestamptz not null default now()
);
alter table public.gs_cafe_station_preparation_events enable row level security;
revoke all on public.gs_cafe_station_preparation_events from public,anon,authenticated;

create or replace function public.gs_accept_station_preparation(p_ticket_id bigint,p_minutes integer)
returns void language plpgsql security definer set search_path = '' as $$
declare v_ticket public.gs_cafe_order_station_tickets%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') then
  raise exception 'Kitchen edit permission required'; end if;
 if p_ticket_id is null or p_ticket_id <= 0 or p_minutes is null or p_minutes not between 1 and 480 then
  raise exception 'Ticket and preparation estimate (1-480 minutes) required'; end if;
 select * into v_ticket from public.gs_cafe_order_station_tickets where id=p_ticket_id for update;
 if not found then raise exception 'Ticket not found'; end if;
 if not exists(select 1 from public.gs_orders where id=v_ticket.order_id and status in ('preparing','ready')) then
  raise exception 'Parent order is not active'; end if;
 if not exists(select 1 from public.gs_cafe_preparation_stations where station_key=v_ticket.station_key and enabled) then
  raise exception 'Station is disabled'; end if;
 insert into public.gs_cafe_station_preparation(ticket_id,state,accepted_by,accepted_at,
   estimated_minutes,estimated_ready_at,updated_at)
 values(p_ticket_id,'preparing',auth.uid(),transaction_timestamp(),p_minutes,
   transaction_timestamp()+make_interval(mins => p_minutes),transaction_timestamp())
 on conflict(ticket_id) do nothing;
 if not found then raise exception 'Station ticket has already been accepted'; end if;
 insert into public.gs_cafe_station_preparation_events(ticket_id,actor_id,event_kind,estimated_minutes)
 values(p_ticket_id,auth.uid(),'accepted',p_minutes);
end;
$$;
revoke all on function public.gs_accept_station_preparation(bigint,integer) from public,anon;
grant execute on function public.gs_accept_station_preparation(bigint,integer) to authenticated;

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
revoke all on function public.gs_kitchen_station_preparation_queue() from public,anon;
grant execute on function public.gs_kitchen_station_preparation_queue() to authenticated;
