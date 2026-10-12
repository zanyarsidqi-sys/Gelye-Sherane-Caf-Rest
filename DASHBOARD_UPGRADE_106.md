# Dashboard Upgrade 106 — Table checkout gate shown in Flutter

This is a **real integration** into the existing table details UI, not another
SQL-only preparation layer.

- Table details now query `gs_visit_settlement_gate` using an explicit,
  server-provided `active_visit_id` or `table_visit_id`.
- Shows linked-order counts, payment reconciliation exceptions, legacy
  unlinked-order warnings, and the backend checkout blocking reason.
- Refresh button rechecks the live backend state.
- If visit ID is missing, permissions fail or the RPC is not deployed,
  checkout remains blocked. No table-number guessing.
- No checkout/release button is exposed. Settlement, departure, cleaning
  and shisha certification still require an authoritative audited mutation.

**Integration dependency:** the dashboard table data provider must supply
`active_visit_id` to display a specific visit; the new widget handles its
absence safely. This source is not a claim of completed table checkout.

ZIP integrity validated; Flutter compilation and Supabase deployment
were not performed.
