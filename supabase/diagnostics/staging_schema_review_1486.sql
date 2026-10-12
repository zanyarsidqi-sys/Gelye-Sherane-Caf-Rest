-- Staging-only prerequisite inspection. No production writes.
BEGIN TRANSACTION READ ONLY;
SELECT current_database() AS database_name, current_user AS executing_role;
SELECT required_object, to_regclass('public.' || required_object) IS NOT NULL AS exists_in_public
FROM (VALUES
 ('gs_motel_cafe_order_identity_evidence'),
 ('gs_motel_cafe_identity_approvals'),
 ('gs_motel_food_finance_invoices'),
 ('gs_unified_payment_ledger'),
 ('gs_motel_prepaid_verified_receipts'),
 ('gs_motel_invoice_prepaid_settlement_journal')
) AS required(required_object);
SELECT required_function, to_regprocedure('public.' || required_function) IS NOT NULL AS installed
FROM (VALUES
 ('gs_register_motel_cafe_order_identity(uuid,bigint,text,text)'),
 ('gs_approve_motel_cafe_identity(uuid)'),
 ('gs_financial_approved_identity_settlement_gate(uuid)'),
 ('gs_financial_allocate_and_journal_verified_prepaid(uuid)')
) AS required(required_function);
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema='public' AND table_name IN
 ('gs_motel_food_finance_invoices','gs_unified_payment_ledger','gs_motel_cafe_order_identity_evidence')
ORDER BY table_name, ordinal_position;
SELECT conrelid::regclass AS table_name, conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint WHERE connamespace='public'::regnamespace
 AND conrelid IN ('public.gs_motel_food_finance_invoices'::regclass,
 'public.gs_unified_payment_ledger'::regclass)
ORDER BY table_name::text, conname;
ROLLBACK;
-- Review all rows manually. Missing objects or incompatible invoice status rules BLOCK settlement deployment.
