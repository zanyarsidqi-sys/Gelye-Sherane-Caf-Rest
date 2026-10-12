-- Upgrade 91: fail-closed settlement gate for table orders (read-only).
-- Never infer a settled bill from provisional totals.
create or replace function public.gs_order_settlement_gate(p_order_id bigint)
returns table(order_id bigint,order_total_iqd bigint,provisional_net_iqd bigint,
 provisional_remaining_iqd bigint,reconciliation_exceptions bigint,
 financial_settlement_verified boolean,table_checkout_allowed boolean,
 bill_transfer_allowed boolean,blocking_reason text)
language plpgsql stable security definer set search_path='' as $$
declare v record; v_linked_visit bigint;
begin
 if auth.uid() is null or not (
  public.gs_can_access('invoices_payments','can_view') or
  public.gs_can_access('payments_management','can_view')) then
  raise exception 'Financial settlement inspection permission denied';
 end if;
 select o.table_visit_id into v_linked_visit from public.gs_orders o
 where o.id=p_order_id;
 if not found then raise exception 'Order not found'; end if;
 select * into v from public.gs_dashboard_payment_reconciliation_summary(p_order_id);
 if not found then raise exception 'Reconciliation summary unavailable'; end if;
 return query select p_order_id,v.order_total_iqd,v.provisional_net_iqd,
  v.apparent_remaining_iqd,v.reconciliation_exceptions,
  false,false,false,
  case
   when v_linked_visit is null then 'BLOCKED: order has no authoritative table visit'
   when v.reconciliation_exceptions>0 then 'BLOCKED: unresolved payment reconciliation exceptions'
   when v.provisional_net_iqd>v.order_total_iqd then 'BLOCKED: provisional overpayment'
   when v.apparent_remaining_iqd>0 then 'BLOCKED: provisional outstanding balance'
   else 'BLOCKED: provisional figures do not certify provider, cash, credit or waiver settlement'
  end::text;
end; $$;
revoke all on function public.gs_order_settlement_gate(bigint) from public,anon;
grant execute on function public.gs_order_settlement_gate(bigint) to authenticated;
-- A true settlement decision must be issued by a separate authoritative,
-- idempotent, audited posting service. This function always returns false.
