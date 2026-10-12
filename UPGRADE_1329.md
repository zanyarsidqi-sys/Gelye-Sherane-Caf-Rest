# Upgrade 1329 — Financial reconciliation readiness audit

- Inspected order, table-visit, cash-payment and motel-order SQL migrations.
- Added permission-scoped read-only Supabase readiness RPC; reports schema presence, never financial amounts.
- Payments Management shows per-source readiness and explicitly blocks misleading balances.
- Dashboard records the same fail-closed contract and routes into Payments.
- No actual settlement amounts are calculated. Standing Cash and Pending Payment remain unavailable until canonical payment allocation and source reconciliation is complete.
- Flutter, PostgreSQL and live Supabase tests not run.
