# Tables Upgrade 177 — Cashier Reservation Requests

Added a cashier-accessible Flutter reservation form for name, phone,
guest count, date/time and special-request notes. Server RPC enforces
permissions, future date and input validation. Every request records
submission_channel='cashier' and submitted_by=auth.uid().

**Reservations remain pending.** Existing approval flow assigns a
capacity-compatible table and checks collisions; this UI does not
reserve a particular table or guarantee availability. Cashier cannot
bypass approval. Existing website requests default to website channel.

Notifications, preorder scheduling and choosing a specific table
before approval remain pending. Time picker uses device local time,
so timezone configuration must be checked for Iraq deployment.

Tables **59% estimated**, not deployed or Flutter-compiled. ZIP integrity
verified. Original milestone count unchanged (7/20).
