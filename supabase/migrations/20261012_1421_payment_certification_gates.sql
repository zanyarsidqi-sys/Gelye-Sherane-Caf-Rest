-- Read-only, permission-scoped certification blockers for the two unpaid Dashboard cards.
-- These gates are NOT certified by the presence of a table or migration.
-- No totals are exposed and no payment state is modified.
create or replace function public.gs_financial_unpaid_certification_gates()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null or
     not coalesce(public.gs_can_access('payments_management','can_view'), false) then
    raise exception 'Payments Management viewing permission required' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'verified_complete', false,
    'standing_cash_active_visits_iqd', null,
    'pending_online_motel_unpaid_iqd', null,
    'status', 'settlement_certification_blocked',
    'certification_gates', jsonb_build_array(
      jsonb_build_object('id', 'active_visit_identity', 'verified', false, 'reason', 'Each occupied table order must bind to one active visit'),
      jsonb_build_object('id', 'departed_visit_exclusion', 'verified', false, 'reason', 'Departed visits must be excluded from Standing Cash'),
      jsonb_build_object('id', 'cash_allocation_identity', 'verified', false, 'reason', 'Cash settlements must link to exact orders'),
      jsonb_build_object('id', 'credit_allocation_identity', 'verified', false, 'reason', 'Credit debits must link to exact orders'),
      jsonb_build_object('id', 'mixed_partial_allocation', 'verified', false, 'reason', 'Mixed and partial payments must reconcile without double count'),
      jsonb_build_object('id', 'prepaid_motel_coverage', 'verified', false, 'reason', 'Prepaid motel package value must be allocated once'),
      jsonb_build_object('id', 'online_motel_disjointness', 'verified', false, 'reason', 'Online and motel orders must not overlap active-table balances'),
      jsonb_build_object('id', 'refund_reversal_identity', 'verified', false, 'reason', 'Refunds and reversals must reference original settlements'),
      jsonb_build_object('id', 'cancel_transfer_comp_integrity', 'verified', false, 'reason', 'Cancelled, transferred and complimentary orders must reconcile'),
      jsonb_build_object('id', 'complete_source_pagination', 'verified', false, 'reason', 'All relevant sources must be complete beyond pagination limits')
    ),
    'generated_at', now()
  );
end; $$;
revoke all on function public.gs_financial_unpaid_certification_gates() from public, anon;
grant execute on function public.gs_financial_unpaid_certification_gates() to authenticated;
