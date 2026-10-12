-- Upgrade 1473: run in isolated staging with real schema and authorized test JWT.
-- READ-ONLY preflight; no invented fixtures or production writes.
BEGIN READ ONLY;
DO $$ BEGIN
 IF to_regclass('public.gs_orders') IS NULL OR
 to_regclass('public.gs_motel_food_finance_invoices') IS NULL OR
 to_regclass('public.gs_motel_cafe_order_identity_evidence') IS NULL THEN
 RAISE EXCEPTION 'Missing mapping prerequisites'; END IF;
 IF to_regprocedure('public.gs_register_motel_cafe_order_identity(uuid,bigint,text,text)') IS NULL THEN
 RAISE EXCEPTION 'Identity registration function missing'; END IF;
 IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='public.gs_motel_cafe_order_identity_evidence'::regclass) THEN
 RAISE EXCEPTION 'Mapping evidence RLS not enabled'; END IF;
 IF has_table_privilege('authenticated','public.gs_motel_cafe_order_identity_evidence','INSERT') THEN
 RAISE EXCEPTION 'Direct client insertion must be denied'; END IF;
END $$;
ROLLBACK;
-- Staging-only mutation test procedure (do not run in production):
-- BEGIN;
-- SELECT public.gs_register_motel_cafe_order_identity('<REAL_INVOICE_UUID>', <REAL_ORDER_BIGINT>,
--   'STAGING-EVIDENCE-REF-123', 'Evidence independently proves this invoice and cafe order are identical');
-- Repeat and verify already_registered=true; attempt conflicting mapping and expect rejection.
-- ROLLBACK;
