-- Upgrade 75: cash/ledger reconciliation crosswalk and exception report (DRAFT).
-- Never sums legacy cash and unified ledger as independent payments.
-- Crosswalk is deliberately private: only trusted migration/service operations
-- may insert after verifying that both records describe the SAME payment.
create table if not exists public.gs_cash_ledger_reconciliation_links (
 legacy_cash_id bigint primary key references public.gs_cash_payments(id) on delete restrict,
 ledger_entry_id bigint not null unique references public.gs_unified_payment_ledger(id) on delete restrict,
 reconciliation_reference text not null unique,
 created_at timestamptz not null default now(),
 created_by uuid references auth.users(id),
 check(length(btrim(reconciliation_reference))>0)
);
alter table public.gs_cash_ledger_reconciliation_links enable row level security;
revoke all on public.gs_cash_ledger_reconciliation_links from public,anon,authenticated;
-- No client write or auto-linking RPC. Requires verified migration reconciliation.

create or replace function public.gs_dashboard_cash_ledger_reconciliation(p_order_id bigint)
returns table(
 cash_receipt_id bigint, cash_amount_iqd bigint,
 linked_ledger_entry_id bigint, ledger_amount_iqd bigint,
 reconciliation_state text
)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (
  public.gs_can_access('invoices_payments','can_view') or
  public.gs_can_access('payments_management','can_view')
 ) then raise exception 'Financial reconciliation access denied'; end if;
 if p_order_id is null or not exists (
  select 1 from public.gs_orders o where o.id=p_order_id
 ) then raise exception 'Order not found'; end if;
 return query
 select c.id,c.amount_iqd,l.id,l.amount_iqd,
  case
   when x.legacy_cash_id is null then 'legacy_cash_unlinked'
   when l.id is null then 'linked_ledger_missing'
   when l.order_id<>c.order_id then 'order_mismatch'
   when l.entry_type<>'cash' or l.direction<>'credit' then 'entry_type_mismatch'
   when l.amount_iqd<>c.amount_iqd then 'amount_mismatch'
   when l.source_system<>'legacy_cash' then 'source_system_review'
   else 'matching_crosswalk_not_settlement_confirmation'
  end::text
 from public.gs_cash_payments c
 left join public.gs_cash_ledger_reconciliation_links x on x.legacy_cash_id=c.id
 left join public.gs_unified_payment_ledger l on l.id=x.ledger_entry_id
 where c.order_id=p_order_id
 order by c.id;
end; $$;
revoke all on function public.gs_dashboard_cash_ledger_reconciliation(bigint)
 from public,anon;
grant execute on function public.gs_dashboard_cash_ledger_reconciliation(bigint)
 to authenticated;

-- A crosswalk match is NOT authorization to transfer or release a table.
-- No provider callbacks, credit debits, refunds, owner waivers, or payment
-- posting are implemented here. Settlement remains fail-closed.
