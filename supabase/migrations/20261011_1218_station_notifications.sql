-- Upgrade 1218: durable, station-scoped notification fanout for new routed tickets.
-- Employee assignments have composite (station_key,employee_id) PK: multiple stations supported.
create table if not exists public.gs_cafe_station_notifications (
 id bigint generated always as identity primary key,
 ticket_id bigint not null references public.gs_cafe_order_station_tickets(id),
 station_key text not null references public.gs_cafe_preparation_stations(station_key),
 employee_id uuid not null references auth.users(id),
 created_at timestamptz not null default now(), seen_at timestamptz,
 unique(ticket_id,employee_id)
);
create index if not exists gs_station_notifications_employee_idx on public.gs_cafe_station_notifications(employee_id,seen_at,created_at desc);
alter table public.gs_cafe_station_notifications enable row level security;
revoke all on public.gs_cafe_station_notifications from public,anon,authenticated;
create or replace function public.gs_notify_station_ticket_1218()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.gs_cafe_station_notifications(ticket_id,station_key,employee_id)
 select new.id,new.station_key,a.employee_id from public.gs_cafe_station_employee_assignments a
 where a.station_key=new.station_key and a.active on conflict do nothing;
 return new;
end $$;
drop trigger if exists gs_notify_station_ticket_1218 on public.gs_cafe_order_station_tickets;
create trigger gs_notify_station_ticket_1218 after insert on public.gs_cafe_order_station_tickets
for each row execute function public.gs_notify_station_ticket_1218();
create or replace function public.gs_my_station_notifications_1218(p_limit integer default 50)
returns table(notification_id bigint,ticket_id bigint,station_key text,order_id bigint,created_at timestamptz,seen_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then raise exception 'Kitchen view permission required'; end if;
 return query select n.id,n.ticket_id,n.station_key,t.order_id,n.created_at,n.seen_at
 from public.gs_cafe_station_notifications n join public.gs_cafe_order_station_tickets t on t.id=n.ticket_id
 join public.gs_cafe_station_employee_assignments a on a.station_key=n.station_key and a.employee_id=auth.uid() and a.active
 where n.employee_id=auth.uid() order by n.created_at desc limit least(greatest(coalesce(p_limit,50),1),200);
end $$;
create or replace function public.gs_seen_station_notification_1218(p_notification_id bigint)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then raise exception 'Kitchen view permission required'; end if;
 update public.gs_cafe_station_notifications n set seen_at=coalesce(n.seen_at,now())
 where n.id=p_notification_id and n.employee_id=auth.uid()
 and exists(select 1 from public.gs_cafe_station_employee_assignments a where a.station_key=n.station_key and a.employee_id=auth.uid() and a.active);
 if not found then raise exception 'Notification unavailable'; end if;
end $$;
revoke all on function public.gs_notify_station_ticket_1218() from public,anon,authenticated;
revoke all on function public.gs_my_station_notifications_1218(integer) from public,anon;
revoke all on function public.gs_seen_station_notification_1218(bigint) from public,anon;
grant execute on function public.gs_my_station_notifications_1218(integer) to authenticated;
grant execute on function public.gs_seen_station_notification_1218(bigint) to authenticated;
