-- Upgrade 1210: append-only Table Orders notifications for replacement handoffs.
-- Delivery events originate from the permission-checked Kitchen transition RPC.
create table if not exists public.gs_cafe_table_replacement_notifications (
 id bigint generated always as identity primary key,
 revision_id bigint not null references public.gs_cafe_correction_station_revisions(id),
 order_id bigint not null,
 event_id bigint not null unique references public.gs_cafe_replacement_delivery_events(id),
 event_kind text not null check (event_kind in ('accepted','picked_up','delivered')),
 created_at timestamptz not null default transaction_timestamp()
);
create table if not exists public.gs_cafe_table_replacement_notification_reads (
 notification_id bigint not null references public.gs_cafe_table_replacement_notifications(id),
 employee_id uuid not null references auth.users(id),
 read_at timestamptz not null default transaction_timestamp(),
 primary key (notification_id,employee_id)
);
create index if not exists gs_table_replacement_notifications_order_idx
 on public.gs_cafe_table_replacement_notifications(order_id,created_at desc);
alter table public.gs_cafe_table_replacement_notifications enable row level security;
alter table public.gs_cafe_table_replacement_notification_reads enable row level security;
revoke all on public.gs_cafe_table_replacement_notifications,public.gs_cafe_table_replacement_notification_reads from public,anon,authenticated;

create or replace function public.gs_record_table_replacement_delivery_event()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_order_id bigint;
begin
 if new.event_kind not in ('accepted','picked_up','delivered') then return new; end if;
 select r.order_id into v_order_id
 from public.gs_cafe_correction_station_revisions r
 where r.id=new.revision_id and r.revision_kind='prepare_replacement';
 if v_order_id is not null then
  insert into public.gs_cafe_table_replacement_notifications(revision_id,order_id,event_id,event_kind)
  values(new.revision_id,v_order_id,new.id,new.event_kind) on conflict(event_id) do nothing;
 end if;
 return new;
end; $$;
drop trigger if exists gs_record_table_replacement_delivery_event on public.gs_cafe_replacement_delivery_events;
create trigger gs_record_table_replacement_delivery_event
 after insert on public.gs_cafe_replacement_delivery_events
 for each row execute function public.gs_record_table_replacement_delivery_event();
revoke all on function public.gs_record_table_replacement_delivery_event() from public,anon,authenticated;

create or replace function public.gs_list_table_replacement_notifications(p_order_id bigint default null)
returns table(notification_id bigint,revision_id bigint,order_id bigint,event_kind text,created_at timestamptz,is_read boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view') then
  raise exception 'Table Orders view permission required';
 end if;
 if p_order_id is not null and p_order_id <= 0 then raise exception 'Invalid order identifier'; end if;
 return query
 select n.id,n.revision_id,n.order_id,n.event_kind,n.created_at,
  exists(select 1 from public.gs_cafe_table_replacement_notification_reads rd
    where rd.notification_id=n.id and rd.employee_id=auth.uid())
 from public.gs_cafe_table_replacement_notifications n
 where p_order_id is null or n.order_id=p_order_id
 order by n.created_at desc,n.id desc limit 100;
end; $$;
revoke all on function public.gs_list_table_replacement_notifications(bigint) from public,anon;
grant execute on function public.gs_list_table_replacement_notifications(bigint) to authenticated;

create or replace function public.gs_mark_table_replacement_notification_read(p_notification_id bigint)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view') then
  raise exception 'Table Orders view permission required';
 end if;
 if not exists(select 1 from public.gs_cafe_table_replacement_notifications n where n.id=p_notification_id) then
  raise exception 'Notification not found';
 end if;
 insert into public.gs_cafe_table_replacement_notification_reads(notification_id,employee_id)
 values(p_notification_id,auth.uid()) on conflict do nothing;
end; $$;
revoke all on function public.gs_mark_table_replacement_notification_read(bigint) from public,anon;
grant execute on function public.gs_mark_table_replacement_notification_read(bigint) to authenticated;
