-- Upgrade 1483: run in a dedicated, access-controlled staging database only.
-- Read-only prerequisites; no test money is posted and no production data touched.
BEGIN READ ONLY;
SELECT current_database() AS database_name, current_user AS executing_role;
SELECT to_regprocedure('public.gs_financial_approved_identity_settlement_gate(uuid)') IS NOT NULL AS approved_identity_gate_exists,
       to_regprocedure('public.gs_financial_review_approved_identity_integrity(uuid)') IS NOT NULL AS independent_identity_review_exists,
       to_regprocedure('public.gs_financial_allocate_and_journal_verified_prepaid(uuid)') IS NOT NULL AS prepaid_atomic_journal_exists,
       to_regclass('public.gs_motel_cafe_identity_approvals') IS NOT NULL AS second_person_approval_table_exists,
       to_regclass('public.gs_unified_payment_ledger') IS NOT NULL AS unified_ledger_exists;
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema='public' AND table_name IN
('gs_motel_food_finance_invoices','gs_orders','gs_unified_payment_ledger','gs_motel_cafe_order_identity_evidence','gs_motel_cafe_identity_approvals')
ORDER BY table_name, ordinal_position;
SELECT conrelid::regclass::text AS table_name, conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint WHERE conrelid IN
('public.gs_motel_food_finance_invoices'::regclass,'public.gs_unified_payment_ledger'::regclass)
ORDER BY table_name, conname;
ROLLBACK;
-- STOP: if any prerequisite is missing or invoice status supports only 'unpaid',
-- do not run a settlement write or certify Standing Cash/Pending Payment IQD.
