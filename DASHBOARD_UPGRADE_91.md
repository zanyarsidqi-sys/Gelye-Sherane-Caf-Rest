# Dashboard Upgrade 91 — Order settlement safety gate

Added `gs_order_settlement_gate(order_id)` as a **read-only** RPC for
Dashboard payment inspection. It reuses the provisional reconciliation
summary, checks whether the order is linked to a table visit, and reports
outstanding amounts and reconciliation exceptions.

All three permission outputs remain **false**:
- `financial_settlement_verified`
- `table_checkout_allowed`
- `bill_transfer_allowed`

This intentionally prevents a zero provisional balance from being mistaken
for proof of payment. No customer bill, table status, payment or refund is
changed. The transfer execution function remains disabled.

## Outstanding blockers
Authoritative cash/provider/credit posting, item-level allocations,
owner-verified financial waivers, checkout/cleaning lifecycle, and actual
atomic bill transfers must be implemented and tested before any gate opens.

Static archive validation passed. Supabase deployment, SQL execution and
Flutter compilation have not been performed.
