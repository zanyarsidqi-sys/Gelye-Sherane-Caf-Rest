# Upgrade 148 — Transaction integrity staging assertions

Added `supabase/tests/mixed_payment_transaction_integrity.sql`, a
read-only PostgreSQL test script for real staging data. Checks duplicate
provider transaction references, duplicate ledger source references,
unverified/mismatched electronic ledger credits, mixed-attestation
arithmetic, post-approval order/cash/provider changes and disabled
mixed checkout release.

Run after migrations with a populated staging fixture database:
`psql -v ON_ERROR_STOP=1 -f supabase/tests/mixed_payment_transaction_integrity.sql`

These tests **have not run against a database** and do not simulate
concurrent sessions or payment-provider signatures. A separate two-session
concurrency harness and actual provider API integration remain necessary.
The mixed-payment release gate remains disabled.
