# Upgrade 332 — Reconciliation arithmetic checks

The staff-only read-only diagnostic rejects inconsistent server totals: matched cash cannot exceed recorded cash; unlinked cash must equal recorded minus matched; provisional received must equal recorded cash plus nonmirrored ledger net; remaining must equal gross minus provisional received. Uses BigInt for validation. Unresolved exceptions receive a prominent warning. No settlement permissions or financial records changed.

Verification: source inspection and ZIP integrity only. Flutter and live Supabase tests are not available in this environment.
