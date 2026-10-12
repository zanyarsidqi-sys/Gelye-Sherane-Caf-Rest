# Dashboard Upgrade 60 — Safe Bill Transfer Request (DRAFT)

New migration 060 adds a secure, transactional request endpoint for ONE
selected order item and quantity, with an idempotency UUID.

- Permission checks for table editing and financial viewing.
- Active distinct source/destination visits and occupied-table checks.
- Stable visit locks and row locks on selected item and source order.
- Blocks cash-paid orders, owner complimentary offers, and duplicate active
  transfer requests.
- Validates requested quantity and records the staff actor and reason.
- Retries with the same UUID return the same request only if inputs match.
- Never moves orders, bills, payments, guests, or revenue.

**Not implemented:** actual transfer execution, multi-item atomic transfer,
partial payment allocation, noncash/credit verification, customer movement,
capacity adjustment, and Flutter UI. Without an authoritative settlement
ledger, applying transfers would risk double charging; this draft fails closed.
Migration must be reconciled with live schema and tested before deployment.
