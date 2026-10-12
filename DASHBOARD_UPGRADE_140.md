# Dashboard Upgrade 140 — Mixed-checkout finance integrity diagnostics

Added a read-only, role-scoped server diagnostic that reports per-order
release blockers: contradictory attestations, post-attestation line/receipt
changes, unverified electronic ledger credits, and unposted payment evidence.

This is intentionally **diagnostic only** and does not claim that a
successful result authorizes release. The mixed-payment release feature
gate remains disabled. Actual provider-specific transaction verification,
staging schema validation and concurrency tests are outstanding.

Known source concern: Upgrade 139 edited migration 137 in the ZIP. If 137
has already been applied to a database, its altered contents do not
automatically execute. Before deployment, reconcile the live migration
history and move any unapplied hardening into a new additive migration.
No live Supabase tests or Flutter compilation were performed.
