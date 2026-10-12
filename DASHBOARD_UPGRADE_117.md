# Dashboard Upgrade 117 — Fix a real checkout race

**Integration defect fixed:** Upgrade 115 locked existing orders during
cash-only table release, but a *new* order could potentially be inserted
for the same visit after that check. The release could then make the table
available despite a newly attached, unpaid order.

Added `gs_order_visit_checkout_race` on `gs_orders` inserts and visit
reassignments. It locks the destination visit row, requires an active
visit, and rejects an unoccupied table. The release function locks the
same visit row, so checkout and order creation now serialize at that
point. This is a concrete concurrency fix, not another readiness RPC.

**Still to review before production:** order writers that bypass
`table_visit_id`, legacy checkout entrypoints, table-level lock ordering,
reservation conflicts, and existing trigger interactions. Test
concurrent order creation vs checkout in staging. No SQL execution or
Flutter compilation was possible in this session.
