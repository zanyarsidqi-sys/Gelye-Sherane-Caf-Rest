# Upgrade 1466: source-backed invoice evidence and staging preflight

Added read-only, permission-checked `gs_financial_motel_invoice_evidence_status(uuid)` for Pending Payment diagnostics. It returns separate cash/credit/prepaid evidence and collision state, **not** a certified paid balance. Does not link numeric café orders to motel UUIDs.

Run migrations in staging first; then run `supabase/diagnostics/financial_evidence_staging_1466.sql` in a staging SQL session. This preflight uses `BEGIN READ ONLY` and `ROLLBACK` and will abort on missing functions or contradictory evidence. It is not a simulated payment transaction or provider verification.

Do not enable payment flags or certify Dashboard IQD totals until provider callback signature validation, authoritative café/motel mapping, atomic invoice/ledger settlement, real database integration tests, and Flutter compilation succeed.
