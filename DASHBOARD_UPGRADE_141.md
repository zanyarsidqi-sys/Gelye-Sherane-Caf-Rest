# Dashboard Upgrade 141 — Additive migration compatibility repair

Adds a new migration (141) that **reapplies the hardened mixed-payment
release function**, including the extra unverified-ledger, unposted-evidence,
owner-offer and accounting-correction checks introduced in Upgrade 139.
This is needed because editing the already-numbered migration 137 does not
update databases that previously applied it.

No earlier migration files are changed in this upgrade. The mixed-release
feature gate remains disabled. Before applying to a real database, check
all referenced table/column names against the actual Supabase schema,
inspect existing migration history, and run transaction/race tests.
No deployment or compilation was performed.
