-- Upgrade 243: Strict finalization eligibility gate. READ ONLY.
-- This does not change payable amounts, invoices, payment ledgers or print jobs.
-- A passing result is provisional, not authorization to settle.
create or replace function public.gs_admin_discount_finalization_readiness(p_order_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_order public.gs_orders%rowtype;
  v_draft public.gs_admin_bill_discount_drafts%rowtype;
  v_total bigint;
  v_has_item_discount boolean;
  v_payment jsonb;
  v_reason text := 'provisional_ready';
  v_current_discount bigint;
begin
  if auth.uid() is null or not exists
    (select 1 from public.gs_cafe_discount_admins where user_id=auth.uid())
  then raise exception 'Admin authorization required'; end if;
  if p_order_id is null or p_order_id <= 0 then raise exception 'Invalid order ID'; end if;
  -- Serialize eligibility evaluation with writes that lock the parent order.
  select * into v_order from public.gs_orders where id=p_order_id for update;
  if not found then raise exception 'Order not found'; end if;
  select * into v_draft from public.gs_admin_bill_discount_drafts
   where order_id=p_order_id and status='draft'
   order by approved_at desc,id desc limit 1;
  if not found then
    return jsonb_build_object('order_id',p_order_id,'status','blocked',
      'reason','no_approved_discount_draft','final_settlement_authorized',false);
  end if;
  select coalesce(sum(line_total_iqd),0)::bigint,
    coalesce(bool_or(discount_per_unit_iqd > 0),false)
    into v_total,v_has_item_discount
    from public.gs_order_items where order_id=p_order_id;
  if v_order.status::text in ('cancelled','paid','settled','closed','completed') then
    v_reason := 'order_closed_or_cancelled';
  elsif v_total <= 0 or v_total <> v_draft.source_total_iqd then
    v_reason := 'order_total_changed_reapproval_required';
  elsif v_has_item_discount and not v_draft.allow_item_discount_stacking then
    v_reason := 'item_discount_stacking_not_approved';
  elsif v_draft.bill_discount_iqd > v_total or
        v_draft.proposed_total_iqd <> v_total - v_draft.bill_discount_iqd then
    v_reason := 'draft_amount_inconsistent';
  else
    -- Recompute percentage/fixed amount to detect invalid or tampered drafts.
    v_current_discount := case when v_draft.discount_type='percent' then
      round(v_total::numeric*v_draft.discount_value/100)::bigint
      else v_draft.discount_value::bigint end;
    v_current_discount := least(v_total,v_current_discount);
    if v_current_discount <> v_draft.bill_discount_iqd then
      v_reason := 'draft_discount_no_longer_matches';
    end if;
  end if;
  -- Reuse the conservative payment-source inventory; unknown schema blocks.
  v_payment := public.gs_admin_discount_payment_reconciliation(p_order_id);
  if v_payment->>'eligibility' <> 'provisional_no_known_payment' then
    v_reason := 'payments_or_unresolved_payment_sources';
  end if;
  return jsonb_build_object(
    'order_id',p_order_id,'draft_id',v_draft.id,
    'source_total_iqd',v_total,'bill_discount_iqd',v_draft.bill_discount_iqd,
    'proposed_total_iqd',v_draft.proposed_total_iqd,
    'payment_eligibility',v_payment->>'eligibility',
    'status',case when v_reason='provisional_ready' then 'provisional_ready' else 'blocked' end,
    'reason',v_reason,'final_settlement_authorized',false,'read_only',true);
end; $$;
revoke all on function public.gs_admin_discount_finalization_readiness(bigint) from public,anon;
grant execute on function public.gs_admin_discount_finalization_readiness(bigint) to authenticated;
