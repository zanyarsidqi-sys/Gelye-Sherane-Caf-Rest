# Upgrade 382 — Finance Intake Integrity

Adds an authorized read-only integrity RPC and an employee UI action to verify whether a food finance intake draft is missing, valid, or stale. Compares guest session, room, amount, source count, attestation fingerprint, and live attestation status. No unified invoice or payment is posted.

Requires applying migration 20261010_382_motel_food_intake_integrity.sql after prior migrations. Flutter compilation and live Supabase migration have not been tested in this environment.
