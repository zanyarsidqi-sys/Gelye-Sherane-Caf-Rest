-- Upgrade 1255: protect device session boundaries and expired print leases.
-- Revision RPCs run only through the trusted station-device-auth Edge Function.
-- No ticket is automatically requeued and no invoice/payment is modified.
-- Must be applied after migrations 1227, 1233, 1237, 1246, 1248 and 1254.

create or replace function public.gs_1233_revision_device_station(p_hash text)
returns text language sql stable security definer set search_path='' as $$
 select a.station_key from public.gs_cafe_station_device_sessions s
 join public.gs_cafe_station_accounts a on a.station_key=s.station_key
 where auth.role()='service_role' and s.token_hash=p_hash and s.revoked_at is null and s.expires_at>now()
 and s.credential_version=a.credential_version and a.enabled and a.allow_order_print
 and s.last_seen_at>now()-interval '2 minutes' limit 1;
$$;

create or replace function public.gs_1233_claim_revision_print(p_token_hash text)
returns table(ticket_id bigint,order_id bigint,station_key text,attempt integer,lease_until timestamptz)
language plpgsql security definer set search_path='' as $$
declare v_station text; v_id bigint; v_order bigint; v_attempt integer; v_lease timestamptz;
begin
 if auth.role() IS DISTINCT FROM 'service_role' then raise exception 'Service access required'; end if;
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

create or replace function public.gs_1233_resolve_revision_print(p_token_hash text,p_ticket_id bigint,p_attempt integer)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_station text; v_payload jsonb;
begin
 if auth.role() IS DISTINCT FROM 'service_role' then raise exception 'Service access required'; end if;
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

create or replace function public.gs_1233_ack_revision_print(
 p_token_hash text,p_ticket_id bigint,p_attempt integer,p_result text,p_error text default null)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_station text; v_ticket public.gs_cafe_station_revision_dispatch_1232%rowtype;
begin
 if auth.role() IS DISTINCT FROM 'service_role' then raise exception 'Service access required'; end if;
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
 if t.status<>'unknown' or t.lease_expires_at is null or t.lease_expires_at<=now() then
  raise exception 'Print attempt expired or requires supervisor review'; end if;
 update public.gs_cafe_order_station_tickets
 set status=p_result,lease_expires_at=null,
     acknowledged_at=case when p_result in ('printed','received') then now() else acknowledged_at end,
     last_error=case when p_result='failed' then left(coalesce(p_error,'Device failure'),500) else null end
 where id=p_ticket_id;
 return true;
end $$;

create or replace function public.gs_1237_review_print_ticket(
 p_queue_kind text,p_ticket_id bigint,p_attempt integer,
 p_decision text,p_explanation text,p_request_key uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_station text; v_status text; v_attempt integer;
 v_lease timestamptz; v_previous public.gs_cafe_print_review_audit_1237%rowtype;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'aal','')<>'aal2' or not public.gs_can_access('kitchen','can_edit') or
    not exists(select 1 from public.gs_cafe_station_supervisors s
               where s.employee_id=auth.uid() and s.active) then
  raise exception 'Station supervisor authorization required';
 end if;
 if p_queue_kind not in ('original','revision') or p_ticket_id is null or p_ticket_id<1
    or p_attempt is null or p_attempt<1
    or p_decision not in ('confirmed_printed','confirmed_not_printed')
    or p_request_key is null or length(trim(coalesce(p_explanation,''))) not between 10 and 1000 then
  raise exception 'Invalid print review request';
 end if;
 -- Idempotent repeats are permitted ONLY for an identical review.
 select * into v_previous from public.gs_cafe_print_review_audit_1237
 where request_key=p_request_key;
 if found then
  if v_previous.queue_kind<>p_queue_kind or v_previous.ticket_id<>p_ticket_id
     or v_previous.attempt<>p_attempt or v_previous.decision<>p_decision
     or v_previous.explanation<>trim(p_explanation) or v_previous.reviewed_by<>auth.uid() then
    raise exception 'Review request key reused with different content';
  end if;
  if not public.gs_1246_can_manage_station(v_previous.station_key) and not exists (
    select 1 from public.gs_cafe_station_supervisors s
    where s.employee_id=auth.uid() and s.active and s.station_key=v_previous.station_key
  ) then raise exception 'Station review permission revoked'; end if;
  return jsonb_build_object('status','already_reviewed','audit_id',v_previous.id);
 end if;
 if p_queue_kind='original' then
  select t.station_key,t.status,t.dispatch_attempts,t.lease_expires_at
    into v_station,v_status,v_attempt,v_lease
  from public.gs_cafe_order_station_tickets t where t.id=p_ticket_id for update;
 else
  select t.station_key,t.status,t.dispatch_attempts,t.lease_expires_at
    into v_station,v_status,v_attempt,v_lease
  from public.gs_cafe_station_revision_dispatch_1232 t where t.id=p_ticket_id for update;
 end if;
 if v_station is null then raise exception 'Ticket unavailable'; end if;
 -- Only a supervisor assigned to THIS station may resolve the uncertainty.
 if not exists(select 1 from public.gs_cafe_station_supervisors s
    where s.employee_id=auth.uid() and s.active and s.station_key=v_station) then
  raise exception 'Not supervisor for ticket station';
 end if;
 if v_status<>'unknown' or v_attempt<>p_attempt then
  raise exception 'Ticket is not awaiting review for this attempt';
 end if;
 -- Do not race a still-active device print attempt. Wait for lease expiry.
 if v_lease is not null and v_lease>now() then
  raise exception 'Print attempt still active; review after lease expires';
 end if;
 insert into public.gs_cafe_print_review_audit_1237
 (queue_kind,ticket_id,station_key,attempt,prior_status,decision,explanation,reviewed_by,request_key)
 values(p_queue_kind,p_ticket_id,v_station,p_attempt,v_status,p_decision,trim(p_explanation),auth.uid(),p_request_key);
 if p_queue_kind='original' then
  update public.gs_cafe_order_station_tickets
  set status=case when p_decision='confirmed_printed' then 'printed' else 'failed' end,
      lease_expires_at=null,
      acknowledged_at=case when p_decision='confirmed_printed' then now() else acknowledged_at end,
      last_error=case when p_decision='confirmed_not_printed' then 'Supervisor confirmed not printed; explicit new print request required' else null end
  where id=p_ticket_id and status='unknown' and dispatch_attempts=p_attempt;
 else
  update public.gs_cafe_station_revision_dispatch_1232
  set status=case when p_decision='confirmed_printed' then 'printed' else 'failed' end,
      lease_expires_at=null,
      acknowledged_at=case when p_decision='confirmed_printed' then now() else acknowledged_at end,
      last_error=case when p_decision='confirmed_not_printed' then 'Supervisor confirmed not printed; explicit new print request required' else null end
  where id=p_ticket_id and status='unknown' and dispatch_attempts=p_attempt;
 end if;
 return jsonb_build_object('status','reviewed','queue_kind',p_queue_kind,
  'ticket_id',p_ticket_id,'result',p_decision);
end $$;

DO $permissions$
DECLARE v_signature text;
BEGIN
 FOR v_signature IN SELECT p.oid::regprocedure::text
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname IN
 ('gs_1233_revision_device_station','gs_1233_claim_revision_print',
  'gs_1233_resolve_revision_print','gs_1233_ack_revision_print',
  'gs_1227_device_ack_print')
 LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated',v_signature);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',v_signature);
 END LOOP;
END $permissions$;

REVOKE ALL ON FUNCTION public.gs_1237_review_print_ticket(text,bigint,integer,text,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gs_1237_review_print_ticket(text,bigint,integer,text,text,uuid) TO authenticated;
