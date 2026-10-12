# Upgrade 1469: provider-backed receipt ingestion adapter (not deployed)

The new Supabase Edge Function performs a **server-to-provider HTTPS transaction lookup** before inserting a verified prepaid receipt. Provider must offer a trusted authenticated GET API at PROVIDER_LOOKUP_BASE_URL/{transaction_id} returning JSON fields status=confirmed, currency=IQD, transaction_id, invoice_id, amount_iqd (integer), confirmed_at (ISO timestamp). **This is an integration contract, not proof that any particular provider supports it.**

Set SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, FINANCE_INGEST_TOKEN (random 32+ characters), PROVIDER_LOOKUP_BASE_URL, PROVIDER_API_TOKEN and PROVIDER_NAME as server-side secrets. Restrict this function to an authorized backend operator; do not expose FINANCE_INGEST_TOKEN in Flutter, browser, source control or logs. Require platform rate limiting and egress allowlisting; audit and test provider responses before deployment. Set Supabase function JWT verification appropriately for service-to-service invocation, and protect it with the independent secret.

A confirmed provider response is rechecked against an existing unpaid invoice and exact IQD total; provider transaction and invoice IDs must match. Receipt evidence is append-only. No receipt is inserted if lookup fails. No payment is allocated, invoice marked paid, or unified ledger written by this endpoint. Existing allocation RPC is a separate authorized step.

Staging: deploy prior migrations in order, configure secrets, use a mock HTTPS provider fixture, test confirmed/pending/mismatched/replay/timeout cases, run node --test tests/test_provider_receipt_1469.mjs and then PostgreSQL staging transaction tests. **No live staging/provider test has been run here.**

Rollback: do not delete attested financial evidence; disable or undeploy the Edge Function and revoke its token. Preserve prior migrations, receipts and audit history.
