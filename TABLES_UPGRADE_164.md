# Tables Upgrade 164 — Transfer request payment guards

The transfer request RPC now **refuses to create a new bill-transfer
request** if the source order has *any* unified ledger posting or
external payment evidence, even if there are no cash receipts.
Existing guards for cash receipts, owner offers, active overlapping
requests, permissions, capacity and visit locks remain intact.
Item validation also rejects missing/nonpositive quantities and
missing/negative original unit prices.

Added a staging-only SQL metadata test that checks all guards exist,
anonymous request access is denied and the unsafe legacy transfer RPC
is not callable by authenticated staff.

This **does not execute bill transfers**. Existing pending requests
must be revalidated; approval and execution remain disabled.
No Supabase runtime or Flutter compilation performed.
Tables: 51% estimated, 7 completed / 13 remaining major steps.
