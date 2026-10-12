-- Upgrade 1482: READ-ONLY staging prerequisite inspection. Does not post money.
BEGIN READ ONLY;
SELECT current_database() AS database_name, current_user AS execution_role;
SELECT p.proname AS function_name, pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN (
 'gs_financial_approved_identity_settlement_gate',
 'gs_financial_review_approved_identity_integrity',
 'gs_financial_approved_motel_cafe_identity',
 'gs_financial_allocate_and_journal_verified_prepaid',
 'gs_financial_post_motel_prepaid_settlement')
ORDER BY p.proname;
SELECT c.relname AS table_name, c.relrowsecurity AS rls_enabled
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN (
 'gs_motel_cafe_order_identity_evidence',
 'gs_motel_cafe_identity_approvals',
 'gs_motel_prepaid_verified_receipts',
 'gs_motel_invoice_prepaid_settlement_journal',
 'gs_unified_payment_ledger')
ORDER BY c.relname;
ROLLBACK;
