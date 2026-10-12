# Upgrade 1312 — Dashboard cash card + linked Payments reconciliation

- Dashboard card explicitly states that recorded cash is cash-only; navigation continues to payments_management.
- Payments Management rejects non-finite, fractional, unsafe-size and missing financial values instead of truncating them or displaying false zeroes.
- A ledger with invalid cash amounts displays an unavailable sample total rather than a misleading partial sum.
- Added a filter for records with unavailable amounts.
- Preserved existing receipts, payment RPCs, permissions, routing, and unrelated source files.
- Archive/source checks passed; Flutter compilation, live Supabase and iPhone runtime tests are NOT verified.
