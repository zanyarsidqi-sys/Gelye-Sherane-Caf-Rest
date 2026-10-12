# Phase 3 Step 2 — Financial review screen wiring

- Invoices & Payments now opens the existing live order review / checkout preparation panel instead of a placeholder.
- Payments Management now opens the existing reconciliation preparation panel instead of a placeholder.
- Both are intentionally read-only. Order totals are not receipts, payment settlement, or recognized revenue.
- Actual payment capture, refund, credit deduction, idempotency, authorization and settlement reconciliation are NOT implemented by this update.
- Requires authenticated Supabase access to gs_orders and gs_order_items and appropriate RLS.
- Flutter compilation and live database testing are NOT verified in this environment.
- Historical 60% progress remains an unverified estimate; this update does not justify a new overall percentage.
