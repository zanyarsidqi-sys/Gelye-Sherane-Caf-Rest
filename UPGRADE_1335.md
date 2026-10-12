# Upgrade 1335: Financial source identity diagnostic

Added permission-gated, read-only gs_financial_order_source_identity RPC, distinguishing same-order external reference candidates, cross-order conflicts, unmatched external evidence and legacy cash without crosswalk. Added source identity inspection handler in Payments Management and Dashboard guidance. Does not certify allocations, balances or motel prepayments. Database migration and Flutter runtime tests pending.
