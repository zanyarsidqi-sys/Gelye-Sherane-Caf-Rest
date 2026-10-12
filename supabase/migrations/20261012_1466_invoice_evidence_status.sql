-- Upgrade 1466: source-backed motel invoice payment evidence status.
-- READ ONLY: no inference of numeric cafe order IDs, no payment posting,
-- no invoice paid mutation, no certified dashboard aggregates.
create or replace function public.gs_financial_motel_invoice_evidence_status(p_invoice_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 i public.gs_motel_food_finance_invoices%rowtype;
 v_source record;
 v_cash_count bigint; v_credit_count bigint; v_prepaid_count bigint;
 v_credit_amount bigint; v_prepaid_amount bigint;
 v_conflict boolean;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Motel and payment view permissions required' using errcode='42501';
 end if;
 if p_invoice_id is null then raise exception 'Invoice required' using errcode='22023'; end if;
 select * into i from public.gs_motel_food_finance_invoices where id=p_invoice_id;
 if not found then raise exception 'Invoice not found' using errcode='P0002'; end if;
 select * into v_source from public.gs_staff_check_motel_food_finance_invoice(i.id);
 select count(*) into v_cash_count from public.gs_motel_food_cash_settlements where finance_invoice_id=i.id;
 select count(*),coalesce(sum(amount_iqd),0) into v_credit_count,v_credit_amount
 from public.gs_financial_credit_invoice_charge_links where finance_invoice_id=i.id;
 select count(*),coalesce(sum(amount_iqd),0) into v_prepaid_count,v_prepaid_amount
 from public.gs_motel_prepaid_invoice_allocations where finance_invoice_id=i.id;
 v_conflict := (v_cash_count>0 and (v_credit_count>0 or v_prepaid_count>0))
  or (v_credit_count>0 and v_prepaid_count>0)
  or v_cash_count>1 or v_credit_count>1 or v_prepaid_count>1
  or (v_credit_count>0 and v_credit_amount is distinct from i.total_iqd)
  or (v_prepaid_count>0 and v_prepaid_amount is distinct from i.total_iqd);
 return pg_catalog.jsonb_build_object(
  'finance_invoice_id',i.id,'invoice_total_iqd',i.total_iqd,
  'invoice_payment_status',i.payment_status,
  'source_integrity_matched',v_source.check_status='matched',
  'cash_settlement_count',v_cash_count,
  'credit_charge_count',v_credit_count,'credit_charge_amount_iqd',v_credit_amount,
  'prepaid_allocation_count',v_prepaid_count,'prepaid_allocation_amount_iqd',v_prepaid_amount,
  'payment_method_conflict',v_conflict,
  'source_backed_evidence_only',true,'invoice_settled',false,
  'unified_ledger_posted',false,'dashboard_certified',false);
end $$;
revoke all on function public.gs_financial_motel_invoice_evidence_status(uuid) from public,anon;
grant execute on function public.gs_financial_motel_invoice_evidence_status(uuid) to authenticated;
