-- STAGING ONLY: run in a rolled-back transaction; never apply to production.
BEGIN;
DO $$ BEGIN
 IF to_regclass('public.gs_motel_invoice_prepaid_settlement_journal') IS NULL THEN
  RAISE EXCEPTION 'Journal table missing'; END IF;
 IF to_regprocedure('public.gs_financial_post_motel_prepaid_settlement(uuid)') IS NULL THEN
  RAISE EXCEPTION 'Posting function missing'; END IF;
 IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='public.gs_motel_invoice_prepaid_settlement_journal'::regclass)
 THEN RAISE EXCEPTION 'RLS disabled'; END IF;
 IF has_table_privilege('authenticated','public.gs_motel_invoice_prepaid_settlement_journal','INSERT')
 THEN RAISE EXCEPTION 'Direct client insert allowed'; END IF;
END $$;
-- Unauthorized caller must fail without writing anything.
DO $$ BEGIN
 BEGIN
  PERFORM public.gs_financial_post_motel_prepaid_settlement(NULL::uuid);
  RAISE EXCEPTION 'Unexpected unauthorized/null allocation success';
 EXCEPTION WHEN insufficient_privilege OR invalid_parameter_value THEN NULL;
 END;
END $$;
ROLLBACK;
