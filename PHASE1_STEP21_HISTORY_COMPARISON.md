# Phase 1 Step 21 — Read-only migration history comparison (Rest)

The script checks migration source hashes and optionally compares a user-provided Supabase migration history export. It never connects to Supabase and never applies SQL.

Run: `python tools/phase1_step21_compare_history.py`

After obtaining an authorized CSV export with `version` column, run: `python tools/phase1_step21_compare_history.py --history path/to/history.csv`. Keep exports containing sensitive details outside the ZIP.

A successful comparison does not authorize deployment or establish actual database ownership, RLS, MFA or isolated environment separation. Two distinct Supabase project IDs must be confirmed independently.
