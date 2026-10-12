# Upgrade 370 — Verified Invoice Source Crosswalk Preview

Adds a read-only employee action showing exact food request IDs, staging ledger IDs, stable source keys, amounts, guest session and review fingerprint. The backend reuses the locked handoff manifest and rejects missing, stale or inconsistent reviews. No official invoice, payment, or credit posting is implemented.

Verification: archive integrity and static file inspection only. Flutter compilation and live Supabase migration have not been tested. Section 04 progress remains 73% estimated.
