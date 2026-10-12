-- Staging-only metadata tests for hardened transfer request endpoint.
-- Run via psql -v ON_ERROR_STOP=1 -f ... after migrations.
begin;
do $$
declare body text;
begin
 select pg_get_functiondef('public.gs_request_table_bill_transfer(bigint,bigint,bigint,integer,text,uuid)'::regprocedure)
 into body;
 if position('gs_unified_payment_ledger' in body)=0 then
  raise exception 'FAIL: transfer request missing unified ledger guard'; end if;
 if position('gs_external_payment_evidence' in body)=0 then
  raise exception 'FAIL: transfer request missing external evidence guard'; end if;
 if position('gs_cash_payments' in body)=0 then
  raise exception 'FAIL: transfer request missing cash guard'; end if;
 if position('gs_owner_guest_offers' in body)=0 then
  raise exception 'FAIL: transfer request missing owner offer guard'; end if;
 if position('gs_table_bill_transfer_request_items' in body)=0 then
  raise exception 'FAIL: transfer request missing duplicate item guard'; end if;
 if has_function_privilege('anon',
  'public.gs_request_table_bill_transfer(bigint,bigint,bigint,integer,text,uuid)','EXECUTE') then
  raise exception 'FAIL: anonymous role may submit transfer request'; end if;
 if has_function_privilege('authenticated',
  'public.gs_transfer_cafe_table(integer,integer)','EXECUTE') then
  raise exception 'FAIL: unsafe legacy table transfer still executable'; end if;
 raise notice 'PASS: hardened transfer request function and legacy RPC grants';
end $$;
rollback;
