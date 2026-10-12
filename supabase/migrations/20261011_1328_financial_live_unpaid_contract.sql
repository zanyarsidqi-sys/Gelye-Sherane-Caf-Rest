-- Financial live unpaid reporting: deliberately fail closed until ledger completeness is proven.
-- This migration is deployable independently and never invents an amount.
-- Schema review: gs_orders / gs_order_items / gs_cash_payments exist, as do
-- gs_table_visits and gs_motel_guest_food_requests in later migrations.
-- HOWEVER cash-only settlement cannot establish outstanding multi-method balances,
-- and online/motel requests can overlap posted invoices or prepaid packages.
-- A reliable complete result requires canonical invoice/payment allocations,
-- source disjointness, refunds, cancellations and visit presence validation.
create or replace function public.gs_financial_live_unpaid_balances()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
begin
  if (select auth.uid()) is null
    or not coalesce(public.gs_can_access('payments_management','can_view'),false) then
    raise exception 'Payments Management viewing permission required' using errcode = '42501';
  end if;
  -- Do not expose a misleading partial sum as a complete monetary balance.
  return jsonb_build_object(
    'verified_complete', false,
    'standing_cash_active_visits_iqd', null,
    'pending_online_motel_unpaid_iqd', null,
    'status', 'requires_canonical_settlement_reconciliation',
    'required_checks', jsonb_build_array(
      'active_visit_and_occupied_table_binding',
      'all_payment_methods_and_partial_allocations',
      'online_motel_source_deduplication',
      'prepaid_packages_and_invoice_posting',
      'refund_cancel_transfer_and_comp_adjustments'
    ),
    'generated_at', now()
  );
end;
$$;
revoke all on function public.gs_financial_live_unpaid_balances() from public, anon;
grant execute on function public.gs_financial_live_unpaid_balances() to authenticated;
