# Upgrade 324 — Bill aggregate integrity

- Validate total gross amount and total units across all lines, not only individual lines.
- Calculate aggregates with BigInt to avoid integer overflow during accumulation.
- Fail closed with the existing cashier-help error when aggregate limits are exceeded.
- Keep customer-facing amounts as a gross order preview, not a payable balance.

Verification: static inspection and ZIP integrity only. Flutter CLI and live Supabase were unavailable.
