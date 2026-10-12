# Upgrade 1370 — Dashboard cash reconciliation footer

Adds a read-only recorded-cash sum and order count **below** the order list on the existing Dashboard cash reconciliation screen. Only nonnegative integral cash-paid amounts are accepted; malformed values cause the total to show Unavailable rather than a misleading partial amount. No new backend calls, permissions, payments, print or save actions. This is a cash-only diagnostic, not total revenue.

Validation: ZIP CRC and archive preservation, static source checks. Flutter compilation and live Supabase/RLS tests are not yet run.
