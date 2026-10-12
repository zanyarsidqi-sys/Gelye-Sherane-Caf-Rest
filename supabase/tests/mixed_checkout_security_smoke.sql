-- Upgrade 146: executable PostgreSQL security regression smoke tests.
-- Run ONLY on staging after migrations through 145. Read-only checks.
-- psql -v ON_ERROR_STOP=1 -f supabase/tests/mixed_checkout_security_smoke.sql
begin;
set local statement_timeout = '20s';
do $$
declare v integer; v_def text;
begin
 if to_regclass('public.gs_mixed_checkout_feature_gate') is null then
  raise exception 'FAIL: checkout feature gate missing';
 end if;
 if exists(select 1 from public.gs_mixed_checkout_feature_gate where enabled) then
  raise exception 'FAIL: mixed checkout feature enabled';
 end if;
 if to_regprocedure('public.gs_post_verified_provider_payment(bigint,uuid)') is null
 or to_regprocedure('public.gs_record_server_verified_payment_event(bigint,text,text,text,bigint,text)') is null then
  raise exception 'FAIL: trusted verification/posting functions missing';
 end if;
 if has_function_privilege('authenticated',
  'public.gs_post_verified_provider_payment(bigint,uuid)','EXECUTE') then
  raise exception 'FAIL: authenticated can invoke trusted posting';
 end if;
 if has_function_privilege('anon',
  'public.gs_post_verified_provider_payment(bigint,uuid)','EXECUTE') then
  raise exception 'FAIL: anon can invoke trusted posting';
 end if;
 if has_function_privilege('authenticated',
  'public.gs_record_server_verified_payment_event(bigint,text,text,text,bigint,text)','EXECUTE') then
  raise exception 'FAIL: authenticated can mark provider event verified';
 end if;
 if has_table_privilege('authenticated',
  'public.gs_mixed_payment_settlement_attestations','INSERT') then
  raise exception 'FAIL: client can insert finance attestation';
 end if;
 if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname='gs_mixed_payment_settlement_attestations'
  and c.relrowsecurity) then
  raise exception 'FAIL: mixed attestation RLS missing';
 end if;
 select count(*) into v from pg_trigger t join pg_class c on c.oid=t.tgrelid
 join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relname='gs_mixed_payment_settlement_attestations'
 and t.tgname in ('gs_mixed_settlement_immutable',
 'gs_reject_conflicting_mixed_attestation') and t.tgenabled<>'D';
 if v<>2 then raise exception 'FAIL: missing mixed attestation triggers: %',v;end if;
 select count(*) into v from pg_trigger t join pg_class c on c.oid=t.tgrelid
 join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relname='gs_cash_only_settlement_attestations'
 and t.tgname='gs_reject_conflicting_cash_attestation' and t.tgenabled<>'D';
 if v<>1 then raise exception 'FAIL: cash attestation conflict guard missing';end if;
 select pg_get_functiondef('public.gs_release_mixed_payment_table_visit(bigint)'::regprocedure)
 into v_def;
 if position('gs_mixed_checkout_feature_gate' in v_def)=0 then
  raise exception 'FAIL: mixed release function lacks feature gate';
 end if;
 raise notice 'PASS: 10 staging database security assertions';
end $$;
rollback;
