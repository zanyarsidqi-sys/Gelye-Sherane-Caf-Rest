-- STAGING ONLY: execute after migrations with read-only finance audit role.
-- No INSERT/UPDATE/DELETE and no simulated provider confirmation.
DO $$
BEGIN
 IF EXISTS (SELECT 1 FROM public.gs_motel_prepaid_invoice_allocations p
  JOIN public.gs_financial_credit_invoice_charge_links c ON c.finance_invoice_id=p.finance_invoice_id) THEN
  RAISE EXCEPTION 'CREDIT_PREPAID_COLLISION';
 END IF;
 IF EXISTS (SELECT 1 FROM public.gs_motel_prepaid_invoice_allocations p
  JOIN public.gs_motel_food_cash_settlements c ON c.finance_invoice_id=p.finance_invoice_id) THEN
  RAISE EXCEPTION 'CASH_PREPAID_COLLISION';
 END IF;
 IF EXISTS (SELECT 1 FROM public.gs_motel_prepaid_invoice_allocations p
  JOIN public.gs_credit_account_journal j ON j.event_kind='charge'
  JOIN public.gs_motel_credit_verification_requests q ON q.id=j.source_request_id
  JOIN public.gs_motel_food_payment_intent_drafts d ON d.id=q.intent_id AND d.finance_invoice_id=p.finance_invoice_id) THEN
  RAISE EXCEPTION 'HISTORICAL_CREDIT_PREPAID_COLLISION';
 END IF;
END $$;
