# Upgrade 532 — Quantity correction concurrency and mobile confirmation

- After the second financial-preview RPC, validate that the same authorized, fresh, unaccepted order item still appears exactly once in the board before submitting the correction.
- Prevent submission if the board changed or became stale while awaiting the server recheck. The database transaction continues to enforce authorization, payment and kitchen guards.
- Make the quantity financial confirmation dialog scrollable for narrow mobile screens and large correction reasons.
- No new database migration.
- Quantity changes remain subject to migrations 522, 524, 527–530.
- Not verified by Flutter compilation or live Supabase.
