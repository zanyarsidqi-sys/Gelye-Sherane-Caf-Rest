# Dashboard Upgrade 59 — Join Tables & Bill Transfer Safety Preview

Implemented a **read-only** backend RPC, `gs_preview_table_bill_transfer`,
that checks active source/destination visits, occupied/non-cleaning tables,
permissions, original item prices, cash recorded against the order, pending
owner offers and overlapping transfer requests.

It returns each item with an eligibility warning and reason; the flag is
**cash-only preliminary screening**, NOT permission to execute a transfer.
No items, guests, revenue, or payments are moved by this upgrade.

**Not complete:** noncash/credit settlement verification; atomic item/quantity
splitting; idempotency; destination capacity updates; owner authorization;
UI; deployment and integration tests. Do not use as a financial gate.

Potential existing migration issues identified: 056 references a
`table_visit_id` column in `gs_owner_guest_offers` that must be verified
against actual applied migrations; all new SQL requires Supabase schema review.
