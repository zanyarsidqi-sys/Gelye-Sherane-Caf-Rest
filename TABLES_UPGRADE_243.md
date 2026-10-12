# Upgrade 243 — Admin bill-discount finalization readiness

Adds `gs_admin_discount_finalization_readiness(order_id)` with Admin authorization, parent-order row lock, latest draft check, current order total/discount recomputation, status validation, item discount stacking validation, and conservative payment-source reconciliation. Returns a **read-only provisional readiness** decision and always `final_settlement_authorized: false`.

The Tables Admin Bill Discount dialog includes a **Finalization check** button. No payable totals, payment records, invoice documents, or print jobs are changed. Existing payment sources not represented in the reconciliation inventory remain a deployment blocker. A passing check is **not** a financial transaction guarantee.

To complete production billing: inventory all actual payment ledgers and statuses; design an atomic, idempotent settlement transaction with appropriate locks; integrate immutable invoice snapshots and printer payloads; test partial/credit/mixed payments and race conditions. Flutter and Supabase live execution not tested.
