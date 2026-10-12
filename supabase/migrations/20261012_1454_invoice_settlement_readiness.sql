-- Upgrade 1454: invoice-level source reconciliation, deliberately read-only.
-- Never infer numeric cafe-order identity from UUID motel source identifiers.
-- No payment posting, prepaid consumption, or certified IQD balance.
create or replace function public.gs_financial_invoice_settlement_readiness(p_invoice_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 v_f public.gs_motel_food_finance_invoices%rowtype;
 v_b public.gs_motel_finance_source_bridge%rowtype;
 v_line_count bigint;
 v_line_sum numeric;
 v_cash_count bigint;
 v_cash_sum numeric;
 v_credit_count bigint;
 v_credit_sum numeric;
 v_draft_count bigint;
 v_crosswalk_count bigint;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Motel and finance view permissions required' using errcode='42501';
 end if;
 if p_invoice_id is null then raise exception 'Invoice ID required' using errcode='22023'; end if;
 select * into v_f from public.gs_motel_food_finance_invoices where id=p_invoice_id;
 if not found then raise exception 'Invoice not found' using errcode='P0002'; end if;
 select count(*),coalesce(sum(amount_iqd),0) into v_line_count,v_line_sum
 from public.gs_motel_food_finance_invoice_lines where finance_invoice_id=p_invoice_id;
 select * into v_b from public.gs_motel_finance_source_bridge where finance_invoice_id=p_invoice_id;
 select count(*),coalesce(sum(amount_iqd),0) into v_cash_count,v_cash_sum
 from public.gs_motel_food_cash_settlements where finance_invoice_id=p_invoice_id;
 select count(*),coalesce(sum(j.delta_outstanding_iqd),0) into v_credit_count,v_credit_sum
 from public.gs_credit_account_journal j
 join public.gs_motel_credit_verification_requests q on q.id=j.source_request_id
 join public.gs_motel_food_payment_intent_drafts d on d.id=q.intent_id
 where d.finance_invoice_id=p_invoice_id and j.event_kind='charge';
 select count(*) into v_draft_count from public.gs_motel_food_payment_intent_drafts
 where finance_invoice_id=p_invoice_id;
 select count(*) into v_crosswalk_count from public.gs_financial_crosswalk_evidence
 where motel_invoice_id=p_invoice_id and review_state<>'rejected';
 return pg_catalog.jsonb_build_object(
  'invoice_id',p_invoice_id,'invoice_status',v_f.payment_status,
  'invoice_total_iqd',v_f.total_iqd,
  'source_lines_reconciled',v_line_count=v_f.source_count and v_line_sum=v_f.total_iqd and v_f.total_iqd>0,
  'bridge_consistent',v_b.id is not null and v_b.legacy_order_id is null
    and v_b.source_fingerprint=v_f.source_fingerprint and v_b.amount_iqd=v_f.total_iqd
    and v_b.guest_session_id=v_f.guest_session_id and v_b.room_id=v_f.room_id,
  'numeric_order_identity_verified',false,
  'active_crosswalk_candidates',v_crosswalk_count,
  'cash_receipts',v_cash_count,'cash_received_iqd',v_cash_sum,
  'credit_charges',v_credit_count,'credit_charged_iqd',v_credit_sum,
  'payment_drafts',v_draft_count,
  'cash_credit_collision',v_cash_count>0 and v_credit_count>0,
  'cash_status_consistent', (v_cash_count=1 and v_cash_sum=v_f.total_iqd and v_f.payment_status='paid_cash')
    or (v_cash_count=0 and v_f.payment_status<>'paid_cash'),
  'prepaid_allocated',false,'unified_ledger_settled',false,
  'verified_complete',false,'certified_unpaid_iqd',null);
end $$;
revoke all on function public.gs_financial_invoice_settlement_readiness(uuid) from public,anon,authenticated;
grant execute on function public.gs_financial_invoice_settlement_readiness(uuid) to authenticated;
