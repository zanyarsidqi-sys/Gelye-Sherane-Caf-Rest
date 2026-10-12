-- Upgrade 1467: fail-closed invoice evidence readiness for financial reconciliation.
-- No financial writes, paid-state changes, inferred order identifiers or dashboard certification.
create or replace function public.gs_financial_motel_invoice_settlement_readiness(p_invoice_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 v jsonb; v_cash bigint; v_credit bigint; v_prepaid bigint; v_count integer;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
    or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
   raise exception 'Motel and invoice payment view permissions required' using errcode='42501';
 end if;
 if p_invoice_id is null then raise exception 'Invoice required' using errcode='22023'; end if;
 v := public.gs_financial_motel_invoice_evidence_status(p_invoice_id);
 v_cash := coalesce((v->>'cash_settlement_count')::bigint,0);
 v_credit := coalesce((v->>'credit_charge_count')::bigint,0);
 v_prepaid := coalesce((v->>'prepaid_allocation_count')::bigint,0);
 v_count := (case when v_cash>0 then 1 else 0 end)
          + (case when v_credit>0 then 1 else 0 end)
          + (case when v_prepaid>0 then 1 else 0 end);
 return pg_catalog.jsonb_build_object(
   'finance_invoice_id',p_invoice_id,
   'invoice_total_iqd',v->'invoice_total_iqd',
   'source_integrity_matched',v->'source_integrity_matched',
   'cash_evidence_count',v_cash,'credit_evidence_count',v_credit,
   'prepaid_evidence_count',v_prepaid,
   'payment_method_conflict',v->'payment_method_conflict',
   'single_method_evidence',v_count=1 and coalesce((v->>'payment_method_conflict')::boolean,true)=false,
   'settlement_ready',false,
   'block_reason',case
     when coalesce((v->>'source_integrity_matched')::boolean,false)=false then 'invoice_source_unverified'
     when coalesce((v->>'payment_method_conflict')::boolean,true) then 'payment_method_conflict'
     when v_count=0 then 'no_confirmed_payment_evidence'
     when v_count>1 then 'multiple_payment_methods'
     else 'authoritative_order_crosswalk_and_unified_ledger_unverified' end,
   'invoice_settled',false,'unified_ledger_posted',false,'dashboard_certified',false);
end $$;
revoke all on function public.gs_financial_motel_invoice_settlement_readiness(uuid) from public,anon;
grant execute on function public.gs_financial_motel_invoice_settlement_readiness(uuid) to authenticated;
