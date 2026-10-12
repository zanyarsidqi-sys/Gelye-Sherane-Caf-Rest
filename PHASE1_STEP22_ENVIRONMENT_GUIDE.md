# Phase 1 Step 22 — Supabase environment separation and history evidence

This tool is offline and read-only. No Supabase connection is attempted. Existing SQL is unchanged.

Run `python tools/phase1_step22_verify_independence.py` to check local migration hashes.

To verify project separation, supply a **local, uncommitted** JSON evidence file with `rest_project_ref` and `sweet_project_ref` containing the two distinct 20-character Supabase project references. **Do not include keys, URLs with credentials, or passwords.** Example: `python tools/phase1_step22_verify_independence.py --evidence /secure/local/refs.json`.

To compare a separately exported history, supply `--history /secure/local/history.json`, formatted as `{"versions":["20261009120000"]}`. An empty history may represent a fresh database, not verification of migration success. A mismatch requires manual investigation; do not auto-repair migration history.

Passing these checks **does not** validate the ownership or configuration of either project. A real Supabase session, verified export, and disposable database tests are still required. This tool cannot authorize migration deployment.
