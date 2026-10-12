-- Upgrade: independently approved mapping cross-check before any proposed settlement.
-- Read-only: no order, invoice, receipt, ledger or payment status is modified.
create or replace function public.gs_financial_review_approved_identity_integrity(p_invoice_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_mapping public.gs_motel_cafe_order_identity_evidence%rowtype;
        v_approval public.gs_motel_cafe_identity_approvals%rowtype;
        v_invoice public.gs_motel_food_finance_invoices%rowtype;
        v_order_exists boolean;
        v_invoice_exists boolean;
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false)
 then raise exception 'Authorized reviewer required' using errcode='42501'; end if;
 if p_invoice_id is null then raise exception 'Invoice UUID required' using errcode='22023'; end if;
 select * into v_mapping from public.gs_motel_cafe_order_identity_evidence
 where finance_invoice_id=p_invoice_id;
 if not found then return jsonb_build_object('identity_valid',false,'reason','mapping_missing',
 'invoice_settled',false,'unified_ledger_posted',false,'dashboard_certified',false); end if;
 select * into v_approval from public.gs_motel_cafe_identity_approvals
 where mapping_id=v_mapping.id;
 if not found then return jsonb_build_object('identity_valid',false,'reason','approval_missing',
 'invoice_settled',false,'unified_ledger_posted',false,'dashboard_certified',false); end if;
 if v_approval.approved_by=v_mapping.verified_by then
 raise exception 'Self approval rejected' using errcode='23514'; end if;
 select * into v_invoice from public.gs_motel_food_finance_invoices where id=p_invoice_id;
 v_invoice_exists := found;
 select exists(select 1 from public.gs_orders where id=v_mapping.cafe_order_id) into v_order_exists;
 if not v_invoice_exists or not v_order_exists then
 return jsonb_build_object('identity_valid',false,'reason','source_record_missing',
 'invoice_settled',false,'unified_ledger_posted',false,'dashboard_certified',false); end if;
 return jsonb_build_object('identity_valid',true,'mapping_id',v_mapping.id,
 'approval_id',v_approval.id,'motel_invoice_id',p_invoice_id,
 'cafe_order_id',v_mapping.cafe_order_id,
 'review_only',true,'invoice_settled',false,'unified_ledger_posted',false,'dashboard_certified',false);
end $$;
revoke all on function public.gs_financial_review_approved_identity_integrity(uuid) from public,anon;
grant execute on function public.gs_financial_review_approved_identity_integrity(uuid) to authenticated;
