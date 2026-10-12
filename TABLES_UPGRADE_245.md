# Upgrade 245 — Discounted invoice lock enforcement and read-only payable contract

- New trigger on `gs_order_items` blocks INSERT, UPDATE and DELETE when the parent order has an immutable Admin discounted invoice snapshot. Locks parent order to serialize with snapshot creation. Existing financial integrity trigger remains intact.
- New trigger on `gs_orders` blocks deletion and changes to destination, order mode or status after the snapshot is locked. This intentionally prevents normal status transitions until an audited settlement integration is implemented.
- Admin-only `gs_get_locked_discount_payable(order_id)` returns the immutable source amount, discount and final due for display; **no money moves** and the response explicitly marks payment authorization false.
- Flutter Admin Bill Discount dialog adds **View locked payable**. It is a read-only preview, not a payment button.

**Still pending:** transactionally posting cash/credit/mixed payments against the locked amount, invoice printing, settlement state transitions, all legacy writers audit, concurrent database regression tests, Flutter compilation and live Supabase tests. No live migrations applied. Use staging first.
