-- Upgrade 147: executable negative-path security tests, STAGING ONLY.
-- Run after all migrations: psql -v ON_ERROR_STOP=1 -f supabase/tests/mixed_checkout_negative_paths.sql
-- Entire test runs inside a rolled-back transaction; no checkout state changes.
begin;
set local statement_timeout='20s';
do $$
declare v_gate boolean;v_count bigint;
begin
 select enabled into v_gate from public.gs_mixed_checkout_feature_gate where singleton=true;
 if v_gate is distinct from false then
  raise exception 'FAIL: mixed checkout release gate must be explicitly disabled';
 end if;
 select count(*) into v_count from public.gs_cash_only_settlement_attestations c
 join public.gs_mixed_payment_settlement_attestations m on m.order_id=c.order_id;
 if v_count<>0 then raise exception 'FAIL: % contradictory attestations exist',v_count;end if;
 if not exists(select 1 from pg_indexes where schemaname='public'
  and indexname='gs_verified_provider_transaction_once') then
  raise exception 'FAIL: provider transaction deduplication index absent';
 end if;
 if not exists(select 1 from pg_indexes where schemaname='public'
  and indexname='gs_verified_provider_event_ledger_once') then
  raise exception 'FAIL: provider ledger deduplication index absent';
 end if;
 raise notice 'PASS: disabled release gate, no contradictory attestations, provider dedup indexes';
end $$;
-- Simulate a public client: no real JWT or identity is required to confirm
-- that the trusted posting and verification RPCs cannot be invoked.
set local role authenticated;
do $$
declare v_state text;
begin
 begin
  perform public.gs_post_verified_provider_payment(-999999,null);
  raise exception 'FAIL: authenticated invoked trusted ledger posting';
 exception when insufficient_privilege then
  raise notice 'PASS: authenticated cannot execute trusted ledger posting';
 end;
 begin
  perform public.gs_record_server_verified_payment_event(
   -999999,'test','test-event','test-reference',1000,'IQD');
  raise exception 'FAIL: authenticated invoked trusted event verification';
 exception when insufficient_privilege then
  raise notice 'PASS: authenticated cannot execute trusted event verification';
 end;
 begin
  perform enabled from public.gs_mixed_checkout_feature_gate limit 1;
  raise exception 'FAIL: authenticated read private checkout feature gate';
 exception when insufficient_privilege then
  raise notice 'PASS: authenticated cannot read private checkout feature gate';
 end;
end $$;
reset role;
rollback;
