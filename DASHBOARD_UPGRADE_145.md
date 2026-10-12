# Upgrade 145 — Repeatable checkout source regression checks

Added `tools/check_mixed_checkout_source.py` to the full Flutter/Supabase
project. It runs 14 source-level regression checks on the verification,
ledger, deduplication, finance attestation, release, and diagnostics
migrations, including service-role gating, MFA, idempotency, release gate,
physical checkout and verification cross-checks.

Run: `python tools/check_mixed_checkout_source.py` from any directory.

**Scope:** This script checks for expected SQL source constructs; it
does not execute PostgreSQL, validate schema compatibility, simulate
concurrency, verify a real provider webhook, or certify the checkout.
Upgrade 137/141 migration-history reconciliation is still required.
The mixed checkout feature gate stays disabled.
