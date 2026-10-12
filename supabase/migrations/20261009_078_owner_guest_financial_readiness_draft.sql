-- Upgrade 78: Owner Guest financial-posting safety review, READ ONLY.
-- An AAL2 owner review is not an applied waiver. Never use this RPC to
-- decrease balances or report complimentary_amount_iqd as verified revenue.
create or replace function public.gs_owner_guest_financial_readiness(p_offer_id bigint)
returns table(
 offer_id bigint, order_id bigint, visit_id bigint,
 requested_amount_iqd bigint, owner_reviewed boolean,
 owner_reviewed_by uuid, owner_reviewed_at timestamptz,
 owner_review_decision text, order_total_iqd bigint,
 cash_receipt_count bigint, ledger_entry_count bigint,
 external_evidence_count bigint, conflicting_offer_count bigint,
 waiver_posted boolean, posting_permitted boolean, blocker text
)
language plpgsql stable security definer set search_path='' as $$
declare
 v_offer public.gs_owner_guest_offers%rowtype;
 v_review public.gs_owner_guest_review_attestations%rowtype;
 v_total bigint;
 v_cash bigint;
 v_ledger bigint;
 v_external bigint;
 v_conflict bigint;
 v_blocker text;
begin
 if auth.uid() is null or not public.gs_can_access('invoices_payments','can_view')
 then raise exception 'Owner Guest financial review permission denied'; end if;
 select * into v_offer from public.gs_owner_guest_offers where id=p_offer_id;
 if not found then raise exception 'Owner Guest request not found'; end if;
 select * into v_review from public.gs_owner_guest_review_attestations
  where gs_owner_guest_review_attestations.offer_id=p_offer_id;
 select coalesce(sum(i.line_total_iqd),0)::bigint into v_total
  from public.gs_order_items i where i.order_id=v_offer.order_id;
 select count(*) into v_cash from public.gs_cash_payments c
  where c.order_id=v_offer.order_id;
 select count(*) into v_ledger from public.gs_unified_payment_ledger l
  where l.order_id=v_offer.order_id;
 select count(*) into v_external from public.gs_external_payment_evidence e
  where e.order_id=v_offer.order_id;
 select count(*) into v_conflict from public.gs_owner_guest_offers g
  where g.order_id=v_offer.order_id and g.id<>v_offer.id
   and g.status in ('pending','verified');
 v_blocker:=case
  when v_offer.status<>'pending' then 'offer_not_pending'
  when v_offer.order_id is null or v_offer.table_visit_id is null then 'order_or_visit_missing'
  when not exists(select 1 from public.gs_orders o where o.id=v_offer.order_id
   and o.table_visit_id=v_offer.table_visit_id and o.is_motel=false
   and o.status<>'cancelled') then 'order_visit_mismatch'
  when v_offer.requested_amount_iqd is null or v_offer.requested_amount_iqd<=0
   or v_offer.requested_amount_iqd>v_total then 'invalid_requested_amount'
  when v_review.id is null then 'owner_review_missing'
  when v_review.decision<>'approve_for_financial_review' then 'owner_review_not_approved'
  when v_review.requested_amount_snapshot_iqd<>v_offer.requested_amount_iqd
   then 'amount_changed_after_owner_review'
  when not exists(select 1 from public.gs_owner_approval_principals p
   where p.user_id=v_review.owner_user_id and p.enabled)
   then 'owner_no_longer_authorized'
  when v_cash>0 or v_ledger>0 or v_external>0 then 'payment_allocation_unverified'
  when v_conflict>0 then 'other_owner_offer_exists'
  else 'financial_waiver_posting_not_implemented'
 end;
 return query select v_offer.id,v_offer.order_id,v_offer.table_visit_id,
  v_offer.requested_amount_iqd,(v_review.id is not null),
  v_review.owner_user_id,v_review.reviewed_at,v_review.decision,
  v_total,v_cash,v_ledger,v_external,v_conflict,
  false,false,v_blocker;
end; $$;
revoke all on function public.gs_owner_guest_financial_readiness(bigint) from public,anon;
grant execute on function public.gs_owner_guest_financial_readiness(bigint) to authenticated;
-- Deliberately no approval-posting RPC: the project lacks authoritative
-- item-level allocation, fresh owner step-up, and immutable waiver ledger.
