-- Run on staging after migration 165, not on production.
begin;
do $$
begin
 if to_regprocedure('public.gs_prepare_table_bill_transfer_approval(bigint)') is null
 then raise exception 'Approval preparation RPC missing'; end if;
 if has_function_privilege('anon',
 'public.gs_prepare_table_bill_transfer_approval(bigint)','EXECUTE')
 then raise exception 'Anonymous approval review access not revoked'; end if;
 if not has_function_privilege('authenticated',
 'public.gs_prepare_table_bill_transfer_approval(bigint)','EXECUTE')
 then raise exception 'Authenticated review RPC access missing'; end if;
 if position('false' in pg_get_functiondef(
 'public.gs_prepare_table_bill_transfer_approval(bigint)'::regprocedure))=0
 then raise exception 'Missing explicit no-execution result'; end if;
 raise notice 'PASS: approval preparation exists and never grants execution';
end $$;
rollback;
