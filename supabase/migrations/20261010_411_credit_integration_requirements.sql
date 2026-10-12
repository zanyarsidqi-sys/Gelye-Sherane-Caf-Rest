-- Upgrade 411: fail-closed authoritative account integration requirements.
-- The project has no authoritative customer credit ledger yet.
create or replace function public.gs_staff_motel_credit_integration_requirements()
returns table(requirement text, implementation_status text, implementation_detail text)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or
 not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 return query values
 ('customer_account_authority'::text,'not_implemented'::text,
  'Identify a real customer credit account keyed by verified customer identity'),
 ('barcode_to_account_binding','not_implemented',
  'Barcode registry alone does not prove account ownership'),
 ('balance_and_credit_limit','not_implemented',
  'Available balance and limit must come from authoritative locked account records'),
 ('customer_authorization','not_implemented',
  'Require recorded consent for the exact charge amount and invoice'),
 ('idempotent_atomic_debit','not_implemented',
  'Use a unique charge key and single transaction with balance and limit validation'),
 ('reversal_and_reconciliation','not_implemented',
  'Support safe refunds and match every charge to ledger entries'),
 ('credit_settlement','blocked',
  'No credit invoice may be marked paid without all verified requirements');
end $$;
revoke all on function public.gs_staff_motel_credit_integration_requirements() from public,anon;
grant execute on function public.gs_staff_motel_credit_integration_requirements() to authenticated;
