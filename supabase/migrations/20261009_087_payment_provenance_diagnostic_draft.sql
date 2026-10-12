-- Upgrade 87: payment provenance and verification-readiness diagnostic.
-- This is NOT provider verification, settlement confirmation, or a posting API.
create or replace function public.gs_dashboard_payment_provenance(p_order_id bigint)
returns table (
 ledger_entry_id bigint, entry_type text, amount_iqd bigint,
 source_system text, source_reference text, verified_at timestamptz,
 posted_at timestamptz, posted_by uuid, source_link_count bigint,
 provenance_status text, settlement_usable boolean
)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (
   public.gs_can_access('invoices_payments','can_view') or
   public.gs_can_access('payments_management','can_view')
 ) then raise exception 'Financial provenance inspection denied'; end if;
 if p_order_id is null or not exists (
   select 1 from public.gs_orders o where o.id=p_order_id
 ) then raise exception 'Order not found'; end if;
 return query
 select l.id,l.entry_type,l.amount_iqd,l.source_system,l.source_reference,
   l.verified_at,l.posted_at,l.posted_by,
   (select count(*)::bigint from public.gs_cash_ledger_reconciliation_links x
    where x.ledger_entry_id=l.id),
   case
    when l.verified_at>now() then 'verification_timestamp_in_future'
    when l.verified_at>l.posted_at then 'verification_after_posting'
    when length(btrim(l.source_system))=0 or length(btrim(l.source_reference))=0
      then 'missing_payment_provenance'
    when l.posted_by is null then 'missing_posting_actor'
    when l.entry_type='cash' and l.source_system='legacy_cash' and not exists (
      select 1 from public.gs_cash_ledger_reconciliation_links x
      where x.ledger_entry_id=l.id
    ) then 'legacy_cash_not_reconciled'
    when l.entry_type in ('card','online','credit') then
      'external_or_credit_provider_not_independently_verified'
    when l.entry_type='owner_waiver' then 'owner_waiver_posting_not_certified'
    when l.entry_type in ('refund','reversal') then 'refund_execution_not_provider_verified'
    else 'provenance_fields_present_not_settlement_certified'
   end::text,
   false
 from public.gs_unified_payment_ledger l
 where l.order_id=p_order_id
 order by l.posted_at,l.id;
end; $$;
revoke all on function public.gs_dashboard_payment_provenance(bigint)
 from public,anon;
grant execute on function public.gs_dashboard_payment_provenance(bigint)
 to authenticated;
-- Intentionally always settlement_usable=false. A timestamp or ledger row
-- is never proof of a payment-provider-confirmed transaction.
