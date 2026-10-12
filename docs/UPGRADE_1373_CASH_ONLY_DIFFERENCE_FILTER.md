# Upgrade 1373: Cash-only difference filter

Filters Dashboard Cash Reconciliation using the existing authorized RPC `balance_iqd` field, separating positive, zero, negative and unavailable cash-only differences. Combines with cash amount and receipt count filters. The bottom total continues to sum only the displayed rows, rejecting invalid cash amounts. A cash-only difference is NOT an all-method outstanding balance. No printing, saving, or payment mutations added.

Checks: ZIP integrity, preserved archive paths and static source assertions. Flutter build and live Supabase testing not performed.
