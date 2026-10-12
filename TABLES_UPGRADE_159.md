# Upgrade 159 — Selected-item bill transfer REQUEST (no execution)

Tables Flutter screen adds a request dialog that selects source and destination
active visits, loads backend-eligible unpaid order items, chooses an item and
quantity, captures a reason, and submits an idempotent request through the
existing `gs_request_table_bill_transfer` RPC. The request key is a randomly
generated UUIDv4 reused for submission retries in the same dialog.

This workflow **does not transfer** guests, items, orders, money, payment
history, reservation ownership or price snapshots. Eligibility shown in the
preview is preliminary; the backend revalidates the request atomically.

Tables estimated completion: **38%**; **7 of 20** major milestones completed,
**13 remaining** (bill transfer is still in progress). ZIP integrity checked;
Flutter compilation and live Supabase testing remain pending.
