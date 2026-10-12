-- Dashboard Upgrade 53: READ-ONLY visit-linked cash reconciliation DRAFT.
-- This deliberately does NOT claim full settlement or confirm noncash payments.
-- Requires 051 visit/session foundation, 021 cash ledger and order items.
create or replace function public.gs_dashboard_visit_cash_reconciliation(p_visit_id bigint)
returns table (
 visit_id bigint, order_id bigint, order_status text,
 order_total_iqd bigint, recorded_cash_iqd bigint,
 cash_remaining_iqd bigint, cash_reconciliation_status text
)
language plpgsql stable security definer set search_path = ''
as $$
begin
 if auth.uid() is null or not (
   public.gs_can_access('invoices_payments','can_view')
   or public.gs_can_access('payments_management','can_view')
 ) then
   raise exception 'Visit payment reconciliation access denied';
 end if;
 if p_visit_id is null or not exists (
   select 1 from public.gs_table_visits v where v.id=p_visit_id
 ) then raise exception 'Visit not found'; end if;
 return query
 select p_visit_id, o.id, o.status::text,
   coalesce(t.total,0)::bigint,
   coalesce(c.cash_paid,0)::bigint,
   greatest(coalesce(t.total,0)-coalesce(c.cash_paid,0),0)::bigint,
   case
     when o.status='cancelled' then 'cancelled_requires_review'
     when coalesce(t.total,0)<=0 then 'no_charge_or_unpriced'
     when coalesce(c.cash_paid,0)=0 then 'no_cash_recorded_non_cash_unknown'
     when c.cash_paid<t.total then 'partially_paid_in_cash_non_cash_unknown'
     when c.cash_paid=t.total then 'cash_covers_order_verify_other_methods'
     else 'cash_overpayment_investigate'
   end::text
 from public.gs_orders o
 left join lateral (
   select sum(i.line_total_iqd)::bigint as total
   from public.gs_order_items i where i.order_id=o.id
 ) t on true
 left join lateral (
   select sum(p.amount_iqd)::bigint as cash_paid
   from public.gs_cash_payments p where p.order_id=o.id
 ) c on true
 where o.table_visit_id=p_visit_id
 order by o.id;
end; $$;
revoke all on function public.gs_dashboard_visit_cash_reconciliation(bigint)
 from public,anon;
grant execute on function public.gs_dashboard_visit_cash_reconciliation(bigint)
 to authenticated;

-- Future unified settlement must use a single authoritative, idempotent
-- transaction ledger for cash/card/online/credit/owner-approved waivers,
-- prevent overpayment under row locks, and verify external receipts server-side.
-- This RPC is NOT a payment gate for checkout/table release.
