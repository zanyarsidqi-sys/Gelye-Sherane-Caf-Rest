# Upgrade 692 — Product catalog pagination and session safety

- Replace 200-row catalog cap with deterministic ID-ordered pagination (500 per page; 5,000 safety ceiling).
- Check authenticated employee after each request; reject results if account changes.
- Show an explicit warning when the safety ceiling is reached; do not imply results are complete.
- Catalog remains read-only and must not be treated as actual stock availability.

## Verification limits
Static tests only. Flutter SDK and live Supabase testing are not available in this environment.
