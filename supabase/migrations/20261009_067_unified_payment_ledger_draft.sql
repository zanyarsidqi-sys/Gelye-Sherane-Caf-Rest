-- Upgrade 67 DRAFT: unified payment ledger foundation.
-- No payment posting RPC or migration of old cash receipts is enabled.
-- A ledger row is not payment verification; only trusted server writers may post.
create table if not exists public.gs_unified_payment_ledger (
 id bigint generated always as identity primary key,
 order_id bigint not null references public.gs_orders(id) on delete restrict,
 entry_type text not null check(entry_type in ('cash','card','online','credit','owner_waiver','refund','reversal')),
 amount_iqd bigint not null check(amount_iqd > 0),
 direction text not null check(direction in ('credit','debit')),
 source_system text not null,
 source_reference text not null,
 verified_at timestamptz not null,
 posted_at timestamptz not null default now(),
 posted_by uuid references auth.users(id),
 original_entry_id bigint references public.gs_unified_payment_ledger(id),
 unique(source_system,source_reference),
 check ((entry_type in ('refund','reversal')) = (direction='debit')),
 check ((entry_type in ('refund','reversal')) = (original_entry_id is not null))
);
create index if not exists gs_unified_ledger_order_idx
 on public.gs_unified_payment_ledger(order_id,posted_at,id);
alter table public.gs_unified_payment_ledger enable row level security;
revoke all on public.gs_unified_payment_ledger from public,anon,authenticated;
-- No direct grants, no client posting endpoint. Trusted verification +
-- shared order-row lock + balance enforcement are future prerequisites.

create or replace function public.gs_dashboard_unified_ledger_diagnostic(p_order_id bigint)
returns table(order_id bigint, order_total_iqd bigint,
 legacy_cash_iqd bigint, new_ledger_net_iqd bigint,
 unverified_external_count bigint, legacy_cash_present boolean,
 ledger_entries bigint, settlement_confirmed boolean, warning text)
language plpgsql stable security definer set search_path='' as $$
declare v_total bigint; v_cash bigint; v_net bigint; v_unverified bigint; v_entries bigint;
begin
 if auth.uid() is null or not (
  public.gs_can_access('invoices_payments','can_view') or
  public.gs_can_access('payments_management','can_view')) then
  raise exception 'Financial diagnostic access denied';
 end if;
 if not exists(select 1 from public.gs_orders where id=p_order_id) then
  raise exception 'Order not found'; end if;
 select coalesce(sum(line_total_iqd),0)::bigint into v_total
  from public.gs_order_items where gs_order_items.order_id=p_order_id;
 select coalesce(sum(amount_iqd),0)::bigint into v_cash
  from public.gs_cash_payments where gs_cash_payments.order_id=p_order_id;
 select coalesce(sum(case when direction='credit' then amount_iqd else -amount_iqd end),0)::bigint,
  count(*)::bigint into v_net,v_entries
  from public.gs_unified_payment_ledger where gs_unified_payment_ledger.order_id=p_order_id;
 select count(*)::bigint into v_unverified from public.gs_external_payment_evidence
  where gs_external_payment_evidence.order_id=p_order_id
   and verification_status<>'verified';
 return query select p_order_id,v_total,v_cash,v_net,v_unverified,(v_cash>0),v_entries,
  false, -- NEVER certify settlement while migration and provider reconciliation are incomplete.
  case when v_cash>0 and v_entries>0 then
   'POTENTIAL_DOUBLE_COUNT: legacy cash and new ledger coexist; do not add totals'
   when v_unverified>0 then 'Unverified external payment evidence exists'
   else 'Migration incomplete: ledger cannot certify settlement' end::text;
end; $$;
revoke all on function public.gs_dashboard_unified_ledger_diagnostic(bigint) from public,anon;
grant execute on function public.gs_dashboard_unified_ledger_diagnostic(bigint) to authenticated;
-- Critical: do not sum legacy cash and unified ledger as both may represent
-- the same transaction. Actual transfer and checkout remain disabled.
