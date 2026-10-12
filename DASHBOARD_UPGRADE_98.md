# Dashboard Upgrade 98 — Legacy cash receipt integrity

## Implemented
The legacy cash receipts table (`gs_cash_payments`) now has an append-only
trigger for **all** receipts. Previously, Upgrade 83 blocked modification
only when a receipt was linked to a unified-ledger record. This closes the
integrity gap for **unmatched** receipts as well.

- Prevents UPDATE and DELETE of recorded cash receipts.
- Preserves existing records and existing receipt INSERT behavior.
- Leaves authorized correction/refund posting unimplemented rather than
  silently changing financial history.
- Does not certify cash, authorize checkout, transfer bills, or mark an
  Owner Guest offer as financially waived.

## Required staging checks
1. Apply the complete migration sequence on a disposable database.
2. Verify existing receipts can be read, and authorized cash collection
   can still insert a new receipt.
3. Confirm UPDATE and DELETE fail for both matched and unmatched receipts.
4. Confirm RLS, permissions, and all affected cash reconciliation reports.
5. Design a proper compensating-entry workflow for mistaken cash receipts.

**Testing:** ZIP CRC and source presence verified only. No SQL execution,
Flutter compilation or production deployment.
