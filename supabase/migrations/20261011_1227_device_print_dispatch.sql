-- Upgrade 1227: device-scoped durable ticket claims and acknowledgments.
-- This is a server-side queue protocol, NOT physical printing.
-- Trusted Edge Function must hash bearer token and call as service_role.
create or replace function public.gs_1227_device_claim_print(
 p_token_hash text)
returns table(ticket_id bigint,order_id bigint,station_key text,attempt integer,lease_until timestamptz)
language plpgsql security definer set search_path='' as $$
declare v_station text; v_ticket bigint; v_order bigint; v_attempt integer; v_lease timestamptz;
begin
 if current_user <> 'service_role' then raise exception 'Service access required'; end if;
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

create or replace function public.gs_1227_device_ack_print(
 p_token_hash text,p_ticket_id bigint,p_attempt integer,p_result text,p_error text default null)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_station text; t public.gs_cafe_order_station_tickets%rowtype;
begin
 if current_user <> 'service_role' then raise exception 'Service access required'; end if;
 if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$'
    or p_result not in ('printed','failed','received') then
  raise exception 'Invalid acknowledgment'; end if;
 select a.station_key into v_station from public.gs_cafe_station_device_sessions s
 join public.gs_cafe_station_accounts a on a.station_key=s.station_key
 where s.token_hash=p_token_hash and s.revoked_at is null and s.expires_at>now()
   and s.credential_version=a.credential_version and a.enabled and a.allow_order_print;
 if v_station is null then raise exception 'Invalid device session'; end if;
 select * into t from public.gs_cafe_order_station_tickets
 where id=p_ticket_id for update;
 if not found or t.station_key<>v_station then raise exception 'Ticket unavailable'; end if;
 -- A stale or replayed acknowledgment must not overwrite a newer attempt.
 if t.dispatch_attempts<>p_attempt then raise exception 'Stale print attempt'; end if;
 if t.status=p_result and p_result in ('printed','received') then return true; end if;
 if t.status<>'unknown' then raise exception 'Ticket is not awaiting device result'; end if;
 update public.gs_cafe_order_station_tickets
 set status=p_result,lease_expires_at=null,
     acknowledged_at=case when p_result in ('printed','received') then now() else acknowledged_at end,
     last_error=case when p_result='failed' then left(coalesce(p_error,'Device failure'),500) else null end
 where id=p_ticket_id;
 return true;
end $$;
revoke all on function public.gs_1227_device_claim_print(text) from public,anon,authenticated;
revoke all on function public.gs_1227_device_ack_print(text,bigint,integer,text,text) from public,anon,authenticated;
grant execute on function public.gs_1227_device_claim_print(text) to service_role;
grant execute on function public.gs_1227_device_ack_print(text,bigint,integer,text,text) to service_role;
