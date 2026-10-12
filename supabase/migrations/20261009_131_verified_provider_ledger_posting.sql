-- Upgrade 131: ledger posting for independently verified provider events.
-- Trusted backend ONLY. Verification of signature and provider API success
-- MUST occur before Upgrade 130 intake. This is NOT a public webhook.
create or replace function public.gs_guard_payment_ledger_insert_provenance()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.posted_by is null or btrim(coalesce(new.source_system,''))=''
   or btrim(coalesce(new.source_reference,''))='' then
  raise exception 'Ledger posting attribution/source required';
 end if;
 if new.verified_at is null or new.verified_at>statement_timestamp()
    or new.posted_at is null or new.posted_at>statement_timestamp()
    or new.verified_at>new.posted_at then
  raise exception 'Invalid payment verification/posting timestamp';
 end if;
 if new.entry_type in ('card','online') then
  if auth.role() is distinct from 'service_role'
    or new.source_system<>'verified_provider_event'
    or not exists (
      select 1 from public.gs_payment_verification_inbox i
      join public.gs_external_payment_evidence e on e.id=i.evidence_id
      where i.id::text=new.source_reference
       and i.intake_status='verified_by_server'
       and i.verified_at=new.verified_at
       and e.order_id=new.order_id and e.method=new.entry_type
       and e.amount_iqd=new.amount_iqd
       and i.reported_amount_iqd=new.amount_iqd
       and i.reported_currency='IQD'
       and i.provider_reference=e.external_reference
       and new.direction='credit'
    ) then raise exception 'Unverified provider ledger posting prohibited';end if;
 elsif new.entry_type in ('credit','owner_waiver','refund','reversal') then
  raise exception 'Credit, owner waiver and refund posting not enabled';
 end if;
 return new;
end; $$;

create or replace function public.gs_post_verified_provider_payment(
 p_inbox_id bigint,p_posting_operator uuid)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_i public.gs_payment_verification_inbox%rowtype;
 v_e public.gs_external_payment_evidence%rowtype;
 v_id bigint;v_total bigint;v_paid bigint;v_cash bigint;
begin
 if auth.role() is distinct from 'service_role' then
  raise exception 'Trusted backend only';
 end if;
 if p_posting_operator is null or not exists(
  select 1 from auth.users where id=p_posting_operator) then
  raise exception 'Real posting operator required for audit';
 end if;
 select * into v_i from public.gs_payment_verification_inbox
  where id=p_inbox_id;
 if not found or v_i.intake_status<>'verified_by_server'
  or v_i.verified_at is null or v_i.reported_currency<>'IQD' then
  raise exception 'Event is not independently verified';
 end if;
 select * into v_e from public.gs_external_payment_evidence
  where id=v_i.evidence_id;
 if not found or v_e.method not in ('card','online')
  or v_e.amount_iqd<>v_i.reported_amount_iqd
  or v_e.external_reference<>v_i.provider_reference then
  raise exception 'Provider evidence mismatch';
 end if;
 -- Order-row lock serializes against all cooperating cash and ledger writers.
 perform 1 from public.gs_orders where id=v_e.order_id
   and status<>'cancelled' for update;
 if not found then raise exception 'Order not eligible for payment';end if;
 -- Re-read verified event under lock to prevent state drift.
 select * into v_i from public.gs_payment_verification_inbox
  where id=p_inbox_id for update;
 if v_i.intake_status<>'verified_by_server' then
  raise exception 'Provider verification withdrawn';end if;
 select id into v_id from public.gs_unified_payment_ledger
  where source_system='verified_provider_event'
    and source_reference=p_inbox_id::text;
 if found then
  if not exists(select 1 from public.gs_unified_payment_ledger
   where id=v_id and order_id=v_e.order_id and entry_type=v_e.method
    and amount_iqd=v_e.amount_iqd and direction='credit') then
   raise exception 'Conflicting provider posting replay';end if;
  return v_id;
 end if;
 select coalesce(sum(line_total_iqd),0)::bigint into v_total
  from public.gs_order_items where order_id=v_e.order_id;
 select coalesce(sum(amount_iqd),0)::bigint into v_cash
  from public.gs_cash_payments where order_id=v_e.order_id;
 select coalesce(sum(case when direction='credit' then amount_iqd else -amount_iqd end),0)::bigint
 into v_paid from public.gs_unified_payment_ledger l
 where l.order_id=v_e.order_id and not exists(
  select 1 from public.gs_cash_ledger_reconciliation_links x
  where x.ledger_entry_id=l.id);
 if v_total<=0 or v_cash+v_paid+v_e.amount_iqd>v_total then
  raise exception 'Provider posting would overpay order';
 end if;
 insert into public.gs_unified_payment_ledger(
  order_id,entry_type,amount_iqd,direction,source_system,
  source_reference,verified_at,posted_by)
 values(v_e.order_id,v_e.method,v_e.amount_iqd,'credit',
  'verified_provider_event',p_inbox_id::text,v_i.verified_at,p_posting_operator)
 returning id into v_id;
 return v_id;
end; $$;
revoke all on function public.gs_post_verified_provider_payment(bigint,uuid)
 from public,anon,authenticated;
grant execute on function public.gs_post_verified_provider_payment(bigint,uuid)
 to service_role;
