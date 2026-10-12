
-- Upgrade 1230: immutable snapshot resolver for already-created station tickets.
-- The snapshot must be inserted by the trusted order-routing transaction BEFORE
-- a ticket becomes queued. This migration deliberately does not fabricate data.
create table if not exists public.gs_cafe_station_ticket_snapshots_1230 (
 ticket_id bigint primary key references public.gs_cafe_order_station_tickets(id),
 station_key text not null references public.gs_cafe_preparation_stations(station_key),
 order_id bigint not null,
 table_label text not null default '',
 kind text not null check(kind in ('ORDER','CORRECTION','REPLACEMENT','CANCELLATION')),
 note text not null default '',
 items jsonb not null check(jsonb_typeof(items)='array' and jsonb_array_length(items)>0),
 created_at timestamptz not null default now()
);
alter table public.gs_cafe_station_ticket_snapshots_1230 enable row level security;
revoke all on public.gs_cafe_station_ticket_snapshots_1230 from public,anon,authenticated;
-- Prevent mutation of ticket contents after the trusted transaction commits.
create or replace function public.gs_1230_snapshot_immutable()
returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Station print snapshots are immutable'; end $$;
drop trigger if exists gs_1230_snapshot_immutable on public.gs_cafe_station_ticket_snapshots_1230;
create trigger gs_1230_snapshot_immutable before update or delete
on public.gs_cafe_station_ticket_snapshots_1230
for each row execute function public.gs_1230_snapshot_immutable();

create or replace function public.gs_1230_resolve_station_ticket(
 p_token_hash text,p_ticket_id bigint,p_attempt integer)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_station text; v_result jsonb;
begin
 if current_user <> 'service_role' then raise exception 'Service access required'; end if;
 if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$'
    or p_ticket_id is null or p_attempt is null or p_attempt<1 then
  raise exception 'Invalid request'; end if;
 select a.station_key into v_station
 from public.gs_cafe_station_device_sessions d
 join public.gs_cafe_station_accounts a on a.station_key=d.station_key
 where d.token_hash=p_token_hash and d.revoked_at is null
 and d.expires_at>now() and d.credential_version=a.credential_version
 and a.enabled and a.allow_order_print
 and d.last_seen_at>now()-interval '2 minutes';
 if v_station is null then raise exception 'Unauthorized device'; end if;
 select jsonb_build_object('ticket_id',t.id,'attempt',t.dispatch_attempts,
   'station',s.station_key,'order_id',s.order_id,'table_label',s.table_label,
   'kind',s.kind,'note',s.note,'items',s.items) into v_result
 from public.gs_cafe_order_station_tickets t
 join public.gs_cafe_station_ticket_snapshots_1230 s on s.ticket_id=t.id
 where t.id=p_ticket_id and t.station_key=v_station and s.station_key=v_station
 and t.dispatch_attempts=p_attempt and t.status='unknown'
 and t.lease_expires_at>now();
 if v_result is null then raise exception 'Ticket snapshot unavailable'; end if;
 return v_result;
end $$;
revoke all on function public.gs_1230_resolve_station_ticket(text,bigint,integer) from public,anon,authenticated;
grant execute on function public.gs_1230_resolve_station_ticket(text,bigint,integer) to service_role;
