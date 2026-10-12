# Phase 1 — Step 7: Deployment preflight inventory

Read-only source audit. No migrations applied and no database connected.
- Migration files: 475
- Duplicate first-token version groups: 3
- Files with potentially destructive SQL patterns: 5

## Deployment blockers
1. Resolve migration version collisions against actual `supabase_migrations.schema_migrations` history; never blindly rename applied migrations.
2. Review potentially destructive SQL in staging with a database backup and explicit approval.
3. Verify separate Supabase project URLs and public keys for each application; never commit service-role keys.
4. Run migration dry run and RLS/MFA integration tests before production.

## Collision groups
- `20261009`: 126 files
- `20261010`: 284 files
- `20261011`: 65 files

## Potentially destructive statements (static text matches; inspect SQL context)
- `20261010_183_counter_draft_item_removal.sql`: `DELETE FROM`
- `20261010_294_event_scope_safety.sql`: `DELETE FROM`
- `20261010_197_worker_job_capabilities.sql`: `DELETE FROM`
- `20261010_199_active_job_capability_guards.sql`: `DELETE FROM`
- `20261009_029_recipe_ingredient_consumption.sql`: `DELETE FROM`

## Verification
- ZIP source audit only; native compilation and Supabase live verification pending.