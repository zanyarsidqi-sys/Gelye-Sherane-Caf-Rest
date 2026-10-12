-- Upgrade 1479: safe staging-only schema smoke check; never run as a payment action.
-- Run in a disposable staging DB after migrations. Transaction always rolls back.
BEGIN;
DO $check$
DECLARE v_missing text;
BEGIN
  SELECT string_agg(required.name, ', ') INTO v_missing
  FROM (VALUES
    ('gs_financial_approved_identity_settlement_gate'),
    ('gs_financial_review_approved_identity_integrity'),
    ('gs_financial_approved_motel_cafe_identity'),
    ('gs_approve_motel_cafe_identity'),
    ('gs_financial_allocate_and_journal_verified_prepaid')
  ) AS required(name)
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname=required.name
  );
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'Missing financial RPCs: %', v_missing;
  END IF;
  IF to_regclass('public.gs_motel_cafe_identity_approvals') IS NULL THEN
    RAISE EXCEPTION 'Missing independent approval table';
  END IF;
  IF to_regclass('public.gs_motel_cafe_order_identity_evidence') IS NULL THEN
    RAISE EXCEPTION 'Missing identity evidence table';
  END IF;
  RAISE NOTICE 'PASS: required financial objects exist; no payments were modified';
END $check$;
ROLLBACK;
