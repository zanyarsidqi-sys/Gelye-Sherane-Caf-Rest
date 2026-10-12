# Upgrade 242 — Read-only payment reconciliation

Adds an Admin-only `gs_admin_discount_payment_reconciliation` RPC and **Check payments** button in Tables → Admin Bill Discount. Inspects known payment/settlement sources for order-linked records and reports unknown source schemas as blockers. Does not apply bill discounts, mutate payment records, or authorize settlement. A provisional result does not prove that no payment exists in an unintegrated system.

Requires migration 240 and preceding project migrations. No live database or Flutter compilation verification has been performed.
