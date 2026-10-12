# Upgrade 179 — Takeaway & Delivery Intake

Added a **Takeaway & Delivery** tab within Table Orders. Customers
can request pickup or delivery without a table or reservation. Authorized
staff can record customer name, optional phone, item/quantity notes,
and delivery instructions. Recent requests are visible in a queue.

Backend RPCs enforce table_orders permissions and input validation;
direct table access is revoked. Requests are separate from financially
posted orders, and **do not** create kitchen tickets, calculate prices,
collect payment, reserve stock, or mark items delivered.

Remaining: real menu item selection, backend pricing, kitchen routing,
delivery assignment/claiming, notifications, payment reconciliation,
and end-to-end testing. Flutter compilation and live Supabase tests
not performed. ZIP integrity verified.

Tables ~60% estimated; Table Orders module now has a new intake draft
but no claim of production readiness.
