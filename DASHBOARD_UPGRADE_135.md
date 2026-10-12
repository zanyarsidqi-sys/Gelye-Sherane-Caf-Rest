# Dashboard Upgrade 135 — Mixed-payment finance approval in Flutter

Updated the existing Dashboard cash reconciliation screen, not a new
readiness function. The order detail dialog now has an **Attest verified
mixed payment** action alongside cash-only attestation.

- Explicit confirmation warns that provider payment evidence must be
  independently verified and posted to the authoritative ledger.
- Calls `gs_attest_mixed_order_settlement(p_order_id)` from Upgrade 133.
- Server enforces finance permissions, MFA, separation of duties, exact
  amount coverage and verified provider provenance; UI cannot override it.
- Shows success/failure without leaking backend exception details.
- Refreshes the reconciliation list after success.

**This does NOT release tables, verify provider signatures, or post funds.**
The trusted provider webhook/API integration is still required. Mixed
checkout remains disabled pending visit-wide settlement revalidation.

ZIP integrity checked only; no Flutter compilation or Supabase runtime test.
