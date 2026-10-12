-- Upgrade 163: disable legacy table transfer that bypasses visit/ledger controls.
-- The 024-era function changes order destinations and table occupancy without
-- migrating visit ownership, settled payment allocations or reservation links.
-- Never allow this unsafe legacy route while guarded transfer is under development.
create or replace function public.gs_transfer_cafe_table(p_from integer, p_to integer)
returns integer
language plpgsql security invoker set search_path='' as $$
begin
 raise exception using
  errcode='P0001',
  message='Legacy table transfer disabled: use audited guest movement requests. Financial order/bill transfer is not yet enabled.';
end; $$;
revoke all on function public.gs_transfer_cafe_table(integer,integer)
 from public,anon,authenticated;
-- No execute grants: legacy RPC is unavailable to ordinary clients.

-- Verify the legacy RPC cannot be called by a client and the guarded
-- bill transfer execution function still rejects execution.
-- These assertions are metadata-only, safe for deployment.
do $$
begin
 if has_function_privilege('authenticated',
   'public.gs_transfer_cafe_table(integer,integer)','EXECUTE') then
   raise exception 'Unsafe legacy table transfer still callable by authenticated';
 end if;
 if has_function_privilege('anon',
   'public.gs_transfer_cafe_table(integer,integer)','EXECUTE') then
   raise exception 'Unsafe legacy table transfer still callable by anon';
 end if;
end $$;
