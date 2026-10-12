-- Upgrade 1476: read-only reviewer confirmation of identity evidence.
-- A second-person approval is a prerequisite for *review*, not settlement.
-- No invoice status or unified-ledger records are changed by this RPC.
create or replace function public.gs_financial_approved_motel_cafe_identity(p_invoice_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_mapping public.gs_motel_cafe_order_identity_evidence%rowtype;
        v_approval public.gs_motel_cafe_identity_approvals%rowtype;
begin
 if auth.uid() is null
    or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
    or not coalesce(public.gs_can_access('invoices_payments','can_view'),false)
 then raise exception 'Authorized reviewer required' using errcode='42501'; end if;
 if p_invoice_id is null then raise exception 'Invoice UUID required' using errcode='22023'; end if;
 select * into v_mapping from public.gs_motel_cafe_order_identity_evidence
 where finance_invoice_id=p_invoice_id;
 if not found then
   return jsonb_build_object('approved',false,'reason','no_registered_mapping',
    'invoice_settled',false,'unified_ledger_posted',false,'dashboard_certified',false);
 end if;
 select * into v_approval from public.gs_motel_cafe_identity_approvals
 where mapping_id=v_mapping.id;
 if not found then
   return jsonb_build_object('approved',false,'reason','independent_approval_missing',
    'mapping_id',v_mapping.id,'invoice_settled',false,
    'unified_ledger_posted',false,'dashboard_certified',false);
 end if;
 if v_mapping.verified_by=v_approval.approved_by then
   raise exception 'Self-approval is not valid' using errcode='23514';
 end if;
 return jsonb_build_object('approved',true,'mapping_id',v_mapping.id,
  'motel_invoice_id',p_invoice_id,'cafe_order_id',v_mapping.cafe_order_id,
  'approval_id',v_approval.id,'approved_at',v_approval.approved_at,
  'invoice_settled',false,'unified_ledger_posted',false,'dashboard_certified',false);
end $$;
revoke all on function public.gs_financial_approved_motel_cafe_identity(uuid) from public, anon;
grant execute on function public.gs_financial_approved_motel_cafe_identity(uuid) to authenticated;
