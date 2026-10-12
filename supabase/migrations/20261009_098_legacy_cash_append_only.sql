-- Upgrade 98: protect every legacy cash receipt from mutation, not only matched ones.
-- Upgrade 83 protected matched receipts. Unmatched receipts are equally important
-- for accurate customer balances and should never be silently rewritten.
create or replace function public.gs_reject_cash_receipt_mutation()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 raise exception using errcode='P0001',
  message='Cash receipts are append-only. Use an authorized, audited correction workflow.';
end; $$;
revoke all on function public.gs_reject_cash_receipt_mutation()
 from public,anon,authenticated;
drop trigger if exists gs_reject_cash_receipt_mutation on public.gs_cash_payments;
create trigger gs_reject_cash_receipt_mutation
 before update or delete on public.gs_cash_payments
 for each row execute function public.gs_reject_cash_receipt_mutation();

-- The legacy cash collection function may still record new receipts; this
-- guard DOES NOT certify physical collection, settle a bill or release a table.
-- Corrections, chargebacks, and refunds need a separate, reviewed posting API.
