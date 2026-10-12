# Upgrade 557 — Replacement request validation consistency

- Adds identical positive-ID/nonnegative expected-price input validation to replacement quote and commit RPCs.
- Rejects invalid/null order-item quantities at commit, matching quote behavior.
- Preserves existing order-row locking, kitchen acknowledgment gating, price confirmation, permissions and financial evidence checks.
- Adds three static regression tests. These do not constitute live database or Flutter verification.
- Apply migration 557 after 556 in staging; test against live Supabase before production.
