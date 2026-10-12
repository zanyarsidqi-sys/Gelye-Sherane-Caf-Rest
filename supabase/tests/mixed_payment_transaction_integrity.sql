-- Upgrade 148: staging-only real-data transaction integrity assertions.
-- Run after migrations, with staging fixtures, using psql -v ON_ERROR_STOP=1.
-- Does not create/modify orders, payments, ledgers, or checkout state.
begin;
set local statement_timeout='30s';
do $$
declare v_count bigint;
begin
 -- One provider transaction may produce multiple webhook events but at most
 -- one VERIFIED inbox row and at most one posted ledger credit.
 select count(*) into v_count from (
  select provider,provider_reference from public.gs_payment_verification_inbox
  where intake_status='verified_by_server'
  group by provider,provider_reference having count(*)>1
 ) d;
 if v_count>0 then raise exception 'FAIL: % duplicate verified provider transactions',v_count;end if;
 raise notice 'PASS: verified provider transaction references unique';

 select count(*) into v_count from (
  select source_system,source_reference from public.gs_unified_payment_ledger
  where source_system='verified_provider_event'
  group by source_system,source_reference having count(*)>1
 ) d;
 if v_count>0 then raise exception 'FAIL: % duplicate provider ledger sources',v_count;end if;
 raise notice 'PASS: provider ledger event idempotency';

 select count(*) into v_count
 from public.gs_unified_payment_ledger l
 where l.source_system='verified_provider_event'
 and not exists (
  select 1 from public.gs_payment_verification_inbox i
  join public.gs_external_payment_evidence e on e.id=i.evidence_id
  where i.id::text=l.source_reference
   and i.intake_status='verified_by_server'
   and i.verified_at=l.verified_at and i.reported_currency='IQD'
   and i.reported_amount_iqd=l.amount_iqd
   and i.provider_reference=e.external_reference
   and e.order_id=l.order_id and e.method=l.entry_type
   and e.amount_iqd=l.amount_iqd and l.direction='credit'
 );
 if v_count>0 then raise exception 'FAIL: % unmatched provider ledger postings',v_count;end if;
 raise notice 'PASS: every posted provider credit matches verified evidence';

 select count(*) into v_count
 from public.gs_mixed_payment_settlement_attestations a
 where a.order_total_iqd<>a.cash_iqd+a.verified_provider_iqd
  or a.provider_payment_count<1
  or a.verified_provider_iqd<=0;
 if v_count>0 then raise exception 'FAIL: % malformed mixed attestations',v_count;end if;
 raise notice 'PASS: mixed settlement arithmetic';

 select count(*) into v_count
 from public.gs_mixed_payment_settlement_attestations a
 where a.order_total_iqd<>coalesce((
  select sum(line_total_iqd)::bigint from public.gs_order_items
  where order_id=a.order_id),0);
 if v_count>0 then raise exception 'FAIL: % mixed attestations have changed order totals',v_count;end if;
 raise notice 'PASS: mixed settlement order totals unchanged';

 select count(*) into v_count
 from public.gs_mixed_payment_settlement_attestations a
 where a.cash_iqd<>coalesce((
  select sum(amount_iqd)::bigint from public.gs_cash_payments
  where order_id=a.order_id),0);
 if v_count>0 then raise exception 'FAIL: % mixed attestations have changed cash receipts',v_count;end if;
 raise notice 'PASS: mixed settlement cash receipts unchanged';

 select count(*) into v_count
 from public.gs_mixed_payment_settlement_attestations a
 where a.verified_provider_iqd<>coalesce((
  select sum(l.amount_iqd)::bigint
  from public.gs_unified_payment_ledger l
  join public.gs_payment_verification_inbox i
   on l.source_system='verified_provider_event'
   and l.source_reference=i.id::text
  join public.gs_external_payment_evidence e on e.id=i.evidence_id
  where l.order_id=a.order_id and e.order_id=a.order_id
   and i.intake_status='verified_by_server'
   and l.entry_type=e.method and l.direction='credit'
   and l.verified_at=i.verified_at and i.reported_currency='IQD'
   and l.amount_iqd=i.reported_amount_iqd
   and l.amount_iqd=e.amount_iqd
   and i.provider_reference=e.external_reference),0);
 if v_count>0 then raise exception 'FAIL: % mixed attestations have changed provider credits',v_count;end if;
 raise notice 'PASS: mixed settlement verified provider credits unchanged';

 if exists(select 1 from public.gs_mixed_checkout_feature_gate where enabled)
 then raise exception 'FAIL: mixed checkout release gate enabled before integration tests';end if;
 raise notice 'PASS: mixed checkout release remains disabled';
end $$;
rollback;
