-- Upgrade 1488: READ ONLY finance staging prerequisites. Run on an isolated staging database.
-- No UPDATE, INSERT, DELETE, payment posting or paid-state certification.
SELECT current_database() AS database_name, current_user AS inspecting_role;
SELECT table_name, column_name, data_type FROM information_schema.columns
 WHERE table_schema='public' AND table_name IN
 ('gs_motel_food_finance_invoices','gs_unified_payment_ledger','gs_motel_cafe_order_identity_evidence','gs_motel_cafe_identity_approvals','gs_motel_invoice_prepaid_settlement_journal')
 ORDER BY table_name,ordinal_position;
SELECT p.proname,pg_get_function_identity_arguments(p.oid) AS args
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname IN
 ('gs_financial_approved_identity_settlement_gate','gs_financial_review_approved_identity_integrity','gs_financial_allocate_and_journal_verified_prepaid','gs_approve_motel_cafe_identity')
 ORDER BY p.proname;
SELECT c.conrelid::regclass AS table_name,c.conname,pg_get_constraintdef(c.oid) AS definition
 FROM pg_constraint c WHERE c.conrelid IN
 (to_regclass('public.gs_motel_food_finance_invoices'),to_regclass('public.gs_unified_payment_ledger'))
 ORDER BY 1,2;
