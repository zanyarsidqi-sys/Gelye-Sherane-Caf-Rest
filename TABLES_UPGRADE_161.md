# Upgrade 161 — Transfer request financial validation

Added a read-only `gs_validate_table_bill_transfer_request(request_id)` RPC.
Checks both active visits and distinct tables, request state, item quantity
and original price snapshots, changed/cancelled source orders, recorded cash,
ledger postings, external evidence, complimentary offers, overlapping requests,
and occupancy/cleaning. Returns machine-readable `blocker_codes`.

`review_passed` means only that the **known checks** returned no blockers.
`execution_permitted` is **always false**, regardless of review outcome.
This is not payment-provider verification, not an atomic transfer and not
authorization to change bills. Tests require a Supabase staging environment.

Tables: 44% estimated; 7 of 20 major milestones completed, 13 remaining.
