# Upgrade 246 — Locked discounted invoice payment preparation

Adds a strictly Admin-only, transactionally serialized and idempotent **payment preparation intent** for immutable discounted invoice snapshots. Stores the correct discounted amount and links the snapshot/order under unique constraints. Checks the existing conservative payment reconciliation before first creation. Flutter Tables > Admin Bill Discount includes **Prepare payment (no charge)** and shows intent ID and amount.

**No payment capture is implemented.** No cash receipt, credit withdrawal, mixed payment, payment ledger write, invoice status transition, or physical printing occurs. Do not treat `awaiting_integration` as paid. Existing order-lock protections remain. Full financial settlement requires schema audit of every payment route and staging concurrency tests, including partial payments and credit debits. This migration and Flutter changes have not been compiled or tested against live Supabase.
