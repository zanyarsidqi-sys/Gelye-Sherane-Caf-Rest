-- Upgrade 1468: executable staging-only smoke assertions.
-- Run AFTER applying all migrations on an isolated Supabase staging database.
-- No writes to financial tables. Transaction always rolls back.
begin;
do $$
declare v_oid oid; v_grant boolean;
begin
 select to_regprocedure('public.gs_financial_motel_invoice_settlement_readiness(uuid)') into v_oid;
 if v_oid is null then raise exception 'Missing settlement readiness RPC'; end if;
 select has_function_privilege('authenticated',v_oid,'EXECUTE') into v_grant;
 if not v_grant then raise exception 'Authenticated finance reviewer cannot execute readiness RPC'; end if;
 if has_function_privilege('anon',v_oid,'EXECUTE') then raise exception 'Anonymous execution allowed'; end if;
 if to_regclass('public.gs_motel_prepaid_verified_receipts') is null or
    to_regclass('public.gs_motel_prepaid_invoice_allocations') is null then
    raise exception 'Prepaid financial tables absent'; end if;
 if not (select relrowsecurity from pg_class where oid='public.gs_motel_prepaid_verified_receipts'::regclass) then
    raise exception 'Verified receipt RLS disabled'; end if;
 if has_table_privilege('authenticated','public.gs_motel_prepaid_verified_receipts','INSERT') then
    raise exception 'Client can forge verified provider receipt'; end if;
 raise notice 'Staging schema and grant smoke assertions passed (not transaction tests)';
end $$;
rollback;
