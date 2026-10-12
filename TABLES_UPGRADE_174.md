# Tables Upgrade 174 — Item-by-item partial payment groundwork

Created a restricted allocation table to associate *future verified*
payment ledger entries with exact order item quantities, payer names,
chair labels and collected amounts. The table has no client write grants.
Records cannot be updated or deleted.

Added `gs_preview_item_payment_allocation(order_item_id,quantity)`,
a permission-checked, read-only preview showing unit price, requested
amount, prior allocation quantity and reconciliation blockers.

**Critical:** `can_collect` is deliberately ALWAYS FALSE. Existing
legacy cash, unified ledger and external payment evidence may overlap.
Until settlement provenance, concurrency-safe allocation posting and
cashier workflows are reconciled, NO item-level payment can be collected
through this new API. This prevents misleading 'paid by customer' labels.

Future upgrades: actual reconciled allocation posting, individual
payer identity, item-level paid display, split receipts, pay-and-remain,
safe checkout, reservation/QR/mobile flows.

Tables progress: 54% estimated. 7/20 original milestones completed;
new requirements remain. ZIP integrity verified, no live DB/Flutter test.
