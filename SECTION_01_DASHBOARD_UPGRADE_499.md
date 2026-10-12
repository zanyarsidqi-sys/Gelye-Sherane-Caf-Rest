# Upgrade 499 — Dashboard cash-source consistency

- Compare today’s independently fetched daily cash RPC with the matching Iraq business date in the seven-day cash RPC.
- Compare both IQD amounts and receipt counts for table orders and motel-food separately.
- Detect conflicting values, missing or restricted fields, inconsistent business dates and inaccessible sources without guessing zeros.
- Show a snapshot time gap; clearly label as a source-consistency check, **not** accounting reconciliation.
- No schema or authorization changes; existing backend permissions remain in force.

Verification: ZIP integrity and duplicate-entry check only. Flutter build, analyzer, and live Supabase integration not run.
