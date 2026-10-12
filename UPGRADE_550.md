# Upgrade 550 — Kitchen revision exception resolution

- Added server-side, permission-checked case closure with mandatory 10–1000 character resolution note.
- Closure is blocked while receipt reconciliation still reports an inconsistency; no automatic receipt or financial changes.
- Row locking prevents concurrent duplicate closure. Original case evidence is retained with closing employee and timestamp.
- Expanded protected case history RPC to return closure details.
- Flutter investigation history now displays case notes and offers a Resolve action when the latest reconciliation is healthy; backend rechecks independently.

Deployment: apply migration 550 after 549. Compile Flutter and test against a staging Supabase database before production. Static inspection only; live tests not performed.
