-- Upgrade 1490: independent mapping/evidence consistency report, read-only.
-- Execute in staging after earlier migrations; NOT a settlement authorization.
create or replace function public.gs_financial_independent_mapping_consistency(
 p_invoice_id uuid, p_order_id bigint)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_mapping public.gs_motel_cafe_order_identity_evidence%rowtype;
 v_approval public.gs_motel_cafe_identity_approvals%rowtype;
 v_review public.gs_financial_crosswalk_evidence%rowtype;
 v_mapping_conflicts bigint; v_review_conflicts bigint;
begin
 if auth.uid() is null or
    not coalesce(public.gs_can_access('motel_orders','can_view'),false) or
    not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Authorized motel and invoice viewer required' using errcode='42501';
 end if;
 if p_invoice_id is null or p_order_id is null or p_order_id <= 0 then
  raise exception 'Explicit invoice UUID and order bigint required' using errcode='22023';
 end if;
 if not exists(select 1 from public.gs_motel_food_finance_invoices where id=p_invoice_id) or
    not exists(select 1 from public.gs_orders where id=p_order_id) then
  raise exception 'Both source records must exist' using errcode='P0002';
 end if;
 select * into v_mapping from public.gs_motel_cafe_order_identity_evidence
  where finance_invoice_id=p_invoice_id and cafe_order_id=p_order_id;
 if v_mapping.id is not null then
  select * into v_approval from public.gs_motel_cafe_identity_approvals
   where mapping_id=v_mapping.id;
 end if;
 select * into v_review from public.gs_financial_crosswalk_evidence
  where motel_invoice_id=p_invoice_id and cafe_order_id=p_order_id;
 select count(*) into v_mapping_conflicts from public.gs_motel_cafe_order_identity_evidence
  where (finance_invoice_id=p_invoice_id or cafe_order_id=p_order_id)
   and not (finance_invoice_id=p_invoice_id and cafe_order_id=p_order_id);
 select count(*) into v_review_conflicts from public.gs_financial_crosswalk_evidence
  where (motel_invoice_id=p_invoice_id or cafe_order_id=p_order_id)
   and not (motel_invoice_id=p_invoice_id and cafe_order_id=p_order_id)
   and review_state <> 'rejected';
 return jsonb_build_object(
  'invoice_id',p_invoice_id,'order_id',p_order_id,
  'mapping_registered',v_mapping.id is not null,
  'independent_mapping_approval',coalesce(v_approval.id is not null and
   v_approval.approved_by <> v_mapping.verified_by,false),
  'separate_crosswalk_review',coalesce(v_review.id is not null and
   v_review.review_state='reviewed_unverified' and
   v_review.reviewed_by is not null and v_review.reviewed_by<>v_review.submitted_by,false),
  'mapping_conflicts',v_mapping_conflicts,
  'active_crosswalk_conflicts',v_review_conflicts,
  'identity_authoritatively_verified',false,
  'settlement_authorized',false,
  'invoice_paid',false,
  'unified_ledger_posted',false,
  'standing_cash_certified_iqd',null,
  'pending_payment_certified_iqd',null);
end $$;
revoke all on function public.gs_financial_independent_mapping_consistency(uuid,bigint) from public,anon;
grant execute on function public.gs_financial_independent_mapping_consistency(uuid,bigint) to authenticated;
