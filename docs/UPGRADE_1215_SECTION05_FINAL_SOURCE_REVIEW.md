# Upgrade 1215 — Section 05 final source review

## Scope
- Confirmed 8 Kitchen tabs and 8 panels in the Section 05 entry screen.
- Added mounted guards to prevent asynchronous refresh/actions after a Kitchen panel is disposed.
- Confirmed Table Orders, service tasks, delivery tasks, correction panels and Supabase migrations remain packaged.
- Source-only checks passed; no Flutter compilation, device testing, migration deployment or live Supabase testing was performed.

## Remaining before production
1. Compile and run Flutter on Windows/iPhone.
2. Apply SQL migrations in a test Supabase environment and verify permissions and RLS.
3. Verify Kitchen, Table Orders, replacement billing, waste, station delivery and printing end to end.
4. Obtain design approval; do not proceed to Section 06 until approved.

Section 05 source milestone can be treated as coding review complete, NOT production-ready or fully verified.
