# Phase 1 Step 13 — Isolated migration preparation (Rest)

- Offline verification: PASS: 475 immutable SQL sources, unique staged filenames; NO database accessed
- Disposable staging: Staged 475 migration copies at /tmp/tmpkil4wir0/stage/supabase/migrations; NO database accessed
- Original migration files unchanged. No database connected or executed.
- Run `python tools/phase1_step13_prepare_isolated_migrations.py --output /path/to/empty/tempdir` to generate copies for a **new disposable** database only.
- Do not apply to an existing Supabase database without reconciling migration history.
- Outstanding: real isolated SQL execution, migration collision reconciliation, RLS/MFA, native builds.
