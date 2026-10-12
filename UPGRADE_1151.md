# Upgrade 1151 — Executable Kitchen staging gate

Added `tools/run_kitchen_staging_gate_1151.py` to execute all four existing
staging SQL verification suites (1145, 1146, 1147, 1149) through `psql`,
parse their returned checks, and **fail closed** on any false result,
malformed output, missing file, SQL error, or absent staging confirmation.

To run on a **staging** Supabase PostgreSQL instance:

```sh
DATABASE_URL='<STAGING_POSTGRES_CONNECTION_URL>' python tools/run_kitchen_staging_gate_1151.py --staging
```

Never commit connection credentials. The gate is read-only and checks schema
and authorization wiring, **not** live business behavior, concurrency, or UI.
No database connection was provided during this upgrade. Kitchen runtime
acceptance remains 0/5 verified; Flutter compile remains untested.
Next upgrade: 1152 — staging workflow tests / fix discovered defects.
