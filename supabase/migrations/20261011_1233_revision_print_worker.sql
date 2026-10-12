-- Upgrade 1233: durable, station-scoped revision print claims.
-- Revision events are immutable and never modify invoices or payments.
-- Only service_role has EXECUTE; Edge Function hashes device token.
create or replace function public.gs_1233_revision_device_station(p_hash text)
returns text language sql stable security definer set search_path='' as $$
 select a.station_key from public.gs_cafe_station_device_sessions s
 join public.gs_cafe_station_accounts a on a.station_key=s.station_key
 where s.token_hash=p_hash and s.revoked_at is null and s.expires_at>now()
 and s.credential_version=a.credential_version and a.enabled and a.allow_order_print
 and s.last_seen_at>now()-interval '2 minutes' limit 1;
$$;
revoke all on function public.gs_1233_revision_device_station(text) from public,anon,authenticated;
grant execute on function public.gs_1233_revision_device_station(text) to service_role;

create or replace function public.gs_1233_claim_revision_print(p_token_hash text)
returns table(ticket_id bigint,order_id bigint,station_key text,attempt integer,lease_until timestamptz)
language plpgsql security definer set search_path='' as $$
declare v_station text; v_id bigint; v_order bigint; v_attempt integer; v_lease timestamptz;
begin
 if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$' then raise exception 'Invalid token hash'; end if;
 v_station:=public.gs_1233_revision_device_station(p_token_hash);
 if v_station is null then raise exception 'Station printing not authorized'; end if;
 select d.id into v_id from public.gs_cafe_station_revision_dispatch_1232 d
 where d.station_key=v_station and d.status='queued'
 order by d.created_at,d.id for update skip locked limit 1;
 if v_id is null then return; end if;
 update public.gs_cafe_station_revision_dispatch_1232 d
 set status='unknown',dispatch_attempts=d.dispatch_attempts+1,
 lease_expires_at=now()+interval '90 seconds',last_error=null
 where d.id=v_id
 returning d.order_id,d.dispatch_attempts,d.lease_expires_at into v_order,v_attempt,v_lease;
 return query select v_id,v_order,v_station,v_attempt,v_lease;
end $$;
revoke all on function public.gs_1233_claim_revision_print(text) from public,anon,authenticated;
grant execute on function public.gs_1233_claim_revision_print(text) to service_role;

create or replace function public.gs_1233_resolve_revision_print(p_token_hash text,p_ticket_id bigint,p_attempt integer)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_station text; v_payload jsonb;
begin
 if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$' then raise exception 'Invalid session'; end if;
 v_station:=public.gs_1233_revision_device_station(p_token_hash);
 if v_station is null then raise exception 'Unauthorized station'; end if;
 select jsonb_build_object('ticket_id',d.id,'attempt',d.dispatch_attempts,
 'station',d.station_key,'order_id',d.order_id,'kind',e.kind,
 'note',e.reason,'items',e.items,'table_label','') into v_payload
 from public.gs_cafe_station_revision_dispatch_1232 d
 join public.gs_cafe_station_print_revision_events_1231 e on e.id=d.revision_event_id
 where d.id=p_ticket_id and d.station_key=v_station and e.station_key=v_station
 and d.dispatch_attempts=p_attempt and d.status='unknown' and d.lease_expires_at>now();
 if v_payload is null then raise exception 'Revision ticket unavailable'; end if;
 return v_payload;
end $$;
revoke all on function public.gs_1233_resolve_revision_print(text,bigint,integer) from public,anon,authenticated;
grant execute on function public.gs_1233_resolve_revision_print(text,bigint,integer) to service_role;

create or replace function public.gs_1233_ack_revision_print(
 p_token_hash text,p_ticket_id bigint,p_attempt integer,p_result text,p_error text default null)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_station text; v_ticket public.gs_cafe_station_revision_dispatch_1232%rowtype;
begin
 if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$'
 or p_result not in ('printed','failed','received') then raise exception 'Invalid acknowledgment'; end if;
 v_station:=public.gs_1233_revision_device_station(p_token_hash);
 if v_station is null then raise exception 'Unauthorized station'; end if;
 select * into v_ticket from public.gs_cafe_station_revision_dispatch_1232
 where id=p_ticket_id for update;
 if not found or v_ticket.station_key<>v_station or v_ticket.dispatch_attempts<>p_attempt
 then raise exception 'Revision ticket unavailable or stale'; end if;
 if v_ticket.status=p_result and p_result in ('printed','received') then return true; end if;
 if v_ticket.status<>'unknown' or v_ticket.lease_expires_at<=now()
 then raise exception 'Revision print requires manual review'; end if;
 update public.gs_cafe_station_revision_dispatch_1232 set status=p_result,
 lease_expires_at=null,acknowledged_at=case when p_result in ('printed','received') then now() else acknowledged_at end,
 last_error=case when p_result='failed' then left(coalesce(p_error,'Confirmed failure'),500) else null end
 where id=p_ticket_id;
 return true;
end $$;
revoke all on function public.gs_1233_ack_revision_print(text,bigint,integer,text,text) from public,anon,authenticated;
grant execute on function public.gs_1233_ack_revision_print(text,bigint,integer,text,text) to service_role;
-- 'unknown' is intentionally never automatically reset to queued.
