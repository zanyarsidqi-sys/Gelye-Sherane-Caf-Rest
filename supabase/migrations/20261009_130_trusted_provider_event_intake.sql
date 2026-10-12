-- Upgrade 130: server-only provider verification recording.
-- CALLER CONTRACT: invoke ONLY from a trusted backend AFTER verifying a
-- provider signature AND fetching transaction status from provider API.
-- Never expose a service-role key in Flutter, browser or a public webhook.
create or replace function public.gs_record_server_verified_payment_event(
 p_evidence_id bigint,p_provider text,p_event_id text,
 p_reference text,p_amount_iqd bigint,p_currency text default 'IQD'
) returns bigint
language plpgsql security definer set search_path='' as $$
declare v_evidence public.gs_external_payment_evidence%rowtype;
 v_existing public.gs_payment_verification_inbox%rowtype;
 v_id bigint;
begin
 if auth.role() is distinct from 'service_role' then
  raise exception 'Trusted backend only';
 end if;
 if p_evidence_id is null or p_provider is null or length(trim(p_provider))<2
    or p_event_id is null or length(trim(p_event_id))<4
    or p_reference is null or length(trim(p_reference))<4
    or p_amount_iqd is null or p_amount_iqd<=0 or p_currency<>'IQD' then
  raise exception 'Invalid verified payment event';
 end if;
 select * into v_evidence from public.gs_external_payment_evidence
  where id=p_evidence_id for update;
 if not found then raise exception 'Payment evidence not found';end if;
 if v_evidence.method not in ('card','online') then
  raise exception 'Provider event cannot verify credit or other payment methods';
 end if;
 if v_evidence.external_reference<>p_reference
    or v_evidence.amount_iqd<>p_amount_iqd then
  raise exception 'Provider event does not match expected payment evidence';
 end if;
 select * into v_existing from public.gs_payment_verification_inbox
  where provider=p_provider and provider_event_id=p_event_id for update;
 if found then
  if v_existing.evidence_id<>p_evidence_id
    or v_existing.provider_reference<>p_reference
    or v_existing.reported_amount_iqd<>p_amount_iqd
    or v_existing.reported_currency<>p_currency
    or v_existing.intake_status<>'verified_by_server' then
   raise exception 'Conflicting provider event replay';
  end if;
  return v_existing.id;
 end if;
 insert into public.gs_payment_verification_inbox(
  evidence_id,provider,provider_event_id,provider_reference,
  reported_amount_iqd,reported_currency,intake_status,verified_at)
 values(p_evidence_id,trim(p_provider),trim(p_event_id),p_reference,
  p_amount_iqd,p_currency,'verified_by_server',now())
 returning id into v_id;
 -- IMPORTANT: this is a trusted event record, not a payment ledger credit.
 -- Financial posting requires separate reconciliation, refund and duplicate
 -- transaction protections and remains disabled.
 return v_id;
end; $$;
revoke all on function public.gs_record_server_verified_payment_event(
 bigint,text,text,text,bigint,text) from public,anon,authenticated;
grant execute on function public.gs_record_server_verified_payment_event(
 bigint,text,text,text,bigint,text) to service_role;
