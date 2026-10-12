-- Upgrade 89: conservative payment reconciliation summary (READ ONLY).
-- Never add a reconciled legacy cash receipt and its mirrored ledger entry.
-- Unlinked records remain provisional; this RPC NEVER certifies settlement.
create or replace function public.gs_dashboard_payment_reconciliation_summary(p_order_id bigint)
returns table(
 order_id bigint, order_total_iqd bigint, legacy_cash_iqd bigint,
 matched_cash_iqd bigint, unlinked_cash_iqd bigint,
 nonmirrored_ledger_net_iqd bigint, provisional_net_iqd bigint,
 apparent_remaining_iqd bigint, reconciliation_exceptions bigint,
 settlement_confirmed boolean, transfer_allowed boolean, warning text
)
language plpgsql stable security definer set search_path='' as $$
declare
 v_total bigint;v_cash bigint;v_matched bigint;v_unlinked bigint;
 v_ledger bigint;v_exceptions bigint;v_provisional bigint;
begin
 if auth.uid() is null or not (
  public.gs_can_access('invoices_payments','can_view') or
  public.gs_can_access('payments_management','can_view')) then
  raise exception 'Financial reconciliation permission denied';
 end if;
 if p_order_id is null or not exists (
  select 1 from public.gs_orders o where o.id=p_order_id) then
  raise exception 'Order not found';
 end if;
 select coalesce(sum(i.line_total_iqd),0)::bigint into v_total
 from public.gs_order_items i where i.order_id=p_order_id;
 select coalesce(sum(c.amount_iqd),0)::bigint into v_cash
 from public.gs_cash_payments c where c.order_id=p_order_id;
 select coalesce(sum(c.amount_iqd),0)::bigint into v_matched
 from public.gs_cash_payments c
 join public.gs_cash_ledger_reconciliation_links x on x.legacy_cash_id=c.id
 join public.gs_unified_payment_ledger l on l.id=x.ledger_entry_id
 where c.order_id=p_order_id and l.order_id=c.order_id
  and l.amount_iqd=c.amount_iqd and l.entry_type='cash'
  and l.direction='credit' and l.source_system='legacy_cash';
 v_unlinked:=v_cash-v_matched;
 -- All ledger rows EXCEPT confirmed cash mirrors count once in the
 -- provisional ledger total; matched cash is already in v_cash.
 select coalesce(sum(case when l.direction='credit' then l.amount_iqd
  else -l.amount_iqd end),0)::bigint into v_ledger
 from public.gs_unified_payment_ledger l
 where l.order_id=p_order_id and not exists (
  select 1 from public.gs_cash_ledger_reconciliation_links x
  join public.gs_cash_payments c on c.id=x.legacy_cash_id
  where x.ledger_entry_id=l.id and c.order_id=l.order_id
   and c.amount_iqd=l.amount_iqd and l.entry_type='cash'
   and l.direction='credit' and l.source_system='legacy_cash');
 select (
  (select count(*) from public.gs_cash_payments c
   left join public.gs_cash_ledger_reconciliation_links x
   on x.legacy_cash_id=c.id
   where c.order_id=p_order_id and x.legacy_cash_id is null)
  + (select count(*) from public.gs_unified_payment_ledger l
    where l.order_id=p_order_id and l.entry_type='cash'
    and not exists(select 1 from public.gs_cash_ledger_reconciliation_links x
      where x.ledger_entry_id=l.id))
  + (select count(*) from public.gs_external_payment_evidence e
    where e.order_id=p_order_id)
  + (select count(*) from public.gs_owner_guest_offers g
    where g.order_id=p_order_id and g.status in ('pending','verified'))
 )::bigint into v_exceptions;
 v_provisional:=v_cash+v_ledger;
 return query select p_order_id,v_total,v_cash,v_matched,v_unlinked,
  v_ledger,v_provisional,v_total-v_provisional,v_exceptions,
  false,false,
  'PROVISIONAL ONLY: unmatched cash, external payment, credit, waivers and provider verification are not certified; do not release tables or transfer bills'::text;
end; $$;
revoke all on function public.gs_dashboard_payment_reconciliation_summary(bigint)
 from public,anon;
grant execute on function public.gs_dashboard_payment_reconciliation_summary(bigint)
 to authenticated;
-- This summary is a diagnostic, not a posting, payment, or settlement API.
