-- STAGING ONLY. Run AFTER all migrations; requires an authorized test employee JWT.
-- A real fixture receipt UUID must refer to a provider-confirmed STAGING receipt.
-- Before running: SET gs_test.receipt_id = '<actual-staging-receipt-uuid>'; in SAME session
-- Transaction rolls back all writes; no production use.
BEGIN;
DO $$
DECLARE v_receipt uuid := current_setting('gs_test.receipt_id')::uuid; v_one jsonb; v_two jsonb;
BEGIN
 v_one := public.gs_financial_allocate_and_journal_verified_prepaid(v_receipt);
 v_two := public.gs_financial_allocate_and_journal_verified_prepaid(v_receipt);
 IF v_one->>'journal_id' IS DISTINCT FROM v_two->>'journal_id' THEN
  RAISE EXCEPTION 'Idempotency failure'; END IF;
 IF v_two->>'already_posted' IS DISTINCT FROM 'true' THEN
  RAISE EXCEPTION 'Retry not marked already posted'; END IF;
 IF v_one->>'dashboard_certified' IS DISTINCT FROM 'false' THEN
  RAISE EXCEPTION 'Unverified dashboard certification'; END IF;
END $$;
ROLLBACK;
