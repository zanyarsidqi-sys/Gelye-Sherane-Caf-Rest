# Upgrade 409 — Credit Verification Gate

Added a read-only server-side credit verification gate per request and a staff **Verification Gate** button. Checks request, registry status, invoice/draft amount and status. Explicitly reports ownership, customer consent, authoritative balance/limit, and atomic debit as unavailable; credit settlement remains blocked. Never treat registry activation or evidence notes as authorization to charge. No actual credit provider has been connected.

Requires migration `20261010_409_motel_credit_verification_gate.sql`. ZIP structure checked; Flutter compilation and live Supabase migration were not run.
