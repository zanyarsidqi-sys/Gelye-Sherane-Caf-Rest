# Tables Upgrade 170 — Add AND Remove Chairs

Added `gs_adjust_table_chairs(table_number,delta,reason)` with positive
delta to add chairs and negative delta to remove chairs. Database row
locking, role permission, bounded adjustment, 1–50 capacity limits,
and prevention of removal below the currently recorded guest count.

Each change creates an immutable audit entry (old/new capacity, delta,
reason, employee, timestamp, optional active visit ID), accessible through
the permission-checked `gs_table_chair_history` RPC.

No order, bill, payment, customer, or visit data is deleted or reassigned.
Seat-name assignment, chair transfers between tables, and Flutter chair
controls are separate upcoming tasks. No live migration/Flutter verification.

Expanded scope (customer names, duration, date history, daily income
rankings, repeat rounds, orders/payments, chairs, exchange) requires a
new progress estimate: **48% estimated**, 7 of 20 previous major
milestones completed, with expanded tasks still outstanding.
