-- Upgrade 1249: close station review replay disclosure and station revision RPC exposure.
-- Station device RPCs are exclusively invoked by trusted Edge Functions using
-- service_role. Do not grant these to anon/authenticated clients.
DO $guard$
DECLARE v_oid oid;
BEGIN
 FOR v_oid IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname IN (
   'gs_1233_claim_revision_print','gs_1233_resolve_revision_print',
   'gs_1233_ack_revision_print')
 LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated',v_oid::regprocedure);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',v_oid::regprocedure);
 END LOOP;
END $guard$;

create or replace function public.gs_1237_review_print_ticket(
 p_queue_kind text,p_ticket_id bigint,p_attempt integer,
 p_decision text,p_explanation text,p_request_key uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_station text; v_status text; v_attempt integer;
 v_lease timestamptz; v_previous public.gs_cafe_print_review_audit_1237%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') or
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
  -- Re-check CURRENT station membership on retries: old request keys must
  -- not disclose prior reviews after a supervisor loses access.
  if not exists(select 1 from public.gs_cafe_station_supervisors s
     where s.employee_id=auth.uid() and s.active
       and s.station_key=v_previous.station_key) then
    raise exception 'Station supervisor authorization required';
  end if;
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

-- No change to financial totals, ticket retry rules or existing invoice rows.
