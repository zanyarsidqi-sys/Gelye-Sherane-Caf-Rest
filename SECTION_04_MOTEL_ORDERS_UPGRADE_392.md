# Upgrade 392 — Shared Payment Ledger Compatibility Gate

Added a read-only RPC and an employee Ledger Mapping action on payment drafts.

The existing shared payment ledger requires `gs_orders.id bigint`, whereas motel food finance invoices use UUID IDs and do not have a verified corresponding `gs_orders` row. The application must not cast the UUID, fabricate a shared order, or write to the shared ledger.

The RPC requires Motel Orders and Invoices & Payments viewing permissions and checks payment draft integrity. It always reports `mapping_required` or `blocked`, never falsely reports settlement eligibility.

No money moves, no payment is marked paid, no credit is debited.

Next: design and verify an explicit source-to-unified-invoice bridge, with a single atomic settlement writer and idempotency safeguards. Flutter compilation and live Supabase migration were not run in this environment.
