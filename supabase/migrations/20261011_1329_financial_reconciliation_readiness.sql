-- Read-only schema readiness diagnostic. This does NOT calculate unpaid money.
-- SECURITY: only authenticated staff with payments_management view permission.
-- Checks schema availability, not actual financial reconciliation or migration deployment.
create or replace function public.gs_financial_reconciliation_readiness()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null
     or not coalesce(public.gs_can_access('payments_management','can_view'), false) then
    raise exception 'Payments Management viewing permission required' using errcode='42501';
  end if;
  return jsonb_build_object(
    'verified_complete', false,
    'source_tables', jsonb_build_object(
      'orders', to_regclass('public.gs_orders') is not null,
      'order_items', to_regclass('public.gs_order_items') is not null,
      'table_visits', to_regclass('public.gs_table_visits') is not null,
      'cafe_tables', to_regclass('public.gs_cafe_tables') is not null,
      'cash_payments', to_regclass('public.gs_cash_payments') is not null,
      'motel_requests', to_regclass('public.gs_motel_guest_food_requests') is not null,
      'motel_finance_invoices', to_regclass('public.gs_motel_food_finance_invoices') is not null
    ),
    'missing_settlement_guarantees', jsonb_build_array(
      'canonical_all_method_payment_allocations',
      'order_to_active_visit_binding',
      'online_and_motel_source_deduplication',
      'prepaid_motel_invoice_settlement',
      'refund_transfer_comp_adjustments'
    ),
    'generated_at', now()
  );
end; $$;
revoke all on function public.gs_financial_reconciliation_readiness() from public, anon;
grant execute on function public.gs_financial_reconciliation_readiness() to authenticated;
