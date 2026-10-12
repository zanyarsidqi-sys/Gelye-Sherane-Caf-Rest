# Phase 1 Step 9 — migration reconciliation (Rest)

Files: 475. Colliding date-prefix groups: 20261009, 20261010, 20261011.

**Deployment remains blocked.** Supabase CLI migration versions use the filename prefix before `_`; multiple files with the same date-only prefix cannot safely be deployed as distinct migrations.

1. Obtain `supabase migration list` from the intended **separate** Supabase project.
2. Confirm whether any existing migrations have been applied. Never rename or rewrite applied migrations without a reconciled history.
3. For a new empty database only, establish dependency order, assign distinct timestamp versions, and test `supabase db reset` in a disposable environment.
4. Compare schema, RLS, auth policies, functions and data with expected contracts.
5. Back up and obtain explicit approval before any production deployment.

A SHA-256 inventory is in `PHASE1_STEP9_MIGRATION_RECONCILIATION.json`. No migration filenames or SQL bodies were changed in this step.
