-- Upgrade 1489: read-only settlement eligibility review. No writes, no paid claims.
-- Run in a disposable staging environment after prior migrations.
create or replace function public.gs_financial_crosswalk_settlement_readiness(
 p_order_id bigint, p_invoice_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_e public.gs_financial_crosswalk_evidence%rowtype;
 v_count bigint; v_invoice public.gs_motel_food_finance_invoices%rowtype;
 v_order public.gs_orders%rowtype; v_conflicts bigint;
begin
 if auth.uid() is null or
    not coalesce(public.gs_can_access('payments_management','can_view'),false) or
    not coalesce(public.gs_can_access('motel_orders','can_view'),false) then
   raise exception 'Finance and motel viewer required' using errcode='42501';
 end if;
 if p_order_id is null or p_order_id<=0 or p_invoice_id is null then
   raise exception 'Valid order and invoice IDs required' using errcode='22023';
 end if;
 select * into v_order from public.gs_orders where id=p_order_id;
 if not found then raise exception 'Order not found' using errcode='P0002'; end if;
 select * into v_invoice from public.gs_motel_food_finance_invoices where id=p_invoice_id;
 if not found then raise exception 'Invoice not found' using errcode='P0002'; end if;
 select * into v_e from public.gs_financial_crosswalk_evidence
  where cafe_order_id=p_order_id and motel_invoice_id=p_invoice_id;
 select count(*) into v_conflicts from public.gs_financial_crosswalk_evidence
  where (cafe_order_id=p_order_id or motel_invoice_id=p_invoice_id)
    and not (cafe_order_id=p_order_id and motel_invoice_id=p_invoice_id)
    and review_state='reviewed_unverified';
 select count(*) into v_count from public.gs_order_items where order_id=p_order_id;
 return jsonb_build_object(
   'order_id',p_order_id,'invoice_id',p_invoice_id,
   'motel_order',coalesce(v_order.is_motel,false),
   'order_not_cancelled',v_order.status is distinct from 'cancelled',
   'order_has_items',v_count>0,
   'evidence_exists',v_e.id is not null,
   'independently_reviewed',coalesce(v_e.review_state='reviewed_unverified'
      and v_e.reviewed_by is not null and v_e.reviewed_by<>v_e.submitted_by,false),
   'conflicting_reviewed_links',v_conflicts,
   'identity_verified',false,
   'atomic_invoice_ledger_settlement_enabled',false,
   'invoice_paid_state_reconciled',false,
   'standing_cash_certified_iqd',null,
   'pending_payment_certified_iqd',null,
   'ready_to_settle',false,
   'reason','Evidence review is not authoritative identity confirmation. Atomic settlement and reconciliation remain blocked.');
end $$;
revoke all on function public.gs_financial_crosswalk_settlement_readiness(bigint,uuid) from public,anon;
grant execute on function public.gs_financial_crosswalk_settlement_readiness(bigint,uuid) to authenticated;
