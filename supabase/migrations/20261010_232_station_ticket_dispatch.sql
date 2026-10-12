-- Upgrade 232: authenticated station ticket dispatch lease, acknowledgement and failure reporting.
-- This is a queue protocol only. No physical printing is performed by SQL.
alter table public.gs_cafe_order_station_tickets
 add column if not exists dispatch_attempts integer not null default 0,
 add column if not exists leased_by uuid,
 add column if not exists lease_expires_at timestamptz,
 add column if not exists dispatched_at timestamptz,
 add column if not exists acknowledged_at timestamptz,
 add column if not exists last_error text;
create index if not exists gs_station_ticket_dispatch_idx
 on public.gs_cafe_order_station_tickets(status,lease_expires_at,created_at);
create table if not exists public.gs_cafe_station_ticket_events (
 id bigint generated always as identity primary key,
 ticket_id bigint not null references public.gs_cafe_order_station_tickets(id),
 actor_id uuid not null references auth.users(id),
 event_kind text not null check(event_kind in ('claimed','received','printed','failed','retry_queued','uncertain')),
 details text,
 occurred_at timestamptz not null default now()
);
alter table public.gs_cafe_station_ticket_events enable row level security;
revoke all on public.gs_cafe_station_ticket_events from public,anon,authenticated;
-- A worker must be signed in, permitted, and assigned to the configured POS device.
-- Printer workers currently require table management permission until printer-device binding is implemented.
create or replace function public.gs_claim_station_ticket(p_ticket_id bigint)
returns table(ticket_id bigint, order_id bigint, station_key text, delivery_method text,
 pos_device_id bigint, printer_id bigint, attempt integer, lease_until timestamptz)
language plpgsql security definer set search_path='' as $$
declare t public.gs_cafe_order_station_tickets%rowtype;
begin
 if auth.uid() is null or not (public.gs_can_access('tables','can_edit') or public.gs_can_access('kitchen','can_edit')) then
  raise exception 'Dispatch permission required'; end if;
 select * into t from public.gs_cafe_order_station_tickets where id=p_ticket_id for update;
 if not found then raise exception 'Ticket not found'; end if;
 if t.status <> 'queued' then raise exception 'Ticket is not queued; do not auto-reprint'; end if;
 if t.delivery_method='pos' and not exists (
  select 1 from public.gs_cafe_pos_devices d where d.id=t.pos_device_id and d.enabled
  and d.assigned_employee_id=auth.uid()) then
  raise exception 'This POS is not assigned to the signed-in employee'; end if;
 if t.delivery_method='printer' and not public.gs_can_access('tables','can_edit') then
  raise exception 'Printer dispatcher requires Tables edit permission'; end if;
 update public.gs_cafe_order_station_tickets
 set status='unknown',dispatch_attempts=dispatch_attempts+1,leased_by=auth.uid(),
 lease_expires_at=now()+interval '90 seconds',dispatched_at=now(),last_error=null
 where id=p_ticket_id returning * into t;
 insert into public.gs_cafe_station_ticket_events(ticket_id,actor_id,event_kind,details)
 values(t.id,auth.uid(),'claimed','Delivery attempt started; awaiting physical device acknowledgement');
 return query select t.id,t.order_id,t.station_key,t.delivery_method,t.pos_device_id,
 t.printer_id,t.dispatch_attempts,t.lease_expires_at;
end $$;
-- 'received' means destination accepted the payload, not paper printed.
-- 'printed' requires a device/driver confirmation; 'failed' is explicit device failure.
create or replace function public.gs_ack_station_ticket(p_ticket_id bigint,p_result text,p_error text default null)
returns void language plpgsql security definer set search_path='' as $$
declare t public.gs_cafe_order_station_tickets%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_result not in ('received','printed','failed') then raise exception 'Invalid acknowledgement'; end if;
 select * into t from public.gs_cafe_order_station_tickets where id=p_ticket_id for update;
 if not found then raise exception 'Ticket not found'; end if;
 if t.leased_by is distinct from auth.uid() then raise exception 'Only claiming worker may acknowledge'; end if;
 if t.status not in ('unknown','received') then raise exception 'Ticket is not awaiting acknowledgement'; end if;
 if t.status='received' and p_result='received' then return; end if;
 if t.status='received' and p_result='failed' then raise exception 'Cannot fail a received ticket without review'; end if;
 update public.gs_cafe_order_station_tickets set status=p_result,
 acknowledged_at=case when p_result in ('received','printed') then now() else acknowledged_at end,
 last_error=case when p_result='failed' then left(coalesce(nullif(trim(p_error),''),'Device reported failure'),500) else null end,
 lease_expires_at=null where id=p_ticket_id;
 insert into public.gs_cafe_station_ticket_events(ticket_id,actor_id,event_kind,details)
 values(p_ticket_id,auth.uid(),p_result,left(p_error,500));
end $$;
-- Unknown and failed jobs are never silently retried. A manager must review and explicitly requeue.
create or replace function public.gs_retry_station_ticket(p_ticket_id bigint,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare t public.gs_cafe_order_station_tickets%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Tables manager permission required'; end if;
 if p_reason is null or length(trim(p_reason)) < 5 then raise exception 'Retry reason required'; end if;
 select * into t from public.gs_cafe_order_station_tickets where id=p_ticket_id for update;
 if not found or t.status not in ('failed','unknown') then
  raise exception 'Only failed or uncertain tickets may be requeued'; end if;
 update public.gs_cafe_order_station_tickets set status='queued',leased_by=null,
 lease_expires_at=null,last_error=null where id=p_ticket_id;
 insert into public.gs_cafe_station_ticket_events(ticket_id,actor_id,event_kind,details)
 values(p_ticket_id,auth.uid(),'retry_queued',left(trim(p_reason),500));
end $$;
create or replace function public.gs_list_station_dispatch_alerts()
returns table(ticket_id bigint,order_id bigint,station_key text,status text,
 attempts integer,last_error text,dispatched_at timestamptz,lease_expires_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (public.gs_can_access('tables','can_view') or public.gs_can_access('kitchen','can_view')) then
  raise exception 'Viewing permission required'; end if;
 return query select t.id,t.order_id,t.station_key,t.status,t.dispatch_attempts,t.last_error,
 t.dispatched_at,t.lease_expires_at from public.gs_cafe_order_station_tickets t
 where t.status='failed' or (t.status='unknown' and t.lease_expires_at < now())
 order by t.created_at desc limit 200;
end $$;
revoke all on function public.gs_claim_station_ticket(bigint) from public,anon;
revoke all on function public.gs_ack_station_ticket(bigint,text,text) from public,anon;
revoke all on function public.gs_retry_station_ticket(bigint,text) from public,anon;
revoke all on function public.gs_list_station_dispatch_alerts() from public,anon;
grant execute on function public.gs_claim_station_ticket(bigint) to authenticated;
grant execute on function public.gs_ack_station_ticket(bigint,text,text) to authenticated;
grant execute on function public.gs_retry_station_ticket(bigint,text) to authenticated;
grant execute on function public.gs_list_station_dispatch_alerts() to authenticated;
