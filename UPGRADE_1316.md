# Upgrade 1316 — Dashboard / Payments ledger guardrails

- Dashboard recorded-cash card now points to ledger and receipts.
- Payments rejects negative order totals or cash-paid values as unavailable status.
- Reconciliation sample total is unavailable if any negative cash collection is returned.
- Invalid/nonpositive/nonintegral order IDs cannot open cash receipts, both at button and RPC entry point.
- Existing backend RPC, permission enforcement, routes and unrelated source files retained.
- Static archive/source checks only; Flutter/Dart compilation, live Supabase and device tests still required.
