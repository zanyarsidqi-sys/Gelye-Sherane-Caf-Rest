# Upgrade 1323 — Payments dashboard batch: ledger data warnings

- Dashboard cash-discrepancies card now explicitly directs employees to ledger review.
- Payments Management identifies malformed reconciliation rows (missing/invalid order ID, negative or non-whole IQD totals, cash and balances, invalid entry count).
- Shows a count and optional filter for these *ledger data warnings*, distinct from the server-provided `cash_discrepancies_count` metric. No unsupported equality between the two is assumed.
- Existing RPC identifiers, permission controls, receipt safeguards, and other files preserved.
- Source checks and ZIP integrity verified; Flutter compilation and live Supabase integration NOT verified.
