-- READ ONLY. Run on isolated staging as an authorized administrator.
-- Do not treat function existence as a successful payment integration test.
BEGIN READ ONLY;
SELECT current_database() AS staging_database_to_verify,
       to_regprocedure('public.gs_financial_approved_identity_settlement_gate(uuid)') IS NOT NULL AS identity_gate_exists,
       to_regprocedure('public.gs_financial_review_approved_identity_integrity(uuid)') IS NOT NULL AS identity_integrity_exists,
       to_regprocedure('public.gs_approve_motel_cafe_identity(uuid)') IS NOT NULL AS independent_approval_exists,
       to_regprocedure('public.gs_financial_allocate_and_journal_verified_prepaid(uuid)') IS NOT NULL AS atomic_prepaid_rpc_exists;
SELECT to_regclass('public.gs_motel_cafe_order_identity_evidence') IS NOT NULL AS identity_evidence_table_exists,
       to_regclass('public.gs_motel_cafe_identity_approvals') IS NOT NULL AS identity_approvals_table_exists,
       to_regclass('public.gs_motel_prepaid_settlement_journal') IS NOT NULL AS prepaid_journal_table_exists;
ROLLBACK;
-- Manual required next: with disposable staging fixture, run successful settlement,
-- replay, conflicting mapping, different-employee approval, concurrent payment,
-- and deliberate rollback tests. DO NOT run these on production.
