# Upgrade 380 — Finance Attestation Status

Adds a read-only Supabase RPC to classify a food register finance attestation as `not_attested`, `valid`, or `stale`. Staleness checks current readiness, source-line fingerprint, source count and total. Adds a per-register status button in the Invoices & Payments motel food handoff screen. No unified invoice or payment posting.

## Verification
Archive structure and duplicate paths checked; Flutter compilation and live Supabase migrations not tested.
