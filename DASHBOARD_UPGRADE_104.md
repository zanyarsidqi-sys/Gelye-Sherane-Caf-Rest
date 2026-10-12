# Dashboard Upgrade 104 — Integrate posted corrections into order totals

This upgrade **connects the working correction posting from Upgrade 103**
to the existing Dashboard reconciliation RPC. Earlier, posting an adjustment
had no effect on the reconciliation summary; now the provisional cash total
subtracts the immutable posted adjustment exactly once.

- Existing cash/ledger mirror exclusion is preserved.
- Matched cash totals also account for adjustments against matched receipts.
- Orders with accounting corrections gain explicit reconciliation exceptions.
- Neither an accounting adjustment nor a zero provisional balance can release
  a table, transfer an order, or certify a physical refund.
- No new request/review/preparation workflow is added.

**Example:** a 50,000 IQD receipt with a posted -10,000 IQD adjustment
appears as 40,000 IQD provisional cash, with an unresolved settlement
exception until the real-world cash/refund is independently verified.

This is SQL source integration, **not** an executed staging migration.
No Supabase deployment, Flutter compilation or device testing was performed.
