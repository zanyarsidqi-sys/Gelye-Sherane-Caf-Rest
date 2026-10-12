-- Upgrade 1480: SAFE READ-ONLY staging verification; run with a dedicated authorized staging account.
-- No fake invoices, no writes, no certified amounts. Requires prior migrations installed.
BEGIN READ ONLY;
SELECT to_regclass('public.gs_motel_cafe_order_identity_evidence') IS NOT NULL AS mapping_table_exists,
       to_regclass('public.gs_motel_cafe_identity_approvals') IS NOT NULL AS approval_table_exists,
       to_regclass('public.gs_motel_prepaid_verified_receipts') IS NOT NULL AS verified_receipts_exists;
SELECT proname, pg_get_function_identity_arguments(oid) AS signature,
       prosecdef AS security_definer
FROM pg_proc WHERE pronamespace='public'::regnamespace
 AND proname IN ('gs_financial_approved_identity_settlement_gate',
 'gs_financial_review_approved_identity_integrity',
 'gs_financial_allocate_and_journal_verified_prepaid',
 'gs_approve_motel_cafe_identity') ORDER BY proname;
-- Deliberately no financial mutation or certification.
ROLLBACK;
