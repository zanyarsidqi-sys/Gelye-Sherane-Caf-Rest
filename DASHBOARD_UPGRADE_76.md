# Dashboard Upgrade 76 — Item-level transfer preflight

Implemented a **read-only** SQL RPC `gs_table_transfer_item_preflight`.
For each requested order item it reports original order, requested quantity,
current quantity, captured unit price and transfer value, plus the number of
legacy cash receipts, unified ledger entries, external payment evidence and
pending/verified owner offers attached to the order.

The RPC checks source visit and quantity consistency, requires view permissions
for table orders and invoices/payments, and returns a specific blocker.

**No bill is moved.** `item_ready_for_transfer` is always false because no
authoritative item-level payment allocation or verified settlement exists.
The existing `gs_apply_table_bill_transfer` remains intentionally disabled.

## Next prerequisites
1. Atomic settlement posting for all payment types with verified source IDs.
2. Item-level allocation and refunds/credit/waiver adjustments.
3. Serializable/idempotent execution with locked source and destination visits.
4. Consistent preservation of original order, item prices, and payment history.
5. Supabase staging migration tests, RLS review, Flutter compilation and QA.

Archive integrity verified only. No live database execution or Flutter build.
