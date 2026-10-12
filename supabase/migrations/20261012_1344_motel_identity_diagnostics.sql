-- Read-only invoice-to-settlement identity consistency checks.
-- No amount here is a collectible due; no unverified online/legacy order mapping.
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
   'draft_intent_count',(select count(*) from public.gs_motel_food_payment_intent_drafts d where d.finance_invoice_id=i.id),
   'review_plan_count',(select count(*) from public.gs_motel_food_payment_allocation_plans p where p.finance_invoice_id=i.id),
   'confirmed_cash_settlement_count',c.settlement_count,
   'confirmed_cash_settlement_iqd',c.cash_total,
   'cash_evidence_exceeds_invoice',(c.cash_total>i.total_iqd),
   'requires_manual_review',(b.bridge_count<>1 or b.bad_identity_count<>0 or c.cash_total>i.total_iqd),
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
             or b.legacy_order_id is not null)::bigint as bad_identity_count
   from public.gs_motel_finance_source_bridge b where b.finance_invoice_id=i.id
 ) b
 cross join lateral (
   select count(*)::bigint as settlement_count,
          coalesce(sum(c.amount_iqd),0)::bigint as cash_total
   from public.gs_motel_food_cash_settlements c where c.finance_invoice_id=i.id
 ) c;
 return jsonb_build_object('verified_complete',false,'collection_enabled',false,
   'online_classified',false,'motel_allocation_diagnostics',v_rows,
   'warning','Bridge consistency is only a diagnostic. No verified all-method due; external payments, refunds, prepaid packages and online identities remain unallocated.');
end; $$;
revoke all on function public.gs_financial_pending_allocation_diagnostics() from public,anon;
grant execute on function public.gs_financial_pending_allocation_diagnostics() to authenticated;
