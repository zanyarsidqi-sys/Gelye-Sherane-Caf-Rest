# Upgrade 522 — Audited pre-acceptance quantity corrections

- Added `gs_correct_unaccepted_table_item_quantity` SQL RPC and staff editor.
- Requires active authenticated table-orders edit permission, open table visit, new order, unaccepted item, no station ticket, no locked invoice, and matching expected quantity.
- Locks order and item, records revision before/after snapshots including integer IQD totals from persisted unit price, and queues staff/customer notifications atomically.
- Does not permit price changes, paid invoice modifications, post-acceptance edits, or motel order changes.
- Apply migration 20261010_522 before using new editor. Flutter compile and live Supabase tests are pending.
