-- Upgrade 1185: station-level pickup and delivery audit, independent of parent order.
alter table public.gs_cafe_station_preparation
 add column if not exists picked_up_at timestamptz,
 add column if not exists picked_up_by uuid references auth.users(id),
 add column if not exists delivered_at timestamptz,
 add column if not exists delivered_by uuid references auth.users(id);
alter table public.gs_cafe_station_preparation
 drop constraint if exists gs_station_delivery_sequence;
alter table public.gs_cafe_station_preparation
 add constraint gs_station_delivery_sequence check (
  (picked_up_at is null and picked_up_by is null and delivered_at is null and delivered_by is null)
  or (picked_up_at is not null and picked_up_by is not null and
      ((delivered_at is null and delivered_by is null) or
       (delivered_at is not null and delivered_by is not null and delivered_at >= picked_up_at)))
 );
alter table public.gs_cafe_station_preparation_events
 drop constraint if exists gs_cafe_station_preparation_events_event_kind_check;
alter table public.gs_cafe_station_preparation_events
 add constraint gs_cafe_station_preparation_events_event_kind_check
 check(event_kind in ('accepted','ready','picked_up','delivered'));

create or replace function public.gs_record_station_handover(p_ticket_id bigint,p_action text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_ticket public.gs_cafe_order_station_tickets%rowtype;
declare v_prep public.gs_cafe_station_preparation%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') then
   raise exception 'Kitchen edit permission required';
 end if;
 if p_ticket_id is null or p_ticket_id <= 0 or p_action not in ('picked_up','delivered') then
   raise exception 'Invalid ticket or handover action';
 end if;
 select * into v_ticket from public.gs_cafe_order_station_tickets where id=p_ticket_id for update;
 if not found then raise exception 'Station ticket not found'; end if;
 if not exists(select 1 from public.gs_orders where id=v_ticket.order_id
   and status in ('preparing','ready')) then
   raise exception 'Parent order is not active';
 end if;
 select * into v_prep from public.gs_cafe_station_preparation where ticket_id=p_ticket_id for update;
 if not found or v_prep.state <> 'ready' then raise exception 'Station ticket is not ready'; end if;
 if p_action = 'picked_up' then
   if v_prep.picked_up_at is not null then raise exception 'Station ticket already picked up'; end if;
   update public.gs_cafe_station_preparation
     set picked_up_at=transaction_timestamp(),picked_up_by=auth.uid(),updated_at=transaction_timestamp()
     where ticket_id=p_ticket_id;
 else
   if v_prep.picked_up_at is null then raise exception 'Pickup required before delivery'; end if;
   if v_prep.delivered_at is not null then raise exception 'Station ticket already delivered'; end if;
   update public.gs_cafe_station_preparation
     set delivered_at=transaction_timestamp(),delivered_by=auth.uid(),updated_at=transaction_timestamp()
     where ticket_id=p_ticket_id;
 end if;
 insert into public.gs_cafe_station_preparation_events(ticket_id,actor_id,event_kind)
 values(p_ticket_id,auth.uid(),p_action);
end;
$$;
revoke all on function public.gs_record_station_handover(bigint,text) from public,anon;
grant execute on function public.gs_record_station_handover(bigint,text) to authenticated;

create or replace function public.gs_station_handover_details(p_ticket_id bigint)
returns table(picked_up_at timestamptz,picked_up_by uuid,delivered_at timestamptz,delivered_by uuid)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then
  raise exception 'Kitchen view permission required';
 end if;
 return query select p.picked_up_at,p.picked_up_by,p.delivered_at,p.delivered_by
 from public.gs_cafe_station_preparation p where p.ticket_id=p_ticket_id;
end;
$$;
revoke all on function public.gs_station_handover_details(bigint) from public,anon;
grant execute on function public.gs_station_handover_details(bigint) to authenticated;
