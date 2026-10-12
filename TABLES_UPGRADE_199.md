# Upgrade 199 — Safe worker permission revocation

- Manager-only RPC lists active assignments by job responsibility.
- Permission UI shows per-responsibility active counts and disables revoke while jobs remain.
- Database RPC rejects revoking a capability if the employee has assigned/in-progress jobs; trigger also guards direct deletes.
- Existing capability grants, employee search, audit history and reassignment remain in place.
- Migration has **not** been executed on a live Supabase project; Flutter has **not** been compiled or integration-tested.
- Race-sensitive concurrent job claims and revocations still need production transaction testing.
- Section 02 Tables: **78% estimated**, not verified deployment.
