-- Executable read-only staging smoke test; run after applying migrations.
-- Execute as a privileged staging SQL operator. No production financial mutations.
begin;
do $$ begin
 if to_regprocedure('public.gs_financial_motel_invoice_evidence_status(uuid)') is null then
   raise exception 'Missing invoice evidence function'; end if;
 if to_regprocedure('public.gs_financial_motel_invoice_settlement_readiness(uuid)') is null then
   raise exception 'Missing readiness function'; end if;
 if has_function_privilege('anon','public.gs_financial_motel_invoice_settlement_readiness(uuid)','EXECUTE') then
   raise exception 'Anonymous execution must be denied'; end if;
 if not has_function_privilege('authenticated','public.gs_financial_motel_invoice_settlement_readiness(uuid)','EXECUTE') then
   raise exception 'Authenticated review grant missing'; end if;
 if not exists(select 1 from pg_class where oid='public.gs_motel_prepaid_verified_receipts'::regclass and relrowsecurity) then
   raise exception 'Receipt RLS disabled'; end if;
 if not exists(select 1 from pg_class where oid='public.gs_motel_prepaid_invoice_allocations'::regclass and relrowsecurity) then
   raise exception 'Allocation RLS disabled'; end if;
end $$;
rollback;
