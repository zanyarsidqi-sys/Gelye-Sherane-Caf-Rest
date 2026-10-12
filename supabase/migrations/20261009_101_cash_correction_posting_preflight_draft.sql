-- Upgrade 101: correction posting preflight, explicitly fail-closed.
-- This does not change cash receipts, ledgers, orders, or balances.
create or replace function public.gs_cash_correction_posting_preflight(p_request_id bigint)
returns table(request_id bigint, cash_receipt_id bigint, order_id bigint,
 original_cash_iqd bigint, proposed_adjustment_iqd bigint,
 finance_review_decision text, finance_reviewer uuid,
 ledger_matches bigint, other_pending_corrections bigint,
 posting_authorized boolean, blocker text)
language plpgsql stable security definer set search_path='' as $$
declare
 v_request public.gs_cash_receipt_correction_requests%rowtype;
 v_review public.gs_cash_correction_finance_reviews%rowtype;
 v_receipt public.gs_cash_payments%rowtype;
 v_links bigint;
 v_other bigint;
 v_blocker text;
begin
 if auth.uid() is null or not (
  public.gs_can_access('invoices_payments','can_view') or
  public.gs_can_access('payments_management','can_view')) then
  raise exception 'Financial correction inspection permission denied';
 end if;
 select * into v_request from public.gs_cash_receipt_correction_requests
  where id=p_request_id;
 if not found then raise exception 'Correction request not found'; end if;
 select * into v_receipt from public.gs_cash_payments
  where id=v_request.cash_receipt_id;
 select * into v_review from public.gs_cash_correction_finance_reviews
  where correction_request_id=p_request_id;
 select count(*) into v_other from public.gs_cash_receipt_correction_requests c
  where c.cash_receipt_id=v_request.cash_receipt_id
   and c.id<>p_request_id and c.status='pending';
 -- Existing ledger linkage must be reconciled, never assumed from amount alone.
 select count(*) into v_links from public.gs_cash_ledger_reconciliation_links l
  where l.cash_receipt_id=v_request.cash_receipt_id;
 v_blocker:=case
  when v_receipt.id is null or v_receipt.order_id is distinct from v_request.order_id
   then 'receipt_order_mismatch'
  when v_request.status<>'pending' then 'request_not_pending'
  when v_review.id is null then 'finance_review_missing'
  when v_review.decision<>'approved_for_posting' then 'finance_review_not_approved'
  when v_review.adjustment_snapshot_iqd<>v_request.requested_adjustment_iqd
   then 'approved_amount_changed'
  when v_review.reviewer_id=v_request.requested_by then 'self_review_detected'
  when v_request.requested_adjustment_iqd<0 and
   -v_request.requested_adjustment_iqd>v_receipt.amount_iqd
   then 'adjustment_exceeds_receipt'
  when v_other>0 then 'another_pending_correction'
  when v_links>1 then 'multiple_ledger_matches'
  else 'trusted_posting_and_refund_execution_not_implemented'
 end;
 return query select v_request.id,v_request.cash_receipt_id,v_request.order_id,
  v_receipt.amount_iqd,v_request.requested_adjustment_iqd,
  v_review.decision,v_review.reviewer_id,v_links,v_other,
  false,v_blocker;
end; $$;
revoke all on function public.gs_cash_correction_posting_preflight(bigint)
 from public,anon;
grant execute on function public.gs_cash_correction_posting_preflight(bigint)
 to authenticated;
-- NEVER grant a correction posting endpoint based on this preflight alone.
