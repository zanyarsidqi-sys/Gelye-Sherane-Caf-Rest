-- Upgrade 1491: read-only staging test plan. Execute with psql ON_ERROR_STOP=1.
-- This script is NOT a claim of staging execution. It intentionally makes no writes.
BEGIN READ ONLY;
DO $$
DECLARE missing text;
BEGIN
 SELECT string_agg(required.name, ', ') INTO missing FROM (
  VALUES ('gs_financial_independent_mapping_consistency'),
         ('gs_financial_crosswalk_settlement_readiness'),
         ('gs_financial_approved_identity_settlement_gate')
 ) AS required(name)
 WHERE NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                   WHERE n.nspname='public' AND p.proname=required.name);
 IF missing IS NOT NULL THEN RAISE EXCEPTION 'Staging prerequisites missing: %', missing; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint c JOIN pg_class t ON t.oid=c.conrelid
                JOIN pg_namespace n ON n.oid=t.relnamespace
                WHERE n.nspname='public' AND t.relname='gs_motel_food_finance_invoices'
                  AND c.contype='c') THEN
   RAISE EXCEPTION 'Invoice check constraints must be inspected before paid-state migration';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                WHERE table_schema='public' AND table_name='gs_unified_payment_ledger') THEN
   RAISE EXCEPTION 'Unified payment ledger missing';
 END IF;
 RAISE NOTICE 'Prerequisite objects present; mapping conflict behavior and settlement still NOT certified';
END $$;
ROLLBACK;
