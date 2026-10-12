# Upgrade 1349 — Standing Cash receipt integrity

Added a read-only, permission-checked Supabase diagnostic `gs_standing_cash_receipt_integrity(bigint)` to inspect legacy cash receipt count, amount and duplicate references per order. It does not write payments, authorize collections, or certify full settlement. Pending Payment motel collection remains disabled.

## Verification
Static ZIP integrity verified. Live Supabase migration, authorization/RLS integration, Flutter build, and transaction tests **not run**. Apply in staging and verify before production.
