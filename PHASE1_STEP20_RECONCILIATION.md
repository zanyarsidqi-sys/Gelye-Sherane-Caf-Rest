# Phase 1 Step 20 — Offline migration reconciliation (Rest)

- Source migrations: 475
- Unique proposed versions: 475
- SHA-256 and source inventory: PASS
- Deliberate execution attempt: BLOCKED
- Existing Supabase migration history: NOT VERIFIED
- PostgreSQL/Supabase execution: NOT RUN

This tool never connects to a database. Proposed names apply to a **fresh disposable database only**, after independent migration-history and SQL dependency review. Do not use these filenames to repair an existing database without comparing `supabase_migrations.schema_migrations` and creating a reviewed reconciliation plan. The original SQL files have not been changed.

Run: `python tools/phase1_step20_reconcile.py` from the extracted project directory.
