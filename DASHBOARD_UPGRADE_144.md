# Dashboard Upgrade 144 — Deployment security diagnostics

Added a permission-gated read-only Supabase diagnostic RPC for MFA-authenticated
finance reviewers. Checks ledger/inbox BIGINT types, feature gate disabled,
no client execution of server-only verification/posting functions, settlement
RLS and insert privileges, enabled settlement immutability/conflict triggers,
and presence of a valid inbox unique index.

The unique-index check verifies existence, not indexed columns; it must be
reviewed manually. Results are diagnostics rather than certification.
Actual deployment, migration execution, provider webhook signature validation,
transaction reconciliation and concurrency tests are still required.
No mixed-payment checkout activation was made.
