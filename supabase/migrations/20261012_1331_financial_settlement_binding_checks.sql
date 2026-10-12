-- Upgrade 1331: additional canonical ledger/visit binding diagnostics, never approve financial balances.
-- This function is additive and deliberately leaves gs_financial_live_unpaid_balances fail-closed.
-- Aggregate counts may include historical/legacy records; no customer identifiers are returned.
create or replace function public.gs_financial_reconciliation_readiness()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
 v_counts jsonb := '{}'::jsonb;
 v_active bigint; v_linked bigint; v_unbound bigint; v_inactive bigint;
 v_overlap bigint; v_motel bigint;
 v_cross_order_reversal bigint; v_excess_reversal bigint; v_visit_conflicts bigint;
begin
 if (select auth.uid()) is null or
    not coalesce(public.gs_can_access('payments_management','can_view'), false) then
   raise exception 'Payments Management viewing permission required' using errcode='42501';
 end if;
 if to_regclass('public.gs_orders') is not null and
    to_regclass('public.gs_table_visits') is not null then
   select count(*) into v_active from public.gs_table_visits where status='active';
   select count(*) into v_linked from public.gs_orders o
     join public.gs_table_visits v on v.id=o.table_visit_id
     where v.status='active' and o.status<>'cancelled' and not o.is_motel;
   select count(*) into v_unbound from public.gs_orders o
     where not o.is_motel and o.status<>'cancelled' and o.table_visit_id is null;
   select count(*) into v_inactive from public.gs_orders o
     join public.gs_table_visits v on v.id=o.table_visit_id
     where v.status<>'active' and o.status<>'cancelled' and not o.is_motel;
   v_counts := v_counts || jsonb_build_object(
     'active_visits',v_active,'active_visit_orders',v_linked,
     'unbound_cafe_orders',v_unbound,'orders_linked_to_inactive_visits',v_inactive);
 end if;
 if to_regclass('public.gs_cash_payments') is not null and
    to_regclass('public.gs_unified_payment_ledger') is not null then
   select count(*) into v_overlap from (
     select distinct c.order_id from public.gs_cash_payments c
     where exists(select 1 from public.gs_unified_payment_ledger l
                  where l.order_id=c.order_id)
   ) overlaps;
   v_counts := v_counts || jsonb_build_object('orders_with_cash_and_unified_ledger',v_overlap);
 end if;
 -- These diagnostics use existing foreign keys and immutable ledger references.
 -- They flag impossible or suspicious settlement bindings without declaring
 -- whether a customer's order is paid.
 if to_regclass('public.gs_unified_payment_ledger') is not null then
   select count(*) into v_cross_order_reversal
   from public.gs_unified_payment_ledger child
   join public.gs_unified_payment_ledger parent on parent.id=child.original_entry_id
   where child.direction='debit' and child.order_id<>parent.order_id;
   select count(*) into v_excess_reversal
   from (
     select parent.id
     from public.gs_unified_payment_ledger parent
     join public.gs_unified_payment_ledger child on child.original_entry_id=parent.id
     where child.direction='debit'
     group by parent.id,parent.amount_iqd
     having sum(child.amount_iqd)>parent.amount_iqd
   ) excessive;
   v_counts := v_counts || jsonb_build_object(
     'cross_order_reversal_links',v_cross_order_reversal,
     'over_reversed_ledger_entries',v_excess_reversal);
 end if;
 if to_regclass('public.gs_table_visits') is not null then
   select count(*) into v_visit_conflicts from (
     select table_id from public.gs_table_visits
     where status='active' group by table_id having count(*)>1
   ) conflicts;
   v_counts := v_counts || jsonb_build_object(
     'tables_with_multiple_active_visits',v_visit_conflicts);
 end if;
 if to_regclass('public.gs_motel_food_finance_invoices') is not null then
   select count(*) into v_motel from public.gs_motel_food_finance_invoices
   where payment_status='unpaid';
   v_counts := v_counts || jsonb_build_object('unpaid_motel_finance_invoices',v_motel);
 end if;
 return jsonb_build_object(
   'verified_complete',false,
   'source_tables',jsonb_build_object(
     'orders',to_regclass('public.gs_orders') is not null,
     'order_items',to_regclass('public.gs_order_items') is not null,
     'table_visits',to_regclass('public.gs_table_visits') is not null,
     'cafe_tables',to_regclass('public.gs_cafe_tables') is not null,
     'cash_payments',to_regclass('public.gs_cash_payments') is not null,
     'motel_requests',to_regclass('public.gs_motel_guest_food_requests') is not null,
     'motel_finance_invoices',to_regclass('public.gs_motel_food_finance_invoices') is not null),
   'binding_diagnostics',v_counts,
   'missing_settlement_guarantees',jsonb_build_array(
     'canonical_all_method_payment_allocations',
     'order_to_active_visit_binding',
     'online_and_motel_source_deduplication',
     'prepaid_motel_invoice_settlement',
     'refund_transfer_comp_adjustments'),
   'generated_at',now());
end; $$;
revoke all on function public.gs_financial_reconciliation_readiness() from public,anon;
grant execute on function public.gs_financial_reconciliation_readiness() to authenticated;
