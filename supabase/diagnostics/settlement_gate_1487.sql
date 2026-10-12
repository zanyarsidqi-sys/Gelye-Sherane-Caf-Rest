-- Read-only staging gate: run with a restricted role. No data changes.
-- A positive schema presence result is NOT settlement certification.
SELECT to_regclass('public.gs_motel_food_finance_invoices') IS NOT NULL AS invoices_exist,
       to_regclass('public.gs_unified_payment_ledger') IS NOT NULL AS unified_ledger_exists,
       to_regclass('public.gs_motel_cafe_identity_approvals') IS NOT NULL AS identity_approvals_exist,
       to_regclass('public.gs_motel_cafe_order_identity_evidence') IS NOT NULL AS evidence_exists;
SELECT conrelid::regclass::text AS relation_name, conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid IN (to_regclass('public.gs_motel_food_finance_invoices'),
                  to_regclass('public.gs_unified_payment_ledger'))
ORDER BY relation_name, conname;
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema='public' AND table_name IN
('gs_motel_food_finance_invoices','gs_unified_payment_ledger',
 'gs_motel_cafe_identity_approvals','gs_motel_cafe_order_identity_evidence')
ORDER BY table_name, ordinal_position;
-- Do not write settlement until schema, approval identity and idempotency verified.
