-- Upgrade 1478: staging-only independently approved mapping readiness view.
-- This read-only function cannot certify payment or mutate financial records.
create or replace function public.gs_financial_approved_identity_settlement_gate(p_invoice_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_review jsonb; v_approved boolean;
begin
 if auth.uid() is null or
 not coalesce(public.gs_can_access('motel_orders','can_view'),false) or
 not coalesce(public.gs_can_access('invoices_payments','can_view'),false)
 then raise exception 'Finance review access required' using errcode='42501'; end if;
 if p_invoice_id is null then raise exception 'Invoice required' using errcode='22023'; end if;
 v_review := public.gs_financial_review_approved_identity_integrity(p_invoice_id);
 v_approved := coalesce((v_review->>'identity_valid')::boolean,false);
 return jsonb_build_object(
 'identity_gate_ready',v_approved,
 'reason',case when v_approved then 'approved_identity_present' else coalesce(v_review->>'reason','identity_not_verified') end,
 'mapping_id',v_review->>'mapping_id',
 'cafe_order_id',v_review->>'cafe_order_id',
 'invoice_settled',false,'unified_ledger_posted',false,
 'dashboard_certified',false,'read_only',true);
end $$;
revoke all on function public.gs_financial_approved_identity_settlement_gate(uuid) from public,anon;
grant execute on function public.gs_financial_approved_identity_settlement_gate(uuid) to authenticated;
