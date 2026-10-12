-- Upgrade 1347: invalid/nonpositive motel invoice totals require manual review.
-- Upgrade 1346: read-only motel invoice source fingerprint and bridge amount collision diagnostics.
-- Never classify online orders from motel UUID invoices or expose a collectible due.
create or replace function public.gs_financial_pending_allocation_diagnostics()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_rows jsonb;
begin
 if auth.uid() is null
    or not coalesce(public.gs_can_access('payments_management','can_view'),false)
    or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
    or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
   raise exception 'Finance and motel viewing permissions required' using errcode='42501';
 end if;
 select coalesce(jsonb_agg(jsonb_build_object(
   'finance_invoice_id',i.id::text,
   'invoice_total_iqd',i.total_iqd,
   'invoice_status',i.payment_status,
   'bridge_count',b.bridge_count,
   'bridge_identity_consistent',(b.bridge_count=1 and b.bad_identity_count=0),
   'bridge_amount_mismatch',(b.amount_mismatch_count>0),
   'source_fingerprint_collision',(f.fingerprint_collision_count>0),
   'draft_intent_count',(select count(*) from public.gs_motel_food_payment_intent_drafts d where d.finance_invoice_id=i.id),
   'review_plan_count',(select count(*) from public.gs_motel_food_payment_allocation_plans p where p.finance_invoice_id=i.id),
   'confirmed_cash_settlement_count',c.settlement_count,
   'confirmed_cash_settlement_iqd',c.cash_total,
   'cash_evidence_exceeds_invoice',(c.cash_total>i.total_iqd),
   'invalid_cash_settlement_amount',(c.invalid_cash_amount_count>0),
   'invalid_invoice_total',(i.total_iqd is null or i.total_iqd<=0),
   'requires_manual_review',(b.bridge_count<>1 or b.bad_identity_count<>0 or
       f.fingerprint_collision_count>0 or b.amount_mismatch_count>0 or
       c.invalid_cash_amount_count>0 or i.total_iqd is null or i.total_iqd<=0 or c.cash_total>i.total_iqd),
   'identity_verified',false,
   'collection_eligible',false
 ) order by i.posted_at desc,i.id),'[]'::jsonb) into v_rows
 from (select id,total_iqd,payment_status,posted_at,guest_session_id,room_id,source_fingerprint
       from public.gs_motel_food_finance_invoices order by posted_at desc,id limit 200) i
 cross join lateral (
   select count(*)::bigint as bridge_count,
          count(*) filter (where b.guest_session_id is distinct from i.guest_session_id
             or b.room_id is distinct from i.room_id
             or b.source_fingerprint is distinct from i.source_fingerprint
             or b.amount_iqd is distinct from i.total_iqd
             or b.legacy_order_id is not null)::bigint as bad_identity_count,
          count(*) filter (where b.amount_iqd is distinct from i.total_iqd)::bigint as amount_mismatch_count
   from public.gs_motel_finance_source_bridge b where b.finance_invoice_id=i.id
 ) b
 cross join lateral (
   select count(*)::bigint as fingerprint_collision_count
   from public.gs_motel_food_finance_invoices other
   where other.id<>i.id and other.source_fingerprint=i.source_fingerprint
 ) f
 cross join lateral (
   select count(*)::bigint as settlement_count,
          coalesce(sum(c.amount_iqd),0)::bigint as cash_total,
          count(*) filter (where c.amount_iqd is null or c.amount_iqd<=0)::bigint as invalid_cash_amount_count
   from public.gs_motel_food_cash_settlements c where c.finance_invoice_id=i.id
 ) c;
 return jsonb_build_object('verified_complete',false,'collection_enabled',false,
   'online_classified',false,'motel_allocation_diagnostics',v_rows,
   'warning','Read-only source fingerprint/bridge and invalid cash evidence checks. No all-method due or provider-confirmed online identity; refunds, prepaid packages and credits are not allocated.');
end; $$;
revoke all on function public.gs_financial_pending_allocation_diagnostics() from public,anon;
grant execute on function public.gs_financial_pending_allocation_diagnostics() to authenticated;
