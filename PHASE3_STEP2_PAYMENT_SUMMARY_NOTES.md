# Phase 3 — Step 2: Order cash payment summary

This checkpoint adds migration 025, a permission-checked RPC `gs_order_cash_payment_summary(order_id)` returning order total, cash received, cash balance, cash status, and number of cash payments. Values are computed from existing order items and the cash ledger. It does not mark an order fulfilled, close a table, or assert settlement via card/credit.

## Deployment / verification remaining
1. Apply migrations in order through 025 on a staging Supabase project.
2. Confirm section permission names against the deployed permission schema.
3. Verify no unauthenticated caller can execute the RPC.
4. Test unpaid, partially paid, fully cash-paid, zero-total, unknown-order and unauthorized employee scenarios.
5. Verify concurrency with simultaneous cash collection; test Flutter compilation and all section workflows.

Historical progress baseline: 61% **estimated**, not measured. The project is not verification-only yet.
