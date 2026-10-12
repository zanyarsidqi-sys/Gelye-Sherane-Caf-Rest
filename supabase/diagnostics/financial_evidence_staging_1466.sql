-- Executable STAGING preflight. Read-only; safe to run with a finance admin role.
-- A failed assertion stops deployment. Does not manufacture payment proof.
BEGIN READ ONLY;
DO $$
DECLARE v_missing integer;
BEGIN
 SELECT count(*) INTO v_missing FROM (VALUES
  ('public.gs_financial_motel_invoice_evidence_status(uuid)'),
  ('public.gs_financial_allocate_verified_motel_prepaid(uuid)'),
  ('public.gs_financial_post_verified_credit_charge(uuid,text)')
 ) x(signature) WHERE to_regprocedure(x.signature) IS NULL;
 IF v_missing>0 THEN RAISE EXCEPTION 'Missing % financial functions',v_missing; END IF;
 IF EXISTS (
  SELECT 1 FROM public.gs_motel_prepaid_invoice_allocations p
  JOIN public.gs_financial_credit_invoice_charge_links c USING(finance_invoice_id)
 ) THEN RAISE EXCEPTION 'Credit/prepaid collision found'; END IF;
 IF EXISTS (
  SELECT 1 FROM public.gs_motel_prepaid_invoice_allocations p
  JOIN public.gs_motel_food_cash_settlements c USING(finance_invoice_id)
 ) THEN RAISE EXCEPTION 'Cash/prepaid collision found'; END IF;
 IF EXISTS (
  SELECT 1 FROM public.gs_motel_prepaid_invoice_allocations a
  JOIN public.gs_motel_prepaid_verified_receipts r ON r.id=a.receipt_id
  WHERE a.finance_invoice_id<>r.finance_invoice_id OR a.amount_iqd<>r.confirmed_amount_iqd
 ) THEN RAISE EXCEPTION 'Prepaid receipt allocation mismatch'; END IF;
END $$;
ROLLBACK;
